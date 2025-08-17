@echo off
echo Making just Steve album and then syncing to S3

:: Get current date and time
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "current_date_time=%MM%/%DD%/%YYYY% %HH%:%Min%"

echo. > timing.txt
echo Started at %current_date_time% >> timing.txt

:: Copy index file (adjust paths as needed for Windows)
echo Copying index file
copy "%USERPROFILE%\personal\donie.us\album-index.html" "%USERPROFILE%\albums\index.html"

:: if this is on, it will always refresh the faces database and always process all the
:: photos. Comment this out when in production mode.
::echo goSteve.bat running face recognition training
::perl TrainFaces.pl personal.aws train

echo. >> timing.txt
echo Time to make Personal >> timing.txt

:: Time the Perl command (Windows doesn't have built-in time command like bash)
echo %TIME% - Starting MakeAlbum.pl >> timing.txt
perl MakeAlbum.pl Personal.aws
echo %TIME% - Finished MakeAlbum.pl >> timing.txt

echo. >> timing.txt
echo Time to sync to S3 >> timing.txt

:: Time the sync script
echo %TIME% - Starting syncSteve.bat >> timing.txt
call syncSteve.bat
echo %TIME% - Finished syncSteve.bat >> timing.txt

:: Get current date and time again
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "current_date_time=%MM%/%DD%/%YYYY% %HH%:%Min%"

echo. >> timing.txt
echo finished at %current_date_time% >> timing.txt

:: Display the timing file contents
type timing.txt