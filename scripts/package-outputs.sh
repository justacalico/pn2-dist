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
  echo "$n.img: $(stat -c%s "$R/out/$n.img") raw -> $(stat -c%s "$D/$n.img") sparse"
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
  env | grep -E '^PIN_' | sort | sed 's/^/  /'
  echo "source refs:"
  env | grep -E '_(REF)=' | grep -vE '^PIN_' | sort | sed 's/^/  /'
  echo
  (cd "$D" && sha256sum *.img)
} > "$D/build-manifest.txt"

(cd "$D" && sha256sum * > SHA256SUMS.txt 2>/dev/null) || true
ls -l "$D"
