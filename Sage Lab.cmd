@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0experiments\visual_lab\sage\launch.ps1" %*
if errorlevel 1 pause
