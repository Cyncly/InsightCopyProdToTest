SET BASEDIR=%~dp0..\
SET RELEASEDIR=%BASEDIR%release
SET TARGETZIP="%RELEASEDIR%\CopyProdToTest.zip"
DEL %RELEASEDIR%\CopyProdToTest.zip

"C:\Program Files\WinRAR\WinRAR.exe" a %RELEASEDIR%\CopyProdToTest.zip Template Tools Call_CopyProdToTest.bat CHANGELOG.txt IDEAS.txt Insight_CopyProdToTest_InstallationGuide.pdf LICENSE.txt
pause

