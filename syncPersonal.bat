@echo off
echo Syncing all personal content from "%USERPROFILE%\albums to S3

REM Copy index file to S3 
aws s3 cp "%USERPROFILE%\albums\index.html" s3://album.donie.us/

echo Syncing resume
aws s3 cp "%USERPROFILE%\Google Drive\Steve Donie" resume.pdf s3://album.donie.us/SteveResume.pdf

echo Syncing album 'projects'
aws s3 sync "%USERPROFILE%\albums\projects" s3://album.donie.us/projects --delete

echo Syncing album 'ancestry'
aws s3 sync "%USERPROFILE%\albums\ancestry" s3://album.donie.us/ancestry --delete

echo Syncing album 'eastdale'
aws s3 sync "%USERPROFILE%\albums\eastdale" s3://album.donie.us/eastdale --delete

echo Syncing album 'eastthird'
aws s3 sync "%USERPROFILE%\albums\eastthird" s3://album.donie.us/eastthird --delete

echo Syncing album 'family'
aws s3 sync "%USERPROFILE%\albums\family" s3://album.donie.us/family --delete

echo Syncing album 'personal'
aws s3 sync "%USERPROFILE%\albums\personal" s3://album.donie.us/personal --delete

REM Create CloudFront invalidation
aws cloudfront create-invalidation --distribution-id EUW7OI0F4K5GR --paths "/*"