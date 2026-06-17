# Agent Notes

## Git And Releases

- Before preparing a commit message, inspect recent history and match the existing style.
- Before creating a tag, inspect existing tags and match the repository convention.
- Version bump commits use `chore: bump addon version to X.Y.Z`.
- Release tags are annotated and named `vX.Y.Z`; use `git tag -a vX.Y.Z -m "Release vX.Y.Z"`.
- Push releases with `git push origin main --tags`.
