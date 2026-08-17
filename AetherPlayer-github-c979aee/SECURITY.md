# Security Policy

## Supported versions

AetherPlayer ships fixes on the latest released line, delivered via the Sparkle auto-update feed. Older builds are not back-patched, so picking up a fix means updating to the latest release.

| Version | Supported          |
| ------- | ------------------ |
| 0.3.x   | :white_check_mark: |
| < 0.3   | :x:                |

## Reporting a vulnerability

Please report security issues **privately**, not as a public issue or pull request.

Use GitHub's private reporting: [Security → Report a vulnerability](https://github.com/superuser404notfound/AetherPlayer/security/advisories/new). That opens a private advisory visible only to you and the maintainers.

Helpful things to include:

- The affected version (AetherPlayer → About AetherPlayer, e.g. `0.3.1 (4)`) and your macOS version.
- A description of the issue and its impact.
- Steps or a proof of concept that reproduce it. For a malformed-media issue, a sample file or `ffprobe` output is ideal.

You can expect an initial acknowledgement within a few days. Once a fix is ready it ships in a new release and the advisory is published with credit, unless you prefer to remain anonymous.

## Scope

AetherPlayer is a sandboxed macOS app shell around the AetherEngine playback engine. Areas most relevant to security:

- **App shell.** File handling for user-selected media, the update path (Sparkle appcast and signature verification), and the snapshot / frame export to disk.
- **Sandbox and entitlements.** The app runs under App Sandbox and the Hardened Runtime with user-selected file access and the network-client entitlement (required because the engine bridges even local files through an on-device HTTP loopback server).

Out of scope, with where to report instead:

- **Media parsing, decoding, and network handling** (untrusted containers and bitstreams, the FFmpeg / dav1d surface, the loopback server, HTTP range reading) live in the engine. Report those privately on [AetherEngine](https://github.com/superuser404notfound/AetherEngine/security/advisories/new).
- **Upstream FFmpeg / dav1d** issues should go upstream, though we are glad to know if a bundled build is affected.
