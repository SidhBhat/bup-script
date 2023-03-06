# bup-script

This is backup script using the awesome [bup](https://github.com/bup/bup) backup utility!. This script
was written primarily to backup my home directory (to a seperate partition). Check out the bup
[documentation](https://bup.github.io/) for more info on how bup works.

This script is only for linux users, Windows Users, I'm sorry this isn't for you.

## Installation

This is a standalone bash script. All you need to do is install bup, the rest ypu probably have on your
system. You can check the complete list of dependencies here.

All you need to do is copy the script:

```bash
curl -sL https://raw.githubusercontent.com/SidhBhat/bup-script/main/bup-run.sh > bup-run.sh
# set execute bit
chmod u+x bup-run.sh
```

And you might want to put it somewhere in your path:

```bash
mv bup-run.sh ~/.local/bin/
```
## Using the script

The script will only backup entire directories. The synatx is:

```bash
bup-run.sh -d <directory to backup> <backup location>
```

`<backup location>` here is either a block device (partition) or a normal directory.

If it is a block device than backup is done on that partition after automatically mountiong it at `/mnt`.
You can control the mountpoint with the option `-m <mount point>`. And if you specify the unmount flag
`-u` than the script unmounts the partition after the backup is complete.

If however `<backup location>` is a directory the backup is written under it.

By default in either case, the backup files are located under \(the `BUP_DIR`\) `<backup location>/bup/`.
This can be changed by the `-t` option.

You want to keep the `<backup location>` \(along with whatever you specify with the `-t` option\) consistant
in order to make use of bup's incremental backups.

Every option mentioned above also has a corresponding long option (eg `--mount=<mount point>`). You can see
the list all options by running:

```bash
bup-run.sh --help
```

## Planned Improvements

 - Remove the `--prompt` option. This is a remnant from [bup-script-wrapper](https://github.com/SidhBhat/bup-script-wrapper).
   This script should focus only on the backup process[^1]. (Resloved!!)
 - Comments!, we need comments in code! I wrote this script a couple of years ago[^2], and than I had no idea this
   project would grow as complicated or that it would have general functionality.

## Contributing

You can simply start by creating a pull request. If you have Improvement suggestions you can contact me by email.


[^1]: This script originally started development along with the project [bup-script-wrapper](https://github.com/SidhBhat/bup-script-wrapper).
In fact you can find scripts from that project among the development history here. Commits before the one pointed by
the tag [wrapper-scrpts-latest](https://github.com/SidhBhat/bup-script/releases/tag/wrapper-scrpts-latest) have
remnants from [bup-script-wrapper](https://github.com/SidhBhat/bup-script-wrapper).
[^2]: Relative to the date of writing this README.
