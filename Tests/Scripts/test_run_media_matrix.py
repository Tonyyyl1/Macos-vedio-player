from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock


PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = PROJECT_ROOT / "Scripts" / "run-media-matrix.py"
SPEC = importlib.util.spec_from_file_location("run_media_matrix", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
run_media_matrix = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(run_media_matrix)


class MediaMatrixRunnerTests(unittest.TestCase):
    def test_expected_unsupported_requires_matching_route_and_reason(self) -> None:
        fixture = {"expectation": {"route": "unsupported"}}
        report = {
            "stages": {
                "route": {
                    "fields": {
                        "decision": "unsupported",
                        "reasons": "sample-buffer.output-bit-depth-unsupported: 12-bit",
                    }
                }
            }
        }
        self.assertTrue(run_media_matrix.is_expected_unsupported(fixture, report))
        report["stages"]["route"]["fields"]["reasons"] = "unexpected"
        self.assertFalse(run_media_matrix.is_expected_unsupported(fixture, report))

    def test_new_json_refuses_to_overwrite(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_name:
            destination = Path(temporary_name) / "result.json"
            run_media_matrix.write_new_json(destination, {"value": 1})
            with self.assertRaises(FileExistsError):
                run_media_matrix.write_new_json(destination, {"value": 2})
            self.assertEqual(json.loads(destination.read_text()), {"value": 1})

    def test_smoke_run_publishes_valid_summary_and_rejects_reused_build_id(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_name:
            root = Path(temporary_name)
            matrix_root = root / "MediaMatrix"
            fixture_root = matrix_root / "fixtures"
            fixture_root.mkdir(parents=True)
            fixture = fixture_root / "fixture-v1.mp4"
            fixture.write_bytes(b"fixture")
            manifest_path = matrix_root / "manifest.json"
            manifest_path.write_text(json.dumps({
                "smoke_fixture_ids": ["fixture-v1"],
                "fixtures": [{
                    "id": "fixture-v1",
                    "availability": "available",
                    "duration_seconds": 2.0,
                    "artifact": {"path": "fixtures/fixture-v1.mp4"},
                }],
            }), encoding="utf-8")

            fake_cli = root / "fake-aetherctl.py"
            fake_cli.write_text(
                "#!/usr/bin/env python3\n"
                "import json, pathlib, sys\n"
                "def value(name): return sys.argv[sys.argv.index(name) + 1]\n"
                "out = pathlib.Path(value('--output'))\n"
                "frame = pathlib.Path(value('--frame-output'))\n"
                "frame.write_bytes(b'png')\n"
                "report = {\n"
                " 'schemaVersion':'1.0.0','buildID':value('--build-id'),\n"
                " 'fixtureID':value('--fixture-id'),'generatedAt':'now','source':sys.argv[-1],\n"
                " 'environment':{},'stages':{'probe':{'status':'passed','summary':'ok','fields':{},'metrics':{},'error':None}},\n"
                " 'diagnostics':[],'manualChecks':[],\n"
                " 'result':{'status':'passed','failureLayer':None}}\n"
                "out.write_text(json.dumps(report))\n",
                encoding="utf-8",
            )
            fake_cli.chmod(0o755)
            arguments = [
                "--engine-cli", str(fake_cli),
                "--build-id", "test-build-v1",
                "--engine-revision", "3009ca258875",
            ]
            with mock.patch.object(run_media_matrix, "MATRIX_ROOT", matrix_root), mock.patch.object(
                run_media_matrix, "MANIFEST_PATH", manifest_path
            ):
                self.assertEqual(run_media_matrix.main(arguments), 0)
                summary = json.loads(
                    (matrix_root / "results" / "test-build-v1" / "summary.json").read_text()
                )
                self.assertEqual(summary["counts"]["passed"], 1)
                with self.assertRaises(SystemExit):
                    run_media_matrix.main(arguments)


if __name__ == "__main__":
    unittest.main()
