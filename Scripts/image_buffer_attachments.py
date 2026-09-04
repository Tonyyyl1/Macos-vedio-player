from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from color_matrix import DEFAULT_MANIFEST, DEFAULT_RESULTS_ROOT, load_json, resolve_results


ATTACHMENT_PATTERN = re.compile(
    r"\[(?:SWDecoder|HardwareVideoDecoder)\] output-attachments "
    r"primaries=(?P<primaries>\S+) "
    r"transfer=(?P<transfer>\S+) "
    r"matrix=(?P<matrix>\S+) "
    r"chroma=(?P<chroma_top>[^/\s]+)/(?P<chroma_bottom>\S+) "
    r"cleanAperture=(?P<clean_aperture>\S+) "
    r"pixelAspectRatio=(?P<pixel_aspect_ratio>\S+)"
    r"(?: masteringDisplay=(?P<mastering_display>\S+)"
    r" contentLight=(?P<content_light>\S+))?"
)

APERTURE_PATTERN = re.compile(
    r"(?P<width>-?[0-9]+(?:\.[0-9]+)?)x"
    r"(?P<height>-?[0-9]+(?:\.[0-9]+)?)@"
    r"(?P<horizontal>-?[0-9]+(?:\.[0-9]+)?),"
    r"(?P<vertical>-?[0-9]+(?:\.[0-9]+)?)"
)

MATRIX_CODES = {
    "identity": "0",
    "bt709": "1",
    "fcc": "4",
    "bt470bg": "5",
    "smpte170m": "6",
    "smpte240m": "7",
    "ycgco": "8",
    "bt2020nc": "9",
    "bt2020c": "10",
    "smpte2085": "11",
    "chroma-derived-nc": "12",
    "chroma-derived-c": "13",
    "ictcp": "14",
    "unknown": "unknown",
}

CHROMA_LOCATIONS = {
    "left": "Left",
    "center": "Center",
    "top-left": "TopLeft",
    "top": "Top",
    "bottom-left": "BottomLeft",
    "bottom": "Bottom",
    "unknown": "unknown",
}


@dataclass(frozen=True)
class AttachmentObservation:
    matrix: str
    chroma_top: str
    chroma_bottom: str
    clean_aperture: str
    pixel_aspect_ratio: str
    mastering_display: str
    content_light: str


@dataclass(frozen=True)
class AttachmentOracle:
    matrix: str
    chroma_top: str
    chroma_bottom: str
    clean_aperture: tuple[float, float, float, float] | None
    pixel_aspect_ratio: str
    mastering_display: str
    content_light: str


def video_stream(probe: dict[str, Any], fixture_id: str) -> dict[str, Any]:
    stream = next(
        (
            candidate
            for candidate in probe.get("streams", [])
            if candidate.get("codec_type") == "video"
        ),
        None,
    )
    if not isinstance(stream, dict):
        raise ValueError(f"{fixture_id}: referenced probe has no video stream")
    return stream


