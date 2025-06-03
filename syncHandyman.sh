#! /bin/bash
echo Syncing content from ~/Google Drive/Handyman/website to S3
aws s3 sync ~/Google\ Drive/Handyman/website/ s3://www.icandothathandyman.com/ --exclude "*/desktop.ini" --exclude "desktop.ini" --delete 
aws cloudfront create-invalidation --distribution-id E3SI1N55U2O78O --paths "/*"