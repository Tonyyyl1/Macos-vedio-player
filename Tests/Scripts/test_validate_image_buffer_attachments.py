from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "Scripts"))

import image_buffer_attachments  # noqa: E402


class ImageBufferAttachmentValidationTests(unittest.TestCase):
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
                    "matrix": "smpte170m",
                    "chroma_location": "left",
                    "hdr": {
                        "mastering_display": None,
                        "max_cll": None,
                        "max_fall": None,
                    },
                }
            },
        }
        self.manifest_path = self.matrix_root / "manifest.json"
        self._write(self.manifest_path, {"fixtures": [self.fixture]})
        self._write(
            self.matrix_root / "probes" / "fixture-v1.json",
            {
                "streams": [
                    {
                        "codec_type": "video",
                        "width": 720,
                        "height": 576,
                        "sample_aspect_ratio": "1:1",
                    }
                ]
            },
        )
        self._write_result([self._diagnostic()])

    def tearDown(self) -> None:
        self.temporary.cleanup()

    @staticmethod
    def _write(path: Path, value: object) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding="utf-8")

    @staticmethod
    def _diagnostic(
        *,
        matrix: str = "6",
        chroma: str = "Left/Left",
        aperture: str = "none",
        aspect: str = "square-or-unknown",
        mastering: str = "absent",
        content_light: str = "absent",
    ) -> str:
        return (
            "[SWDecoder] output-attachments primaries=6 transfer=1 "
            f"matrix={matrix} chroma={chroma} cleanAperture={aperture} "
            f"pixelAspectRatio={aspect} masteringDisplay={mastering} "
            f"contentLight={content_light}"
        )

    def _write_result(
        self,
        diagnostics: list[str],
        route_fields: dict[str, str] | None = None,
    ) -> None:
        self._write(
            self.results / "fixture-v1" / "result.json",
            {
                "diagnostics": diagnostics,
                "stages": {"route": {"fields": route_fields or {}}},
            },
        )

    def test_accepts_matching_matrix_chroma_square_par_and_no_aperture(self) -> None:
        count, errors, explained = image_buffer_attachments.validate(
            self.manifest_path, self.results
        )
        self.assertEqual(count, 1)
        self.assertEqual(errors, [])
        self.assertEqual(explained, [])

    def test_accepts_non_square_par_and_frame_crop_aperture(self) -> None:
        probe_path = self.matrix_root / "probes" / "fixture-v1.json"
        probe = json.loads(probe_path.read_text(encoding="utf-8"))
        probe["streams"][0].update(
            {
                "sample_aspect_ratio": "16:15",
                "crop_left": 8,
                "crop_right": 8,
                "crop_top": 4,
                "crop_bottom": 12,
            }
        )
        self._write(probe_path, probe)
        self._write_result(
            [
                self._diagnostic(
                    aperture="704.0x560.0@0.0,4.0",
                    aspect="16:15",
                )
            ]
        )
        _, errors, explained = image_buffer_attachments.validate(
            self.manifest_path, self.results
        )
        self.assertEqual(errors, [])
        self.assertEqual(explained, [])

    def test_rejects_mismatches_and_conflicting_observations(self) -> None:
        self._write_result(
            [
                self._diagnostic(),
                self._diagnostic(
                    matrix="1",
                    chroma="Center/Center",
                    aperture="704.0x560.0@0.0,0.0",
                    aspect="16:15",
                ),
            ]
        )
        _, errors, _ = image_buffer_attachments.validate(
            self.manifest_path, self.results
        )
        self.assertTrue(any("matrix code expected" in error for error in errors))
        self.assertTrue(any("chroma expected" in error for error in errors))
        self.assertTrue(any("clean aperture expected" in error for error in errors))
        self.assertTrue(any("pixel aspect ratio expected" in error for error in errors))

    def test_validates_static_hdr_and_distinguishes_present_zero_from_missing(self) -> None:
        self.fixture["streams"]["video"]["hdr"] = {
            "mastering_display": "G(...)B(...)R(...)WP(...)L(...)",
            "max_cll": 0,
            "max_fall": 0,
        }
        self._write(self.manifest_path, {"fixtures": [self.fixture]})
        self._write_result([
            self._diagnostic(
                mastering="present(24B)",
                content_light="MaxCLL=0,MaxFALL=0",
            )
        ])
        _, errors, explained = image_buffer_attachments.validate(
            self.manifest_path, self.results
        )
        self.assertEqual(errors, [])
        self.assertEqual(explained, [])

        self._write_result([self._diagnostic()])
        _, errors, _ = image_buffer_attachments.validate(
            self.manifest_path, self.results
        )
        self.assertTrue(any("mastering display expected" in error for error in errors))
        self.assertTrue(any("content light expected" in error for error in errors))

    def test_decoder_unavailable_is_the_only_explained_missing_output(self) -> None:
        self._write_result(
            [],
            {
                "decision": "unsupported",
                "reasons": "software.decoder-unavailable: no decoder",
            },
        )
        _, errors, explained = image_buffer_attachments.validate(
            self.manifest_path, self.results
        )
        self.assertEqual(errors, [])
        self.assertEqual(len(explained), 1)

        self._write_result([])
        _, errors, explained = image_buffer_attachments.validate(
            self.manifest_path, self.results
        )
        self.assertTrue(any("no output-attachments" in error for error in errors))
        self.assertEqual(explained, [])

    def test_hardware_decoder_diagnostic_uses_the_same_contract(self) -> None:
        line = self._diagnostic().replace("[SWDecoder]", "[HardwareVideoDecoder]")
        self._write_result([line])
        _, errors, _ = image_buffer_attachments.validate(
            self.manifest_path, self.results
        )
        self.assertEqual(errors, [])

    def test_explicit_unsupported_bit_depth_is_an_explained_gap(self) -> None:
        self._write_result(
            [],
            {
                "decision": "unsupported",
                "reasons": "sample-buffer.output-bit-depth-unsupported: 12-bit",
            },
        )
        _, errors, explained = image_buffer_attachments.validate(
            self.manifest_path, self.results
        )
        self.assertEqual(errors, [])
        self.assertEqual(len(explained), 1)


if __name__ == "__main__":
    unittest.main()
