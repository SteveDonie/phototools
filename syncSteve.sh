#! /bin/bash
echo Syncing Steve content from ~/albums to S3
aws s3 cp ~/albums/index.html s3://album.donie.us/

echo Syncing album 'personal'
aws s3 sync ~/albums/personal/ s3://album.donie.us/personal --delete

aws cloudfront create-invalidation --distribution-id EUW7OI0F4K5GR --paths "/personal/*"
