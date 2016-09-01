#!/bin/sh
# Create a RAM disk with same perms as mountpoint
# Script based on http://itux.idev.pro/2012/04/iservice-speed-up-your-xcode-%D0%BD%D0%B5%D0%BA%D0%BE%D1%82%D0%BE%D1%80%D1%8B%D0%B5-%D1%81%D0%BF%D0%BE%D1%81%D0%BE%D0%B1%D1%8B/ with some additions
# Usage: sudo ./xcode_ramdisk.sh start

USERNAME=$(logname)

TMP_DIR="/private/tmp"
RUN_DIR="/var/run"

USER_CACHES_DIR="/Users/$USERNAME/Library/Caches"
DEV_CACHES_DIR="/Users/$USERNAME/Library/Developer/Xcode/DerivedData"
DEV_IPHONE_DIR="/Users/$USERNAME/Library/Application Support/iPhone Simulator"
SYS_CACHES_DIR="/Library/Caches" # this must laster than USER_CACHES_DIR...

# Create folder if not exists
mkdir -p $USER_CACHES_DIR
mkdir -p $DEV_CACHES_DIR
mkdir -p $DEV_IPHONE_DIR
mkdir -p $SYS_CACHES_DIR

RAMDisk() {
	mntpt="$1"
	rdsize=$(($2*1024*1024/512))

	# Create the RAM disk.
	dev=`hdik -drivekey system-image=yes -nomount ram://$rdsize`
	# Successfull creation...
	if [ $? -eq 0 ] ; then
	# Create HFS on the RAM volume.
	newfs_hfs $dev
	# Store permissions from old mount point.
	eval `/usr/bin/stat -s "$mntpt"`
	# Mount the RAM disk to the target mount point.
	mount -t hfs -o union -o nobrowse -o nodev -o noatime $dev "$mntpt"
	# Restore permissions like they were on old volume.
	chown $st_uid:$st_gid "$mntpt"
	chmod $st_mode "$mntpt"
	
	echo "Creating RamFS for $mntpt $rdsize $dev"
	fi
}

UmountDisk() {
	mntpt="$1"
	dev=`mount | grep "$mntpt" | grep hfs | cut -f 1 -d ' '`
	umount -f "$mntpt"
	hdiutil detach "$dev"
	echo "Umount RamFS for $mntpt $dev"
	echo ""
}

# Test for arguments.
if [ -z $1 ]; then
echo "Usage: $0 [start|stop|restart] "
exit 1
fi

# Source the common setup functions for startup scripts
test -r /etc/rc.common || exit 1 
. /etc/rc.common

StartService () {
	ConsoleMessage "Starting RamFS disks..."

	RAMDisk "$TMP_DIR" 64
	RAMDisk "$RUN_DIR" 32
	RAMDisk "$SYS_CACHES_DIR" 32
	RAMDisk "$USER_CACHES_DIR" 128
	RAMDisk "$DEV_CACHES_DIR" 750
	RAMDisk "$DEV_IPHONE_DIR" 256

	#RAMDisk /var/db 1024
	#mkdir -m 1777 /var/db/mds
}
StopService () {
	ConsoleMessage "Stopping RamFS disks..."
	
	UmountDisk "$TMP_DIR"
	UmountDisk "$RUN_DIR"
	UmountDisk "$SYS_CACHES_DIR"
	UmountDisk "$USER_CACHES_DIR"
	UmountDisk "$DEV_CACHES_DIR"
	UmountDisk "$DEV_IPHONE_DIR"
	
	# diskutil unmount /private/tmp /private/var/run
	# diskutil unmount /private/var/run
}

RestartService () {
	ConsoleMessage "Restarting RamFS disks..."
	StopService
	StartService
}

RunService "$1"

