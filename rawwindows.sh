#!/bin/bash

set -e

# === Konfigurasi ===
IMG_NAME="alpine-auto-dd.img"
IMG_SIZE_MB=100
ALPINE_VERSION="3.19.1"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-${ALPINE_VERSION}-x86_64.tar.gz"
OS_IMAGE_URL="http://206.189.154.112/dotajav2.gz"
MOUNT_DIR="/mnt/alpine"

echo "[*] Membuat image $IMG_NAME sebesar ${IMG_SIZE_MB}MB..."
dd if=/dev/zero of="$IMG_NAME" bs=1M count="$IMG_SIZE_MB"
mkfs.ext4 -F "$IMG_NAME"

mkdir -p "$MOUNT_DIR"
mount -o loop "$IMG_NAME" "$MOUNT_DIR"

echo "[*] Mengunduh dan ekstrak Alpine Linux minimal..."
wget -qO alpine.tar.gz "$ALPINE_URL"
tar -xzf alpine.tar.gz -C "$MOUNT_DIR"

echo "[*] Membuat script autorun..."
cat > "$MOUNT_DIR/etc/local.d/autoinstall.start" <<EOF
#!/bin/sh
URL="${OS_IMAGE_URL}"
wget -O /os.gz "\$URL"
gunzip -c /os.gz | dd of=/dev/vda bs=4M status=progress
sync
reboot -f
EOF

chmod +x "$MOUNT_DIR/etc/local.d/autoinstall.start"

chroot "$MOUNT_DIR" /bin/sh -c "rc-update add local"

echo "[*] Membersihkan dan melepas mount..."
umount "$MOUNT_DIR"
rm alpine.tar.gz

echo "[*] Mengompres image menjadi ${IMG_NAME}.gz ..."
gzip -9 "$IMG_NAME"

echo "[✓] Selesai! File siap diupload: ${IMG_NAME}.gz"
