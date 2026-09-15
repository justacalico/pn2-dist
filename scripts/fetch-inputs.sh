#!/usr/bin/env bash
# Download the pinned input packages from this project's generic package
# registry and lay them out under $PN2_ROOT the way the tools/ scripts expect.
#
# Auth: the inputs-reader deploy token (GL_DT_USER / GL_DT_TOKEN secrets).
# Everything here is proprietary Pico material or derived from it - the repos
# deliberately don't carry it, which is why it travels as packages.
set -euo pipefail

R="${PN2_ROOT:?}"
PID="${GL_PROJECT_ID:?}"
BASE="https://gitlab.com/api/v4/projects/$PID/packages/generic"
SELF="$(cd "$(dirname "$0")/.." && pwd)"
. "$SELF/manifest.env"

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

dl() { # dl <pkg> <ver> <file>
  echo ">> $1/$2/$3"
  curl -fsSL --retry 3 -u "$GL_DT_USER:$GL_DT_TOKEN" \
      -o "$W/$3" "$BASE/$1/$2/$3"
  stat -c '   %s bytes' "$W/$3"
}

dl gsi         "$PIN_GSI"        lineage-17.1-20210808-UNOFFICIAL-treble_arm64_avS.img.xz
dl pvr-stack   "$PIN_STACK"      pvr_stack.tar.xz
dl pvr-apps    "$PIN_APPS"       pvr_apps_final.tar.xz
dl pvr-applibs "$PIN_APPLIBS"    pvr_applibs.tar.xz
dl oem-final   "$PIN_OEM"        oem_final.tar.xz
dl loadingres  "$PIN_LOADINGRES" LoadingRes.tar.xz
dl blobs       "$PIN_BLOBS"      blobs.tar.xz
dl seethrough  "$PIN_SEETHROUGH" seethrough.tar.xz

mkdir -p "$R/gsi" "$R/notes" "$R/out" "$R/.stub"
mv "$W/lineage-17.1-20210808-UNOFFICIAL-treble_arm64_avS.img.xz" "$R/gsi/"

for f in pvr_stack pvr_apps_final pvr_applibs oem_final blobs seethrough; do
  tar -xJf "$W/$f.tar.xz" -C "$R"
done
# LoadingRes feeds a fake stock image for 144_stage_full.sh
mkdir -p "$R/.stub/media"
tar -xJf "$W/LoadingRes.tar.xz" -C "$R/.stub/media"

echo "=== inputs laid out ==="
du -sh "$R"/{pvr_stack,pvr_apps_final,pvr_applibs,oem_final,seethrough,overlay_pvr,airsvc,rfsa,qvr,cdsp,fan,linklibs,build,notes} 2>/dev/null
