# WebM fixtures

`vp9-opus.webm` is a two-second, 320×180, 30 fps VP9 Profile 0 video with a
48 kHz Opus audio track. It is generated locally from FFmpeg test sources; it
contains no third-party media.

`av1-opus.webm` is a two-second, 320×180, 30 fps AV1 Main Profile video with a
48 kHz Opus audio track. It too is generated from FFmpeg test sources and
contains no third-party media. On macOS, the engine selects VideoToolbox when
AV1 hardware decode is available and its dav1d software path otherwise.

M5 baseline: each codec must open and decode its first frame in under three
seconds on the macOS test runner. The test reports an over-budget decode as a
failure, while the manifest preserves the budget as reviewable metadata.
