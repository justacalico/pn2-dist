#!/usr/bin/env bash
# Turn the raw ext4 outputs into sparse images (what fastboot actually wants)
# and lay out the release directory.
set -euo pipefail
R="${PN2_ROOT:?}"
D="${1:-dist-out}"
SELF="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$D"

for n in system-pn2 system-pn2-full; do
  img2simg "$R/out/$n.img" "$D/$n.img"
  # GitHub release assets cap at 2G - the full sparse image is ~2.5G, so both
  # ship xz'd (the usual GSI convention: unxz, then fastboot flash)
  xz -1 -T0 "$D/$n.img"
  echo "$n.img.xz: $(stat -c%s "$R/out/$n.img") raw -> $(stat -c%s "$D/$n.img.xz") sparse+xz"
done

tar -cJf "$D/build-logs.tar.xz" --exclude='*.so' -C "$R" notes

{
  echo "PN2Lineage image build"
  echo "date:    $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "commit:  ${GITHUB_SHA:-local}"
  echo "run:     ${GITHUB_SERVER_URL:-}/${GITHUB_REPOSITORY:-}/${GITHUB_RUN_ID:-}"
  echo
  . "$SELF/manifest.env"
  echo "input pins:"
  set | grep -E '^PIN_' | sort | sed 's/^/  /'
  echo "source refs:"
  set | grep -E '^[A-Z]+_REF=' | sort | sed 's/^/  /'
  echo
  (cd "$D" && sha256sum *.img.xz)
} > "$D/build-manifest.txt"

(cd "$D" && find . -type f ! -name SHA256SUMS.txt -exec sha256sum {} + | sort -k2 > SHA256SUMS.txt)
ls -l "$D"
