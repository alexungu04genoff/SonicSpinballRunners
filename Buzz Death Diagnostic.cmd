@echo off
setlocal
cd /d "%~dp0"
echo Buzz first-kill diagnostic
echo 1. Opaque fallback (current default)
echo 2. Legacy transparent flash
echo 3. Death flash disabled
choice /c 123 /n /m "Choose effect: "
set "BUZZ_EFFECT=opaque"
if errorlevel 3 (set "BUZZ_EFFECT=off") else if errorlevel 2 (set "BUZZ_EFFECT=legacy")
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\buzz_death_diagnostic.ps1" -Effect %BUZZ_EFFECT%
pause
