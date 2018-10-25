@echo off

REM it would be nicer if this used Ant so it didn't make a new version every time, but only
REM when files in the distribution changed. It would also be nice to keep the source code
REM under source control somewhere, etc. etc..

echo This makes a distribution zip file for MakeAlbum, and copies the files
echo to the Tripod web directory.

call SetDayUID.bat
call SetDayUID.bat > MakeAlbumVersion.txt
echo.
if '%1'=='' pause
del SetupMakeAlbum.zip
del SetupMakeAlbum.exe
pkzip25 -add -warn SetupMakeAlbum.zip @FileList.txt >  MakeDist.log 2>&1 || type MakeDist.log | more

winzipse SetupMakeAlbum.zip -y -d "c:\photos" -win32 -st"Setup MakeAlbum %DAYUID%" -o -c "MakeAlbum.bat -help" 

echo copying files to e:\tripod...
copy SetupMakeAlbum.exe e:\tripod
copy MakeAlbumReadme.htm e:\tripod
copy MakeAlbumSyntax.htm e:\tripod
