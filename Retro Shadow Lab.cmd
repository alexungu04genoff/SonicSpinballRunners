@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
set "engine=%~dp0Sonic Spinball Runners.exe"
if not exist "%engine%" set "engine=%ProgramFiles%\Godot\Godot.exe"
if not exist "%engine%" (
  echo Extract the complete review package before starting the Lab.
  pause
  exit /b 1
)
set "results=%~dp0Results"
if exist ".git" set "results=%~dp0test-results\retro-shadow-lab"
:newrun
set "run=%results%\Review-%RANDOM%-%RANDOM%"
if exist "%run%\" goto newrun
set "APPDATA=%run%\Roaming"
set "LOCALAPPDATA=%run%\Local"
mkdir "%APPDATA%" "%LOCALAPPDATA%" || exit /b 1
set "review="
if /i "%~1"=="evidence" set "review=--shadow-evidence"
if /i "%~1"=="smoke" set "review=--shadow-evidence --quick"
if /i "%~1"=="bands" set "review=--penumbra-study"
"%engine%" --path "." --screen 0 --rendering-method forward_plus --rendering-driver vulkan --log-file "%run%\engine.log" res://experiments/retro_shadow_lab/lab.tscn -- --seed=18 --retro=production %review% "--output=%run%"
exit /b %errorlevel%
