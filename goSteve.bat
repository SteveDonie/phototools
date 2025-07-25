@echo off
echo Making just Steve album and then syncing to S3

REM Get current date and time
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "current_date_time=%MM%/%DD%/%YYYY% %HH%:%Min%"

echo. > timing.txt
echo Started at %current_date_time% >> timing.txt

REM Copy index file (adjust paths as needed for Windows)
copy "%USERPROFILE%\personal\donie.us\album-index.html" "%USERPROFILE%\albums\index.html"

echo. >> timing.txt
echo Time to make Personal >> timing.txt

REM Time the Perl command (Windows doesn't have built-in time command like bash)
echo %TIME% - Starting MakeAlbum.pl >> timing.txt
perl MakeAlbum.pl Personal.aws
echo %TIME% - Finished MakeAlbum.pl >> timing.txt

echo. >> timing.txt
echo Time to sync to S3 >> timing.txt

REM Time the sync script
echo %TIME% - Starting syncSteve.bat >> timing.txt
call syncSteve.bat
echo %TIME% - Finished syncSteve.bat >> timing.txt

REM Get current date and time again
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "current_date_time=%MM%/%DD%/%YYYY% %HH%:%Min%"

echo. >> timing.txt
echo finished at %current_date_time% >> timing.txt

REM Display the timing file contents
type timing.txt