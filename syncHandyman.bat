@echo off

:: This assumes that the handyman MakeAlbum has been run, which populates the Google drive handyman website
:: past work album. Up until July 2026, that also contained the copy-pasted Canva website. In July 2026 I am
:: going to transition to the React-built website so I am going to have to redo this. The react website is 
:: currently set up with source code in C:\users\steve\Claude\Projects\HandymanWebsite\icandothat-react
:: and then the built version in C:\users\steve\Claude\Projects\HandymanWebsite\icandothat-react\dist
::
:: I think for safety's sake, I am going to start by copying the photo album into the new website and then 
:: syncing from there.

:: OLD---------------
:: echo Syncing content from %USERPROFILE%\Google Drive\Handyman\website to S3
:: aws s3 sync "%USERPROFILE%\Google Drive\Handyman\website" s3://www.icandothathandyman.com/ --exclude "*/desktop.ini" --exclude "desktop.ini" --delete 

:: NEW---------------
echo copying photo album to react dist directory
xcopy /e /y /q "%USERPROFILE%\Google Drive\Handyman\website\past-work" "%USERPROFILE%\Claude\Projects\HandymanWebsite\icandothat-react\dist\past-work"

echo Syncing content from %USERPROFILE%\Claude\Projects\HandymanWebsite\icandothat-react\dist to S3
aws s3 sync "%USERPROFILE%\Claude\Projects\HandymanWebsite\icandothat-react\dist" s3://www.icandothathandyman.com/ --exclude "*/desktop.ini" --exclude "desktop.ini" --delete

echo Running s3 cloud invalidation...
aws cloudfront create-invalidation --distribution-id E3SI1N55U2O78O --paths "/*"
