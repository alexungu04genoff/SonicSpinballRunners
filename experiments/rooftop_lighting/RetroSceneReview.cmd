@echo off
setlocal
set "experiment_root=%~dp0..\.."
start "Rooftop Run Retro Material Review" "C:\Program Files\Godot\Godot.exe" --path "%experiment_root%" --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://experiments/rooftop_lighting/retro_scene_review.gd
