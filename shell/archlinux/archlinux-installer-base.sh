#!/bin/sh

# a shell script to perform to a very basic installation of Arch Linux

[ "$(id -u)" -ne 0 ] && { echo "This script must be run as root"; exit 1; }

: "${progname:="${0##*/}"}"
usage() {
	cat <<_EOF
Usage: $progname [glibc]
_EOF
}

step1_partition() {
	umount /dev/sda*
	umount -R /mnt
	wipefs -a /dev/sda
	dd if=/dev/zero of=/dev/sda bs=8M count=80 status=progress
	(
	echo o		# create a new empty DOS partition table
	echo n		# partition 1, primary, 200M
	echo p
	echo 1
	echo
	echo +200M
	echo n		# partition 2, primary
	echo p
	echo 2
	echo
	echo
	echo a		# bootable: partition 1
	echo 1
	echo w
	) | fdisk /dev/sda
	sync
	mkfs.vfat -F32 /dev/sda1
	mkfs.xfs -f /dev/sda2
	sync
}

step2_bootstrap() {
	mount /dev/sda2 /mnt
	mkdir /mnt/boot
	mount /dev/sda1 /mnt/boot
	echo "Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch" >/etc/pacman.d/mirrorlist
	pacstrap /mnt base linux linux-firmware xfsprogs syslinux
	genfstab -U /mnt >>/mnt/etc/fstab
}

step3_chroot() {
	cat >/mnt/home/chroot_script.sh <<- _CHROOT_SCRIPT_EOF
# configuration
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf
echo "KEYMAP=dvorak-programmer" >/etc/vconsole.conf
echo "arch-basic" >/etc/hostname
cat <<_END_OF_HOSTS >>/etc/hosts
127.0.0.1	localhost
::1		localhost
_END_OF_HOSTS

# tty1 autologin
mkdir /etc/systemd/system/getty\@tty1.service.d
cat <<_END_OF_GETTY_TTY1_CONF >/etc/systemd/system/getty\@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin root --noclear %I \\\$TERM
_END_OF_GETTY_TTY1_CONF
echo 'cat /proc/uptime >/tmp/uptime' >>/root/.bash_profile

# syslinux
mkinitcpio -P
echo 'root:password' | chpasswd
syslinux-install_update -i -m
sed -i 's#APPEND root=/dev/sda3 rw\$#APPEND root=/dev/sda2 rw#' /boot/syslinux/syslinux.cfg
_CHROOT_SCRIPT_EOF
	arch-chroot /mnt /bin/sh /home/chroot_script.sh
	rm /mnt/home/chroot_script.sh
}

read -p "Press Enter to continue... " reply
[ "$reply" != "" ] && { echo "Stopped."; exit 0; }

timedatectl set-ntp true
step1_partition
step2_bootstrap
step3_chroot
umount -R /mnt

# get uptime/memory_usage/systemd_analyze
#BT=$(cut -d' ' -f1 /tmp/uptime)
#MEM=$(free -h | grep '^Mem:' | awk '{print $3}')
#SA=$(systemd-analyze | cut -d' ' -f4,7,10 | paste -d' ' -s)
#echo -e "$BT\n$MEM\n$SA" >$(date -u +%s).txt
