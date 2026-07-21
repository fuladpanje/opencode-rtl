@echo off
title OpenCode-RTL Patch
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0patch\patch.ps1"
echo.
echo Press any key to close...
pause >nul
