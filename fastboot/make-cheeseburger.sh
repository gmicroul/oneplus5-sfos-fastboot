#!/bin/bash
# Convert a dumpling rootfs tree to cheeseburger (OnePlus 5) in place.
#
# usage: make-cheeseburger.sh <rootfs-tree> <vendor.img>
set -e

H="${1:?usage: make-cheeseburger.sh <rootfs-tree> <vendor.img>}"
VENDOR="${2:?missing vendor.img}"

echo "-- vendor.img --"
cp -f "$VENDOR" "$H/var/lib/lxc/android/vendor.img"
chown 0:0 "$H/var/lib/lxc/android/vendor.img"
chmod 644 "$H/var/lib/lxc/android/vendor.img"

echo "-- hw-release --"
cat > "$H/etc/hw-release" <<'EOF'
# This file is copied as hw-release (analogous to os-release)
NAME="OnePlus OnePlus 5"
ID=halium-cheeseburger
MER_HA_DEVICE=halium-cheeseburger
MER_HA_VENDOR=oneplus
VERSION="0.0.1.202610202052 (unknown)"
VERSION_ID=0.0.1.202610202052
PRETTY_NAME="OnePlus 5 0.0.1.202610202052 (unknown)"
SAILFISH_BUILD=202610202052
SAILFISH_FLAVOUR=unknown
HOME_URL="https://sailfishos.org/"
EOF

echo "-- hostname / machine-info --"
printf 'OnePlus5' > "$H/etc/hostname"
printf 'PRETTY_HOSTNAME="OnePlus 5"\n' > "$H/etc/machine-info"

echo "-- prop.halium --"
cat > "$H/usr/share/halium-overlay/system/etc/prop.halium" <<'EOF'
ro.product.vendor.device=OnePlus5
ro.product.device=OnePlus5
ro.product.model=ONEPLUS A5000
ro.product.vendor.model=ONEPLUS A5000
ro.product.vendor.manufacturer=OnePlus
ro.product.manufacturer=OnePlus
wifi.interface=wlan0
EOF

echo "-- ssu board mapping --"
rm -f "$H/usr/share/ssu/board-mappings.d/05-oneplus-halium-dumpling.ini"
cat > "$H/usr/share/ssu/board-mappings.d/05-oneplus-halium-cheeseburger.ini" <<'EOF'
[hwrelease.device]
halium-cheeseburger=halium-cheeseburger

[halium-cheeseburger]
prettyModel=OnePlus 5
deviceManufacturer=OnePlus
deviceDesignation=halium-cheeseburger
img-arch=aarch64
img-type=fs

[var-halium-cheeseburger]
vendor=oneplus
maintainer=jolla
EOF

echo "-- csd header --"
sed -i 's/# CSD hardware features for OnePlus 5T (halium-dumpling)/# CSD hardware features for OnePlus 5 (halium-cheeseburger)/' \
    "$H/usr/share/csd/settings.d/hw-settings.ini" 2>/dev/null || true

chown 0:0 "$H/etc/hw-release" "$H/etc/hostname" "$H/etc/machine-info" \
    "$H/usr/share/halium-overlay/system/etc/prop.halium" \
    "$H/usr/share/ssu/board-mappings.d/05-oneplus-halium-cheeseburger.ini"
chmod 644 "$H/etc/hw-release" "$H/etc/hostname" "$H/etc/machine-info" \
    "$H/usr/share/halium-overlay/system/etc/prop.halium" \
    "$H/usr/share/ssu/board-mappings.d/05-oneplus-halium-cheeseburger.ini"

echo "-- cheeseburger swap done --"
