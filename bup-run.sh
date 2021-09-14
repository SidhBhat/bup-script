#!/bin/bash
options=$(getopt -o hm:t:d: --long help,mountpoint:,target-dir:dir:directory: -- "$@")
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
spath=

while true; do
	case "$1" in
	  -h | --help)
		echo "work in progress"
		exit 0
		shift
		;;
	 -m | --mountpoint)
		shift
		[ -d "$1" ] && {
			mntpt="$1"
		} ||  { echo -e "\e[31mError\e[0m: mountpoint is does not exist"; exit 1; }
		shift
		;;
	 -t | --target-dir)
		shift
			[ "${1:0:1}" == "/" ] && tardir="${1:1}" || tardir="$1"
		shift
		;;
	  -d | --dir | --directory)
		shift
		[ -d "$1" ] && {
			spath="$1"
		} ||  { echo -e "\e[31mError\e[0m: directory \"$1\" is does not exist"; exit 1; }
		shift
		;;
	  --)
		shift
		break
		;;
	esac
done
if [ -b "$1" ]; then
	dev="$1"
	mode=2
elif [ -d "$1" ]; then
	[ -n "$mntpt" ] && {
		echo -e "\e[31mError\e[0m: mountpoint specified for non-block device"
		exit 2
	}
	path="$1"
	mode=1
else
	echo -e "\e[31mError\e[0m: Non-existant directory \"$1\""
	exit 3
fi

function expand_link {
	[ -n "$1" ] && { [ -d "$1" ] || [ -e "$1" ]; } && printf "$(readlink -f "$1")"
}

[ -z "$mntpt" ] && mntpt=/mnt
[ -z "$spath" ] && spath=./
[ -z "$tardir" ] && tardir=bup

mntpt=$(expand_link "$mntpt")
path=$(expand_link "$path")
spath=$(expand_link "$spath")

function search_dev {
	lsblk -no UUID | grep -qiw "$1"
	return $?
}

function mount_dev {
	search_dev "$1" || return $?
	findmnt -S UUID="$1"  > /dev/null 2>&1 && { local c=0; } || {
		if [ -n "$(cat /etc/fstab | grep -iw "$1" |awk '/^UUID/ { print $1 }' | awk -F = '{ print $NF }' )" ]; then
			mount UUID="$1"
			local c=$?
		else
			mount UUID="$1" "$2"
			local c=$?
		fi
	}
	[ $c -eq 0 ] && mntpt="$(findmnt -no TARGET -S UUID="$1")" && uuid="$1"
	return $c
}

function umount_dev {
	[ -n "$uuid" ] &&
	umount UUID="$uuid" ||
	return 1
}

case 1 in
	1)

		;;
	2)
		uuid=$(lsblk -lpno NAME,UUID | grep -w "$dev" | awk '{ print $NF }')
		[ -z "$uuid" ] && { echo -e "\e[31mError :\e[0m No filesystem detected on $dev"; exit 1; };
		mount_dev "$uuid" "$mntpt"; tmp=$?
		[ $tmp -eq 0 ] || { echo -e "\e[31mError :\e[0m Mounting device"; exit $tmp; };
		echo "backing up....."; sleep 1
		lsblk "$dev"
		umount_dev; tmp=$?
		[ $tmp -eq 0 ] || { echo -e "\e[31mError :\e[0m Unmounting device"; };
		;;
esac

echo "path : $path"
echo "mntpt : $mntpt"
echo "dev : $dev"
echo "mode : " $mode
echo "tardir : $tardir"
echo "spath : $spath"





#mode
# 1, wake at select time, search for drive, if connected ,mount and backup
# 2, frequntly wake , search for drive, if connected, mount and backup
# 3,
