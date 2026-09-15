#!/usr/bin/env bash
# Build the input packages from the local workspace and upload them to this
# project's generic package registry. The repos deliberately carry no
# binaries, so the proprietary pieces travel to the builder this way.
#
#   GL_TOKEN=<token with api scope> scripts/upload-inputs.sh [version]
#
# Defaults to the version already pinned in manifest.env - bump the pin,
# upload, push.
set -euo pipefail
SRC="${PN2_SRC:-$HOME/PN2Lineage}"
SELF="$(cd "$(dirname "$0")/.." && pwd)"
PID="${GL_PROJECT_ID:-86495557}"
BASE="https://gitlab.com/api/v4/projects/$PID/packages/generic"
: "${GL_TOKEN:?need a GitLab token with api scope}"

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

up() { # up <pkg> <ver> <file>
  printf '>> %-56s %s\n' "$1/$2/$3" "$(du -h "$W/$3" | cut -f1)"
  curl -fsSL -X PUT -H "Authorization: Bearer $GL_TOKEN" \
      --upload-file "$W/$3" "$BASE/$1/$2/$3"
  echo
}

tarball() { # tarball <out.tar.xz> <path...> relative to $SRC
  tar --exclude='.git' --exclude='.gitignore' --exclude='LICENSE' \
      --exclude='README.md' -cJf "$@" 
}

. "$SELF/manifest.env"
V="${1:-}"
VER_GSI=${V:-$PIN_GSI}
VER_STACK=${V:-$PIN_STACK}
VER_APPS=${V:-$PIN_APPS}
VER_APPLIBS=${V:-$PIN_APPLIBS}
VER_OEM=${V:-$PIN_OEM}
VER_RES=${V:-$PIN_LOADINGRES}
VER_BLOBS=${V:-$PIN_BLOBS}
VER_ST=${V:-$PIN_SEETHROUGH}

cd "$SRC"

echo "=== gsi image ==="
cp gsi/lineage-17.1-20210808-UNOFFICIAL-treble_arm64_avS.img.xz "$W/"
up gsi "$VER_GSI" lineage-17.1-20210808-UNOFFICIAL-treble_arm64_avS.img.xz

echo "=== pvr stack ==="
tarball "$W/pvr_stack.tar.xz" -C "$SRC" pvr_stack
up pvr-stack "$VER_STACK" pvr_stack.tar.xz

echo "=== pvr apps (signed) ==="
tarball "$W/pvr_apps_final.tar.xz" -C "$SRC" pvr_apps_final
up pvr-apps "$VER_APPS" pvr_apps_final.tar.xz

echo "=== app-private libs ==="
tarball "$W/pvr_applibs.tar.xz" -C "$SRC" pvr_applibs
up pvr-applibs "$VER_APPLIBS" pvr_applibs.tar.xz

echo "=== oem apps (signed) ==="
tarball "$W/oem_final.tar.xz" -C "$SRC" oem_final
up oem-final "$VER_OEM" oem_final.tar.xz

echo "=== LoadingRes ==="
tar -cJf "$W/LoadingRes.tar.xz" -C "$SRC/fullstage/media" LoadingRes
up loadingres "$VER_RES" LoadingRes.tar.xz

echo "=== blobs ==="
B="$W/blobs-root"
mkdir -p "$B"/overlay/lib64 "$B"/notes/vrshell_lib "$B"/build/keys "$B"/linklibs "$B"/cdsp/vendor
cp -a "$SRC/overlay_pvr" "$B/"
cp -a "$SRC/airsvc"     "$B/"
cp -a "$SRC/qvr"        "$B/"
cp -a "$SRC/rfsa"       "$B/"
mkdir -p "$B/fan" && cp "$SRC/fan/fancontrol" "$B/fan/"
cp "$SRC/cdsp/vendor/libcdsprpc.so" "$SRC/cdsp/vendor/libmdsprpc.so" "$B/cdsp/vendor/"
cp "$SRC/overlay/lib64/libsensorservice.so" "$B/overlay/lib64/"
cp "$SRC/notes/libart-patched.so" "$B/notes/"
cp "$SRC/notes/vrshell_lib/libPvr_UnitySDK.patched2.so" "$B/notes/vrshell_lib/"
cp "$SRC/build/keys/platform.pk8" "$SRC/build/keys/platform.x509.pem" "$B/build/keys/"
for l in libgui libui libutils libcamera_client libtinyxml2; do
  cp "$SRC/notes/qlibs/$l.so" "$B/linklibs/"
done
find "$B" -name .git -prune -exec rm -rf {} + 2>/dev/null || true
find "$B" -name .gitignore -delete 2>/dev/null || true
tar -cJf "$W/blobs.tar.xz" -C "$B" .
up blobs "$VER_BLOBS" blobs.tar.xz

echo "=== seethrough ==="
S="$W/seethrough-root"
mkdir -p "$S/seethrough"
cp "$SRC/seethrough/seethroughsetting-signed.apk" "$S/seethrough/"
cp -a "$SRC/seethrough/lib" "$S/seethrough/"
tar -cJf "$W/seethrough.tar.xz" -C "$S" seethrough
up seethrough "$VER_ST" seethrough.tar.xz

echo
echo "all packages uploaded as version ${V:-<pins>} - manifest pins: $PIN_GSI $PIN_STACK $PIN_APPS $PIN_APPLIBS $PIN_OEM $PIN_LOADINGRES $PIN_BLOBS $PIN_SEETHROUGH"
