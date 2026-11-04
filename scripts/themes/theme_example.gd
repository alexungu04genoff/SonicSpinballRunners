extends "res://experiments/visual_lab/visual_lab.gd"
## Visual Lab authoring example. This is not the Prototype production runtime.
@export_file("*.tres") var example_act_path := "res://data/acts/decor_terraces.tres"

func _ready() -> void:
 authored_act_path = example_act_path
 super._ready()
 if retro_filter != null: retro_filter.set_preset(0)
 presentation.set_camera_follow(false)
