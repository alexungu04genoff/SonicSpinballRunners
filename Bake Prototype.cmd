@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\prototype\launch.ps1" -Bake %*
if errorlevel 1 pause
