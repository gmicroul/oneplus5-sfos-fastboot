#!/bin/bash
# Assemble a fastboot package directory from a built userdata.img.
#
# usage: make-package.sh <dumpling|cheeseburger> <build-outdir> <pkg-dir>
set -e

DEVICE="${1:?usage: make-package.sh <dumpling|cheeseburger> <build-outdir> <pkg-dir>}"
OUTDIR="${2:?missing build outdir}"
PKG="${3:?missing package dir}"

BASE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$BASE/.." && pwd)"

case "$DEVICE" in
    dumpling)     DEVNAME="OnePlus 5T" ;;
    cheeseburger) DEVNAME="OnePlus 5" ;;
    *) echo "unknown device: $DEVICE"; exit 1 ;;
esac

[ -f "$OUTDIR/userdata.img" ] || { echo "missing $OUTDIR/userdata.img"; exit 1; }
mkdir -p "$PKG"

echo "== gzip =="
if command -v pigz >/dev/null 2>&1; then
    pigz -1 -k -f "$OUTDIR/userdata.img"
else
    gzip -1 -k -f "$OUTDIR/userdata.img"
fi

echo "== split (<2GiB parts) =="
rm -f "$PKG"/userdata.img.gz.part-*
split -b 1900M -d -a 2 "$OUTDIR/userdata.img.gz" "$PKG/userdata.img.gz.part-"

echo "== boot.img (shared) =="
cp "$REPO/boot/boot.img" "$PKG/boot.img"

echo "== flash.sh / join script / README =="
sed -e "s/@DEVICE@/$DEVICE/g" "$BASE/flash.sh.tmpl" > "$PKG/flash.sh"
chmod +x "$PKG/flash.sh"
cp "$BASE/join-and-verify.sh" "$PKG/join-and-verify.sh"
chmod +x "$PKG/join-and-verify.sh"
sed -e "s/@DEVICE@/$DEVICE/g" -e "s/@DEVNAME@/$DEVNAME/g" \
    "$BASE/README-package.md.tmpl" > "$PKG/README.md"

echo "== checksums =="
( cd "$PKG" && sha256sum boot.img userdata.img.gz.part-* flash.sh join-and-verify.sh README.md > SHA256SUMS )
cat "$PKG/SHA256SUMS"
ls -l "$PKG"
