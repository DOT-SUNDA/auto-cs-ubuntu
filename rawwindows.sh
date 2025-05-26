#!/bin/bash
set -e

IMG_NAME="alpine-bootable.img"
IMG_SIZE_MB=100
ALPINE_VERSION="3.19.1"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}-x86_64.tar.gz"
OS_IMAGE_URL="http://206.189.154.112/dotajav2.gz"
MOUNT_DIR="/mnt/alpine"

echo "[*] Membuat image $IMG_NAME ukuran ${IMG_SIZE_MB}MB..."
dd if=/dev/zero of="$IMG_NAME" bs=1M count=$IMG_SIZE_MB

echo "[*] Membuat partisi MBR dan partisi primary ext4..."
parted "$IMG_NAME" --script mklabel msdos
parted "$IMG_NAME" --script mkpart primary ext4 1MiB 100%
parted "$IMG_NAME" --script set 1 boot on

LOOP_DEV=$(losetup --find --show --partscan "$IMG_NAME")
echo "[*] Loop device: $LOOP_DEV"

PART_DEV="${LOOP_DEV}p1"
echo "[*] Membuat filesystem ext4 di $PART_DEV..."
mkfs.ext4 -F "$PART_DEV"

mkdir -p "$MOUNT_DIR"
mount "$PART_DEV" "$MOUNT_DIR"

echo "[*] Mengunduh Alpine minirootfs..."
wget -qO alpine-rootfs.tar.gz "$ALPINE_URL"

echo "[*] Mengekstrak Alpine ke mount point..."
tar -xzf alpine-rootfs.tar.gz -C "$MOUNT_DIR"

echo "[*] Menyiapkan direktori boot..."
mkdir -p "$MOUNT_DIR"/boot

echo "[*] Mengunduh kernel dan initramfs Alpine..."
# Kernel dan initramfs di repo Alpine
wget -qO "$MOUNT_DIR"/boot/vmlinuz-virt "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/vmlinuz-virt"
wget -qO "$MOUNT_DIR"/boot/initramfs-virt "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/initramfs-virt"

echo "[*] Membuat script autorun untuk download dan dd..."
cat > "$MOUNT_DIR/etc/local.d/autoinstall.start" <<EOF
#!/bin/sh
URL="${OS_IMAGE_URL}"
wget -O /os.gz "\$URL"
gunzip -c /os.gz | dd of=/dev/vda bs=4M status=progress
sync
reboot -f
EOF

chmod +x "$MOUNT_DIR/etc/local.d/autoinstall.start"

echo "[*] Menambahkan service local ke rc-update..."
chroot "$MOUNT_DIR" /bin/sh -c "rc-update add local"

echo "[*] Memasang GRUB bootloader di image..."
grub-install --target=i386-pc --boot-directory="$MOUNT_DIR/boot" --modules="part_msdos ext2 normal multiboot" --recheck "$LOOP_DEV"

echo "[*] Membuat file grub.cfg..."
cat > "$MOUNT_DIR/boot/grub/grub.cfg" <<EOF
set timeout=5
set default=0

menuentry "Alpine Linux Auto Installer" {
    linux /boot/vmlinuz-virt console=ttyS0
    initrd /boot/initramfs-virt
}
EOF

echo "[*] Sync dan unmount..."
sync
umount "$MOUNT_DIR"
losetup -d "$LOOP_DEV"

rm alpine-rootfs.tar.gz

echo "[✓] Selesai! File image bootable siap: $IMG_NAME"
