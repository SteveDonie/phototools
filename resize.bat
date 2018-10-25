@echo off
if exist %2 goto SKIPIT
echo Resizing %1 to make %2, max dimension %3
java Thumbnail %1 %2 %3
goto END
  
:SKIPIT
echo %2 already exists, skipping resize

:END
