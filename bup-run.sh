 #!/bin/bash
options=$(getopt -o hDum:t:d: --long help,debug,mountpoint:,report:,unmount,target-dir:,dir:,directory: -- "$@")
[ $? -eq 0 ] || {
	echo -e "\e[1;31mUnexpected Error\e[0m terminating...."
	exit 3
}
eval set -- $options

function set_zero() {
	mode=0
	umnt=0
	dev=""
	path=""
	tardir=""
	mntpt=""
	spath=""
	debug=0
}
set_zero

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
		} ||  { echo -e "\e[31mError\e[0m: mountpoint is does not exist" 1>&2; exit 1; }
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
		} ||  { echo -e "\e[31mError\e[0m: directory \"$1\" is does not exist" 1>&2; exit 1; }
		shift
		;;
	  -u | --unmount)
		umnt=1
		shift
		;;
	  -D | --debug )
		debug=1
		shift
		;;
	  --report)
		shift
		id "$1" > /dev/null || { echo -e "\e[31mError\e[0m: User does not exist" 1>&2; exit 1; };
		tmp=$(id -u)
		[ $((tmp)) -eq 0 ] || [ $tmp -eq $(($(id -u "$1"))) ] && reportuser="$(id -nu "$1")" ||
		  { echo -e "\e[31mError\e[0m: Current User must be root to report to \"$1\"" 1>&2; exit 1; };
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
		echo -e "\e[31mError\e[0m: mountpoint specified for non-block device" 1>&2
		exit 2
	}
	path="$1"
	mode=1
else
	echo -e "\e[31mError\e[0m: Non-existant directory \"$1\"" 1>&2
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

[ -z "$path" ] && [ "$(printf "$path" | tr -s '/' | awk -F '/' '{ print $2 }')" = "home" ] &&
	echo -e "\e[31mError\e[0m: For safty reasons backup cannot be stored in system directories" 1>&2 &&
	exit 1;

function message {
	[ -z "$reportuser" ] && return 1;
	#sudo -nu "$reportuser" bash -c 'env XAUTHORITY=$XAUTHORITY DISPLAY=$DISPLAY dbus-launch kdialog --title "$1" --passivepopup "$2" 5'
	#sudo -E -nuu "$reportuser" bash -c ' echo $XDG_RUNTIME_DIR'
	local xdg_dir="/run/user/$(id -u "$reportuser")"
	sudo -nu "$reportuser" env XDG_RUNTIME_DIR="$xdg_dir" kdialog --title "$1" --passivepopup "$2" 5
}


if [ $debug -eq 1 ]; then
	echo "cmdline : \"$@\""
	echo "path : $path"
	echo "mntpt : $mntpt"
	echo "dev : $dev"
	echo "mode : " $mode
	echo "tardir : $tardir"
	echo "spath : $spath"
	echo "umnt : $umnt"
	echo "debug : $debug"
	echo "reportuser : $reportuser"
	message "Backup Script" "Debug Prompt"
	exit 0
fi

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

function backup { #arg1 == directory to backup, arg2 == directory to store backup
	local dir="Backup-$(date +'%Y')"
	[ -d "$2" ] && BUP_DIR="$2" || return 1;
	message "Backup Script" "Backup Started"
	[ -d "$BUP_DIR/$dir" ] || { mkdir "$BUP_DIR/$dir"; bup -d "$BUP_DIR/$dir" init; } || exit 100
	[ -d "$1" ] &&
	  { echo -e "\e[34mIndexing....\e[0m"; bup -d "$BUP_DIR/$dir" index -ux "$1" || exit 101; } || return 2;
	echo -e "\e[34mBacking up....\e[0m"
	bup -d "$BUP_DIR/$dir" save -c --name "$(date +'bup-%Y')" "$1" || exit 102
	printf "bup" > "$BUP_DIR/$dir/"version.txt && bup --version >> "$BUP_DIR/$dir/"version.txt
	git --version >> "$BUP_DIR/$dir/"version.txt
	message "Backup Script" "Finished Backing Up"
}

case $mode in
	1)
		uuid=$(lsblk -lpno NAME,UUID | grep -w "$dev" | awk '{ print $NF }')
		[ -z "$uuid" ] && { echo -e "\e[31mError :\e[0m No filesystem detected on $dev" 1>&2; exit 1; };
		[ -d  "$path/$tardir" ] || mkdir -p "$path/$tardir" || { echo -e "\e[31mError\e[0m : Failed to make directory \"$path/$tardir\"" 1>&2; exit 1; };
		backup "$spath" "$path/$tardir"; tmp=$?
		[ $tmp -eq 0 ] || { echo -e "\e[31mError :\e[0m During Backup" 1>&2; exit 1; };
		;;
	2)
		uuid=$(lsblk -lpno NAME,UUID | grep -w "$dev" | awk '{ print $NF }')
		[ -z "$uuid" ] && { echo -e "\e[31mError :\e[0m No filesystem detected on $dev" 1>&2; exit 1; };
		mount_dev "$uuid" "$mntpt"; tmp=$?
		[ $tmp -eq 0 ] || { echo -e "\e[31mError :\e[0m Mounting device" 1>&2; exit $tmp; };
		[ -d  "$mntpt/$tardir" ] || mkdir -p "$mntpt/$tardir" || { echo -e "\e[31mError\e[0m : Failed to make directory \"$mntpt/$tardir\"" 1>&2; exit 1; };
		backup "$spath" "$mntpt/$tardir"; tmp=$?
		[ $tmp -eq 0 ] || { echo -e "\e[31mError :\e[0m During Backup" 1>&2; exit 1; };
		[ $umnt -eq 1 ] && { sleep 1; umount_dev; tmp=$?;
		[ $tmp -eq 0 ] || { echo -e "\e[31mError :\e[0m Unmounting device" 1>&2; exit 1; }; };
		;;
esac
