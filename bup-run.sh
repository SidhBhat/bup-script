 #!/bin/bash
options=$(getopt -o hDum:t:d: --long help,debug,mountpoint:,report:,user:,unmount,target-dir:,dir:,directory: -- "$@")
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
	user=""
	reportuser=""
}
set_zero

while true; do
	case "$1" in
	   -h | --help)
		echo -e "Usage:\n\t$0 [short-option <arg> ] [long-option <arg>] <backup location>\n"
		echo -e "Script to backup a entire directory (unfortunatly backups of directories are only supported)\n"
		echo "Options:"
		echo -e "  -h, --help\t\t\tDisplay this message"
		echo -e "  -d <dir>, --directory=<dir>\tDirectory to backup (defualt './')"
		echo -e "  -t <dir>, --target-dir=<dir>\tBackup folder(s) starting at the <backup location>"
		echo -e "\t\t\t\t  This directory is specified as an absolute path"
		echo -e "\t\t\t\t  The path is then built under the \"backup location\" (defualt 'bup/')"
		echo -e "  -m <dir>, --mountpoint=<dir>\tIf \"backup location\" is a block device (partition or external device)"
		echo -e "\t\t\t\t  this is the directory to mount it at (it must exist) (defualt '/mnt')"
		echo -e "  -u, --unmount\t\t\tIf \"backup location\" is a block device (partition or external device)"
		echo -e "\t\t\t\t  Unmount after backing up"
		echo -e "  -D, --debugt\t\t\tPrint Debugging information and exit"
		echo -e "  --report=<user>\t\tDisplay a graphical popup at a sesstion of <user>"
		echo -e "\t\t\t\t  during and after backup is complete(useful if running in background)"
		echo -e "  --user=<user>\t\t\tbackup as <user> (requires superuser previlages)"
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
		[ -d "/run/user/$(id -u "$reportuser")" ] || { echo -e "\e[31mError\e[0m: Cannot find \"xdg_runtime_dir\" for \"$reportuser\"" 1>&2; exit 1; };
		shift
		;;
	  --user)
		shift
		id "$1" > /dev/null || { echo -e "\e[31mError\e[0m: User does not exist" 1>&2; exit 1; };
		[ $((tmp)) -eq 0 ] || [ $tmp -eq $(($(id -u "$1"))) ] && user="$(id -nu "$1")" ||
		  { echo -e "\e[31mError\e[0m: Current User must be root to execute as \"$1\"" 1>&2; exit 1; };
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

[ -z "$path" ] && [ "$(printf "$path" | tr -s '/' | awk -F '/' '{ print $2 }')" == "home" ] &&
	echo -e "\e[31mError\e[0m: For safty reasons backup cannot be stored in system directories" 1>&2 &&
	exit 1;

[ -n "$user" ] && exec_as_user="sudo -nu $user"

function message {
	#[ -z "$reportuser" ] && { kdialog --title "$1" --passivepopup "$2" 5; return $?; };
	#sudo -nu "$reportuser" bash -c 'env XAUTHORITY=$XAUTHORITY DISPLAY=$DISPLAY dbus-launch kdialog --title "$1" --passivepopup "$2" 5'
	#sudo -E -nuu "$reportuser" bash -c ' echo $XDG_RUNTIME_DIR'
	[ -n "$reportuser" ] && {
		local xdg_dir="/run/user/$(id -u "$reportuser")";
		sudo -nu "$reportuser" env XDG_RUNTIME_DIR="$xdg_dir" kdialog --title "$1" --passivepopup "$2" 10 &
	} || {
		local xdg_dir="/run/user/$(id -u)";
		env XDG_RUNTIME_DIR="$xdg_dir" kdialog --title "$1" --passivepopup "$2" 10 &
	};
}


if [ $debug -eq 1 ]; then
	echo "cmdline : \"$options\""
	echo "path : $path"
	echo "mntpt : $mntpt"
	echo "dev : $dev"
	echo "mode : " $mode
	echo "tardir : $tardir"
	echo "spath : $spath"
	echo "umnt : $umnt"
	echo "debug : $debug"
	echo "reportuser : $reportuser"
	echo "user : $user"
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

