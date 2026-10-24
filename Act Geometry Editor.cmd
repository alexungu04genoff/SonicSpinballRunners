@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\act_editor\launch.ps1" %*
if errorlevel 1 pause
