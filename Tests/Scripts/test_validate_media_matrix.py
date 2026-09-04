from __future__ import annotations

import copy
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "Scripts"))

import media_matrix  # noqa: E402


class MediaMatrixValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest_path = PROJECT_ROOT / "Tests" / "MediaMatrix" / "manifest.json"
        cls.matrix_root = cls.manifest_path.parent
        cls.manifest = media_matrix.load_json(cls.manifest_path)

    def test_repository_manifest_is_valid_with_explicit_gaps(self) -> None:
        self.assertEqual(media_matrix.validate_manifest(self.manifest, self.matrix_root), [])

    def test_schema_declares_draft_and_matching_version(self) -> None:
        schema = media_matrix.load_json(
            self.matrix_root / "schema" / "media-matrix.schema.json"
        )
        self.assertEqual(schema["$schema"], "https://json-schema.org/draft/2020-12/schema")
        self.assertEqual(
            schema["properties"]["schema_version"]["const"],
            self.manifest["schema_version"],
        )

    def test_minimum_coverage_cells_cannot_silently_disappear(self) -> None:
        coverage_ids = {requirement["id"] for requirement in self.manifest["coverage"]}
        self.assertTrue(media_matrix.REQUIRED_COVERAGE_IDS <= coverage_ids)

    def test_smoke_subset_only_references_available_immutable_fixtures(self) -> None:
        fixture_by_id = {fixture["id"]: fixture for fixture in self.manifest["fixtures"]}
        smoke_ids = self.manifest["smoke_fixture_ids"]
        self.assertEqual(len(smoke_ids), len(set(smoke_ids)))
        self.assertGreaterEqual(len(smoke_ids), 3)
        for fixture_id in smoke_ids:
            self.assertRegex(fixture_id, r"-v[1-9][0-9]*$")
            self.assertEqual(fixture_by_id[fixture_id]["availability"], "available")

    def test_smoke_subset_rejects_unknown_fixture(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["smoke_fixture_ids"][0] = "missing-fixture-v1"
        errors = media_matrix.validate_manifest(manifest, self.matrix_root)
        self.assertTrue(any("smoke_fixture_ids: unknown fixture ID" in error for error in errors))

    def test_completion_gate_accepts_explicit_gaps_but_not_planned_cells(self) -> None:
        self.assertEqual(
            media_matrix.validate_manifest(
                self.manifest,
                self.matrix_root,
                require_complete=True,
            ),
            [],
        )
        manifest = copy.deepcopy(self.manifest)
        manifest["coverage"][0]["status"] = "planned"
        manifest["coverage"][0]["gap_reason"] = "Pending regeneration"
        errors = media_matrix.validate_manifest(
            manifest,
            self.matrix_root,
            require_complete=True,
        )
        self.assertTrue(any(error.startswith("completion: pending matrix cells") for error in errors))

    def test_duplicate_fixture_id_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["fixtures"].append(copy.deepcopy(manifest["fixtures"][0]))
        errors = media_matrix.validate_manifest(manifest, self.matrix_root)
        self.assertTrue(any("duplicate IDs" in error for error in errors))

    def test_missing_critical_video_dimension_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        del manifest["fixtures"][0]["streams"]["video"]["range"]
        errors = media_matrix.validate_manifest(manifest, self.matrix_root)
        self.assertTrue(any("missing keys: range" in error for error in errors))

    def test_unavailable_fixture_requires_explicit_gap(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        fixture = manifest["fixtures"][0]
        fixture["availability"] = "planned"
        fixture["artifact"]["sha256"] = None
        fixture["artifact"]["size_bytes"] = None
        fixture["probe"] = {"path": None, "sha256": None}
        fixture["gap"] = None
        errors = media_matrix.validate_manifest(manifest, self.matrix_root)
        self.assertTrue(any("unavailable fixtures require reason" in error for error in errors))

    def test_generation_recipe_requires_pinned_version_and_output_placeholder(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        generation = manifest["fixtures"][0]["generation"]
        generation["ffmpeg_version"] = "latest"
        generation["command"].remove("{output}")
        errors = media_matrix.validate_manifest(manifest, self.matrix_root)
        self.assertTrue(any("must match the pinned toolchain" in error for error in errors))
        self.assertTrue(any("exactly one {output}" in error for error in errors))

    def test_coverage_cannot_reference_unknown_fixture(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["coverage"][0]["fixture_ids"] = ["missing-fixture-v1"]
        errors = media_matrix.validate_manifest(manifest, self.matrix_root)
        self.assertTrue(any("unknown fixture ID" in error for error in errors))

    def test_available_fixture_hash_and_probe_are_verified(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        with tempfile.TemporaryDirectory() as temporary_name:
            matrix_root = Path(temporary_name)
            shutil.copytree(self.matrix_root / "schema", matrix_root / "schema")
            shutil.copytree(self.matrix_root / "fixtures", matrix_root / "fixtures")
            shutil.copytree(self.matrix_root / "probes", matrix_root / "probes")
            self.assertEqual(media_matrix.validate_manifest(manifest, matrix_root), [])

            manifest["fixtures"][0]["artifact"]["sha256"] = "0" * 64
            errors = media_matrix.validate_manifest(manifest, matrix_root)
            self.assertTrue(any("SHA-256 mismatch" in error for error in errors))


class MediaMatrixGenerationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.repository_manifest = media_matrix.load_json(
            PROJECT_ROOT / "Tests" / "MediaMatrix" / "manifest.json"
        )
        cls.schema_path = (
            PROJECT_ROOT
            / "Tests"
            / "MediaMatrix"
            / "schema"
            / "media-matrix.schema.json"
        )
        cls.generator = PROJECT_ROOT / "Scripts" / "generate-media-fixtures.py"

    def test_generator_publishes_atomically_and_rejects_changed_bytes(self) -> None:
        fixture_id = self.repository_manifest["fixtures"][0]["id"]
        with tempfile.TemporaryDirectory() as temporary_name:
            matrix_root = Path(temporary_name)
            (matrix_root / "schema").mkdir()
            (matrix_root / "schema" / "media-matrix.schema.json").write_bytes(
                self.schema_path.read_bytes()
            )
            planned_manifest = copy.deepcopy(self.repository_manifest)
            planned_manifest["smoke_fixture_ids"] = [fixture_id]
            planned_manifest["toolchain"]["ffmpeg"]["detected_version"] = None
            planned_manifest["toolchain"]["ffprobe"]["detected_version"] = None
            for fixture in planned_manifest["fixtures"]:
                fixture["availability"] = "planned"
                fixture["artifact"]["sha256"] = None
                fixture["artifact"]["size_bytes"] = None
                fixture["probe"] = {"path": None, "sha256": None}
                fixture["gap"] = {
                    "reason": "Test fixture is not generated yet",
                    "resolution": "Run the fake generator",
                }
            for requirement in planned_manifest["coverage"]:
                if requirement["status"] == "covered":
                    requirement["status"] = "planned"
                    requirement["gap_reason"] = "Test fixture is not generated yet"

            manifest_path = matrix_root / "manifest.json"
            manifest_path.write_text(
                json.dumps(planned_manifest, indent=2) + "\n",
                encoding="utf-8",
            )
            ffmpeg = matrix_root / "fake-ffmpeg"
            ffprobe = matrix_root / "fake-ffprobe"
            ffmpeg.write_text(
                "#!/bin/sh\n"
                "if [ \"${1:-}\" = \"-version\" ]; then\n"
                "  echo 'ffmpeg version 8.1.2 test'\n"
                "  exit 0\n"
                "fi\n"
                "for output_path do :; done\n"
                "printf 'fixture-v1' > \"$output_path\"\n",
                encoding="utf-8",
            )
            ffprobe.write_text(
                "#!/bin/sh\n"
                "if [ \"${1:-}\" = \"-version\" ]; then\n"
                "  echo 'ffprobe version 8.1.2 test'\n"
                "  exit 0\n"
                "fi\n"
                "printf '%s' '{\"streams\":["
                "{\"codec_type\":\"video\",\"codec_name\":\"h264\",\"profile\":\"High\","
                "\"pix_fmt\":\"yuv420p\",\"color_range\":\"tv\",\"color_space\":\"bt709\","
                "\"color_transfer\":null,\"color_primaries\":null,\"chroma_location\":\"left\","
                "\"field_order\":\"progressive\",\"avg_frame_rate\":\"24/1\","
                "\"bits_per_raw_sample\":\"8\"},"
                "{\"codec_type\":\"audio\",\"codec_name\":\"aac\",\"sample_rate\":\"48000\","
                "\"channels\":1}],\"format\":{}}'\n",
                encoding="utf-8",
            )
            ffmpeg.chmod(0o755)
            ffprobe.chmod(0o755)

            command = [
                sys.executable,
                str(self.generator),
                "--manifest",
                str(manifest_path),
                "--fixture",
                fixture_id,
                "--ffmpeg",
                str(ffmpeg),
                "--ffprobe",
                str(ffprobe),
            ]
            first_run = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(first_run.returncode, 0, first_run.stderr)
            generated_manifest = media_matrix.load_json(manifest_path)
            generated_fixture = generated_manifest["fixtures"][0]
            self.assertEqual(generated_fixture["availability"], "available")
            self.assertIsNone(generated_fixture["gap"])
            self.assertEqual(
                media_matrix.validate_manifest(generated_manifest, matrix_root),
                [],
            )

            ffmpeg.write_text(
                ffmpeg.read_text(encoding="utf-8").replace("fixture-v1", "fixture-v2"),
                encoding="utf-8",
            )
            second_run = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(second_run.returncode, 0)
            self.assertIn("create a new -vN fixture ID", second_run.stderr)
            self.assertEqual(
                (matrix_root / generated_fixture["artifact"]["path"]).read_bytes(),
                b"fixture-v1",
            )


if __name__ == "__main__":
    unittest.main()
