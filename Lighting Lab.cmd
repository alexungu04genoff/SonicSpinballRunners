@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0experiments\lighting_lab\launch.ps1" %*
if errorlevel 1 pause
