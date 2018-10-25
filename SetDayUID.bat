@echo off
REM How this works:
REM first FOR command splits the output of the date /t command which looks like Tue 02/06/2001 into
REM 2 tokens: 1="Tue", 2="02/06/2001".
REM Then the second FOR command splits the 2nd token (%%j) into 3 tokens: 1="02", 2="06", 3="2001"
REM Finally, the DAYUID is set based on those by recombining the tokens in the right order.

for /F "tokens=1,2,*" %%i in ('date /T') do for /F "tokens=1,2,3,* delims=/" %%s in ("%%j") do set DAYUID=%%u%%s%%t
echo DayUID=%DAYUID%