@echo off
echo Syncing Brain Tumor content from ~/albums to S3

REM Copy index file to S3 
aws s3 cp "%USERPROFILE%\albums\index.html" s3://album.donie.us/
aws s3 cp "%USERPROFILE%\albums\resume-icon.jpg" s3://album.donie.us/

echo Syncing album 'Brain Tumor Stories'

REM Sync brain tumor` folder to S3
aws s3 sync "%USERPROFILE%\albums\brainTumor" s3://album.donie.us/brainTumor --delete

REM Create CloudFront invalidation
aws cloudfront create-invalidation --distribution-id EUW7OI0F4K5GR --paths "/brainTumor/*"