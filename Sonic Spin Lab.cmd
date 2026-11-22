@echo off
setlocal
cd /d "%~dp0"
"%ProgramFiles%\Godot\Godot.exe" --path "." --position 20,30 --rendering-method forward_plus --rendering-driver vulkan res://scenes/prototype_run.tscn -- --spin-lab --act "res://data/acts/Authored/Clover Scoop.tres"
if errorlevel 1 pause
