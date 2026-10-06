@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Backup-Drivers.ps1" %*
exit /b %errorlevel%
