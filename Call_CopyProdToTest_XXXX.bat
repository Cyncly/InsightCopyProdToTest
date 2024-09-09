SET BASEDIR=%~dp0
SET BASEDIR=%BASEDIR:~0,-1%
call %BASEDIR%\Call_CopyProdToTest.bat XXXX
pause



