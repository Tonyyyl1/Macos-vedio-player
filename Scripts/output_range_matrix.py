from __future__ import annotations

import argparse
import re
from pathlib import Path

from color_matrix import DEFAULT_MANIFEST, DEFAULT_RESULTS_ROOT, load_json, resolve_results


OUTPUT_PATTERN = re.compile(
    r"\[(?:SWDecoder|HardwareVideoDecoder)\].*?"
    r"source=(?P<source_depth>[0-9]+)-bit/(?P<source_chroma>[^/\s]+)/\S+ "
    r"effective=(?P<effective_depth>8|10)-bit/(?P<effective_chroma>[^\s]+) "
    r"(?P<effective_range>video|full)-range .*?"
    r"actual-surface='[^']+'/"
    r"(?P<actual_depth>8|10)-bit/(?P<actual_chroma>[^/\s]+)/"
    r"(?P<actual_range>video|full)-range"
)
LEGACY_OUTPUT_PATTERN = re.compile(
    r"\[SWDecoder\] (?P<effective_depth>8|10)-bit "
    r"(?P<effective_range>video|full)-range output:"
)


def validate_fixture(fixture: dict, results_directory: Path) -> tuple[list[str], list[str]]:
    fixture_id = fixture["id"]
    result_path = results_directory / fixture_id / "result.json"
    if not result_path.is_file():
        return [f"{fixture_id}: missing result {result_path}"], []
    report = load_json(result_path)
    errors: list[str] = []
    explained: list[str] = []

    route_fields = report.get("stages", {}).get("route", {}).get("fields", {})
    if isinstance(route_fields, dict) and route_fields.get("decision") == "unsupported":
        reasons = route_fields.get("reasons", "")
        if "software.decoder-unavailable" in reasons:
            explained.append(
                f"{fixture_id}: output unavailable because the shipped decoder is absent"
            )
            return errors, explained
        if "sample-buffer.output-bit-depth-unsupported" in reasons:
            explained.append(
                f"{fixture_id}: output unavailable because the source bit depth has no "
                "verified renderer surface"
            )
            return errors, explained

    video = fixture["streams"]["video"]
    expected_depth = "10" if int(video["bit_depth"]) > 8 else "8"
    expected_source_depth = str(int(video["bit_depth"]))
    expected_source_chroma = video.get("chroma_subsampling")
    expected_effective_chroma = "4:2:0"
    expected_range = {"limited": "video", "full": "full"}.get(video["range"])
    if expected_range is None:
        return [f"{fixture_id}: manifest range {video['range']!r} has no output oracle"], explained

    observed: set[tuple[str, str]] = set()
    detailed_observed: set[tuple[str, str, str, str, str, str]] = set()
    for line in report.get("diagnostics", []):
        match = OUTPUT_PATTERN.search(line)
        if match:
            effective = (
                match.group("effective_depth"),
                match.group("effective_range"),
            )
            observed.add(effective)
            detailed_observed.add((
                match.group("source_depth"),
                match.group("source_chroma"),
                match.group("effective_depth"),
                match.group("effective_chroma"),
                match.group("actual_depth"),
                match.group("actual_chroma"),
            ))
            actual = (match.group("actual_depth"), match.group("actual_range"))
            if actual != effective:
                errors.append(
                    f"{fixture_id}: requested effective output {effective!r} differs "
                    f"from actual surface {actual!r}"
                )
            continue
        legacy = LEGACY_OUTPUT_PATTERN.search(line)
        if legacy:
            observed.add((
                legacy.group("effective_depth"),
                legacy.group("effective_range"),
            ))
    expected = (expected_depth, expected_range)
    if expected not in observed:
        errors.append(
            f"{fixture_id}: expected {expected_depth}-bit {expected_range}-range output, "
            f"observed {sorted(observed)!r}"
        )
    conflicts = observed - {expected}
    if conflicts:
        errors.append(f"{fixture_id}: conflicting output plans observed: {sorted(conflicts)!r}")
    if detailed_observed:
        expected_detail = (
            expected_source_depth,
            expected_source_chroma,
            expected_depth,
            expected_effective_chroma,
            expected_depth,
            expected_effective_chroma,
        )
        if expected_source_chroma is not None and expected_detail not in detailed_observed:
            errors.append(
                f"{fixture_id}: expected source/effective/actual format {expected_detail!r}, "
                f"observed {sorted(detailed_observed)!r}"
            )
    return errors, explained


def validate(manifest_path: Path, results_directory: Path) -> tuple[int, list[str], list[str]]:
    manifest = load_json(manifest_path)
    fixtures = [
        fixture
        for fixture in manifest.get("fixtures", [])
        if fixture.get("availability") == "available"
    ]
    errors: list[str] = []
    explained: list[str] = []
    for fixture in fixtures:
        fixture_errors, fixture_explained = validate_fixture(fixture, results_directory)
        errors.extend(fixture_errors)
        explained.extend(fixture_explained)
    return len(fixtures), errors, explained


def cli(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Validate decoded source/effective/actual bit depth, chroma, and range "
            "against the media matrix."
        )
    )
    parser.add_argument("results", help="Result directory or build ID under Tests/MediaMatrix/results")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    arguments = parser.parse_args(argv)
    count, errors, explained = validate(arguments.manifest, resolve_results(arguments.results))
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        print(f"Output range matrix failed: {len(errors)} mismatch(es) across {count} fixtures.")
        return 1
    for note in explained:
        print(f"EXPLAINED: {note}")
    print(
        f"Validated decoded bit depth/range for {count - len(explained)} fixtures "
        f"({len(explained)} explicit output gap(s))."
    )
    return 0
