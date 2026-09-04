from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = PROJECT_ROOT / "Tests" / "MediaMatrix" / "manifest.json"
DEFAULT_RESULTS_ROOT = PROJECT_ROOT / "Tests" / "MediaMatrix" / "results"

VALUE_MAPPINGS = {
    "transfer": {
        "smpte2084": "pq",
        "bt470bg": "gamma28",
    },
    "matrix": {
        "bt2020nc": "bt2020NCL",
        "bt2020c": "bt2020CL",
    },
    "chromaLocation": {
        "top-left": "topLeft",
        "bottom-left": "bottomLeft",
    },
}


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return value


def mapped(field: str, value: Any) -> str:
    rendered = str(value)
    return VALUE_MAPPINGS.get(field, {}).get(rendered, rendered)


def expected_fields(fixture: dict[str, Any], matrix_root: Path) -> dict[str, str]:
    video = fixture["streams"]["video"]
    probe = load_json(matrix_root / fixture["probe"]["path"])
    video_stream = next(
        (stream for stream in probe.get("streams", []) if stream.get("codec_type") == "video"),
        None,
    )
    if video_stream is None:
        raise ValueError(f"{fixture['id']}: referenced probe has no video stream")

    aspect_ratio = video_stream.get("sample_aspect_ratio")
    if not aspect_ratio or aspect_ratio in {"N/A", "0:1"}:
        aspect_ratio = "unknown"

    return {
        "range": mapped("range", video["range"]),
        "primaries": mapped("primaries", video["primaries"]),
        "transfer": mapped("transfer", video["transfer"]),
        "matrix": mapped("matrix", video["matrix"]),
        "chromaLocation": mapped("chromaLocation", video["chroma_location"]),
        "bitDepth": str(video["bit_depth"]),
        "pixelFormat": str(video["pixel_format"]),
        "pixelAspectRatio": str(aspect_ratio),
    }


def validate_fixture(
    fixture: dict[str, Any],
    matrix_root: Path,
    results_directory: Path,
) -> tuple[list[str], list[str]]:
    fixture_id = fixture["id"]
    result_path = results_directory / fixture_id / "result.json"
    if not result_path.is_file():
        return [f"{fixture_id}: missing result {result_path}"], []

    try:
        report = load_json(result_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        return [f"{fixture_id}: cannot read result: {error}"], []

    errors: list[str] = []
    explained: list[str] = []
    if report.get("fixtureID") != fixture_id:
        errors.append(
            f"{fixture_id}: fixtureID expected {fixture_id!r}, got {report.get('fixtureID')!r}"
        )
    color = report.get("stages", {}).get("color")
    if not isinstance(color, dict):
        return errors + [f"{fixture_id}: color stage is missing"], explained
    if color.get("status") != "passed":
        errors.append(
            f"{fixture_id}: color.status expected 'passed', got {color.get('status')!r}"
        )
    fields = color.get("fields")
    if not isinstance(fields, dict):
        return errors + [f"{fixture_id}: color.fields is missing or not an object"], explained

    try:
        expected = expected_fields(fixture, matrix_root)
    except (KeyError, OSError, ValueError, json.JSONDecodeError) as error:
        return errors + [f"{fixture_id}: cannot derive oracle: {error}"], explained

    route_fields = report.get("stages", {}).get("route", {}).get("fields", {})
    decoder_unavailable = (
        isinstance(route_fields, dict)
        and route_fields.get("decision") == "unsupported"
        and "software.decoder-unavailable" in route_fields.get("reasons", "")
    )
    unknown_diagnostics = fields.get("canonical.unknowns", "")

    core_fields = {
        "range",
        "primaries",
        "transfer",
        "matrix",
        "chromaLocation",
        "bitDepth",
        "pixelFormat",
    }
    for field, expected_value in expected.items():
        key = f"canonical.{field}"
        actual_value = fields.get(key)
        explained_unavailable = (
            actual_value == "unknown"
            and expected_value != "unknown"
            and decoder_unavailable
            and f"{field}(raw=" in unknown_diagnostics
        )
        if explained_unavailable:
            explained.append(
                f"{fixture_id}: {key} unavailable because the shipped decoder is absent "
                f"({fields.get(f'{key}.raw', 'raw absent')})"
            )
        elif actual_value != expected_value:
            errors.append(
                f"{fixture_id}: {key} expected {expected_value!r}, got {actual_value!r}"
            )
        expected_source = (
            "unknown" if expected_value == "unknown" or explained_unavailable else "stream"
        )
        source_key = f"{key}.source"
        if fields.get(source_key) != expected_source:
            errors.append(
                f"{fixture_id}: {source_key} expected {expected_source!r}, "
                f"got {fields.get(source_key)!r}"
            )
        if field in core_fields and f"{key}.raw" not in fields:
            errors.append(f"{fixture_id}: {key}.raw is missing")

    # The fact-only stream API deliberately does not invent frame-only
    # aperture or HDR side-data. Those become available through decoded-frame
    # metadata, not through this stream oracle.
    for field in ("cleanAperture", "masteringDisplay", "contentLight"):
        key = f"canonical.{field}"
        if fields.get(key) != "unknown":
            errors.append(f"{fixture_id}: {key} expected 'unknown', got {fields.get(key)!r}")
        source_key = f"{key}.source"
        if fields.get(source_key) != "unknown":
            errors.append(
                f"{fixture_id}: {source_key} expected 'unknown', got {fields.get(source_key)!r}"
            )

    for field in ("canonical.conflicts", "canonical.fallbacks"):
        if fields.get(field) != "":
            errors.append(f"{fixture_id}: {field} expected '', got {fields.get(field)!r}")
    return errors, explained


def validate(
    manifest_path: Path,
    results_directory: Path,
) -> tuple[int, list[str], list[str]]:
    manifest = load_json(manifest_path)
    matrix_root = manifest_path.parent
    fixtures = [
        fixture
        for fixture in manifest.get("fixtures", [])
        if fixture.get("availability") == "available"
    ]
    errors: list[str] = []
    explained: list[str] = []
    for fixture in fixtures:
        fixture_errors, fixture_explained = validate_fixture(
            fixture, matrix_root, results_directory
        )
        errors.extend(fixture_errors)
        explained.extend(fixture_explained)
    return len(fixtures), errors, explained


def resolve_results(value: str) -> Path:
    candidate = Path(value)
    if candidate.is_dir() or candidate.is_absolute() or "/" in value:
        return candidate
    return DEFAULT_RESULTS_ROOT / value


def cli(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Compare canonical AetherEngine color facts with the immutable media matrix."
    )
    parser.add_argument("results", help="Result directory or build ID under Tests/MediaMatrix/results")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    arguments = parser.parse_args(argv)
    results_directory = resolve_results(arguments.results)

    try:
        fixture_count, errors, explained = validate(arguments.manifest, results_directory)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        parser.error(str(error))
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        print(f"Color matrix failed: {len(errors)} mismatch(es) across {fixture_count} fixtures.")
        return 1
    for note in explained:
        print(f"EXPLAINED: {note}")
    print(
        f"Validated canonical color fields for {fixture_count} available fixtures "
        f"({len(explained)} decoder-unavailable field gap(s) explicitly explained)."
    )
    return 0
