#!/bin/bash
[[ $(id -u) -eq 0 ]] || { echo "Superuser privilage required." ; exit 1; };

#configuration begin

#Filesystem UUID of external device
uuid="e7d5d3ec-c60c-49f9-b6a0-259a751b5bca"
#user whose directiry is to be backed up
user="siddharthbhat"
#mountpoint of external device
mountpoint="/home/backup"
#directory where bachup should be stored. cannot be empty
dir="backup"
# specify "true" if a gui prompt is required at the end of backup
gui="true"
# display backup status? specify "true" for yes. display 0 must be active.
status_report="true"

#configuration end

dev=$(lsblk -no UUID,PATH | awk "/^$uuid/ { print \$NF } ")
[[ -z "$mountpoint" ]] && mountpoint="/mnt"
[[ -z "$dir" ]] && dir="bup/"
[[ "$status_report" == "true" ]] && gui="true"

if [[ -z "$uuid" ]]; then
	echo "uuid=\"$uuid\" is empty" 1>&2;
	exit 1;
else
	[[ -b "$dev" ]] || { echo "uuid=\"$uuid\" is not assosiated with any block device" 1>&2 ; exit 1; };
fi

[ -f "/home/$user/.local/bin/bup-run.sh" ] || { echo "bup-run.sh not found" 1>&2; exit 1; } &&
[ -x "/home/$user/.local/bin/bup-run.sh" ] || { echo "bup-run.sh not executable" 1>&2; exit 1; };

if [ "$status_report" == "true" ]; then
	rm -f /tmp/backup-script-error.log

	env DISPLAY=":0" "/home/$user/.local/bin/bup-run.sh" --directory="/home/$user" \
		--target-dir="$dir" --mountpoint="$mountpoint" --unmount \
		--prompt gui  --user="$user" --report="$user" "$dev" 2>/tmp/backup-script-error.log
	code=$?

	chown "$user":"$user" /tmp/backup-script-error.log
	chmod a+r /tmp/backup-script-error.log
else
	"/home/$user/.local/bin/bup-run.sh" --directory="/home/$user" \
	        --target-dir="$dir" --mountpoint="$mountpoint" --unmount \
	        --prompt cli  --user="$user" "$dev"
	code=$?
fi

if [ $code -ne 0 ]; then
	echo "non zero exit code : $code" 1>&2;
	if [ "$gui" == "true" ]; then
		sudo -nu "$user" env DISPLAY=":0" XDG_RUNTIME_DIR="/run/user/$(id -u "$user")" KDE_SESSION_VERSION=5 KDE_FULL_SESSION=true dbus-launch \
			kdialog --title "Backup Script" --sorry \
			"Script returned with non zero exit status $code\nPlease check \"/tmp/backup-script-error.log\" for details." &
	fi
else
	if [ "$gui" == "true" ]; then
		sudo -nu "$user" env DISPLAY=":0" XDG_RUNTIME_DIR="/run/user/$(id -u "$user")" KDE_SESSION_VERSION=5 KDE_FULL_SESSION=true dbus-launch \
			kdialog --title "Backup Script" --sorry \
			"Script returned with exit status $code\nSuccessfully finished backing up!" &
	fi
fi

exit $code
