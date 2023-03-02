#!/usr/bin/env python3
# delete old backups in Amazon S3
# unless you're using lifecycle policy; see README.md

import boto3
from datetime import datetime
import re
import socket
import sys

AWS_REGION = "ca-central-1"
BUCKET_NAME = "S3BUCKET"
PREFIX = socket.gethostname()
PREFIX = PREFIX[:PREFIX.find('.')]


def whisper(msg):
    if sys.stdin.isatty():
        print(msg)


def get_all_s3folders(bucket, prefix):
    item_list = []
    partial_list = s3.list_objects_v2(
        Bucket=bucket, Prefix=prefix, Delimiter="/")
    if partial_list["KeyCount"] <= 0:
        return item_list
    item_list = [i.get("Prefix")
                 for i in partial_list["CommonPrefixes"]]  # folders
    while partial_list["IsTruncated"]:
        next_token = partial_list["NextContinuationToken"]
        partial_list = s3.list_objects_v2(
            Bucket=bucket, Prefix=prefix, Delimiter="/", ContinuationToken=next_token)
        item_list.extend([i.get("Prefix")
                         for i in partial_list["CommonPrefixes"]])
    return item_list


def get_all_s3files(bucket, prefix):
    item_list = []
    partial_list = s3.list_objects_v2(
        Bucket=bucket, Prefix=prefix, Delimiter="/")
    if partial_list["KeyCount"] <= 0:
        return item_list
    item_list = [i.get("Key") for i in partial_list["Contents"]]  # folders
    while partial_list["IsTruncated"]:
        next_token = partial_list["NextContinuationToken"]
        partial_list = s3.list_objects_v2(
            Bucket=bucket, Prefix=prefix, Delimiter="/", ContinuationToken=next_token)
        item_list.extend([i.get("Prefix") for i in partial_list["Contets"]])
    return item_list


s3 = boto3.client("s3")

# get the list of folders in there
item_list = get_all_s3folders(BUCKET_NAME, PREFIX)
# keep only the yyyy-mm-dd prefixes
filter_iso = re.compile(PREFIX+'\d\d\d\d-\d\d-\d\d/$')
item_list = list(filter(filter_iso.match, item_list))
item_list = sorted(item_list, reverse=True)
if not item_list:
    whisper("Nothing to do?")
    sys.exit(0)
# decide what to remove
to_remove = []
# keep the newest
whisper(f"keeping newest {item_list[0]}")
item_list.pop(0)
# keep newer than a week $age < 7
# keep weekly newer than a month $age < 30 and %yday % 7 == 1
# keep monthly up to a year $age < 365 and %yday % 28 == 1
# discard the rest
for i in item_list:
    datepart = i[len(PREFIX):-1]
    datepart = datetime.strptime(datepart, "%Y-%m-%d")
    age = (datetime.now() - datepart).days
    yday = int(datepart.strftime("%j"))
    if age < 7:
        whisper(f"keeping daily backup {i}")
    elif age < 30 and (yday % 7 == 1):
        whisper(f"keeping weekly backup {i}")
    elif age < 365 and (yday % 28 == 1):
        whisper(f"keeping monthly backup {i}")
    else:
        whisper(f"removing {i}")
        to_remove.append(i)

for doomed in to_remove:
    for i in get_all_s3files(BUCKET_NAME, doomed):
        whisper(f"deleting {i}")
        s3.delete_object(Bucket=BUCKET_NAME, Key=i)

