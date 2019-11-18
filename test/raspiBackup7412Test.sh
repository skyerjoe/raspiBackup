#!/bin/bash
#######################################################################################################################
#
# 	Test script to test raspiBackup smarte recycle strategy
#	1) Keep last 7 daily backups
#	2) Keep last 4 weekly backups
#	3) Keep last 12 monthly backups
#	4) Keep last 1 yearly backup
#
#######################################################################################################################
#
#    Copyright (C) 2019 framp at linux-tips-and-tricks dot de
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

set -euf -o pipefail

MYSELF=${0##*/}
MYNAME=${MYSELF%.*}
VERSION="0.1"

set +u;GIT_DATE="$Date: 2019-11-15 11:55:29 +0100$"; set -u
GIT_DATE_ONLY=${GIT_DATE/: /}
GIT_DATE_ONLY=$(cut -f 2 -d ' ' <<< $GIT_DATE)
GIT_TIME_ONLY=$(cut -f 3 -d ' ' <<< $GIT_DATE)
set +u;GIT_COMMIT="$Sha1: 51b67df$";set -u
GIT_COMMIT_ONLY=$(cut -f 2 -d ' ' <<< $GIT_COMMIT | sed 's/\$//')

GIT_CODEVERSION="$MYSELF $VERSION, $GIT_DATE_ONLY/$GIT_TIME_ONLY - $GIT_COMMIT_ONLY"

if (( $UID != 0 )); then
	echo "Call me as root"
	exit 1
fi

# main program

### NOTE ### This is test code for raspiBackup smart recycle strategy !!!

SCRIPT_DIR=$( cd $( dirname ${BASH_SOURCE[0]}); pwd | xargs readlink -f)
DIR="7412backups"

rm -rf $DIR
mkdir $DIR	# create directory to get faked backup directories
# create daily fake backups for the last 2 years
c=$((365 * 2))

# create just daily backup directories as raspiBackup will do
today=$(date +"%Y-%m-%d")
echo "Creating $c fake backups in dir $DIR"
TICKS=100
t=$TICKS
for i in $(seq 0 $c); do
	F_D=0
	for y in $(seq 0 $F_D); do		# added rnd loop to make 1-5 backups each day - warning LOG/CONSOLE SPAM ! call test with echo to file
		F_HR=15
		F_MI=42
		F_SI=45
		printf -v F_HR "%02d" $F_HR
		printf -v F_MI "%02d" $F_MI
		printf -v F_SI "%02d" $F_SI
        h="$(hostname)/$(hostname)-rsync-backup-"$(date -d "$today -$i days" +%Y%m%d-)
        n="$h$F_HR$F_MI$F_SI"
		mkdir -p $DIR/$n
		if (( --t == 0 )); then
			echo "Next $TICKS ... $n ..."
			t=$TICKS
		fi
	done
done

./raspiBackup.sh --smartRecycleOptions "7 4 12 1" --smartRecycle --smartRecycleDryrun- -t rsync -F -x -c -e $(<email.conf) -Z -m 1 -l 1 -L 3 -o : -a : 7412backups

f=$(ls 7412backups/obelix.framp.de/ | wc -l)

if (( f != 23 )); then
	echo "???: Expected 23 but found $f backups"
	exit 1
else
	echo "---: Test succeeded"
fi
