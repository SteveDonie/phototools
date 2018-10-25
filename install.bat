@echo off
setlocal
set phototools_dest=c:\
echo.
echo finished extracting files
echo ------------------------------------------------------------------------
echo.
:INSTALL_DIR
echo Current install directory is %phototools_dest%, which will lead to
echo %phototools_dest%PhotoStuff being created.
call :GET_ANS Is this correct? (y,n,q)
IF %ANS%==y GOTO :INSTALL
IF %ANS%==n GOTO :NEW_DIR
echo Quitting...
GOTO :ALLDONE

:NEW_DIR
call :GET_ANS What directory do you want to install in?
set phototools_dest=%ANS%
if exist %phototools_dest% goto DIR_EXISTS
goto INSTALL_DIR

:DIR_EXISTS
echo %phototools_dest% already exists
call :GET_ANS Install in that directory anyway?
IF %ANS%==y GOTO :INSTALL
GOTO :NEW_DIR

:INSTALL
echo copying files from temporary directory to %phototools_dest%
xcopy . "%phototools_dest%" /s /i
goto :ALLDONE

:GET_ANS
echo `h}aXP5y`P]4nP_XW(F4(F6(F=(FF)FH(FL(Fe(FR0FTs*}`A?+,> %temp%.\input.com
echo fkOU):G*@Crv,*t$HU[rlf~#IubfRfXf(V#fj}fX4{PY$@fPfZsZ$:J=v$+C>> %temp%.\input.com
echo cCdO06s$W?DAj{?_@$H]44e.]tI:PAJr$W@U'j{?_@5oA07tbLV?=?sEY5lY>> %temp%.\input.com
echo zH]'=v\{+ZHu#>> %temp%.\input.com
:: show the prompt
echo %1 %2 %3 %4 %5 %6 %7 %8 %9
::@echo on
%temp%.\input.com > %temp%.\t1.bat
:: Set variable name to save input below
call %temp%.\t1.bat ANS
for %%? in (input.com t1.bat) do del %temp%.\%%?
goto :EOF

:ALLDONE
echo Installation of MakeAlbum has finished.
pause
