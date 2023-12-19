#! /bin/bash
echo Syncing content from ~/albums to S3
aws s3 cp ~/albums/index.html s3://album.donie.us/

echo Syncing album 'projects'
aws s3 sync ~/albums/projects/ s3://album.donie.us/projects --delete

echo Syncing album 'eastdale'
aws s3 sync ~/albums/eastdale/ s3://album.donie.us/eastdale --delete

echo Syncing album 'incoming'
aws s3 sync ~/albums/incoming/ s3://album.donie.us/incoming --delete

