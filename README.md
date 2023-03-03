What
====
Offsite backups to Amazon S3.  I want it to be super-easy to restore,
even for someone who only uses windows, so no complicated software they
have to install first.

Good idea to `dpkg -l | grep '^.i' >/root/installed-packages.txt;` just
before the backup, and other config that isn't obvious from reading
`/etc/*`.

**TODO:** need more documentation for each of the wrinkles I've had to add
over time.

Set-up
======
Have an S3 bucket in Amazon, duh.  Has to be globally unique among
all Amazon customers, so don't worry about it being inelegant.

Install aws-cli; version 2, don't use the Debian packages and
don't just use pip to install boto3.

In Amazon console, create an IAM policy and new IAM user.
IAM policy should be named like 'HOSTONE\_write\_S3BUCKET'

```json
    { "Statement": [
      { "Action": "s3:ListBucket",
        "Condition": {
          "StringLike": { "s3:prefix": "HOSTONE/*" }
        },
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::S3BUCKET",
        "Sid": "readHOSTONE"
      },
      { "Action": [
          "s3:PutObject",
          "s3:GetObject",
          "s3:AbortMultipartUpload",
          "s3:DeleteObjectVersion",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:ListMultipartUploadParts"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::S3BUCKET/HOSTONE/*",
        "Sid": "writeHOSTONE"
      }
    ],
    "Version": "2012-10-17"
    }
```

```
mkdir /root/.aws ; chmod 700 /root/.aws ;
echo -e "[default]\nregion = ca-central-1" >/root/.aws/config
echo -e "[default]\naws_access_key_id = AKarglebargle\n" \
  >/root/.aws/credentials
echo "aws_secret_access_key = 8kkXhoobastank" >>/root/.aws/credentials
history -d -2  # erase the log of your password
aws sts get-caller identity  # make sure it works
```

Add some rules to the bucket's lifecycle config, like below.
Unfortunately,
the rules are bucket-wide so you have to overwrite all the rules when you
just want to change one of them.
```json
{ "Rules": [
    { "Expiration": { "Days": 8 },
      "ID": "HOSTONE-daily",
      "Filter": { "Prefix": "HOSTONE/backups_daily" },
      "Status": "Enabled" },
    { "Expiration": { "Days": 36 },
      "ID": "HOSTONE-weekly",
      "Filter": { "Prefix": "HOSTONE/backups_weekly" },
      "Status": "Enabled" },
    { "Expiration": { "Days": 730 },
      "ID": "HOSTONE-monthly",
      "Filter": { "Prefix": "HOSTONE/backups_monthly" },
      "Status": "Enabled" },
    { "Expiration": { "Days": 8 },
      "ID": "HOSTTWO-daily",
      "Filter": { "Prefix": "HOSTTWO/backups_daily" },
      "Status": "Enabled" },
    { "Expiration": { "Days": 36 },
      "ID": "HOSTTWO-weekly",
      "Filter": { "Prefix": "HOSTTWO/backups_weekly" },
      "Status": "Enabled" },
    { "Expiration": { "Days": 730 },
      "ID": "HOSTTWO-monthly",
      "Filter": { "Prefix": "HOSTTWO/backups_monthly" },
      "Status": "Enabled" }
  ]
}
```
Then
`aws --profile S3admin s3api put-bucket-lifecycle-configuration \
  --bucket $S3BUCKET --lifecycle-configuration file://./policy.json`

Copy s3-backup.example.cfg to s3-backup.cfg and edit it to match
your personal settings.


Automation
==========
Throw this into /etc/cron.d/local
```
# offsite backups
12 6 * * *      root    /root/s3-backup/backup_cronjob.sh
```

TODO
====
* move the config out to a config file so I don't have to keep stripping/
  injecting my personal info to this git repo. =P

* Easy tool to just point at a dir like /home/radio and upload just
  that one thing right now.  Needed for the huge and unchanging things
  like /home/radio/sessionrecordings

* Is it worth doing level-2 incrementals with tar?

* investigate using `aws s3api put-object` instead of `aws s3 cp`, so
  we can use tagging for expiry instead of object-name prefixes

* incremental backups of mysql databases, how if possible?
