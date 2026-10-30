#!/bin/bash
# Build a fastboot-flashable userdata.img for OnePlus 5 / 5T SailFish OS.
#
# usage: build-userdata.sh <dumpling|cheeseburger> <snapshot.tar.gz> <outdir> [vendor.img]
#
# run as root. requires: e2fsprogs, tar, openssl, ssh-keygen, setcap (libcap2-bin), python3
set -e

DEVICE="${1:?usage: build-userdata.sh <dumpling|cheeseburger> <snapshot.tar.gz> <outdir> [vendor.img]}"
SNAPSHOT="${2:?missing snapshot tarball}"
OUTDIR="${3:?missing output dir}"
VENDOR="${4:-}"

BASE="$(cd "$(dirname "$0")" && pwd)"
IMG="$OUTDIR/userdata.img"
MNT="$(mktemp -d /tmp/udbuild.XXXXXX)"
mkdir -p "$OUTDIR"
cleanup() { umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT

echo "== create ext4 image (8GiB, label=userdata) =="
rm -f "$IMG"
truncate -s 8G "$IMG"
# orphan_file must stay disabled: the device runs kernel 4.4 which cannot mount it.
# e2fsprogs >= 1.47 enables it by default; e2fsprogs 1.46 does not know the option.
ORPHAN_OPT=""
TMPFS="$(mktemp)"
truncate -s 8M "$TMPFS"
if mke2fs -q -F -t ext4 -O ^orphan_file "$TMPFS" >/dev/null 2>&1; then
    ORPHAN_OPT=",^orphan_file"
fi
rm -f "$TMPFS"
mke2fs -t ext4 -F -L userdata -O "64bit,metadata_csum${ORPHAN_OPT}" "$IMG" >/dev/null
if dumpe2fs -h "$IMG" 2>/dev/null | grep -q "orphan_file"; then
    echo "ERROR: orphan_file feature is present (device kernel 4.4 cannot mount this)"
    exit 1
fi
mount -o loop "$IMG" "$MNT"
H="$MNT/halium-rootfs"

echo "== extract rootfs snapshot =="
tar -xzf "$SNAPSHOT" -C "$MNT" --numeric-owner -p

echo "== fix mountpoint dirs =="
find "$H/mnt" -mindepth 1 -delete
find "$H/linkerconfig" -mindepth 1 -delete
chmod 755 "$H/mnt" "$H/proc" "$H/sys" "$H/linkerconfig"
chown 0:0 "$H/mnt" "$H/proc" "$H/sys" "$H/linkerconfig"

echo "== clean user data (defense in depth, snapshot should already be clean) =="
find "$H/home/defaultuser" -mindepth 1 -maxdepth 1 ! -name .config -exec rm -rf {} +
find "$H/home/defaultuser/.config" -mindepth 1 -maxdepth 1 ! -name systemd -exec rm -rf {} +
rm -f "$H/home/defaultuser/.config/systemd/user/lipstick.service.d/90-overlay-trace.conf"
rm -f "$H/home/defaultuser/.config/systemd/user/lipstick.service.d/91-capture-stderr.conf"
rm -f "$H/home/defaultuser/.config/systemd/user/lipstick-security-ui.service.d/91-capture.conf"
for d in Desktop Documents Downloads Music Pictures Videos; do
    mkdir -p "$H/home/defaultuser/$d"; chmod 775 "$H/home/defaultuser/$d"; chown 100000:100000 "$H/home/defaultuser/$d"
done
mkdir -p "$H/home/defaultuser/Playlists"; chmod 700 "$H/home/defaultuser/Playlists"; chown 100000:100000 "$H/home/defaultuser/Playlists"
for d in Public Templates; do
    mkdir -p "$H/home/defaultuser/$d"; chmod 755 "$H/home/defaultuser/$d"; chown 100000:100000 "$H/home/defaultuser/$d"
done
chmod 750 "$H/home/defaultuser"; chown 100000:100000 "$H/home/defaultuser"

find "$H/home/.system" -mindepth 1 -delete 2>/dev/null || true
mkdir -p "$H/home/.system/var/lib/connman" "$H/home/.system/var/lib/connman-vpn"
chown 0:0 "$H/home/.system" "$H/home/.system/var" "$H/home/.system/var/lib" \
    "$H/home/.system/var/lib/connman" "$H/home/.system/var/lib/connman-vpn"
chmod 755 "$H/home/.system" "$H/home/.system/var" "$H/home/.system/var/lib"
chmod 700 "$H/home/.system/var/lib/connman" "$H/home/.system/var/lib/connman-vpn"

if [ -d "$H/home/appsupport-root" ]; then
    AU=$(stat -c %u "$H/home/appsupport-root"); AG=$(stat -c %g "$H/home/appsupport-root"); AM=$(stat -c %a "$H/home/appsupport-root")
    find "$H/home/appsupport-root" -mindepth 1 -delete
    chown "$AU:$AG" "$H/home/appsupport-root"; chmod "$AM" "$H/home/appsupport-root"
fi
for d in "$H/home/.pk-zypp-dist-upgrade-cache" "$H/home/.zypp-cache" "$H/home/.zypp-tmp"; do
    [ -d "$d" ] && find "$d" -mindepth 1 -delete
done

rm -rf "$H/root/.cache" "$H/root/.config" "$H/root/.local" "$H/root/connman-wlan1-backup" \
       "$H/root/wlan1_psk.txt" "$H/root/.ash_history" "$H/root/.bash_history"

find "$H/var/lib/connman" -mindepth 1 -delete 2>/dev/null || true
find "$H/var/log/journal" -mindepth 1 -delete 2>/dev/null || true
for f in wtmp lastlog btmp harbour-storeman-installer.log.txt sailfishos-chum-gui-installer.log.txt; do
    [ -e "$H/var/log/$f" ] && : > "$H/var/log/$f"
done
find "$H/var/log" -maxdepth 1 -name 'updateTestcase-*' -type d -exec rm -rf {} + 2>/dev/null || true
find "$H/tmp" -mindepth 1 -delete 2>/dev/null || true
find "$H/var/tmp" -mindepth 1 -delete 2>/dev/null || true

echo "== blank ssu store credentials =="
if [ -f "$H/etc/ssu/ssu.ini" ]; then
    sed -i 's/^password=.*/password=/; s/^username=.*/username=/' "$H/etc/ssu/ssu.ini"
fi

echo "== regenerate ssh host keys =="
rm -f "$H"/etc/ssh/ssh_host_*
ssh-keygen -q -t rsa -N '' -f "$H/etc/ssh/ssh_host_rsa_key"
ssh-keygen -q -t ecdsa -N '' -f "$H/etc/ssh/ssh_host_ecdsa_key"
ssh-keygen -q -t ed25519 -N '' -f "$H/etc/ssh/ssh_host_ed25519_key"
chmod 600 "$H"/etc/ssh/ssh_host_*_key
chmod 644 "$H"/etc/ssh/ssh_host_*.pub
chown 0:0 "$H"/etc/ssh/ssh_host_*

echo "== reset machine-id =="
NEWID="$(openssl rand -hex 16)"
printf '%s\n' "$NEWID" > "$H/etc/machine-id"
[ -L "$H/var/lib/dbus/machine-id" ] || printf '%s\n' "$NEWID" > "$H/var/lib/dbus/machine-id"
chown 0:0 "$H/etc/machine-id" "$H/var/lib/dbus/machine-id"
chmod 444 "$H/etc/machine-id" "$H/var/lib/dbus/machine-id"

echo "== apply startup-wizard patches =="
python3 "$BASE/patch-wizard.py" "$H"

echo "== restore file capability (timed) =="
setcap cap_sys_time=ep "$H/usr/bin/timed"

if [ "$DEVICE" = "cheeseburger" ]; then
    echo "== cheeseburger device swap =="
    [ -f "$VENDOR" ] || { echo "ERROR: cheeseburger build requires vendor.img as 4th argument"; exit 1; }
    bash "$BASE/make-cheeseburger.sh" "$H" "$VENDOR"
elif [ "$DEVICE" != "dumpling" ]; then
    echo "ERROR: unknown device $DEVICE (use dumpling|cheeseburger)"; exit 1
fi

umount "$MNT"; rmdir "$MNT"; trap - EXIT

echo "== e2fsck =="
e2fsck -fy "$IMG" >/dev/null 2>&1 || true
e2fsck -fn "$IMG" >/dev/null || { echo "fsck reported errors"; exit 1; }
echo "OK: $IMG"
