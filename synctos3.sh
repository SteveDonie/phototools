#! /bin/bash
echo Syncing personal content from ~/albums to S3
aws s3 cp ~/albums/index.html s3://album.donie.us/

echo Syncing album 'projects'
aws s3 sync ~/albums/projects/ s3://album.donie.us/projects --delete

echo Syncing album 'ancestry'
aws s3 sync ~/albums/ancestry/ s3://album.donie.us/ancestry --delete

echo Syncing album 'eastdale'
aws s3 sync ~/albums/eastdale/ s3://album.donie.us/eastdale --delete

echo Syncing album 'eastthird'
aws s3 sync ~/albums/eastthird/ s3://album.donie.us/eastthird --delete

echo Syncing album 'incoming'
aws s3 sync ~/albums/incoming/ s3://album.donie.us/incoming --delete

# moved to syncHandyman.sh
#echo Syncing content from ~/Google Drive/Handyman/website/httrack/webnode-site/i-can-do-that-handyman.webnode.page to S3
#aws s3 sync ~/Google\ Drive/Handyman/website/httrack/webnode-site/i-can-do-that-handyman.webnode.page/ s3://www.icandothathandyman.com/ --delete