def expected_oracle(fixture: dict[str, Any], matrix_root: Path) -> AttachmentOracle:
    fixture_id = fixture["id"]
    video = fixture["streams"]["video"]
    matrix_name = str(video["matrix"])
    chroma_name = str(video["chroma_location"])
    if matrix_name not in MATRIX_CODES:
        raise ValueError(f"{fixture_id}: matrix {matrix_name!r} has no CoreVideo code oracle")
    if chroma_name not in CHROMA_LOCATIONS:
        raise ValueError(f"{fixture_id}: chroma location {chroma_name!r} has no oracle")

    probe = load_json(matrix_root / fixture["probe"]["path"])
    stream = video_stream(probe, fixture_id)
    aspect_ratio = stream.get("sample_aspect_ratio")
    if not aspect_ratio or aspect_ratio in {"N/A", "0:1", "1:1"}:
        expected_aspect = "square-or-unknown"
    else:
        match = re.fullmatch(r"([1-9][0-9]*):([1-9][0-9]*)", str(aspect_ratio))
        if match is None:
            raise ValueError(
                f"{fixture_id}: sample_aspect_ratio {aspect_ratio!r} is not usable"
            )
        expected_aspect = f"{int(match.group(1))}:{int(match.group(2))}"

    crop_left = int(stream.get("crop_left") or 0)
    crop_right = int(stream.get("crop_right") or 0)
    crop_top = int(stream.get("crop_top") or 0)
    crop_bottom = int(stream.get("crop_bottom") or 0)
    if any(value < 0 for value in (crop_left, crop_right, crop_top, crop_bottom)):
        raise ValueError(f"{fixture_id}: ffprobe crop values must be non-negative")
    if crop_left + crop_right > 0 or crop_top + crop_bottom > 0:
        width = int(stream["width"])
        height = int(stream["height"])
        if width <= crop_left + crop_right or height <= crop_top + crop_bottom:
            raise ValueError(f"{fixture_id}: ffprobe crop exceeds the decoded frame")
        expected_aperture = (
            float(width - crop_left - crop_right),
            float(height - crop_top - crop_bottom),
            (crop_left - crop_right) / 2.0,
            (crop_bottom - crop_top) / 2.0,
        )
    else:
        expected_aperture = None

    chroma = CHROMA_LOCATIONS[chroma_name]
    hdr = video.get("hdr") or {}
    mastering_display = (
        "present(24B)" if hdr.get("mastering_display") is not None else "absent"
    )
    if hdr.get("max_cll") is None and hdr.get("max_fall") is None:
        content_light = "absent"
    elif hdr.get("max_cll") is None or hdr.get("max_fall") is None:
        raise ValueError(f"{fixture_id}: MaxCLL and MaxFALL must be present together")
    else:
        content_light = f"MaxCLL={int(hdr['max_cll'])},MaxFALL={int(hdr['max_fall'])}"
    return AttachmentOracle(
        matrix=MATRIX_CODES[matrix_name],
        chroma_top=chroma,
        chroma_bottom=chroma,
        clean_aperture=expected_aperture,
        pixel_aspect_ratio=expected_aspect,
        mastering_display=mastering_display,
        content_light=content_light,
    )


def parse_observations(diagnostics: list[Any]) -> set[AttachmentObservation]:
    observations: set[AttachmentObservation] = set()
    for line in diagnostics:
        if not isinstance(line, str):
            continue
        match = ATTACHMENT_PATTERN.search(line)
        if match is None:
            continue
        observations.add(
            AttachmentObservation(
                matrix=match.group("matrix"),
                chroma_top=match.group("chroma_top"),
                chroma_bottom=match.group("chroma_bottom"),
                clean_aperture=match.group("clean_aperture"),
                pixel_aspect_ratio=match.group("pixel_aspect_ratio"),
                mastering_display=match.group("mastering_display") or "absent",
                content_light=match.group("content_light") or "absent",
            )
        )
    return observations


def parsed_aperture(value: str) -> tuple[float, float, float, float] | None:
    if value == "none":
        return None
    match = APERTURE_PATTERN.fullmatch(value)
    if match is None:
        raise ValueError(f"malformed clean-aperture diagnostic {value!r}")
    return tuple(
        float(match.group(name))
        for name in ("width", "height", "horizontal", "vertical")
    )


def aperture_matches(
    actual: tuple[float, float, float, float] | None,
    expected: tuple[float, float, float, float] | None,
) -> bool:
    if actual is None or expected is None:
        return actual is expected
    return all(abs(left - right) <= 1e-6 for left, right in zip(actual, expected))


def explicit_output_gap(report: dict[str, Any]) -> str | None:
    route_fields = report.get("stages", {}).get("route", {}).get("fields", {})
    if not isinstance(route_fields, dict) or route_fields.get("decision") != "unsupported":
        return None
    reasons = route_fields.get("reasons", "")
    if "software.decoder-unavailable" in reasons:
        return "the shipped decoder is absent"
    if "sample-buffer.output-bit-depth-unsupported" in reasons:
        return "source bit depth has no verified renderer surface"
    return None


