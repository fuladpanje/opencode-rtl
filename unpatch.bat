@echo off
title OpenCode-RTL Restore
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0patch\unpatch.ps1"
echo.
echo Press any key to close...
pause >nul
