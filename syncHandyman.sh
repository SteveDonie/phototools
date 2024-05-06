#! /bin/bash
echo Syncing content from ~/Google Drive/Handyman/website/httrack/webnode-site/i-can-do-that-handyman.webnode.page to S3
aws s3 sync ~/Google\ Drive/Handyman/website/httrack/webnode-site/i-can-do-that-handyman.webnode.page/ s3://www.icandothathandyman.com/ --delete
