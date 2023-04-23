#!/bin/bash
# remakes the index.html file for each backup hosted in S3
#   remember Amazon S3 doesn't really have subdirectories,
#   it's all a key-value store pretending to be a filesystem.

subdirs=(
	backups_monthly
	backups_weekly
	backups_daily
)
	

cd "$(dirname "$(readlink -f -- "$0")")" || exit 1;
# load config
for f in "$HOME/.config/s3-backup.cfg" "$HOME/.s3-backup.cfg" "./s3-backup.cfg"; do
	# shellcheck disable=SC1090
	[[ -e "$f" ]] && source "$f" && break;
done
if [[ -z "$S3BUCKET" ]]; then
	echo >&2 "no cfg file found"; exit 1;
fi

# upload an index.html to each "subdirectory"
prefix="$S3BUCKET/$S3PATH"
prefix=${prefix%/}
for subdir in "${subdirs[@]}"; do
	for when in $(aws s3 ls "$prefix/$subdir/" |awk '/PRE/{print $2;}'); do 
		./backup_index_in_s3 "$prefix/$subdir/$when"
	done
done
# should sense the "backups_*" and make the top-level index.html
./backup_index_in_s3 "$prefix/"

