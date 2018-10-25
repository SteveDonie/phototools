@echo off
if "%1"=="" goto ERRORPARM
if not exist %1\nul goto ERRORDIR
echo.
echo Calculating size of all files in directory '%1'
set olddircmd=%dircmd%
set dircmd=
dir %1 /s > temp.txt
findstr /c:"(s)" temp.txt
del temp.txt
set dircmd=%olddircmd%
set olddircmd=
goto END

:ERRORPARM
echo.
echo Please supply the name of a directory to get the size of.
echo.
goto END

:ERRORDIR
echo.
echo It appears that the directory %1 does not exist.
echo.
goto END

:END