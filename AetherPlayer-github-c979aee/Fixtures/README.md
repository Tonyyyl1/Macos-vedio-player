# Media fixtures

This directory contains small, deterministic local media assets used by the
macOS playback compatibility matrix. They are deliberately short and contain
no third-party footage or audio.

`mp4/`, `mov/`, and `mkv/` hold the generated Tier 1 smoke fixtures. The
`subtitles/` directory contains the sidecar source used by the Matroska sample.
`hdr/`, `pgs/`, and `malformed/` are reserved for externally supplied source
material: those formats cannot be represented faithfully by synthetic colour
bars alone.

Run `Scripts/verify-fixtures.rb` after changing an asset or its manifest entry.
The script checks only probe-level facts. Runtime playback assertions (open,
first frame, clock advancement, seek, stop, and natural end) are recorded in
the manifest and will be driven by the macOS integration harness.
