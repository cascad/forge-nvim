@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launch-forge.ps1" %*
exit /b %errorlevel%
