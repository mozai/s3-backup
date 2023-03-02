#!/bin/bash
# because the backup is multiple steps

cd $(dirname "$(readlink -f -- "$0")") || exit 1;

# clean out older backups; keep daily < 7d, keep weekly <30d, keep monthly <1y
# nah, using Amazon S3 lifecycle policy instead; see README.md
#./prune_s3.py

# some stuff I'll need for rebuilding but don't need lying around
dpkg -l |grep '^.i' >/root/installed-packages.txt

# this will stream tarballs up to Amazon S3
./backup_files_to_s3
./backup_mysql_to_s3

