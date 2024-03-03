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

if [[ -n "$CLOUDFRONT_URL" ]]; then
	# update the simple loading dock pages
	./backup_index_in_s3
fi
