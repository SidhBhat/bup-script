[[ $(id -u) -eq 0 ]] || { echo "Superuser privilage required." ; exit 1; };

#Filesystem UUID of external device
uuid="e7d5d3ec-c60c-49f9-b6a0-259a751b5bca"
#user whose directiry is to be backed up
user="siddharthbhat"
#mountpoint of external device
mountpoint="/home/backup"
#directory where bachup should be stored. cannot be empty
dir="backup/"


dev=$(lsblk -no UUID,PATH | awk "/^$uuid/ { print \$NF } ")
[[ -z "$mountpoint" ]] && mountpoint="/mnt"
[[ -z "$dir" ]] && dir="bup/"

if [[ -z "$uuid" ]]; then
	echo "uuid=\"$uuid\" is empty" 1>&2;
	exit 1;
else
	[[ -b "$dev" ]] || { echo "uuid=\"$uuid\" is not assosiated with any block device" 1>&2 ; exit 1; };
fi

[ -f "/home/$user/.local/bin/bup-run.sh" ] || { echo "bup-run.sh not found" 1>&2; exit 1; } &&
[ -x "/home/$user/.local/bin/bup-run.sh" ] || { echo "bup-run.sh not executable" 1>&2; exit 1; };

"/home/$user/.local/bin/bup-run.sh" --directory="/home/$user" --prompt gui --unmount \ 
	--target-dir="$dir" --mountpoint="$mountpoint" --report="$user" --user="$user" "$dev" 2>/tmp/backup-script-error.log
code=$?
[ $code -ne 0 ] && {
	echo "non zero exit code : $code" 1>&2;
	sudo -u "$user" env XDG_RUNTIME_DIR="/run/user/$(id -u "$user")" kdialog --title "Backup Script" --sorry \
		"Script returned with non zero exit status\nPlease check \"/tmp/backup-script-error.log\" for details." &
	chmod a+r /tmp/backup-script-error.log
};

exit $code
