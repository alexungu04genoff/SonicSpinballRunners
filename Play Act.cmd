@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0experiments\visual_lab\launch.ps1" %*
if errorlevel 1 pause
