#!/bin/bash
# because the backup is multiple steps

workdir=$(dirname "$(readlink -f -- "$0")")
cd "$workdir" || exit 1;

# clean out older backups; keep daily < 7d, keep weekly <30d, keep monthly <1y
# nah, using Amazon S3 lifecycle policy instead; see README.md
#./prune_s3.py

# some stuff I'll need for rebuilding but don't need lying around
dpkg -l |grep '^.i' >/root/installed-packages.txt

# load config
for f in "$HOME/.config/s3-backup.cfg" "$HOME/.s3-backup.cfg" "./s3-backup.cfg"; do
	# shellcheck disable=SC1090
	[[ -e "$f" ]] && source "$f" && break;
done

# this will stream tarballs up to Amazon S3
./backup_files_to_s3
./backup_mysql_to_s3

# TODO: this is awkward as heck
update_top=""
today=$(date -I)
for j in backups_daily backups_weekly backups_monthly; do
	if aws s3 ls "$S3BUCKET/$S3PATH/$j/$today" >/dev/null; then
		./backup_index_in_s3 "$S3BUCKET/$S3PATH/backups_daily/$today"
		update_top=t
		break
	fi
done
if [[ -n "$update_top" ]]; then
	./backup_index_in_s3 "$S3BUCKET/$S3PATH/"
fi
