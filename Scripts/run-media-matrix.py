#!/usr/bin/env python3
"""Run immutable media fixtures through AetherEngine's JSON diagnostics CLI."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MATRIX_ROOT = PROJECT_ROOT / "Tests" / "MediaMatrix"
MANIFEST_PATH = MATRIX_ROOT / "manifest.json"
SAFE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def write_new_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
    except Exception:
        path.unlink(missing_ok=True)
        raise


def failure_report(
    *,
    build_id: str,
    fixture_id: str,
    engine_revision: str,
    source: Path,
    failure_layer: str,
    error: str,
) -> dict[str, Any]:
    return {
        "schemaVersion": "1.0.0",
        "buildID": build_id,
        "fixtureID": fixture_id,
        "generatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "source": str(source),
        "environment": {
            "engineRevision": engine_revision,
            "collector": "run-media-matrix.py",
        },
        "stages": {
            "runner": {
                "status": "failed",
                "summary": "The diagnostics subprocess did not publish a report.",
                "fields": {},
                "metrics": {},
                "error": error,
            }
        },
        "diagnostics": [],
        "manualChecks": [],
        "result": {"status": "failed", "failureLayer": failure_layer},
    }


def validate_report(report: dict[str, Any], build_id: str, fixture_id: str) -> None:
    if report.get("schemaVersion") != "1.0.0":
        raise ValueError("collector report schemaVersion is not 1.0.0")
    if report.get("buildID") != build_id or report.get("fixtureID") != fixture_id:
        raise ValueError("collector report buildID/fixtureID does not match invocation")
    stages = report.get("stages")
    if not isinstance(stages, dict) or not stages:
        raise ValueError("collector report has no structured stages")
    result = report.get("result")
    if not isinstance(result, dict) or result.get("status") not in {"passed", "failed", "partial"}:
        raise ValueError("collector report has no valid result status")


def is_expected_unsupported(fixture: dict[str, Any], report: dict[str, Any]) -> bool:
    if fixture.get("expectation", {}).get("route") != "unsupported":
        return False
    route = report.get("stages", {}).get("route", {})
    fields = route.get("fields", {}) if isinstance(route, dict) else {}
    return (
        isinstance(fields, dict)
        and fields.get("decision") == "unsupported"
        and "sample-buffer.output-bit-depth-unsupported" in fields.get("reasons", "")
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine-cli", type=Path, required=True)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--engine-revision", required=True)
    parser.add_argument("--all", action="store_true", help="Run every available fixture, not the smoke subset.")
    parser.add_argument("--fixture", action="append", default=[], help="Run only the named fixture; repeatable.")
    parser.add_argument("--timeout", type=float, default=45.0, help="Per-fixture subprocess timeout in seconds.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    if not SAFE_ID.fullmatch(args.build_id):
        raise SystemExit("--build-id must contain only letters, digits, dot, underscore, or dash")
    if not SAFE_ID.fullmatch(args.engine_revision):
        raise SystemExit("--engine-revision must be a safe identifier")
    if args.timeout <= 0:
        raise SystemExit("--timeout must be positive")
    engine_cli = args.engine_cli.resolve()
    if not engine_cli.is_file() or not os.access(engine_cli, os.X_OK):
        raise SystemExit(f"--engine-cli is not executable: {engine_cli}")

    manifest = load_json(MANIFEST_PATH)
    fixtures = {fixture["id"]: fixture for fixture in manifest["fixtures"]}
    if args.fixture:
        selected_ids = args.fixture
    elif args.all:
        selected_ids = [
            fixture["id"] for fixture in manifest["fixtures"]
            if fixture["availability"] == "available"
        ]
    else:
        selected_ids = manifest["smoke_fixture_ids"]
    if len(selected_ids) != len(set(selected_ids)):
        raise SystemExit("fixture selection contains duplicate IDs")
    for fixture_id in selected_ids:
        fixture = fixtures.get(fixture_id)
        if fixture is None or fixture.get("availability") != "available":
            raise SystemExit(f"fixture is unknown or unavailable: {fixture_id}")

    build_root = MATRIX_ROOT / "results" / args.build_id
    if build_root.exists():
        raise SystemExit(f"refusing to overwrite historical build results: {build_root}")
    build_root.mkdir(parents=True)

    results: list[dict[str, Any]] = []
    failed = False
    for fixture_id in selected_ids:
        fixture = fixtures[fixture_id]
        artifact = MATRIX_ROOT / fixture["artifact"]["path"]
        result_dir = build_root / fixture_id
        result_dir.mkdir()
        result_path = result_dir / "result.json"
        frame_path = result_dir / "frame.png"
        frame_time = min(0.5, max(0.0, float(fixture["duration_seconds"]) / 2.0))
        command = [
            str(engine_cli),
            "matrix",
            "--build-id", args.build_id,
            "--fixture-id", fixture_id,
            "--engine-revision", args.engine_revision,
            "--output", str(result_path),
            "--frame-output", str(frame_path),
            "--at", str(frame_time),
            "--observe", "1.0",
            "--frames", "180",
            str(artifact),
        ]
        try:
            completed = subprocess.run(
                command,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=args.timeout,
                check=False,
            )
            if not result_path.is_file():
                write_new_json(
                    result_path,
                    failure_report(
                        build_id=args.build_id,
                        fixture_id=fixture_id,
                        engine_revision=args.engine_revision,
                        source=artifact,
                        failure_layer="runner",
                        error=f"collector exited {completed.returncode}: {completed.stdout[-4000:]}",
                    ),
                )
        except subprocess.TimeoutExpired as error:
            write_new_json(
                result_path,
                failure_report(
                    build_id=args.build_id,
                    fixture_id=fixture_id,
                    engine_revision=args.engine_revision,
                    source=artifact,
                    failure_layer="timeout",
                    error=f"collector exceeded {args.timeout:.1f}s: {error.stdout or ''}",
                ),
            )

        report = load_json(result_path)
        try:
            validate_report(report, args.build_id, fixture_id)
        except ValueError as error:
            failed = True
            status = "invalid-report"
            failure_layer = "runner"
            message = str(error)
        else:
            status = report["result"]["status"]
            failure_layer = report["result"].get("failureLayer")
            message = None
            if status == "failed" and is_expected_unsupported(fixture, report):
                status = "expected-unsupported"
                failure_layer = None
            elif status == "failed":
                failed = True
        results.append({
            "fixtureID": fixture_id,
            "status": status,
            "failureLayer": failure_layer,
            "error": message,
            "result": str(result_path.relative_to(MATRIX_ROOT)),
            "frame": str(frame_path.relative_to(MATRIX_ROOT)) if frame_path.is_file() else None,
        })
        print(f"{fixture_id}: {status}" + (f" ({failure_layer})" if failure_layer else ""))

    counts = {
        status: sum(1 for result in results if result["status"] == status)
        for status in (
            "passed", "partial", "expected-unsupported", "failed", "invalid-report"
        )
    }
    write_new_json(build_root / "summary.json", {
        "schemaVersion": "1.0.0",
        "buildID": args.build_id,
        "engineRevision": args.engine_revision,
        "generatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "fixtureCount": len(results),
        "counts": counts,
        "results": results,
    })
    print(f"summary: {build_root / 'summary.json'}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