def validate_fixture(
    fixture: dict[str, Any],
    matrix_root: Path,
    results_directory: Path,
) -> tuple[list[str], list[str]]:
    fixture_id = fixture["id"]
    result_path = results_directory / fixture_id / "result.json"
    if not result_path.is_file():
        return [f"{fixture_id}: missing result {result_path}"], []
    report = load_json(result_path)
    observations = parse_observations(report.get("diagnostics", []))
    gap = explicit_output_gap(report)
    if not observations and gap:
        return [], [
            f"{fixture_id}: image-buffer attachments unavailable because {gap}"
        ]
    if not observations:
        return [f"{fixture_id}: no output-attachments diagnostic was captured"], []

    try:
        oracle = expected_oracle(fixture, matrix_root)
    except (KeyError, OSError, ValueError) as error:
        return [f"{fixture_id}: cannot derive attachment oracle: {error}"], []

    errors: list[str] = []
    for observation in sorted(observations, key=repr):
        if observation.matrix != oracle.matrix:
            errors.append(
                f"{fixture_id}: matrix code expected {oracle.matrix!r}, "
                f"got {observation.matrix!r}"
            )
        actual_chroma = (observation.chroma_top, observation.chroma_bottom)
        expected_chroma = (oracle.chroma_top, oracle.chroma_bottom)
        if actual_chroma != expected_chroma:
            errors.append(
                f"{fixture_id}: chroma expected {expected_chroma!r}, got {actual_chroma!r}"
            )
        if observation.pixel_aspect_ratio != oracle.pixel_aspect_ratio:
            errors.append(
                f"{fixture_id}: pixel aspect ratio expected {oracle.pixel_aspect_ratio!r}, "
                f"got {observation.pixel_aspect_ratio!r}"
            )
        if observation.mastering_display != oracle.mastering_display:
            errors.append(
                f"{fixture_id}: mastering display expected {oracle.mastering_display!r}, "
                f"got {observation.mastering_display!r}"
            )
        if observation.content_light != oracle.content_light:
            errors.append(
                f"{fixture_id}: content light expected {oracle.content_light!r}, "
                f"got {observation.content_light!r}"
            )
        try:
            actual_aperture = parsed_aperture(observation.clean_aperture)
        except ValueError as error:
            errors.append(f"{fixture_id}: {error}")
        else:
            if not aperture_matches(actual_aperture, oracle.clean_aperture):
                errors.append(
                    f"{fixture_id}: clean aperture expected {oracle.clean_aperture!r}, "
                    f"got {actual_aperture!r}"
                )
    return errors, []


def validate(
    manifest_path: Path,
    results_directory: Path,
) -> tuple[int, list[str], list[str]]:
    manifest = load_json(manifest_path)
    fixtures = [
        fixture
        for fixture in manifest.get("fixtures", [])
        if fixture.get("availability") == "available"
    ]
    errors: list[str] = []
    explained: list[str] = []
    for fixture in fixtures:
        fixture_errors, fixture_explained = validate_fixture(
            fixture, manifest_path.parent, results_directory
        )
        errors.extend(fixture_errors)
        explained.extend(fixture_explained)
    return len(fixtures), errors, explained


def cli(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Validate CoreVideo matrix, chroma, clean-aperture, pixel-aspect, and "
            "static-HDR attachments read back from decoded image buffers."
        )
    )
    parser.add_argument(
        "results", help="Result directory or build ID under Tests/MediaMatrix/results"
    )
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    arguments = parser.parse_args(argv)
    count, errors, explained = validate(
        arguments.manifest, resolve_results(arguments.results)
    )
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        print(
            f"Image-buffer attachment matrix failed: {len(errors)} mismatch(es) "
            f"across {count} fixtures."
        )
        return 1
    for note in explained:
        print(f"EXPLAINED: {note}")
    print(
        f"Validated image-buffer attachments for {count - len(explained)} fixtures "
        f"({len(explained)} explicit output gap(s))."
    )
    return 0
