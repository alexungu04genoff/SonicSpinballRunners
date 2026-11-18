@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_motion_microbenchmark.ps1" %*
if errorlevel 1 pause
