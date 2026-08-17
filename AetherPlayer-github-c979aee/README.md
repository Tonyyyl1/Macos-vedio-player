# AetherPlayer

[简体中文](README.zh-CN.md)

A native macOS media player built on [AetherEngine](https://github.com/superuser404notfound/AetherEngine).

This export is a GitHub-ready source snapshot of commit `c979aee` (`0.11.0`, build `49`). It contains source code, reproducible local-media fixtures, compatibility metadata, and verification scripts. It deliberately excludes `.git`, DerivedData, build products, signing identities, notarization credentials, and user-local settings.

## Scope and status

The active delivery scope is macOS 14.0 or later, on both Apple Silicon and Intel Macs. iOS source and targets remain in the tree for compatibility, but they are not part of this development line's roadmap or acceptance criteria.

The macOS M1--M7 compatibility work is complete. It covers session identity and stale-callback protection, lifecycle coordination, sandbox security-scoped file access, and vertical media validation for:

- H.264/AAC in MP4 and MOV
- H.264/AAC/SRT and HEVC Main10/AAC in Matroska
- VP9/Opus and AV1 Main/Opus in WebM
- HEVC Main10/E-AC-3/SRT, VP9/PGS, and HDR10 in Matroska
- malformed-media failure diagnostics

Each ready fixture has probe, playback-route, first-frame, seek, and runtime validation. The verification manifest currently reports 10 ready fixtures and no planned fixtures.

## Build

Requirements: macOS 14+, a current Xcode installation, and an internet connection for Swift Package Manager dependencies. The checked-in Xcode project can be built directly:

```bash
xcodebuild -project AetherPlayer.xcodeproj \
  -scheme AetherPlayer \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

`project.yml` is the XcodeGen source of truth. When changing it, regenerate the project first:

```bash
brew install xcodegen
xcodegen generate
```

## Verify

Run the fixture manifest check:

```bash
ruby Scripts/verify-fixtures.rb
```

Run the macOS fixture suite:

```bash
xcodebuild -project AetherPlayer.xcodeproj \
  -scheme AetherPlayer \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AetherPlayerTests/FixtureProbeTests \
  test
```

Use `arch=x86_64` on an Intel Mac if required.

## Distribution

For a user-installable direct-distribution DMG, a valid Apple Developer Program membership, a `Developer ID Application` identity, and notarization credentials are required:

```bash
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="AetherPlayerNotary" \
./Scripts/build-dmg.sh
```

The script creates a signed DMG; with `NOTARY_PROFILE` it also notarizes and staples it. Never commit certificates, private keys, app-specific passwords, or keychain profiles.

## Upload to GitHub

Create an empty repository on GitHub, then run these commands from this folder:

```bash
git init
git add .
git commit -m "Initial import: AetherPlayer macOS M1-M7"
git branch -M main
git remote add origin https://github.com/YOUR_ACCOUNT/AetherPlayer.git
git push -u origin main
```

Alternatively, use GitHub Desktop to add this folder as a local repository and publish it. Do not upload the generated `.app`, DMG, `DerivedData`, or signing material to the source repository.

## License

[LGPL-3.0](LICENSE). AetherPlayer depends on [AetherEngine](https://github.com/superuser404notfound/AetherEngine), which is resolved through Swift Package Manager at the revision declared in `project.yml`.
