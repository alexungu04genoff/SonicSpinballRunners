@echo off
setlocal
set "experiment_root=%~dp0..\.."
start "Rooftop Convex Height Review" "C:\Program Files\Godot\Godot.exe" --path "%experiment_root%" --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://experiments/rooftop_lighting/review.gd -- --height-study
