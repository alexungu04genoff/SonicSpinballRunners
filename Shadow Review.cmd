@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
set "results=%~dp0Results"
if exist ".git" set "results=%~dp0test-results\shadow-review"
set "engine=%~dp0Sonic Spinball Runners.exe"
if not exist "%engine%" set "engine=%ProgramFiles%\Godot\Godot.exe"
if not exist "%engine%" (
  echo Extract the whole package with Sonic Spinball Runners.exe next to this menu.
  pause
  exit /b 1
)
if /i "%~1"=="matrix" goto matrix
if /i "%~1"=="lab" goto lab
echo 1. Live shadow review in Atmosphere Lab
echo 2. Benchmark Prototype and Endless, first and repeat runs
echo 3. Exit
choice /c 123 /n /m "Choose 1, 2 or 3: "
if errorlevel 3 exit /b
if errorlevel 2 goto matrix

:lab
call :newrun
if errorlevel 1 exit /b 1
set "APPDATA=%run%\profile\Roaming"
set "LOCALAPPDATA=%run%\profile\Local"
mkdir "%APPDATA%" "%LOCALAPPDATA%" || exit /b 1
"%engine%" --path "." --screen 0 --rendering-method forward_plus --rendering-driver vulkan --log-file "%run%\lab.log" res://experiments/lighting_lab/lighting_lab.tscn -- --shadow-review
exit /b %errorlevel%

:matrix
call :newrun
if errorlevel 1 exit /b 1
set "failed=0"
echo Results in "%run%"
for %%R in (prototype endless) do (
  for %%Q in (production quality performance) do call :pair %%R %%Q
)
for %%Q in (neither ultra-only both) do call :pair endless %%Q
echo Finished. Return the case folders and status.txt from "%run%".
if "%~1"=="" pause
exit /b %failed%

:pair
set "APPDATA=%run%\cache-%1-%2\Roaming"
set "LOCALAPPDATA=%run%\cache-%1-%2\Local"
mkdir "%APPDATA%" "%LOCALAPPDATA%" || (
  set "failed=1"
  exit /b 1
)
for %%P in (first repeat) do call :case %1 %2 %%P
exit /b

:case
set "out=%run%\%1-%2-%3"
mkdir "%out%" || (
  set "failed=1"
  exit /b 1
)
echo %1 %2 %3
"%engine%" --path "." --screen 0 --rendering-method forward_plus --rendering-driver vulkan --log-file "%out%\engine.log" --script res://tests/grounding_lab.gd -- --seed=18 --retro=production --profile-stages --grounding-lab --grounding-task=shadow-bench --grounding-runtime=%1 --grounding-quality=%2 --grounding-seconds=3 --cache-pass=%3 "--output=%out%"
set "rc=%errorlevel%"
if not exist "%out%\report.json" set "rc=1"
if not exist "%out%\teardown.json" set "rc=1"
%SystemRoot%\System32\findstr.exe /l /c:"SCRIPT ERROR:" "%out%\engine.log" >nul && set "rc=1"
if not "%rc%"=="0" set "failed=1"
>>"%run%\status.txt" echo %1 %2 %3 exit=%rc%
exit /b

:newrun
set "run=%results%\Shadow-%RANDOM%-%RANDOM%"
if exist "%run%\" goto newrun
mkdir "%run%" || exit /b 1
exit /b 0
