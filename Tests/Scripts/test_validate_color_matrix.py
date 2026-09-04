from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "Scripts"))

import color_matrix  # noqa: E402


class ColorMatrixValidationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.matrix_root = self.root / "matrix"
        self.results = self.root / "results"
        (self.matrix_root / "probes").mkdir(parents=True)
        self.fixture = {
            "id": "fixture-v1",
            "availability": "available",
            "probe": {"path": "probes/fixture-v1.json"},
            "streams": {
                "video": {
                    "range": "limited",
                    "primaries": "bt2020",
                    "transfer": "smpte2084",
                    "matrix": "bt2020nc",
                    "chroma_location": "top-left",
                    "bit_depth": 10,
                    "pixel_format": "yuv420p10le",
                }
            },
        }
        self.manifest_path = self.matrix_root / "manifest.json"
        self._write_json(self.manifest_path, {"fixtures": [self.fixture]})
        self._write_json(
            self.matrix_root / "probes" / "fixture-v1.json",
            {"streams": [{"codec_type": "video", "sample_aspect_ratio": "1:1"}]},
        )
        self.fields = self._valid_fields()
        self._write_result(self.fields)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    @staticmethod
    def _write_json(path: Path, value: object) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding="utf-8")

    def _write_result(self, fields: dict[str, str], status: str = "passed") -> None:
        self._write_json(
            self.results / "fixture-v1" / "result.json",
            {
                "fixtureID": "fixture-v1",
                "stages": {"color": {"status": status, "fields": fields}},
            },
        )

    @staticmethod
    def _valid_fields() -> dict[str, str]:
        values = {
            "range": "limited",
            "primaries": "bt2020",
            "transfer": "pq",
            "matrix": "bt2020NCL",
            "chromaLocation": "topLeft",
            "bitDepth": "10",
            "pixelFormat": "yuv420p10le",
            "pixelAspectRatio": "1:1",
        }
        fields: dict[str, str] = {}
        for name, value in values.items():
            fields[f"canonical.{name}"] = value
            fields[f"canonical.{name}.source"] = "stream"
            fields[f"canonical.{name}.raw"] = value
        for name in ("cleanAperture", "masteringDisplay", "contentLight"):
            fields[f"canonical.{name}"] = "unknown"
            fields[f"canonical.{name}.source"] = "unknown"
        fields["canonical.conflicts"] = ""
        fields["canonical.fallbacks"] = ""
        return fields

    def test_accepts_mapped_values_sources_and_raw_facts(self) -> None:
        count, errors, explained = color_matrix.validate(self.manifest_path, self.results)
        self.assertEqual(count, 1)
        self.assertEqual(errors, [])
        self.assertEqual(explained, [])

    def test_rejects_value_mismatch_and_missing_raw_fact(self) -> None:
        fields = copy.deepcopy(self.fields)
        fields["canonical.matrix"] = "bt2020CL"
        del fields["canonical.transfer.raw"]
        self._write_result(fields)
        _, errors, _ = color_matrix.validate(self.manifest_path, self.results)
        self.assertTrue(any("canonical.matrix expected" in error for error in errors))
        self.assertTrue(any("canonical.transfer.raw is missing" in error for error in errors))

    def test_unknown_value_requires_unknown_source(self) -> None:
        fixture = copy.deepcopy(self.fixture)
        fixture["streams"]["video"]["primaries"] = "unknown"
        self._write_json(self.manifest_path, {"fixtures": [fixture]})
        fields = copy.deepcopy(self.fields)
        fields["canonical.primaries"] = "unknown"
        fields["canonical.primaries.source"] = "stream"
        self._write_result(fields)
        _, errors, _ = color_matrix.validate(self.manifest_path, self.results)
        self.assertTrue(
            any("canonical.primaries.source expected 'unknown'" in error for error in errors)
        )

    def test_accepts_only_explicit_decoder_unavailable_unknown(self) -> None:
        fields = copy.deepcopy(self.fields)
        fields["canonical.bitDepth"] = "unknown"
        fields["canonical.bitDepth.source"] = "unknown"
        fields["canonical.bitDepth.raw"] = "0"
        fields["canonical.unknowns"] = "bitDepth(raw=0)"
        self._write_json(
            self.results / "fixture-v1" / "result.json",
            {
                "fixtureID": "fixture-v1",
                "stages": {
                    "color": {"status": "passed", "fields": fields},
                    "route": {
                        "fields": {
                            "decision": "unsupported",
                            "reasons": "software.decoder-unavailable: no decoder",
                        }
                    },
                },
            },
        )
        _, errors, explained = color_matrix.validate(self.manifest_path, self.results)
        self.assertEqual(errors, [])
        self.assertEqual(len(explained), 1)

        report = json.loads(
            (self.results / "fixture-v1" / "result.json").read_text(encoding="utf-8")
        )
        del report["stages"]["route"]
        self._write_json(self.results / "fixture-v1" / "result.json", report)
        _, errors, explained = color_matrix.validate(self.manifest_path, self.results)
        self.assertTrue(any("canonical.bitDepth expected '10'" in error for error in errors))
        self.assertEqual(explained, [])


if __name__ == "__main__":
    unittest.main()
