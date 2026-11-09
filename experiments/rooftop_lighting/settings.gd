extends Resource
## Experiment-only controls. The production theme is never modified.
@export var key_elevation := -42.0
@export var key_azimuth := -62.0
@export var key_energy := 1.05
@export var key_color := Color("ffe9cc")
@export var ambient_energy := 0.28
@export var sky_contribution := 0.15
@export var exposure := 1.0
@export var tonemap_mode := Environment.TONE_MAPPER_LINEAR
@export var shadow_bias := 0.22
@export var shadow_normal_bias := 2.0
@export var shadow_distance := 24.0
@export var ssao_enabled := true
@export var ssao_radius := 0.24
@export var ssao_intensity := 0.85
@export var ssao_light_affect := 0.15
@export var normal_strength := 0.45
## Deliberately stronger diagnostic controls, separate from the old edge map.
@export var convex_normal_strength := 1.0
@export var height_strength := 0.04
@export_range(4, 24) var parallax_steps := 12
@export var roughness_variation := 0.75
@export var floor_specular := 0.25
@export var fog_enabled := false
@export var fog_density := 0.002
## Low-poly material review; normal-map-only controls.
@export var lowpoly_normal_strength := 0.55
@export var lowpoly_mortar_depth := 0.65
@export var lowpoly_detail_intensity := 0.65
@export var lowpoly_variation := 0.15
