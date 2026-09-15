#!/usr/bin/env bash
# First-boot adb props, applied to gsi_raw.img through debugfs - same result
# as tools/build/26_patch_gsi_adb.sh but without a loop mount (no root needed,
# matching the debugfs convention the rest of the pipeline uses).
#
# Fresh /data has no persisted USB config, so default the gadget to adb+mtp
# and drop adb auth.
set -euo pipefail
R="${PN2_ROOT:?}"
IMG="$R/gsi/gsi_raw.img"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

patch_prop() { # patch_prop <img-path>
  local dst="$1" t="$T/$(basename "$1")"
  debugfs -R "dump $dst $t" "$IMG" 2>/dev/null
  [ -s "$t" ] || { echo "  no $dst in image"; return 0; }
  if grep -q 'Pico Neo 2 adb bring-up' "$t"; then echo "  $dst already patched"; return 0; fi
  sed -i -E '/^(persist\.sys\.usb\.config|ro\.adb\.secure|ro\.debuggable|ro\.secure)=/d' "$t"
  [ -n "$(tail -c1 "$t")" ] && echo "" >> "$t" || true
  cat >> "$t" <<'EOF'

# --- Pico Neo 2 adb bring-up -----------------------------------------------
# Fresh /data has no persisted USB config, so default the gadget to adb+mtp and
# drop adb auth. Bring-up only; remove for any release build.
persist.sys.usb.config=adb,mtp
ro.adb.secure=0
ro.debuggable=1
ro.secure=0
EOF
  debugfs -w -R "rm $dst" "$IMG" >/dev/null 2>&1
  debugfs -w -R "write $t $dst" "$IMG" >/dev/null 2>&1
  debugfs -w -R "sif $dst mode 0100600" "$IMG" >/dev/null 2>&1
  debugfs -w -R "sif $dst uid 0" "$IMG" >/dev/null 2>&1
  debugfs -w -R "sif $dst gid 0" "$IMG" >/dev/null 2>&1
  echo "  $dst patched"
}

patch_prop /build.prop
patch_prop /etc/prop.default

e2fsck -fy "$IMG" >/dev/null 2>&1
e2fsck -fn "$IMG" >/dev/null 2>&1 || { echo "fsck dirty after prop patch" >&2; exit 1; }
grep -E 'persist\.sys\.usb|ro\.(adb\.secure|debuggable|secure)' "$T/build.prop"
