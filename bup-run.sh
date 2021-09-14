#!/bin/bash
options=$(getopt -o hm:t: --long help,mountpoint:,target-dir: -- "$@")
[ $? -eq 0 ] || {
	echo -e "\e[1;31mUnexpected Error\e[0m terminating...."
	exit 3
}
eval set -- $options
mode=
dev=
path=
tardir=
mntpt=

while true; do
	case "$1" in
	  -h | --help)
		echo "work in progress"
		shift
		;;
	 -m | --mountpoint)
		shift
		[ -d "$1" ] && {
			mntpt="$1"
		} || { echo -e "\e[31mError\e[0m: mountpoint is does not exist"; exit 1; }
		shift
		;;
	 -t | --target-dir)
		shift
			[ "${1:0:1}" == "/" ] && tardir="${1:1}" || tardir="$1"
		shift
		;;
	  --)
		shift
		break
		;;
	esac
done
[ -b "$1" ] && {
	dev="$1"
	mode=2
} ||  { [ -d "$1" ] && { [ -n "$mntpt" ] && {
	echo -e "\e[31mError\e[0m: mountpoint specified for non-block device"
	exit 2
} || {
	path="$1"
	mode=1
}; }; } || {
	echo -e "\e[31mError\e[0m: Non-existant directory \"$1\""
	exit 3
};

echo "path : $path"
echo "mntpt : $mntpt"
echo "dev : $dev"
echo "mode : " $mode
echo "tardir : $tardir"


function search_dev {
	lsblk -no UUID | grep -qiw "$1"
	return $?
}

function mount_dev {
	search_dev "$1" || return $?
	findmnt -S UUID="$1"  > /dev/null 2>&1 || {
		if [ -n "$(cat /etc/fstab | grep -iw "$1" |awk '/^UUID/ { print $1 }' | awk -F = '{ print $NF }' )" ]; then
			mount UUID="$1"
			local code=$?
		else
			mount UUID="$1" /mnt
			local code=$?
		fi
	} && local code=0
	[ $code -eq 0 ] && mntpt="$(findmnt -no TARGET -S UUID="$1")" && uuid="$1"
	return $code
}

function umount_dev {
	[ -n "$uuid" ] &&
	umount UUID="$uuid" ||
	return 1
}


#mode
# 1, wake at select time, search for drive, if connected ,mount and backup
# 2, frequntly wake , search for drive, if connected, mount and backup
# 3,
