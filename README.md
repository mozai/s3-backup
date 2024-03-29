What
----
Offsite backups to Amazon S3.  I want it to be super-easy to restore,
even for someone who only uses windows, so no complicated software they
have to install first.

Good idea to `dpkg -l | grep '^.i' >/root/installed-packages.txt;` just
before the backup, and other config that isn't obvious from reading
`/etc/*`.

Set-up
------
Have an S3 bucket in Amazon, duh.  Has to be globally unique among
all Amazon customers, so don't worry about it being inelegant.

Install aws-cli; version 2, don't use the Debian packages and
don't just use pip to install boto3.

In Amazon console, create an IAM policy and new IAM user.
I usually name the policy "S3\_{S3BUCKET}\_write"
The "seeBuckets" could be discarded, but this is designed
to be easy for Amazon non-experts, and without it the AWS Console
will hide buckets from your users.
```json
{ "Version": "2012-10-17",
  "Statement": [
    { "Sid": "seeBuckets",
      "Action": "s3:ListAllMyBuckets",
      "Effect": "Allow",
      "Resource": "*"
    },
    { "Sid": "seeSepulchre",
      "Action": "s3:ListBucket",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::{S3BUCKET}"
    },
    { "Sid": "writeToSepulchre",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListMultipartUploadParts",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::{S3BUCKET}/*"
    }
  ]
}
```

For the end-user that needs read access to these backups, make
another police (I'd name it "S3\_{S3BUCKET}\_read") like the above
but without the "Abort" and "DeleteObject" and "PutObject" actions.

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
      "ID": "backups_daily",
      "Filter": { "Prefix": "backups_daily/" },
      "Status": "Enabled" },
    { "Expiration": { "Days": 36 },
      "ID": "backups_weekly",
      "Filter": { "Prefix": "backups_weekly/" },
      "Status": "Enabled" },
    { "Expiration": { "Days": 730 },
      "ID": "backups_monthly",
      "Filter": { "Prefix": "backups_monthly/" },
      "Status": "Enabled" }
  ]
}
```
Then
`aws --profile S3admin s3api put-bucket-lifecycle-configuration \
  --bucket $S3BUCKET --lifecycle-configuration file://./policy.json`

Copy s3-backup.example.cfg to s3-backup.cfg and edit it to match
your personal settings.

Easy pick-up via Cloudfront
---------------------------
**TODO** explain what I did, how I made it safe.  Leave 
CLOUDFRONT\_URL empty in the config file until I write
out how to use it properly.

Automation
----------
Throw this into /etc/cron.d/local
```
# offsite backups
12 6 * * *      root    /opt/s3-backup/backup_cronjob.sh
```

DEBUG
-----
set envvar `DRYRUN=1` before launching; it won't upload but show you
how it would upload instead. [**TODO** this needs better instructions]

TODO
----
* Easy tool to just point at a dir like /home/radio and upload just
  that one thing right now.  Needed for the huge and unchanging things
  like /home/radio/sessionrecordings
* ~~investigate using `aws s3api put-object` instead of `aws s3 cp`~~
  No, put-object limited to 5GB upload, and can't handle pipes/stdin besides.
* add `aws put-object-tagging --bucket BN --key FN --tagging
  '{"TagSet":[{"Key": "string","Value": "string"}, ...]}'
  after a successful upload.  Maybe use tagging instead of prefixes
  for the lifecycle policy?  But doesn't appear in AWS console. =/
* Sense when the full backup is missing, even if there are (incorrect)
  snarfiles locally.
* Cloudfront documentation
* Is it worth doing level-2 incrementals with tar?
* incremental backups of mysql databases, how if possible?
* need more documentation for each of the wrinkles I've had to add
  over time.
* maybe ignore/skip more directories by default, like '.ssh' and '.aws'
  and '.git'.  THe first two for security, the second for sheer bloat.
