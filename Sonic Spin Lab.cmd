@echo off
setlocal
cd /d "%~dp0"
set "previewCharacter=sonic"
if /i "%~1"=="tails" set "previewCharacter=tails"
if /i "%~1"=="knuckles" set "previewCharacter=knuckles"
"%ProgramFiles%\Godot\Godot.exe" --path "." --position 20,30 --rendering-method forward_plus --rendering-driver vulkan res://scenes/prototype_run.tscn -- --spin-lab --character=%previewCharacter% --act "res://data/acts/Authored/Clover Scoop.tres"
if errorlevel 1 pause
