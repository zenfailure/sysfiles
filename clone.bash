#!/usr/bin/env bash

set -eu

function efi {
    [[ -d /sys/firmware/efi ]]
}

if which wget &>/dev/null; then
    FETCHCMD='wget --quiet -O-'
elif which curl &>/dev/null; then
    FETCHCMD='curl -s'
fi

NAME="${NAME:-epicenter}"
TARGETS="${TARGETS:-$(echo /dev/[vs]d?)}"
TIMEZONE="${TIMEZONE:-Europe/Paris}"
NEWUSER="${NEWUSER:-maiz}"

NEWROOT=/newroot
SYSDIR="/home/$NEWUSER/.sysfiles"
SYSURL=\
"https://raw.githubusercontent.com/zenfailure/sysfiles/master/install.bash"

ARCH="${ARCH:-x86_64}"

REPO="${REPO:-https://alpha.de.repo.voidlinux.org/live/current/}"

ROOTFS=$($FETCHCMD "$REPO" | grep -i "$ARCH-rootfs" |
    sed -rn 's:<[^>]*>(.*)<[^>]*>:\1:p' | awk '{print $1}')

BOOTLABEL="${BOOTLABEL:-EFIBOOT}"
ROOTLABEL="${ROOTLABEL:-VOIDROOT}"
SWAPLABEL="${SWAPLABEL:-VOIDSWAP}"

BOOTPART="/dev/disk/by-label/$BOOTLABEL"
ROOTPART="/dev/disk/by-label/$ROOTLABEL"

SWAPSZ="${SWAPSW:-8}"
SWAPSZ=$((1024 * "$SWAPSZ"))

MOUNT_OPTS="defaults,rw,noatime"
BTRFS_OPTS="$MOUNT_OPTS,compress=zstd,space_cache,autodefrag"

mkdir -p "$NEWROOT"

for TARGET in $TARGETS; do
    offset=$(($(blockdev --getsz "$TARGET") - 2048))

    dd bs=512 count=2048 if=/dev/zero of="$TARGET"
    dd bs=512 count=2048 if=/dev/zero of="$TARGET" seek="$offset"

    parted "$TARGET" mklabel gpt

    parted "$TARGET" mkpart primary   2MiB  10MiB
    parted "$TARGET" mkpart primary  10MiB 138MiB
    parted "$TARGET" mkpart primary 138MiB   100%

    parted "$TARGET" set 1 bios_grub on
    parted "$TARGET" set 2 esp       on

    PARTS+=(${TARGET}3)
done


DISK="${PARTS[0]}"
EFI="${PARTS[0]//3/2}"

mkfs.vfat  -n "$BOOTLABEL" -F 32 "$EFI"
mkfs.btrfs -L "$ROOTLABEL" -f "${PARTS[@]}"

mountpoint -q "$NEWROOT" && umount -R "$NEWROOT"

mount -o "$MOUNT_OPTS" "$DISK" "$NEWROOT"

btrfs subvolume create "$NEWROOT/main"
btrfs subvolume create "$NEWROOT/home"
btrfs subvolume create "$NEWROOT/snapshots"

umount -R "$NEWROOT"

mount -o "$BTRFS_OPTS,subvol=main" "$DISK" "$NEWROOT"

mkdir -p "$NEWROOT/home"
mkdir -p "$NEWROOT/.snapshots"
mkdir -p "$NEWROOT/.volumes"
mkdir -p "$NEWROOT/boot/grub/efi"

mount -o "$BTRFS_OPTS,subvol=home"      "$DISK" "$NEWROOT/home"
mount -o "$BTRFS_OPTS,subvol=snapshots" "$DISK" "$NEWROOT/.snapshots"
mount -o "$MOUNT_OPTS"                  "$DISK" "$NEWROOT/.volumes"
mount -o "$MOUNT_OPTS"                  "$EFI"  "$NEWROOT/boot/grub/efi"

wget "$REPO/$ROOTFS"

tar xvf "$ROOTFS" -C "$NEWROOT"

for dir in dev proc sys; do
    mount --rbind /$dir $NEWROOT/$dir
    mount --make-rslave $NEWROOT/$dir
done

cp -L /etc/resolv.conf $NEWROOT/etc/

chroot $NEWROOT xbps-install -Syu xbps
chroot $NEWROOT xbps-install -yu \
    base-system btrfs-progs grub grub-x86_64-efi \
    ansible git zsh curl wget void-repo-nonfree \
    gnupg mkpasswd pass tar sudo rsync openssh

echo $NAME             > $NEWROOT/etc/hostname
echo LANG=en_US.UTF-8  > $NEWROOT/etc/locale.conf
echo en_US.UTF-8 UTF-8 > $NEWROOT/etc/default/libc-locales
chroot $NEWROOT xbps-reconfigure -f glibc-locales

echo "HARDWARECLOCK=UTC"     > $NEWROOT/etc/rc.conf
echo "TIMEZONE=$TIMEZONE"   >> $NEWROOT/etc/rc.conf
echo "CGROUP_MODE=hybrid"   >> $NEWROOT/etc/rc.conf

cat << EOF | column -t > $NEWROOT/etc/fstab
LABEL=$ROOTLABEL /              btrfs $BTRFS_OPTS,subvol=main 0 0
LABEL=$ROOTLABEL /home          btrfs $BTRFS_OPTS,subvol=home 0 0
LABEL=$BOOTLABEL /boot/grub/efi vfat  $MOUNT_OPTS 0 2
tmpfs            /tmp           tmpfs defaults,nosuid,nodev 0 0
EOF
#/.swapfile       none           swap  defaults 0 0

chroot "$NEWROOT" mkdir  -p /var/lib/libvirt/images
chroot "$NEWROOT" chattr +C /var/lib/libvirt/images
chroot "$NEWROOT" btrfs property set /var/lib/libvirt/images compression none

cat << EOF > "$NEWROOT/etc/default/grub"
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL=console
EOF
# GRUB_CMDLINE_LINUX_DEFAULT="video=efifb"

if efi; then
    chroot "$NEWROOT" grub-install        \
        --target=x86_64-efi            \
        --efi-directory=/boot/grub/efi \
        --boot-directory=/boot         \
        --bootloader-id=GRUB
fi

for TARGET in $TARGETS; do
    chroot "$NEWROOT" grub-install --target=i386-pc "$TARGET"
done

chroot "$NEWROOT" grub-mkconfig -o /boot/grub/grub.cfg
chroot "$NEWROOT" xbps-reconfigure -fa

chroot "$NEWROOT" usermod -s /bin/zsh root
chroot "$NEWROOT" useradd -m -s /bin/zsh "$NEWUSER"

chroot "$NEWROOT" \
    bash -c 'echo "ALL ALL=(ALL) NOPASSWD: ALL" | EDITOR=tee visudo'

if [[ -z "$PASSPHRASE" ]]; then
    echo "Set env variable PASSPHRASE then continue"
    exit 1
fi

chroot "$NEWROOT" su -l "$NEWUSER" -s /bin/bash -c \
    "export PASSPHRASE=\"$PASSPHRASE\"; $FETCHCMD \"$SYSURL\" | bash"

echo "Define root password:"
chroot "$NEWROOT" passwd

echo "Define user password:"
chroot "$NEWROOT" passwd "$NEWUSER"

umount -R "$NEWROOT"
