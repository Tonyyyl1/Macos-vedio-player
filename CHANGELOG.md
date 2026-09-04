# Change log

> [简体中文说明](README.zh-Hans.md) · [English README](README.md)

This file records the provenance of this source bundle. It is not a claim that every item below is a notarized or production release.

## Unreleased — source bundle `0.11.0` (build `49`)

Packaged: 2026-09-04

### Bundle contents

- Current AetherPlayer source, generated Xcode project, scripts, unit tests, media-matrix definitions, fixture inputs, probes, and release images.
- Media-matrix validation tooling and fixture coverage for video color, output range, image-buffer attachments, HDR static metadata, frame reordering, and subtitle/backfill scenarios.
- English and Simplified Chinese documentation with bidirectional language links and in-page navigation.

### Verification status

- The package deliberately excludes Git metadata, build products, DerivedData, `.build`, and prior test-result directories.
- The packaged source tree was compared against the active source tree after those exclusions; both contain 191 files.
- The ZIP archive passed `unzip -t` verification.

### Important boundary

- `0.11.0 (49)` is the project marketing/build version carried by this source tree. Creating this bundle does not create a new signed, notarized, or published app release.
- Current engineering evidence is documented in `docs/` in the parent workspace and is not represented here as a release certification.

## Upstream baseline — `0.11.0` (build `49`)

- Official upstream baseline: AetherPlayer commit `36eb8cb902eecbeb2cffbb893c368e75fefe00c3`.
- This project contains subsequent local development and test-harness work; consult the source and the parent-workspace evidence for its exact scope.

## Format

Future entries should use a release version/build, date, user-visible changes, verification performed, and explicit release-status boundary.
