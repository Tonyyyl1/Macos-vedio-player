<!-- Thanks for contributing to AetherPlayer. Keep this short; the test plan is the part that matters most. -->

## Summary

<!-- What does this change do, and why? One or two sentences. -->

Closes #

## What changed

<!-- The concrete changes. Bullet points are fine. -->

-

## Test plan

<!-- Playback correctness is verified manually against reference files. Name the Mac, the macOS version, and the exact media you played, and note which backend badge (native / sw) the session used so a reviewer can reason about coverage. -->

- Mac / macOS:
- Source media (container / video codec + profile / audio / HDR-DV):
- Backend badge (native / sw):
- Result:

## Checklist

- [ ] Commit messages follow Conventional Commits (`feat(...)`, `fix(...)`, `chore(...)`)
- [ ] No em-dashes in code, commits, or user-facing text
- [ ] Any playback bug is fixed in AetherEngine, not worked around here
- [ ] User-facing text proofread (no leaked German)
- [ ] `xcodegen generate` re-run if `project.yml` changed, and the build passes
