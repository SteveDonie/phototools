:: FixOldPhotoNames
:: 
:: recurses through a directory with sub-directories named by YYYY-MM,
:: looks at each of the JPG files there, and if they fit the pattern 
:: NNNN - xxxxxxx.jpg, then change the date/time stamp on the file to be
:: YYYY-MM-NN:NN, and rename the JPG file to match that date/time stamp.
:: At the same time, take the caption part (xxxxxxx) and write that to a 
:: new .txt file that has the same name as the JPG, but contains the caption
:: info for the photo.
::
:: <!-- THUMBSPART:caption --> 
::  
:: <!-- THUMBSPART:comment --> 
::  
:: <!-- THUMBSPART:name --> 
@echo off
setlocal
if .%1.==.. echo you must supply a directory to work in. && goto :EOF
set "topLevelDir=%~f1"
:: check if path ends with backslash or not, both with and without are valid, but whatever
:: way we use has to be consistent for the rest of the script to work properly.

pushd "%topLevelDir%"
call :FixTopLevelDir
goto :EOF

:FixTopLevelDir
echo Fixing top level dir %topLevelDir%

for /d %%p in ("%topLevelDir%\*") do (
  call :FixOneDisplayDir "%topLevelDir%\%%~np"
)

: FixOneDisplayDir
if .%1.==.. (
  echo  Not processing empty directory
  goto :EOF
)
echo  Fixing photos in %1
pushd %1
for %%P in (*.jpg) do (
  call :FixOnePhoto "%%~nxP" "%%~pP"
)
popd
goto :EOF

:FixOnePhoto
:: If the filename fits the pattern NNNN - xxxxxxx.jpg, then extract the 
:: YYYY-MM from the path, :: change the date/time stamp on the file to be
:: YYYY-MM-NN:NN, and rename the JPG file to match that date/time stamp.
:: At the same time, take the caption part (xxxxxxx) and write that to a 
:: new .txt file that has the same name as the JPG, but contains the caption
:: info for the photo.
set filename=%1
set filepath=%2

:: remove quotes from filename
set filename=%filename:"=%
echo   Fixing photo %filename% at %2
:: check if filename matches pattern
set "regexp=^[0-9][0-9][0-9][0-9] - .*"
echo "%filename%" | findstr /r /C:"%regexp%" >nul 2>&1
if errorlevel 1 ( 
  echo    Filename does not match. 
) else (
  echo    Filename matches.
)
goto :EOF
