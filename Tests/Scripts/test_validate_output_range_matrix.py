from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "Scripts"))

import output_range_matrix  # noqa: E402


class OutputRangeMatrixTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.manifest_path = self.root / "manifest.json"
        self.results = self.root / "results"
        self.fixture = {
            "id": "fixture-v1",
            "availability": "available",
            "streams": {
                "video": {
                    "bit_depth": 10,
                    "chroma_subsampling": "4:2:0",
                    "range": "full",
                }
            },
        }
        self._write(self.manifest_path, {"fixtures": [self.fixture]})
        self._write_result(["[SWDecoder] 10-bit full-range output: decoded frame color_range"])

    def tearDown(self) -> None:
        self.temporary.cleanup()

    @staticmethod
    def _write(path: Path, value: object) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding="utf-8")

    def _write_result(self, diagnostics: list[str], route_fields: dict | None = None) -> None:
        self._write(
            self.results / "fixture-v1" / "result.json",
            {"diagnostics": diagnostics, "stages": {"route": {"fields": route_fields or {}}}},
        )

    def test_accepts_matching_depth_and_range(self) -> None:
        count, errors, explained = output_range_matrix.validate(
            self.manifest_path, self.results
        )
        self.assertEqual(count, 1)
        self.assertEqual(errors, [])
        self.assertEqual(explained, [])

    def test_rejects_missing_or_conflicting_output_plan(self) -> None:
        self._write_result([
            "[SWDecoder] 8-bit video-range output: decoded frame color_range"
        ])
        _, errors, _ = output_range_matrix.validate(self.manifest_path, self.results)
        self.assertTrue(any("expected 10-bit full-range" in error for error in errors))
        self.assertTrue(any("conflicting output plans" in error for error in errors))

    def test_validates_source_effective_and_actual_surface_formats(self) -> None:
        self.fixture["streams"]["video"].update({
            "bit_depth": 12,
            "chroma_subsampling": "4:2:2",
            "range": "limited",
        })
        self._write(self.manifest_path, {"fixtures": [self.fixture]})
        self._write_result([
            "[SWDecoder] source=12-bit/4:2:2/yuv422p12le "
            "effective=10-bit/4:2:0 video-range "
            "precision-loss=2-bit dithering=implementation-defined: decoded frame "
            "color_range actual-surface='x420'/10-bit/4:2:0/video-range"
        ])
        _, errors, explained = output_range_matrix.validate(
            self.manifest_path, self.results
        )
        self.assertEqual(errors, [])
        self.assertEqual(explained, [])

        self._write_result([
            "[SWDecoder] source=10-bit/4:2:0/yuv420p10le "
            "effective=10-bit/4:2:0 video-range precision=exact: decoded frame "
            "color_range actual-surface='x420'/8-bit/4:2:0/video-range"
        ])
        _, errors, _ = output_range_matrix.validate(
            self.manifest_path, self.results
        )
        self.assertTrue(any("actual surface" in error for error in errors))
        self.assertTrue(any("source/effective/actual format" in error for error in errors))

    def test_decoder_unavailable_is_the_only_explained_gap(self) -> None:
        self._write_result([], {
            "decision": "unsupported",
            "reasons": "software.decoder-unavailable: no decoder",
        })
        _, errors, explained = output_range_matrix.validate(
            self.manifest_path, self.results
        )
        self.assertEqual(errors, [])
        self.assertEqual(len(explained), 1)

        report_path = self.results / "fixture-v1" / "result.json"
        report = json.loads(report_path.read_text(encoding="utf-8"))
        report["stages"]["route"]["fields"] = {}
        self._write(report_path, report)
        _, errors, explained = output_range_matrix.validate(
            self.manifest_path, self.results
        )
        self.assertTrue(errors)
        self.assertEqual(explained, [])

    def test_explicit_unsupported_bit_depth_is_explained(self) -> None:
        self._write_result([], {
            "decision": "unsupported",
            "reasons": "sample-buffer.output-bit-depth-unsupported: 12-bit",
        })
        _, errors, explained = output_range_matrix.validate(
            self.manifest_path, self.results
        )
        self.assertEqual(errors, [])
        self.assertEqual(len(explained), 1)


if __name__ == "__main__":
    unittest.main()
