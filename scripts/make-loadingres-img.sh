#!/usr/bin/env bash
# 144_stage_full.sh reads /media/LoadingRes (VRShell's boot animation) out of
# the stock OTA system.img. The real thing is 3.6G and carries nothing else we
# need, so fake just that subtree in a small ext4 image - rdump can't tell the
# difference.
set -euo pipefail
R="${PN2_ROOT:?}"
SRC="$R/.stub"
IMG="$R/images/ota_4.1.3/system.img"

[ -d "$SRC/media/LoadingRes" ] || { echo "$SRC/media/LoadingRes missing" >&2; exit 1; }
mkdir -p "$(dirname "$IMG")"

mb=$(( $(du -sm "$SRC" | cut -f1) * 2 + 16 ))
dd if=/dev/zero of="$IMG" bs=1M count="$mb" status=none
mke2fs -q -F -t ext4 -d "$SRC" "$IMG"
echo "stub stock image: $IMG (${mb}M)"
debugfs -R "ls /media/LoadingRes" "$IMG" 2>/dev/null | head -5
