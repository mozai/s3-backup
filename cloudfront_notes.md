Using https instead of AWS Console to fetch backups
===================================================
For Jax and her assistants, I wanted a way for them to access
their backups that was easier than learning AWS Console.

The point of doing these tarball backups instead of efficient
block-level stuff and "thou must use special client software"
stuff is because I want non-technical people to get their stuff
even if the clown mafia finds out where I live and they drag me back.

Steps I took to get it working securely:
- I already have the s3 bucket as per what's in [README.md](README.md).
  It was named backups-taurus in region ca-central-1.
- backups-taurus permissions are set thus:
  - Block public access: On
  - Bucket Policy: (empty) (for now)
- in AWS Cloudfront, first you create a Function and then a Distribution.
- The new Cloudfront Function you make like so:
  - left-hand sidebar click "functions" then the orange "create function"
    button.
  - Name "backup-taurus-auth" Description "password-protect an S3 bucket"
    then "Create function"
  - on the "Development" tab, replace the code with this javascript:
    ```javascript
    function handler(event) {
      var allowedAuths = [
        "Basic " + "user1:password-one".toString("base64"),
        "Basic " + "user2:password-two".toString("base64")
      ];
      var authHeader = event.request.headers.authorization;
      if (authHeader && allowedAuths.indexOf(authHeader.value) >= 0)
        return event.request;
      else {
        return {
          statusCode: 401,
          statusDescription: "Unauthorized",
          headers: {"www-authenticate": {value: "Basic realm=\"Application\"" } },
        };
      }
    }
    ```
    Yeah yeah, plaintext passwords, but only if you let other people
    read your Cloudfront stuff.
  - On the "test" tab you can try it out.  Event "Viewer Request", stage
    "Development", http method "GET", URL path "/index.html", and add
    a header like so: header 'authorization" value "Basic
    dXNlcjE6cGFzc3dvcmQtb25lCg=="  where it's the base64-encoded version
    of the "userblah:password-blah" you put into the function.  Click the
    orange "test" button and I hope you see green.
  - on the "publish" tab there's an orange "publish function" button.
    hit it.  Then go back to the list of Cloudfront functions and wait
    for the "status" column to change from "Updating" to "Deployed"
    before going on to the next part.
- The new Cloudfront Distribution is made like this (hope I remembered
  all the steps):
  - left-hand sidebar click "distributions", then the orange "create
    distribution" button.
  - Origin domain: click on it and you'll get a list of your S3 buckets;
    here I used "backups-taurus.s3.ca-central-1.amazonaws.com"
  - Name: leave as-is, it's irrelevant
  - Origin access: "Origin access control settings"
    Then "Origin access control" is empty, click the "create control
    setting" and accept the defaults but name it "S3 control" because
    you can re-use it.
    It will also warn you about updating the S3 bucket policy.  Keep going.
  - Default cache behavior, Compress objects automatically "No" because
    tarballs are already compressed it's a waste
  - Viewer
    - viewer protocol policy: "Redirect HTTP to HTTPS" because we're
      going to use basic http auth and that can be evesdropped on if you
      allow normal HTTP.
    - allowed http methods: "GET, HEAD" because this is read-only access
    - restrict viewer access: No, because we're going to use something else
  - Cache key and origin
    - "Cache policy and origin request policy" when I wrote this the
      UI had an error where the next two fields are connected to the
      option you didn't choose.  Cache policy could be "CachingOptimized"
      but I  used the "Create policy" link to make a new one with "min 1s,
      max 86400, default 3600"  Origin request policy empty, response
      headers empty.
  - Function association.  remember the one you made above?  here it goes.
    "Viewer request" function type is "Cloudfront Functions" and Name is
    the one you made above "backup-taurus-auth" for me.
  - the rest leave as defaults, tho write a nice Description at the end
    just before the orange "Create distribution" button.  I turned off
    IPv6 on a whim.  "Standard logging" can be turned off you don't
    want to store logs of every bot trying to guess passwords.
  - click that orange "create distribution" button, and you're not
    done yet.
  - You'll get a status page for the new Cloudfront Distribution AND
    a blue warning about "The S3 bucket policy needs to be updated".
    First thing's first, write down the 12+ random character name for this
    Cloudfront Distribution.  Then click the white "copy policy" button
    to stuff your clipboard, then click "Go to S3 bucket to update
    policy".  Scroll down to "bucket policy" and click "edit" then Ctrl-V
    paste into the empty text editor. (Is it not empty? well paste on the
    end, then just pluck the one "Statement" item and paste it in with
    the rest and clean it up; if it wasn't empty then surely you know what
    you're doing.)  The new Statement should look something like this:
    ```json
    { "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": { "Service": "cloudfront.amazonaws.com" },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::backups-taurus/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::<<acctnum>>:distribution/<<cloudfront-id>>"
        }
      }
    }
    ```
    Save changes and close this tab, go back to the Cloudfront one.
- Back in the Cloudfront tab, click on "Distributions" in the left-hand
  column to get a list of all of them.  Wait for the "Status" item
  to turn green with "Enabled".  then time to test.
- Open a new private/incognito window, aim it at
  https://{{cloudfront-id}}.cloudfront.net/  and hopefully your browser
  prompts you for a username and password.  Give it the "user-foo" and
  "password-bar" you wrote into the Cloudfront Function, and I hope it works
  because I've already written over a hundred and twenty lines just to
  describe what to do if things go right; writing another four-hundred lines
  for an incomplete list of what could go wrong is too much when I'm not
  getting paid for this.


TODO: how to do all the above with aws-cli instead of pointy-clicky.

    s3bucket="backups-taurus"
    funcname="backups-taurus_auth"
    etag=$(aws cloudfront describe-function --name $funcname |jq -r '.ETag')
    aws cloudfront get-function --name $funcname --stage LIVE ${funcname}.js
    # edit it, then
    aws cloudfront update-function --name $funcname --if-match $etag --function-config '{"Comment": "HTTP Basic auth for '"$s3bucket"'.s3", "Runtime": "cloudfront-js-1.0"}' --function-code file://$funcname.js
    # get new etag
    etag=$(aws cloudfront describe-function --name $funcname |jq -r '.ETag')
    aws cloudfront publish-function --name $funcname --if-match $etag
 

done: make an index.html generator. `backup_index_in_s3 s3://bucket/prefix` 
TODO: custom error pages for 403 forbidden and 404 not found.

