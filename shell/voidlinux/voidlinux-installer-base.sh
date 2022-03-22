#!/bin/sh

# a shell script to perform a very basic installation of Void Linux

: "${progname:="${0##*/}"}"
[ "$(id -u)" -ne 0 ] && { echo "This script must be run as root"; exit 1; }


usage() {
	cat <<_EOF
Usage: $progname [glibc|musl]
_EOF
}

partition_format() {
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
	echo w		# write table to disk and exit
	) | fdisk /dev/sda
	sync
	mkfs.vfat -F32 /dev/sda1
	mkfs.xfs -f /dev/sda2
	sync
}

mount_bootstrap() {
	mount /dev/sda2 /mnt
	mkdir /mnt/boot
	mount /dev/sda1 /mnt/boot
	XBPS_ARCH="$XBPS_ARCH" xbps-install -y -S -R "$VOID_REPO" -r /mnt base-system syslinux
	for mp in sys dev proc; do
		mount --rbind /$mp /mnt/$mp && mount --make-rslave /mnt/$mp
	done
	cp /etc/resolv.conf /mnt/etc/

}

chroot_script() {
	cat >/mnt/home/chroot_script.sh <<- _CHROOT_SCRIPT_EOF
### System configuration
sed -i '
s/^#HARDWARECLOCK=.*/HARDWARECLOCK="UTC"/
s/^#TIMEZONE=.*/TIMEZONE="UTC"/
s/^#KEYMAP=.*/KEYMAP="dvorak-programmer"/
s/^#FONT=.*/FONT="Lat2-Terminus16"/
' /etc/rc.conf
if [ "$XBPS_ARCH" = "x86_64" ]; then
	sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/default/libc-locales
	xbps-reconfigure -f glibc-locales
fi
echo void-basic >/etc/hostname
echo "UUID=$(blkid -o value -s UUID /dev/sda1)\t/boot\tvfat\tdefaults\t0\t0" >>/etc/fstab
echo "UUID=$(blkid -o value -s UUID /dev/sda2)\t/\txfs\trw,noatime,discard\t0\t1" >>/etc/fstab
echo 'hostonly="yes"' >/etc/dracut.conf.d/hostonly.conf

### User
useradd -m -s /bin/bash baz
echo 'password\npassword' | passwd baz
echo 'password\npassword' | passwd
echo 'cat /proc/uptime >/tmp/uptime' >>/home/baz/.bash_profile

### tty1 autologin
cp -r /etc/sv/agetty-tty1 /etc/sv/agetty-autologin-tty1
rm /etc/sv/agetty-autologin-tty1/supervise
sed -i 's/GETTY_ARGS="--noclear"/GETTY_ARGS="--autologin baz --noclear"/' /etc/sv/agetty-autologin-tty1/conf
#rm /etc/runit/runsvdir/current/agetty-tty1
#ln -s /etc/sv/agetty-autologin-tty1 /etc/runit/runsvdir/current/agetty-tty1

### syslinux
mkdir /boot/syslinux
cp /usr/lib/syslinux/ldlinux.c32 /boot/syslinux/
extlinux --install /boot/syslinux
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr.bin of=/dev/sda
cat >/etc/kernel.d/post-install/50-syslinux <<- END_OF_50_SYSLINUX
#!/bin/sh
PKGNAME="\\\$1"
VERSION="\\\$2"
cat >/boot/syslinux/syslinux.cfg <<- END_OF_SYSLINUX_CFG
PROMPT 1
TIMEOUT 50
DEFAULT void
LABEL void
LINUX /vmlinuz-\\\${VERSION}
APPEND initrd=/initramfs-\\\${VERSION}.img
END_OF_SYSLINUX_CFG
END_OF_50_SYSLINUX
chmod 754 /etc/kernel.d/post-install/50-syslinux
xbps-reconfigure -fa
rm /etc/runit/runsvdir/current/agetty-tty1
ln -s /etc/sv/agetty-autologin-tty1 /etc/runit/runsvdir/current/agetty-tty1
_CHROOT_SCRIPT_EOF
chroot /mnt /bin/sh /home/chroot_script.sh
rm /mnt/home/chroot_script.sh
umount -R /mnt
}

case $1 in
	glibc)
		read -p "Press Enter to continue... " reply
		[ "$reply" != "" ] && { echo "Stopped."; exit 0; }
		XBPS_ARCH="x86_64"
		VOID_REPO="https://alpha.de.repo.voidlinux.org/current"
		partition_format
		mount_bootstrap
		chroot_script
		;;
	musl)
		read -p "Press Enter to continue... " reply
		[ "$reply" != "" ] && { echo "Stopped."; exit 0; }
		XBPS_ARCH="x86_64-musl"
		VOID_REPO="https://alpha.de.repo.voidlinux.org/current/musl"
		partition_format
		mount_bootstrap
		chroot_script
		;;
	*)	usage;;
esac

