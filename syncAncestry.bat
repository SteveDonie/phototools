@echo off
echo Syncing ancestry album from "%USERPROFILE%\albums\ancestry to S3

echo Syncing album 'ancestry'
aws s3 sync "%USERPROFILE%\albums\ancestry" s3://album.donie.us/ancestry --delete

REM Create CloudFront invalidation
aws cloudfront create-invalidation --distribution-id EUW7OI0F4K5GR --paths "/*"