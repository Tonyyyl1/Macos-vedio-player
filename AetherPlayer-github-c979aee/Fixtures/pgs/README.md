# PGS fixtures

`mkv-vp9-pgs.mkv` is a 16-second, 320×180 VP9 Profile 0 Matroska clip with a
real HDMV PGS subtitle stream. The subtitle has a tiny white bitmap cue from
9.5 s to 14.5 s; it is intentionally visually minimal so the file stays
deterministic and copyright-clean while still exercising software-route PGS
packet parsing, bitmap decoding, selection, rendering, seek, and teardown.

The delayed cue allows the software playback route to establish its source-time
anchor before subtitle packet draining begins. The matrix rejects text
subtitles as substitutes for this coverage.
