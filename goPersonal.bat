@echo off
echo Making all personal albums and then syncing to S3

REM Get current date and time
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "current_date_time=%MM%/%DD%/%YYYY% %HH%:%Min%"

echo. > timing.txt
echo Started at %current_date_time% >> timing.txt

REM Copy index file and resume icon
copy "%USERPROFILE%\personal\donie.us\album-index.html" "%USERPROFILE%\albums\index.html"
copy "%USERPROFILE%\personal\donie.us\resume-icon.jpg" "%USERPROFILE%\albums\resume-icon.jpg"

echo. >> timing.txt
echo Time to make Personal >> timing.txt

REM Time the Perl command (Windows doesn't have built-in time command like bash)
echo %TIME% - Starting MakeAlbum.pl for Family >> timing.txt
perl MakeAlbum.pl Family.aws
echo %TIME% - Finished MakeAlbum.pl for Family >> timing.txt

echo %TIME% - Starting MakeAlbum.pl for Personal >> timing.txt
perl MakeAlbum.pl Personal.aws
echo %TIME% - Finished MakeAlbum.pl for Personal >> timing.txt

echo %TIME% - Starting MakeAlbum.pl for Eastdale >> timing.txt
perl MakeAlbum.pl Eastdale.aws
echo %TIME% - Finished MakeAlbum.pl for Eastdale >> timing.txt

echo %TIME% - Starting MakeAlbum.pl for EastThird >> timing.txt
perl MakeAlbum.pl EastThird.aws
echo %TIME% - Finished MakeAlbum.pl for EastThird >> timing.txt

echo %TIME% - Starting MakeAlbum.pl for projects >> timing.txt
perl MakeAlbum.pl projects.aws
echo %TIME% - Finished MakeAlbum.pl for projects >> timing.txt

echo %TIME% - Starting MakeAlbum.pl for ancestry >> timing.txt
perl MakeAlbum.pl ancestry.aws
echo %TIME% - Finished MakeAlbum.pl for ancestry >> timing.txt

echo. >> timing.txt
echo Time to sync to S3 >> timing.txt

REM Time the sync script
echo %TIME% - Starting syncPersonal.bat >> timing.txt
call syncPersonal.bat
echo %TIME% - Finished syncPersonal.bat >> timing.txt

REM Get current date and time again
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "current_date_time=%MM%/%DD%/%YYYY% %HH%:%Min%"

echo. >> timing.txt
echo finished at %current_date_time% >> timing.txt

REM Display the timing file contents
type timing.txt