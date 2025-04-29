REM Call to CopyProdToTest.ps1:
REM
REM The name of the subdirectory containing your configuration must be provided as parameter!
REM Copy the subfolder "Template" to "XXXX" and make your adjustments there.
REM
SET CONFIGFOLDER=%1%
SET BASEDIR=%~dp0
SET BASEDIR=%BASEDIR:~0,-1%
SET LOGDIR=%BASEDIR%\log
md %LOGDIR% 2>NUL
SET LOGFILE=%LOGDIR%\CopyProdToTest_%CONFIGFOLDER%.log
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NonInteractive -NoProfile -ExecutionPolicy unrestricted -c "powershell -c %BASEDIR%\tools\ArchiveLogfiles.ps1 -Config %CONFIGFOLDER% -KeepLogfileCount 2 2>&1 >%LOGDIR%\ArchiveLogfile_%CONFIGFOLDER%.log"
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NonInteractive -NoProfile -ExecutionPolicy unrestricted -c "powershell -c %BASEDIR%\tools\CopyProdToTest.ps1 -Config %CONFIGFOLDER% 2>&1 >%LOGFILE%"

C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NonInteractive -NoProfile -ExecutionPolicy unrestricted -c "powershell -c %BASEDIR%\tools\SendLogfile.ps1 -Config %CONFIGFOLDER% -Logfile %LOGFILE% 2>&1 >%LOGDIR%\SendLogfile_%CONFIGFOLDER%.log"





