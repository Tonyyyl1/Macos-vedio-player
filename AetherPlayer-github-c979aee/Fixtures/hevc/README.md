# HEVC index

HEVC fixtures live in their container directories. Generated Main 10 smoke
fixtures are `../mkv/hevc-main10-aac.mkv` and
`../mkv/hevc-main10-eac3-srt.mkv`. The latter combines a 48 kHz E-AC-3 audio
track with the shared embedded SRT cue to exercise the native Matroska route.
HDR remains separately represented in `compatibility/manifest.yaml`.
