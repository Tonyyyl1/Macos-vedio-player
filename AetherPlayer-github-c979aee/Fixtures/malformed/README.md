# Malformed fixtures

`truncated.mp4` is the first 4 KiB of the generated H.264/AAC MP4 fixture, so
its required `moov` atom is absent. It is intentionally invalid. The probe
verifier expects FFmpeg to reject it; XCTest separately asserts that the player
reports failure without remaining in `.loading`, then returns to `.idle` on
stop.
