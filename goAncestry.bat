@echo off
echo Making ancestry album and then syncing to S3

REM Get current date and time
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "current_date_time=%MM%/%DD%/%YYYY% %HH%:%Min%"

echo. > timing.txt
echo Started at %current_date_time% >> timing.txt

echo %TIME% - Starting MakeAlbum.pl for ancestry >> timing.txt
perl MakeAlbum.pl ancestry.aws
echo %TIME% - Finished MakeAlbum.pl for ancestry >> timing.txt

echo. >> timing.txt
echo Time to sync to S3 >> timing.txt

REM Time the sync script
echo %TIME% - Starting syncAncestry.bat >> timing.txt
call syncAncestry.bat
echo %TIME% - Finished syncAncestry.bat >> timing.txt

REM Get current date and time again
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "current_date_time=%MM%/%DD%/%YYYY% %HH%:%Min%"

echo. >> timing.txt
echo finished at %current_date_time% >> timing.txt

REM Display the timing file contents
type timing.txt