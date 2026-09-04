#!/usr/bin/env python3
"""Structural and semantic validation for the AetherPlayer media matrix."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = PROJECT_ROOT / "Tests" / "MediaMatrix" / "manifest.json"
FIXTURE_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]+-v[1-9][0-9]*$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")

REQUIRED_COVERAGE_IDS = {
    "codec-h264-8bit",
    "codec-hevc-8bit",
    "codec-hevc-10bit",
    "codec-h264-hi10p",
    "codec-h264-422",
    "codec-h264-444",
    "codec-av1",
    "codec-vp9",
    "codec-mpeg2",
    "codec-vc1",
    "codec-prores",
    "codec-mjpeg",
    "codec-dnxhd-hr",
    "codec-ffv1",
    "codec-theora",
    "container-mp4",
    "container-mov",
    "container-mkv",
    "container-ts",
    "container-webm",
    "container-avi",
    "color-bt601",
    "color-bt709",
    "color-bt2020",
    "range-limited",
    "range-full",
    "timing-cfr",
    "timing-vfr",
    "timing-interlaced",
    "subtitle-srt",
    "subtitle-ass",
    "subtitle-pgs",
}

TOP_LEVEL_KEYS = {
    "schema_version",
    "matrix_id",
    "toolchain",
    "smoke_fixture_ids",
    "fixtures",
    "coverage",
}
FIXTURE_KEYS = {
    "id",
    "availability",
    "artifact",
    "provenance",
    "generation",
    "container",
    "duration_seconds",
    "streams",
    "expectation",
    "probe",
    "actual",
    "gap",
}
VIDEO_KEYS = {
    "codec",
    "profile",
    "level",
    "bit_depth",
    "chroma_subsampling",
    "pixel_format",
    "range",
    "primaries",
    "transfer",
    "matrix",
    "chroma_location",
    "scan",
    "frame_rate",
    "gop",
    "hdr",
}


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _is_non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _require_keys(
    value: Any,
    required: set[str],
    location: str,
    errors: list[str],
    *,
    reject_unknown: bool = True,
) -> bool:
    if not isinstance(value, dict):
        errors.append(f"{location}: expected an object")
        return False
    missing = sorted(required - set(value))
    if missing:
        errors.append(f"{location}: missing keys: {', '.join(missing)}")
    if reject_unknown:
        unknown = sorted(set(value) - required)
        if unknown:
            errors.append(f"{location}: unknown keys: {', '.join(unknown)}")
    return not missing


def _safe_child(root: Path, relative: Any, location: str, errors: list[str]) -> Path | None:
    if not _is_non_empty_string(relative):
        errors.append(f"{location}: expected a non-empty relative path")
        return None
    candidate = (root / relative).resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError:
        errors.append(f"{location}: path escapes the media matrix directory")
        return None
    return candidate


def _validate_schema(matrix_root: Path, schema_version: Any, errors: list[str]) -> None:
    schema_path = matrix_root / "schema" / "media-matrix.schema.json"
    if not schema_path.is_file():
        errors.append("schema: schema/media-matrix.schema.json is missing")
        return
    try:
        schema = load_json(schema_path)
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"schema: cannot parse JSON: {error}")
        return
    if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
        errors.append("schema: expected JSON Schema draft 2020-12")
    if schema.get("properties", {}).get("schema_version", {}).get("const") != schema_version:
        errors.append("schema: schema_version const does not match manifest")
    required_definitions = {"fixture", "video", "coverageRequirement", "toolchain"}
    missing_definitions = required_definitions - set(schema.get("$defs", {}))
    if missing_definitions:
        errors.append(f"schema: missing definitions: {', '.join(sorted(missing_definitions))}")


def _validate_available_file(
    matrix_root: Path,
    descriptor: Any,
    location: str,
    errors: list[str],
    *,
    include_size: bool,
) -> None:
    required = {"path", "sha256"} | ({"size_bytes"} if include_size else set())
    if not _require_keys(descriptor, required, location, errors):
        return
    path = _safe_child(matrix_root, descriptor.get("path"), f"{location}.path", errors)
    expected_hash = descriptor.get("sha256")
    if not isinstance(expected_hash, str) or not SHA256_PATTERN.fullmatch(expected_hash):
        errors.append(f"{location}.sha256: expected 64 lowercase hexadecimal characters")
    if include_size and (not isinstance(descriptor.get("size_bytes"), int) or descriptor["size_bytes"] < 1):
        errors.append(f"{location}.size_bytes: expected a positive integer")
    if path is None or not path.is_file():
        errors.append(f"{location}: declared available file is missing")
        return
    actual_hash = sha256(path)
    if expected_hash != actual_hash:
        errors.append(f"{location}: SHA-256 mismatch (expected {expected_hash}, actual {actual_hash})")
    if include_size and descriptor.get("size_bytes") != path.stat().st_size:
        errors.append(
            f"{location}: size mismatch (expected {descriptor.get('size_bytes')}, actual {path.stat().st_size})"
        )


def _normalized_probe_value(value: Any) -> str:
    if value is None:
        return "unknown"
    normalized = str(value).strip().lower().replace(" ", "")
    aliases = {
        "unspecified": "unknown",
        "tv": "limited",
        "pc": "full",
        "high10": "high10",
        "main10": "main10",
        "profile0": "profile0",
    }
    return aliases.get(normalized, normalized)


def _probe_bit_depth(stream: dict[str, Any]) -> int | None:
    raw_depth = stream.get("bits_per_raw_sample")
    if isinstance(raw_depth, str) and raw_depth.isdigit():
        return int(raw_depth)
    pixel_format = str(stream.get("pix_fmt", ""))
    match = re.search(r"(?:p|gbrp)(9|10|12|16)(?:le|be)?$", pixel_format)
    if match:
        return int(match.group(1))
    if pixel_format:
        return 8
    return None


def _validate_probe_metadata(
    fixture: dict[str, Any],
    probe_json: dict[str, Any],
    location: str,
    errors: list[str],
) -> None:
    streams = probe_json.get("streams")
    if not isinstance(streams, list):
        return
    declared_streams = fixture.get("streams", {})
    declared_video = declared_streams.get("video") if isinstance(declared_streams, dict) else None
    video_streams = [stream for stream in streams if stream.get("codec_type") == "video"]
    if declared_video is None:
        if video_streams:
            errors.append(f"{location}: probe contains an undeclared video stream")
    elif not video_streams:
        errors.append(f"{location}: declared video stream is missing from probe")
    else:
        actual_video = video_streams[0]
        comparisons = {
            "codec": "codec_name",
            "profile": "profile",
            "pixel_format": "pix_fmt",
            "range": "color_range",
            "primaries": "color_primaries",
            "transfer": "color_transfer",
            "matrix": "color_space",
            "chroma_location": "chroma_location",
        }
        for declared_key, probe_key in comparisons.items():
            declared_value = _normalized_probe_value(declared_video.get(declared_key))
            actual_value = _normalized_probe_value(actual_video.get(probe_key))
            if declared_value != actual_value:
                errors.append(
                    f"{location}.{declared_key}: declared {declared_value}, probe reports {actual_value}"
                )
        declared_depth = declared_video.get("bit_depth")
        actual_depth = _probe_bit_depth(actual_video)
        if actual_depth is not None and declared_depth != actual_depth:
            errors.append(
                f"{location}.bit_depth: declared {declared_depth}, probe reports {actual_depth}"
            )
        frame_rate = declared_video.get("frame_rate", {}).get("average")
        if frame_rate != actual_video.get("avg_frame_rate"):
            errors.append(
                f"{location}.frame_rate.average: declared {frame_rate}, probe reports {actual_video.get('avg_frame_rate')}"
            )
        declared_scan = declared_video.get("scan")
        actual_field_order = actual_video.get("field_order")
        field_order_matches = {
            "progressive": {"progressive", None},
            "interlaced_tff": {"tt"},
            "interlaced_bff": {"bb"},
        }
        if actual_field_order not in field_order_matches.get(declared_scan, set()):
            errors.append(
                f"{location}.scan: declared {declared_scan}, probe reports {actual_field_order}"
            )
        hdr_kind = declared_video.get("hdr", {}).get("kind")
        if hdr_kind == "hdr10" and (
            actual_video.get("color_transfer") != "smpte2084"
            or actual_video.get("color_primaries") != "bt2020"
        ):
            errors.append(f"{location}.hdr: HDR10 requires probe-visible BT.2020/PQ metadata")

    declared_audio = declared_streams.get("audio") if isinstance(declared_streams, dict) else None
    audio_streams = [stream for stream in streams if stream.get("codec_type") == "audio"]
    if declared_audio is None:
        if audio_streams:
            errors.append(f"{location}: probe contains an undeclared audio stream")
    elif not audio_streams:
        errors.append(f"{location}: declared audio stream is missing from probe")
    else:
        actual_audio = audio_streams[0]
        if declared_audio.get("codec") != actual_audio.get("codec_name"):
            errors.append(f"{location}.audio.codec: does not match probe")
        if declared_audio.get("sample_rate") != int(actual_audio.get("sample_rate", 0)):
            errors.append(f"{location}.audio.sample_rate: does not match probe")
        if declared_audio.get("channels") != actual_audio.get("channels"):
            errors.append(f"{location}.audio.channels: does not match probe")

    declared_subtitles = declared_streams.get("subtitles", []) if isinstance(declared_streams, dict) else []
    subtitle_streams = [stream for stream in streams if stream.get("codec_type") == "subtitle"]
    if len(declared_subtitles) != len(subtitle_streams):
        errors.append(
            f"{location}.subtitles: declared {len(declared_subtitles)}, probe reports {len(subtitle_streams)}"
        )


def _validate_fixture(
    fixture: Any,
    index: int,
    matrix_root: Path,
    required_ffmpeg_version: str | None,
    errors: list[str],
) -> str | None:
    location = f"fixtures[{index}]"
    if not _require_keys(fixture, FIXTURE_KEYS, location, errors):
        return fixture.get("id") if isinstance(fixture, dict) else None

    fixture_id = fixture.get("id")
    if not isinstance(fixture_id, str) or not FIXTURE_ID_PATTERN.fullmatch(fixture_id):
        errors.append(f"{location}.id: expected an immutable ID ending in -vN")
        fixture_id = fixture_id if isinstance(fixture_id, str) else None

    availability = fixture.get("availability")
    allowed_availability = {"planned", "available", "external_authorized", "missing_authorized_source"}
    if availability not in allowed_availability:
        errors.append(f"{location}.availability: unsupported value {availability!r}")

    duration = fixture.get("duration_seconds")
    if not isinstance(duration, (int, float)) or isinstance(duration, bool) or duration <= 0 or duration > 30:
        errors.append(f"{location}.duration_seconds: expected a value in (0, 30]")

    provenance = fixture.get("provenance")
    provenance_keys = {"kind", "source", "license", "license_url", "authorization"}
    if _require_keys(provenance, provenance_keys, f"{location}.provenance", errors):
        for key in ("source", "license", "authorization"):
            if not _is_non_empty_string(provenance.get(key)):
                errors.append(f"{location}.provenance.{key}: expected a non-empty string")

    generation = fixture.get("generation")
    if isinstance(provenance, dict) and provenance.get("kind") == "generated":
        if not isinstance(duration, (int, float)) or duration < 2 or duration > 10:
            errors.append(f"{location}.duration_seconds: generated fixtures must be 2-10 seconds")
        if _require_keys(generation, {"ffmpeg_version", "command"}, f"{location}.generation", errors):
            if generation.get("ffmpeg_version") != required_ffmpeg_version:
                errors.append(f"{location}.generation.ffmpeg_version: must match the pinned toolchain")
            command = generation.get("command")
            if not isinstance(command, list) or not all(_is_non_empty_string(item) for item in command):
                errors.append(f"{location}.generation.command: expected a non-empty string array")
            else:
                if not command or command[0] != "ffmpeg":
                    errors.append(f"{location}.generation.command: first argument must be ffmpeg")
                if command.count("{output}") != 1:
                    errors.append(f"{location}.generation.command: must contain exactly one {{output}} placeholder")
                if command[-1] != "{output}":
                    errors.append(f"{location}.generation.command: output placeholder must be the final argument")
    elif generation is not None:
        errors.append(f"{location}.generation: external fixtures must not provide a generation recipe")

    if not _is_non_empty_string(fixture.get("container")):
        errors.append(f"{location}.container: expected a non-empty string")

    streams = fixture.get("streams")
    if _require_keys(streams, {"video", "audio", "subtitles"}, f"{location}.streams", errors):
        video = streams.get("video")
        if video is not None:
            _require_keys(video, VIDEO_KEYS, f"{location}.streams.video", errors)
            if isinstance(video, dict):
                for key in VIDEO_KEYS - {"bit_depth", "frame_rate", "gop", "hdr"}:
                    if not _is_non_empty_string(video.get(key)):
                        errors.append(f"{location}.streams.video.{key}: expected a non-empty string")
                if video.get("bit_depth") not in {8, 9, 10, 12, 16}:
                    errors.append(f"{location}.streams.video.bit_depth: unsupported bit depth")
                _require_keys(video.get("frame_rate"), {"mode", "average"}, f"{location}.streams.video.frame_rate", errors)
                _require_keys(video.get("gop"), {"size", "max_reorder_frames"}, f"{location}.streams.video.gop", errors)
                _require_keys(
                    video.get("hdr"),
                    {"kind", "dolby_vision_profile", "mastering_display", "max_cll", "max_fall"},
                    f"{location}.streams.video.hdr",
                    errors,
                )
        if not isinstance(streams.get("subtitles"), list):
            errors.append(f"{location}.streams.subtitles: expected an array")

    expectation = fixture.get("expectation")
    if _require_keys(
        expectation,
        {"route", "decoder", "fallback_eligibility", "oracles"},
        f"{location}.expectation",
        errors,
    ):
        oracles = expectation.get("oracles")
        if _require_keys(oracles, {"visual", "audio", "subtitle"}, f"{location}.expectation.oracles", errors):
            for key in ("visual", "audio", "subtitle"):
                if not _is_non_empty_string(oracles.get(key)):
                    errors.append(f"{location}.expectation.oracles.{key}: expected a non-empty string")

    artifact = fixture.get("artifact")
    probe = fixture.get("probe")
    if availability == "available":
        _validate_available_file(matrix_root, artifact, f"{location}.artifact", errors, include_size=True)
        _validate_available_file(matrix_root, probe, f"{location}.probe", errors, include_size=False)
        if fixture.get("gap") is not None:
            errors.append(f"{location}.gap: available fixtures must not have a gap")
        if isinstance(probe, dict) and _is_non_empty_string(probe.get("path")):
            probe_path = _safe_child(matrix_root, probe["path"], f"{location}.probe.path", errors)
            if probe_path and probe_path.is_file():
                try:
                    probe_json = load_json(probe_path)
                    if not isinstance(probe_json.get("streams"), list):
                        errors.append(f"{location}.probe: raw ffprobe JSON must contain a streams array")
                    else:
                        _validate_probe_metadata(fixture, probe_json, f"{location}.probe", errors)
                except (OSError, json.JSONDecodeError, AttributeError) as error:
                    errors.append(f"{location}.probe: invalid ffprobe JSON: {error}")
    else:
        gap = fixture.get("gap")
        if not isinstance(gap, dict) or not _is_non_empty_string(gap.get("reason")) or not _is_non_empty_string(gap.get("resolution")):
            errors.append(f"{location}.gap: unavailable fixtures require reason and resolution")
        if isinstance(artifact, dict) and (artifact.get("sha256") is not None or artifact.get("size_bytes") is not None):
            errors.append(f"{location}.artifact: unavailable fixtures must not claim a hash or size")
        if isinstance(probe, dict) and (probe.get("path") is not None or probe.get("sha256") is not None):
            errors.append(f"{location}.probe: unavailable fixtures must not claim probe evidence")

    return fixture_id


def _coverage_tokens(fixture: dict[str, Any], dimension: str) -> set[str]:
    if fixture.get("availability") != "available":
        return set()
    tokens: set[str] = set()
    streams = fixture.get("streams", {})
    video = streams.get("video") if isinstance(streams, dict) else None
    if dimension == "container":
        container = _normalized_probe_value(fixture.get("container"))
        tokens.add(container)
        if container == "matroska":
            tokens.add("mkv")
    elif dimension == "codec" and isinstance(video, dict):
        tokens.update(
            {
                _normalized_probe_value(video.get("codec")),
                _normalized_probe_value(video.get("profile")),
                f"{video.get('bit_depth')}-bit",
                _normalized_probe_value(video.get("chroma_subsampling")),
            }
        )
        if str(video.get("scan", "")).startswith("interlaced"):
            tokens.add("interlaced")
    elif dimension == "color" and isinstance(video, dict):
        color_values = {
            _normalized_probe_value(video.get("primaries")),
            _normalized_probe_value(video.get("transfer")),
            _normalized_probe_value(video.get("matrix")),
        }
        if "unknown" not in color_values:
            tokens.update(color_values)
    elif dimension == "range" and isinstance(video, dict):
        tokens.add(_normalized_probe_value(video.get("range")))
    elif dimension == "timing" and isinstance(video, dict):
        tokens.add(_normalized_probe_value(video.get("frame_rate", {}).get("mode")))
        scan = video.get("scan")
        if isinstance(scan, str) and scan.startswith("interlaced"):
            tokens.add("interlaced")
        if scan == "interlaced_tff":
            tokens.add("tff")
        if scan == "interlaced_bff":
            tokens.add("bff")
    elif dimension == "subtitle" and isinstance(streams, dict):
        for subtitle in streams.get("subtitles", []):
            tokens.add(_normalized_probe_value(subtitle.get("codec")))
            tokens.add(_normalized_probe_value(subtitle.get("kind")))
    elif dimension == "dynamic_range" and isinstance(video, dict):
        hdr = video.get("hdr", {})
        tokens.add(_normalized_probe_value(hdr.get("kind")))
        tokens.add(_normalized_probe_value(hdr.get("dolby_vision_profile")))
        transfer = _normalized_probe_value(video.get("transfer"))
        tokens.add("pq" if transfer == "smpte2084" else transfer)
    return tokens - {"unknown", "none"}


def coverage_is_satisfied(
    requirement: dict[str, Any],
    fixture_by_id: dict[str, dict[str, Any]],
) -> bool:
    references = requirement.get("fixture_ids")
    values = requirement.get("values")
    if not isinstance(references, list) or not references or not isinstance(values, list):
        return False
    if any(fixture_by_id.get(reference, {}).get("availability") != "available" for reference in references):
        return False
    tokens: set[str] = set()
    for reference in references:
        tokens.update(_coverage_tokens(fixture_by_id[reference], requirement.get("dimension", "")))
    normalized_values = {_normalized_probe_value(value) for value in values}
    return normalized_values <= tokens


def validate_manifest(
    manifest: Any,
    matrix_root: Path,
    *,
    require_complete: bool = False,
) -> list[str]:
    errors: list[str] = []
    if not _require_keys(manifest, TOP_LEVEL_KEYS, "manifest", errors):
        return errors
    if manifest.get("schema_version") != "1.0.0":
        errors.append("manifest.schema_version: expected 1.0.0")
    _validate_schema(matrix_root, manifest.get("schema_version"), errors)

    toolchain = manifest.get("toolchain")
    required_ffmpeg_version: str | None = None
    if _require_keys(toolchain, {"ffmpeg", "ffprobe"}, "manifest.toolchain", errors):
        for tool_name in ("ffmpeg", "ffprobe"):
            tool = toolchain.get(tool_name)
            if _require_keys(tool, {"required_version", "source_url", "detected_version"}, f"manifest.toolchain.{tool_name}", errors):
                if not _is_non_empty_string(tool.get("required_version")):
                    errors.append(f"manifest.toolchain.{tool_name}.required_version: expected a version")
                if not _is_non_empty_string(tool.get("source_url")):
                    errors.append(f"manifest.toolchain.{tool_name}.source_url: expected a URL")
        ffmpeg = toolchain.get("ffmpeg") if isinstance(toolchain, dict) else None
        ffprobe = toolchain.get("ffprobe") if isinstance(toolchain, dict) else None
        if isinstance(ffmpeg, dict):
            required_ffmpeg_version = ffmpeg.get("required_version")
        if isinstance(ffmpeg, dict) and isinstance(ffprobe, dict) and ffmpeg.get("required_version") != ffprobe.get("required_version"):
            errors.append("manifest.toolchain: ffmpeg and ffprobe must use the same pinned release")

    fixtures = manifest.get("fixtures")
    if not isinstance(fixtures, list):
        errors.append("manifest.fixtures: expected an array")
        fixtures = []
    fixture_ids: list[str] = []
    fixture_by_id: dict[str, dict[str, Any]] = {}
    for index, fixture in enumerate(fixtures):
        fixture_id = _validate_fixture(fixture, index, matrix_root, required_ffmpeg_version, errors)
        if fixture_id is not None:
            fixture_ids.append(fixture_id)
            if isinstance(fixture, dict):
                fixture_by_id[fixture_id] = fixture
    duplicates = sorted({fixture_id for fixture_id in fixture_ids if fixture_ids.count(fixture_id) > 1})
    if duplicates:
        errors.append(f"manifest.fixtures: duplicate IDs: {', '.join(duplicates)}")

    smoke_fixture_ids = manifest.get("smoke_fixture_ids")
    if (
        not isinstance(smoke_fixture_ids, list)
        or not smoke_fixture_ids
        or not all(_is_non_empty_string(item) for item in smoke_fixture_ids)
    ):
        errors.append("manifest.smoke_fixture_ids: expected a non-empty string array")
    else:
        duplicate_smoke = sorted(
            {item for item in smoke_fixture_ids if smoke_fixture_ids.count(item) > 1}
        )
        if duplicate_smoke:
            errors.append(
                "manifest.smoke_fixture_ids: duplicate IDs: " + ", ".join(duplicate_smoke)
            )
        for fixture_id in smoke_fixture_ids:
            fixture = fixture_by_id.get(fixture_id)
            if fixture is None:
                errors.append(
                    f"manifest.smoke_fixture_ids: unknown fixture ID {fixture_id}"
                )
            elif require_complete and fixture.get("availability") != "available":
                errors.append(
                    f"manifest.smoke_fixture_ids: unavailable fixture ID {fixture_id}"
                )

    coverage = manifest.get("coverage")
    if not isinstance(coverage, list):
        errors.append("manifest.coverage: expected an array")
        coverage = []
    coverage_ids: list[str] = []
    referenced_fixtures: set[str] = set()
    for index, requirement in enumerate(coverage):
        location = f"coverage[{index}]"
        required_keys = {"id", "dimension", "values", "status", "fixture_ids", "gap_reason"}
        if not _require_keys(requirement, required_keys, location, errors):
            continue
        coverage_id = requirement.get("id")
        if not _is_non_empty_string(coverage_id):
            errors.append(f"{location}.id: expected a non-empty string")
        else:
            coverage_ids.append(coverage_id)
        values = requirement.get("values")
        if not isinstance(values, list) or not values or not all(_is_non_empty_string(value) for value in values):
            errors.append(f"{location}.values: expected a non-empty string array")
        refs = requirement.get("fixture_ids")
        if not isinstance(refs, list) or not all(isinstance(ref, str) for ref in refs):
            errors.append(f"{location}.fixture_ids: expected a string array")
            refs = []
        for ref in refs:
            referenced_fixtures.add(ref)
            if ref not in fixture_by_id:
                errors.append(f"{location}.fixture_ids: unknown fixture ID {ref}")
        status = requirement.get("status")
        gap_reason = requirement.get("gap_reason")
        if status == "covered":
            if not refs:
                errors.append(f"{location}: covered requirements need at least one fixture")
            for ref in refs:
                if fixture_by_id.get(ref, {}).get("availability") != "available":
                    errors.append(f"{location}: covered requirement references unavailable fixture {ref}")
            if gap_reason is not None:
                errors.append(f"{location}.gap_reason: covered requirements must use null")
            if not coverage_is_satisfied(requirement, fixture_by_id):
                errors.append(f"{location}: available fixtures do not satisfy all declared values")
        elif status in {"planned", "gap"}:
            if not _is_non_empty_string(gap_reason):
                errors.append(f"{location}.gap_reason: planned/gap requirements need an explanation")
        else:
            errors.append(f"{location}.status: unsupported value {status!r}")

    duplicate_coverage = sorted({coverage_id for coverage_id in coverage_ids if coverage_ids.count(coverage_id) > 1})
    if duplicate_coverage:
        errors.append(f"manifest.coverage: duplicate IDs: {', '.join(duplicate_coverage)}")
    missing_coverage = sorted(REQUIRED_COVERAGE_IDS - set(coverage_ids))
    if missing_coverage:
        errors.append(f"manifest.coverage: missing required cells: {', '.join(missing_coverage)}")
    unreferenced = sorted(set(fixture_ids) - referenced_fixtures)
    if unreferenced:
        errors.append(f"manifest.fixtures: fixtures not referenced by coverage: {', '.join(unreferenced)}")

    if require_complete:
        unavailable = sorted(
            fixture_id
            for fixture_id, fixture in fixture_by_id.items()
            if fixture.get("availability") != "available"
        )
        pending_coverage = sorted(
            requirement.get("id", f"coverage[{index}]")
            for index, requirement in enumerate(coverage)
            if isinstance(requirement, dict) and requirement.get("status") == "planned"
        )
        if unavailable:
            errors.append(f"completion: unavailable fixtures: {', '.join(unavailable)}")
        if pending_coverage:
            errors.append(f"completion: pending matrix cells: {', '.join(pending_coverage)}")
        if isinstance(toolchain, dict):
            for tool_name in ("ffmpeg", "ffprobe"):
                tool = toolchain.get(tool_name)
                if isinstance(tool, dict) and tool.get("detected_version") != tool.get("required_version"):
                    errors.append(f"completion: {tool_name} detected_version does not match required_version")

    return errors


def counts(manifest: dict[str, Any]) -> tuple[int, int, int, int]:
    fixtures = manifest.get("fixtures", [])
    coverage = manifest.get("coverage", [])
    available = sum(1 for fixture in fixtures if fixture.get("availability") == "available")
    gaps = sum(1 for requirement in coverage if requirement.get("status") == "gap")
    return len(fixtures), len(coverage), available, gaps


def cli(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", nargs="?", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument(
        "--require-complete",
        action="store_true",
        help="Fail unless all fixtures are available and all coverage cells are covered.",
    )
    arguments = parser.parse_args(list(argv) if argv is not None else None)
    manifest_path = arguments.manifest.resolve()
    try:
        manifest = load_json(manifest_path)
    except (OSError, json.JSONDecodeError) as error:
        print(f"Cannot read manifest: {error}", file=sys.stderr)
        return 2
    errors = validate_manifest(manifest, manifest_path.parent, require_complete=arguments.require_complete)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    fixture_count, coverage_count, available_count, gap_count = counts(manifest)
    print(
        f"Validated {fixture_count} fixtures and {coverage_count} coverage cells "
        f"({available_count} available, {gap_count} explicit gaps)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(cli())
