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
	[ $code -eq 0 ] && path="$(findmnt -no TARGET -S UUID="$1")" && uuid="$1"
	return $code
}

function umount_dev {
	[ -n "$uuid" ] &&
	umount UUID="$uuid" ||
	return 1
}
mount_dev "$1"
echo "mounted : $path"
umount_dev
code=$?
exit $code

#mode
# 1, wake at select time, search for drive, if connected ,mount and backup
# 2, frequntly wake , search for drive, if connected, mount and backup
# 3,
