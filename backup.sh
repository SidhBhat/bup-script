[[ $(id -u) -eq 0 ]] || { echo "Superuser privilage required." ; exit 1; };

uuid="e7d5d3ec-c60c-49f9-b6a0-259a751b5bca"
dev=$(lsblk -no UUID,PATH | awk "/^$uuid/ { print \$NF } ")

if [[ -z "$uuid" ]]; then
	echo "uuid=\"$uuid\" is empty" 1>&2;
	exit 1;
else
	[[ -b "$dev" ]] || { echo "uuid=\"$uuid\" is not assosiated with any block device" 1>&2 ; exit 1; };
fi

[ -f "/home/siddharthbhat/.local/bin/bup-run.sh" ] || { echo "bup-run.sh not found" 1>&2; exit 1; } &&
[ -x "/home/siddharthbhat/.local/bin/bup-run.sh" ] || { echo "bup-run.sh not executable" 1>&2; exit 1; };

/home/siddharthbhat/.local/bin/bup-run.sh --directory=/home/siddharthbhat --prompt gui --unmount --target-dir=backup/ --mountpoint=/home/backup --report=siddharthbhat "$dev" | logger -st backup-script
code=$?
[ $code -ne 0 ] && {
	echo "non zero exit code : $code" 1>&2;
	sudo -u siddharthbhat env XDG_RUNTIME_DIR="/run/user/$(id -u siddharthbhat)" kdialog --title "Backup Script" --sorry \
	"Script returned with non zero exit status\nPlease check system logs with tag \"backup-script\" for details."
};

exit $code
