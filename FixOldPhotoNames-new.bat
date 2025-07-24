@echo off
setlocal enabledelayedexpansion

echo Photo Renaming and Metadata Extraction Script
echo ============================================
echo.

REM Check if exiftool is available (recommended for accurate date extraction)
where exiftool >nul 2>nul
if %errorlevel% equ 0 (
    set USE_EXIFTOOL=1
    echo Using ExifTool for date extraction
) else (
    set USE_EXIFTOOL=0
    echo ExifTool not found - using file system dates
    echo Note: Install ExifTool for more accurate photo date extraction
)
echo.

if .%1.==.. echo you must supply a directory to work in. && goto :EOF
set "topLevelDir=%~f1"
:: check if path ends with backslash or not, both with and without are valid, but whatever
:: way we use has to be consistent for the rest of the script to work properly.

pushd "%topLevelDir%"
call :FixTopLevelDir
goto :EOF

:FixTopLevelDir
echo Fixing top level dir %topLevelDir%


REM Process all JPG files in current directory
for %%f in (*.jpg *.JPG *.jpeg *.JPEG) do (
    echo Processing: %%f
    
    REM Extract the caption from filename
    set "filename=%%~nf"
    set "caption=!filename!"
    
    REM Check if filename starts with a number and dash pattern
    echo !filename! | findstr /r "^[0-9][0-9]* - " >nul
    if !errorlevel! equ 0 (
        REM Remove the number prefix (everything up to and including " - ")
        for /f "tokens=2*" %%a in ("!filename: - = - !") do set "caption=%%a %%b"
        set "caption=!caption: =!"
        if "!caption!" equ "" for /f "tokens=2*" %%a in ("!filename: - = - !") do set "caption=%%a"
    )
    
    REM Get creation date/time
    if !USE_EXIFTOOL! equ 1 (
        REM Use ExifTool to get DateTimeOriginal
        for /f "delims=" %%d in ('exiftool -d "%%Y%%m%%d-%%H%%M%%S" -DateTimeOriginal -s -s -s "%%f" 2^>nul') do (
            set "newname=%%d"
        )
        REM If DateTimeOriginal not found, try CreateDate
        if "!newname!" equ "" (
            for /f "delims=" %%d in ('exiftool -d "%%Y%%m%%d-%%H%%M%%S" -CreateDate -s -s -s "%%f" 2^>nul') do (
                set "newname=%%d"
            )
        )
        REM If still no date found, use file modification time
        if "!newname!" equ "" (
            for /f "delims=" %%d in ('exiftool -d "%%Y%%m%%d-%%H%%M%%S" -FileModifyDate -s -s -s "%%f" 2^>nul') do (
                set "newname=%%d"
            )
        )
    ) else (
        REM Use file system date (less accurate for photos)
        for /f "tokens=1-3 delims=/ " %%a in ('dir "%%f" /tc ^| findstr "%%f"') do (
            set "filedate=%%a"
            set "filetime=%%b"
        )
        REM Convert date format (this is a simplified version)
        REM You might need to adjust based on your system's date format
        set "newname=!filedate:/=!!filetime::=!"
        set "newname=!newname: =!"
    )
    
    REM Handle case where we couldn't get a date
    if "!newname!" equ "" (
        echo   Warning: Could not extract date for %%f, skipping...
        echo.
        goto :continue
    )
    
    REM Ensure new filename doesn't already exist
    set "counter=0"
    set "finalname=!newname!"
    :checkname
    if exist "!finalname!.jpg" (
        set /a counter+=1
        set "finalname=!newname!_!counter!"
        goto :checkname
    )
    
    REM Rename the file
    echo   Renaming to: !finalname!.jpg
    ren "%%f" "!finalname!.jpg"
    
    REM Create the text file with metadata
    echo   Creating: !finalname!.txt
    (
        echo ^<!-- THUMBSPART:caption --^>
        echo !caption!
        echo.
        echo ^<!-- THUMBSPART:comment --^>
        echo.
        echo.
        echo ^<!-- THUMBSPART:name --^>
        echo.
        echo.
    ) > "!finalname!.txt"
    
    echo   Caption extracted: !caption!
    echo.
    
    :continue
)

echo.
echo Processing complete!
echo.
echo Note: If you want more accurate date extraction from photo EXIF data,
echo install ExifTool from https://exiftool.org/
pause