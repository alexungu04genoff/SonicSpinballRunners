@echo off
setlocal
set "experiment_root=%~dp0..\.."
start "Rooftop Low-Poly Normal Review" "C:\Program Files\Godot\Godot.exe" --path "%experiment_root%" --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://experiments/rooftop_lighting/lowpoly_review.gd
