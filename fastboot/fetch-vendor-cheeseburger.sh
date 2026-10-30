#!/bin/bash
# Download the LineageOS 20 cheeseburger zip and extract vendor.img from it.
#
# usage: fetch-vendor-cheeseburger.sh [output-vendor.img]
set -e

OUT="${1:-vendor.img}"
URL="https://b4.timschumi.net/lineage-archive/lineage-20.0-20240129-nightly-cheeseburger-signed.zip"
ZIP_SHA256="d2c3086f25ea5794c2152e773bb88c9e0121234cf26d4a9f12944fa2aa9b50ff"
IMG_SHA256="7a5c68d6e667a730e4a188f8a79bb064f2458493b07d5da0cae2659b05abdce8"

BASE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== download LOS 20 cheeseburger zip =="
curl -L --fail --retry 3 -o "$TMP/los.zip" "$URL"
echo "$ZIP_SHA256  $TMP/los.zip" | sha256sum -c -

echo "== extract vendor.new.dat.br / transfer.list =="
python3 - "$TMP/los.zip" "$TMP" <<'PY'
import os
import sys
import zipfile

zp, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zp) as z:
    for name in ("vendor.new.dat.br", "vendor.transfer.list"):
        with z.open(name) as src, open(os.path.join(out, name), "wb") as dst:
            while True:
                chunk = src.read(1 << 20)
                if not chunk:
                    break
                dst.write(chunk)
PY

echo "== brotli decompress =="
python3 - "$TMP/vendor.new.dat.br" "$TMP/vendor.new.dat" <<'PY'
import sys

import brotli

src, dst = sys.argv[1], sys.argv[2]
d = brotli.Decompressor()
with open(src, "rb") as f, open(dst, "wb") as o:
    while True:
        chunk = f.read(1 << 20)
        if not chunk:
            break
        o.write(d.process(chunk))
PY

echo "== sdat2img =="
python3 "$BASE/sdat2img.py" "$TMP/vendor.transfer.list" "$TMP/vendor.new.dat" "$OUT"

echo "$IMG_SHA256  $OUT" | sha256sum -c -
ls -l "$OUT"
echo "OK: $OUT"
