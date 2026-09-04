# AetherPlayer media matrix

This directory is the machine-readable source of truth for media compatibility
fixtures. A container extension alone is never treated as a support claim.

## Files

- `schema/media-matrix.schema.json`: versioned JSON Schema contract.
- `manifest.json`: immutable fixture IDs, expected metadata/routes, generation
  recipes, provenance, hashes, probe paths, and explicit coverage gaps.
- `sources/`: project-authored subtitle or metadata inputs used by recipes.
- `fixtures/`: generated or authorized media. A file must never be replaced
  under an existing fixture ID with different bytes.
- `probes/`: raw `ffprobe` JSON paired with each available fixture.
- `results/`: build-specific P2-T02/P2-T03 output; historical runs must not be
  overwritten.

## Validation

Run the structural and semantic validator:

```bash
python3 Scripts/validate-media-matrix.py
python3 -m unittest Tests/Scripts/test_validate_media_matrix.py
```

The default mode accepts explicitly documented gaps. The completion gate is
stricter:

```bash
python3 Scripts/validate-media-matrix.py --require-complete
```

`--require-complete` fails if a declared fixture is unavailable, a coverage
cell is still `planned`, or the detected toolchain differs from the pinned
version. A lawful/technical `gap` with no fixture is allowed only when the
manifest records a concrete reason; this matches the plan's requirement to
make unavailable DV, PGS, VC-1, DRM, and similar samples explicit rather than
fabricating media or support claims.

## Generation

Recipes are argument arrays, not shell strings. They are pinned to FFmpeg
8.1.2 and use 2–10 second project-authored test sources. After that exact
toolchain is installed, generate selected fixtures with:

```bash
python3 Scripts/generate-media-fixtures.py \
  --fixture gen-h264-8bit-420-709-limited-mp4-v1
```

The generator stages output, captures raw `ffprobe` JSON, computes SHA-256,
and publishes atomically. If an existing fixture ID would change bytes, it
refuses the update and requires a new `-vN` ID.

Dolby Vision, VC-1, PGS, damaged/DRM, and any copyrighted samples are not
fabricated. They remain explicit authorized-source gaps until a lawful source
and its hash are recorded.

## Structured Engine results

After building the non-product `aetherctl` executable from the active Engine
worktree, run the manifest-defined smoke subset with one command:

```bash
python3 Scripts/run-media-matrix.py \
  --engine-cli /absolute/path/to/aetherctl \
  --build-id local-<immutable-build-id> \
  --engine-revision 3009ca258875
```

Use `--all` for every available fixture or repeat `--fixture <id>` for an
explicit selection. Each subprocess has a timeout. Results are written to
`results/<build-id>/<fixture-id>/result.json` with an optional frame PNG, plus
a build summary. The runner refuses to reuse a build ID, so historical
baselines cannot be silently overwritten. Display, audible channel mapping,
subtitle presentation, and HDR/EDR hardware checks remain explicit manual
oracles in each Engine report.

P4 color/output validation uses the immutable result directory as its oracle:

```bash
python3 Scripts/validate-color-matrix.py <build-id>
python3 Scripts/validate-output-range-matrix.py <build-id>
python3 Scripts/validate-image-buffer-attachments.py <build-id>
```

The output validator compares the decoded source-frame format, requested
effective format, and actual CoreVideo surface bit depth/chroma/range. This
makes 12-to-10-bit conversion and any precision-loss diagnostic visible.
The attachment validator parses metadata read back from the actual decoded
`CVImageBuffer`, then compares matrix code points, top/bottom chroma location,
clean aperture, pixel aspect ratio, Mastering Display Color Volume, MaxCLL, and
MaxFALL with the manifest and ffprobe record. Missing output is accepted only
for an explicit `software.decoder-unavailable` route; a missing diagnostic on
any decodable route is a failure.

P5 timing coverage includes the immutable
`gen-h264-8bit-420-709-limited-vfr-b6-mkv-v1` fixture. Its pinned FFmpeg recipe
drops every tenth 30 fps input frame under VFR muxing and uses six consecutive
B-frames (`b-adapt=0`), giving a lawful periodic 67 ms timestamp gap plus a deep
decode-order witness. Missing, duplicate, and non-monotonic PTS are covered by
the pure Engine reorder state-machine tests instead of publishing intentionally
malformed media as a positive decode fixture.