function restore_msg {
	echo "restore command:"
	echo "bup -d <location of backup> restore [ --outdir=<dir to restore to(must be empty)>] <path to backup version>"
	echo "'path to backup version' is the bath to the backup as found by 'bup ls'"
	echo "basically it is 'bup-<year>/date/\"fully quallified path to saved directory\""
	echo "if 'path to backup version' is followed by a trailng '/' then the contents of the directory is restored directly in outdir"
}

function backup { #arg1 == directory to backup, arg2 == directory to store backup
	local dir="Backup-$(date +'%Y')"
	[ -d "$2" ] && BUP_DIR="$2" || return 1;
	message "Backup Script" "Backup Started"
	[ -d "$BUP_DIR/$dir" ] || { $exec_as_user mkdir "$BUP_DIR/$dir"; $exec_as_user bup -d "$BUP_DIR/$dir" init; } || exit 100
	[ -d "$1" ] &&
	  { echo -e "\e[34mIndexing....\e[0m"; $exec_as_user bup -d "$BUP_DIR/$dir" index -ux "$1" || exit 101; } || return 2;
	echo -e "\e[34mBacking up....\e[0m"
	$exec_as_user bup -d "$BUP_DIR/$dir" save -c --name "$(date +'bup-%Y')" "$1" || exit 102
	printf "bup " > "$BUP_DIR/$dir/"version.txt &&  bup --version >> "$BUP_DIR/$dir/"version.txt
	git --version >> "$BUP_DIR/$dir/"version.txt
	restore_msg > "$BUP_DIR/$dir/"restore.txt
	chown "$user":"$user" "$BUP_DIR/$dir/"restore.txt "$BUP_DIR/$dir/"version.txt
	message "Backup Script" "Finished Backing Up"
}

case $mode in
	1)
		uuid=$(lsblk -lpno NAME,UUID | grep -w "$dev" | awk '{ print $NF }')
		[ -z "$uuid" ] && { echo -e "\e[31mError :\e[0m No filesystem detected on $dev" 1>&2; exit 1; };
		[ -d  "$path/$tardir" ] || { mkdir -p "$path/$tardir"; } || { echo -e "\e[31mError\e[0m : Failed to make directory \"$path/$tardir\"" 1>&2; exit 1; };
		[ -n "$user" ] && { { chown "$user":"$user" "$path/$tardir" && chmod u+w,g+rx "$path/$tardir"; } || { echo -e "\e[31mError\e[0m : Failed to set permissions for directory \"$path/$tardir\"" 1>&2; exit 1; }; };
		backup "$spath" "$path/$tardir"; tmp=$?
		[ $tmp -eq 0 ] || { echo -e "\e[31mError :\e[0m During Backup" 1>&2; exit 1; };
		;;
	2)
		uuid=$(lsblk -lpno NAME,UUID | grep -w "$dev" | awk '{ print $NF }')
		[ -z "$uuid" ] && { echo -e "\e[31mError :\e[0m No filesystem detected on $dev" 1>&2; exit 1; };
		mount_dev "$uuid" "$mntpt"; tmp=$?
		[ $tmp -eq 0 ] || { echo -e "\e[31mError :\e[0m Mounting device" 1>&2; exit $tmp; };
		[ -d  "$mntpt/$tardir" ] || { mkdir -p "$mntpt/$tardir"; } || { echo -e "\e[31mError\e[0m : Failed to make directory \"$mntpt/$tardir\"" 1>&2; exit 1; };
		[ -n "$user" ] && { { chown "$user":"$user" "$mntpt/$tardir" && chmod u+w,g+rx "$mntpt/$tardir"; } || { echo -e "\e[31mError\e[0m : Failed to set permissions for directory \"$mntpt/$tardir\"" 1>&2; exit 1; }; };
		backup "$spath" "$mntpt/$tardir"; tmp=$?
		[ $tmp -eq 0 ] || { echo -e "\e[31mError :\e[0m During Backup" 1>&2; exit 1; };
		[ $umnt -eq 1 ] && { sleep 1; umount_dev; tmp=$?;
		[ $tmp -eq 0 ] || { echo -e "\e[31mError :\e[0m Unmounting device" 1>&2; exit 1; }; };
		;;
esac
