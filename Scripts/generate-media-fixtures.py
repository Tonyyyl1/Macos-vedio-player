#!/usr/bin/env python3
"""Generate immutable synthetic fixtures declared by the media matrix."""

from __future__ import annotations

import argparse
import copy
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from media_matrix import (
    DEFAULT_MANIFEST,
    coverage_is_satisfied,
    load_json,
    sha256,
    validate_manifest,
)


def detected_version(executable: str) -> str:
    result = subprocess.run(
        [executable, "-version"],
        check=True,
        capture_output=True,
        text=True,
    )
    first_line = result.stdout.splitlines()[0].split()
    if len(first_line) < 3:
        raise RuntimeError(f"Cannot parse version from {executable!r}")
    return first_line[2]


def publish_immutable(staged: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if sha256(staged) != sha256(destination):
            raise RuntimeError(
                f"{destination} already exists with different bytes; create a new -vN fixture ID"
            )
        staged.unlink()
        return
    os.replace(staged, destination)


def write_manifest_atomic(path: Path, manifest: dict) -> None:
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        prefix=".manifest-",
        suffix=".json",
        dir=path.parent,
        delete=False,
    ) as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
        staged_manifest = Path(handle.name)
    os.replace(staged_manifest, path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--fixture", action="append", required=True, dest="fixture_ids")
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--ffprobe", default="ffprobe")
    arguments = parser.parse_args()

    manifest_path = arguments.manifest.resolve()
    matrix_root = manifest_path.parent
    manifest = load_json(manifest_path)
    initial_errors = validate_manifest(manifest, matrix_root)
    if initial_errors:
        for error in initial_errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    ffmpeg_path = shutil.which(arguments.ffmpeg)
    ffprobe_path = shutil.which(arguments.ffprobe)
    if ffmpeg_path is None or ffprobe_path is None:
        print("FFmpeg and ffprobe must both be installed and available on PATH.", file=sys.stderr)
        return 2

    required_version = manifest["toolchain"]["ffmpeg"]["required_version"]
    ffmpeg_version = detected_version(ffmpeg_path)
    ffprobe_version = detected_version(ffprobe_path)
    if ffmpeg_version != required_version or ffprobe_version != required_version:
        print(
            f"Expected FFmpeg/ffprobe {required_version}; found {ffmpeg_version}/{ffprobe_version}.",
            file=sys.stderr,
        )
        return 2

    updated = copy.deepcopy(manifest)
    fixtures = {fixture["id"]: fixture for fixture in updated["fixtures"]}
    unknown = sorted(set(arguments.fixture_ids) - set(fixtures))
    if unknown:
        print(f"Unknown fixture IDs: {', '.join(unknown)}", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory(prefix=".generation-stage-", dir=matrix_root) as stage_name:
        stage_root = Path(stage_name)
        for fixture_id in arguments.fixture_ids:
            fixture = fixtures[fixture_id]
            generation = fixture.get("generation")
            if not isinstance(generation, dict):
                print(f"{fixture_id} is not a generated fixture.", file=sys.stderr)
                return 2

            declared_artifact = matrix_root / fixture["artifact"]["path"]
            staged_artifact = stage_root / declared_artifact.name
            command = [
                ffmpeg_path if argument == "ffmpeg" else str(staged_artifact) if argument == "{output}" else argument
                for argument in generation["command"]
            ]
            print(f"Generating {fixture_id}...")
            subprocess.run(command, check=True, cwd=matrix_root)

            staged_probe = stage_root / f"{fixture_id}.ffprobe.json"
            probe_result = subprocess.run(
                [
                    ffprobe_path,
                    "-v",
                    "error",
                    "-show_format",
                    "-show_streams",
                    "-show_chapters",
                    "-print_format",
                    "json",
                    str(staged_artifact),
                ],
                check=True,
                capture_output=True,
            )
            staged_probe.write_bytes(probe_result.stdout)
            json.loads(probe_result.stdout)

            artifact_destination = declared_artifact
            probe_relative = f"probes/{fixture_id}.ffprobe.json"
            probe_destination = matrix_root / probe_relative
            artifact_hash = sha256(staged_artifact)
            artifact_size = staged_artifact.stat().st_size
            probe_hash = sha256(staged_probe)
            publish_immutable(staged_artifact, artifact_destination)
            publish_immutable(staged_probe, probe_destination)

            fixture["availability"] = "available"
            fixture["artifact"]["sha256"] = artifact_hash
            fixture["artifact"]["size_bytes"] = artifact_size
            fixture["probe"] = {"path": probe_relative, "sha256": probe_hash}
            fixture["gap"] = None

    updated["toolchain"]["ffmpeg"]["detected_version"] = ffmpeg_version
    updated["toolchain"]["ffprobe"]["detected_version"] = ffprobe_version
    for requirement in updated["coverage"]:
        if coverage_is_satisfied(requirement, fixtures):
            requirement["status"] = "covered"
            requirement["gap_reason"] = None

    errors = validate_manifest(updated, matrix_root)
    if errors:
        for error in errors:
            print(f"ERROR after generation: {error}", file=sys.stderr)
        return 1
    write_manifest_atomic(manifest_path, updated)
    print(f"Updated {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
