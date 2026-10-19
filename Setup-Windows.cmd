@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0tools\Link-WindowsAddon.ps1"
set "RCP_SETUP_RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %RCP_SETUP_RESULT%
