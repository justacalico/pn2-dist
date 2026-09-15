#!/usr/bin/env bash
# The whole pipeline, end to end. Assumes fetch-inputs.sh already populated
# $PN2_ROOT and the source repos (tools, overlay, shim, vrhome) are cloned.
#
# The numbered tools/ scripts write their logs into notes/ and mostly don't
# exit nonzero on failure - each step greps the log for its success marker.
set -euo pipefail
R="${PN2_ROOT:?}"
T="$R/tools/build"
N="$R/notes"
SELF="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$N" "$R/out"

step() { echo; echo "######## $* ########"; }
fail() { echo "FAILED: $*" >&2; exit 1; }
ran() { # ran <logfile> <marker>
  local log="$N/$1" mark="$2"
  echo "--- $log (tail) ---"
  tail -25 "$log" 2>/dev/null || true
  grep -q "$mark" "$log" || fail "marker '$mark' not in $log"
}

step "gsi: unxz + simg2img"
cd "$R/gsi"
if [ ! -f gsi_raw.img ]; then
  xz -dk lineage-17.1-20210808-UNOFFICIAL-treble_arm64_avS.img.xz
  simg2img lineage-17.1-20210808-UNOFFICIAL-treble_arm64_avS.img gsi_raw.img
  rm -f lineage-17.1-20210808-UNOFFICIAL-treble_arm64_avS.img
fi
ls -l gsi_raw.img

step "shims from source"
"$SELF/scripts/build-shims.sh"

step "adb props into gsi_raw"
"$SELF/scripts/patch-gsi-props.sh"

step "clean image: overlay into GSI (143)"
bash "$T/143_build_image2.sh" || true
ran 143_build.txt "BUILD OK"

step "LoadingRes stub image"
"$SELF/scripts/make-loadingres-img.sh"

step "stage Pico stack (144)"
bash "$T/144_stage_full.sh" || true
ran 144_stage.txt "DONE"
[ -d "$R/fullstage/media/LoadingRes" ] || fail "LoadingRes not staged"
echo "  staged: $(find "$R/fullstage" -type f | wc -l) files, $(du -sh "$R/fullstage" | cut -f1)"

step "grow + inject stack (145)"
bash "$T/145_build_full.sh" || true
ran 145_full.txt "fits"

step "vrhome apk"
make -C "$R/vrhome" apk
BT=$(ls -d "${ANDROID_SDK_ROOT:-$ANDROID_HOME}"/build-tools/* | sort -V | tail -1)
"$BT/apksigner" verify --print-certs "$R/vrhome/out/vrhome.apk" | grep -q "CN=Android" \
  || fail "vrhome.apk is not platform-signed"

step "overlay fixes + patched libs + apps (267)"
bash "$T/267_build_full.sh" || true
ran 267_build.txt "BUILD OK"

step "DSP stack (300)"
bash "$T/300_img_dsp.sh" || true
ran 300_img_dsp.txt "DSP STACK ADDED OK"

step "mdsprpc (301)"
bash "$T/301_mdsp_img.sh"

step "QVR clients (352)"
bash "$T/352_img_qvrclient.sh" || true
ran 352_img_qvrclient.txt "QVR CLIENT ADDED OK"

step "fan daemon (373)"
bash "$T/373_img_fan.sh" || true
ran 373_img_fan.txt "FAN DAEMON ADDED OK"

step "verify (268)"
bash "$T/268_verify_img.sh" || true
tail -30 "$N/268_verify.txt"

step "final assertions"
IMG="$R/out/system-pn2-full.img"
e2fsck -fn "$IMG" >/dev/null 2>&1 || fail "system-pn2-full.img fsck dirty"
e2fsck -fn "$R/out/system-pn2.img" >/dev/null 2>&1 || fail "system-pn2.img fsck dirty"
sz=$(stat -c%s "$IMG")
[ "$sz" -le 3943694336 ] || fail "full image $sz > partition 3943694336"
echo "full image: $sz bytes, fsck clean"

step "BUILD PIPELINE OK"
