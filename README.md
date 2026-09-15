# dist

Build pipeline for the PN2Lineage system images.

GitLab is the source of truth. Pushes mirror the repo to
[justacalico/pn2-dist](https://github.com/justacalico/pn2-dist), and a manual
pipeline dispatches the real build to GitHub Actions - the shared runners
here don't have the disk or the Android SDK the build needs. When the GitHub
run finishes, the release assets are copied back to a GitLab release through
the package registry, so they never expire.

## What a build does

1. `scripts/fetch-inputs.sh` downloads the pinned input packages from this
   project's package registry (the proprietary blobs - kept private, see
   `overlay/PROPRIETARY-PVR.md` in the overlay repo) and clones the source
   repos listed in `manifest.env`.
2. `scripts/build-image.sh` runs the real `tools/build` chain on the runner:
   GSI xz -> simg2img -> build.prop -> overlay -> staged Pico stack ->
   fixes -> verify.
3. Outputs land as sparse `system-pn2.img` / `system-pn2-full.img` on a
   GitHub release, then on a same-named GitLab release via the
   `github-release-sync` job.

## Running a build

Run a pipeline on `main` (web UI "Run pipeline", or `glab ci run`). The
`github-dispatch` job triggers the workflow and streams the GitHub log into
the job trace; `github-release-sync` publishes the assets when it succeeds.

## Updating inputs

From the workspace root:

```
./scripts/upload-inputs.sh <new-version>
```

then bump the matching `PIN_*` in `manifest.env` and push. Every input is a
separate package so unchanged pieces are not re-uploaded.

## Flashing

The release images are Android sparse images - flash them directly:

```
fastboot oem pico unlock
fastboot -S 128M flash system system-pn2-full.img
```
