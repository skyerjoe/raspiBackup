#!/bin/bash
#######################################################################################################################
#
# raspiBackup backup creation regression test
#
#######################################################################################################################
#
#    Copyright (C) 2013-2019 framp at linux-tips-and-tricks dot de
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#######################################################################################################################

MYSELF=${0##*/}
MYNAME=${MYSELF%.*}
CURRENT_DIR=$(pwd)

if [[ $UID != 0 ]]; then
	sudo $0 """"$@""""
	exit $?
fi

LOG_FILE="$CURRENT_DIR/${MYNAME}.log"
rm -f "$LOG_FILE" 2>&1 1>/dev/null
exec 1> >(tee -a "$LOG_FILE" >&1)
exec 2> >(tee -a "$LOG_FILE" >&2)

VMs=$CURRENT_DIR/qemu
IMAGES=$VMs/images

TEST_SCRIPT="testRaspiBackup.sh"
BACKUP_ROOT_DIR="/disks/bigdata"
BACKUP_MOUNT_POINT="obelix:$BACKUP_ROOT_DIR"
BACKUP_DIR="raspibackupTest"
BOOT_ONLY=0
KEEP_VM=1
RASPBIAN_OS="wheezy"
RASPBIAN_OS="stretch"

(( $START_NOMMCBLK )) && echo "Starting no MMCBLK image"

VM_IP="192.168.0.114"	# wheezy
VM_IP="192.168.0.135" 	# stretch

echo "Removing snapshot"
rm $IMAGES/raspianRaspiBackup-snap-${RASPBIAN_OS}.qcow &>/dev/null

echo "Creating target backup directies"
mkdir -p $BACKUP_ROOT_DIR/${BACKUP_DIR}_N
mkdir -p $BACKUP_ROOT_DIR/${BACKUP_DIR}_P

TESTENVIRONMENTS="SD USB SDBOOTONLY"
TESTENVIRONMENTS="SDBOOTONLY"

for environment in $TESTENVIRONMENTS; do

	echo "Checking for VM $VM_IP already active and start VM otherwise with environment $environment"

	if ! ping -c 1 $VM_IP; then

		echo "Creating snapshot"

		case $environment in
			# SD card only
			SD) qemu-img create -f qcow2 -b $IMAGES/raspianRaspiBackup-${RASPBIAN_OS}.qcow $IMAGES/raspianRaspiBackup-snap-${RASPBIAN_OS}.qcow
				echo "Starting VM in raspianRaspiBackup-snap-${RASPBIAN_OS}.qcow"
				$VMs/start.sh raspianRaspiBackup-snap-${RASPBIAN_OS}.qcow &
				;;
			# no SD card, USB boot
			USB) qemu-img create -f qcow2 -b $IMAGES/raspianRaspiBackup-Nommcblk-${RASPBIAN_OS}.qcow $IMAGES/raspianRaspiBackup-snap-${RASPBIAN_OS}.qcow
				echo "Starting VM in raspianRaspiBackup-snap-${RASPBIAN_OS}.qcow"
				$VMs/start.sh raspianRaspiBackup-snap-${RASPBIAN_OS}.qcow &
				;;
			# boot on SD card but use external root filesystem
			SDBOOTONLY) qemu-img create -f qcow2 -b $IMAGES/raspianRaspiBackup-BootSDOnly-${RASPBIAN_OS}.qcow $IMAGES/raspianRaspiBackup-snap-${RASPBIAN_OS}.qcow
				qemu-img create -f qcow2 -b $IMAGES/raspianRaspiBackup-RootSDOnly-${RASPBIAN_OS}.qcow $IMAGES/raspianRaspiBackup-RootSDOnly-snap-${RASPBIAN_OS}.qcow
				echo "Starting VM in raspianRaspiBackup-snap-${RASPBIAN_OS}.qcow"
				$VMs/startStretchBootSDOnly.sh raspianRaspiBackup-snap-${RASPBIAN_OS}.qcow raspianRaspiBackup-RootSDOnly-snap-${RASPBIAN_OS}.qcow &
				types="dd"
				modes="N"
				bootModes="-B-"
				;;
			*) echo "invalid environment $environment"
				ext 42
		esac

		echo "Waiting for VM with IP $VM_IP to come up"
		while ! ping -c 1 $VM_IP &>/dev/null; do
			sleep 3
		done
	fi

	SCRIPTS="raspiBackup.sh $TEST_SCRIPT .raspiBackup.conf"

	for file in $SCRIPTS; do
		echo "Uploading $file"
		while ! scp $file root@$VM_IP:/root &>/dev/null; do
			sleep 3
		done
	done
done

if (( $BOOT_ONLY )); then
	echo "Finished"
	exit 0
fi

function sshexec() { # cmd
	echo "Executing $@"
	ssh root@$VM_IP "$@"
}

sshexec "chmod +x ~/$TEST_SCRIPT"

sshexec "time ~/$TEST_SCRIPT $BACKUP_MOUNT_POINT \"$BACKUP_DIR\" \"$environment\" \"$types\" \"$modes\" \"$bootmodes\""

echo "Downloading testrun log"
scp root@$VM_IP:/root/testRaspiBackup.log . 1>/dev/null

echo "Downloading raspiBackup.log log"
scp root@$VM_IP:/root/raspiBackup.log . 1>/dev/null

if (( ! $KEEP_VM )); then
	echo "Shuting down"
	sshexec "shutdown -h now"
	sudo pkill qemu
fi

grep "Backup test finished successfully" testRaspiBackup.log

if (( $? > 0 )); then
	echo "??? Backup failures: $failures"
	exit 127
else
	echo "--- Backup test successfull"
	exit 0
fi
