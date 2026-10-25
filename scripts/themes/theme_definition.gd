extends RefCounted
## Presentation-only theme contract. No Act records or gameplay systems live here.
var theme_id := ""
var display_name := ""
var floor_material: Material
var top_material: Material
var side_material: Material
var cliff_material: Material
var edge_trim_color := Color("638697")
## Optional collisionless horizontal contour bands; widths are physics pixels.
var floor_border_material: Material
var top_border_material: Material
var floor_border_width := 0.0
var top_border_width := 0.0

func _apply_texture_set() -> void:
 var sets = preload("res://scripts/themes/terrain_texture_sets.gd")
 floor_material = sets.material(theme_id, "floor")
 top_material = sets.material(theme_id, "top")
 side_material = sets.material(theme_id, "wall")
 cliff_material = sets.material(theme_id, "facade")
 floor_border_material = sets.material(theme_id, "floor-border")
 top_border_material = sets.material(theme_id, "top-border")
 var widths: Vector2 = sets.SETS[theme_id].width
 floor_border_width = widths.x
 top_border_width = widths.y

func _texture_ramp() -> ShaderMaterial:
 return preload("res://scripts/themes/terrain_texture_sets.gd").material(theme_id, "ramp")

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
 var result := StandardMaterial3D.new()
 result.albedo_color = color
 result.roughness = 0.65
 if glow > 0.0:
  result.emission_enabled = true
  result.emission = color
  result.emission_energy_multiplier = glow
 return result

func _shader_material(source: String) -> ShaderMaterial:
 var shader := Shader.new()
 shader.code = source
 var result := ShaderMaterial.new()
 result.shader = shader
 return result

func configure_environment(_presentation: Node3D) -> void:
 pass

func build_background(_presentation: Node3D) -> void:
 pass

func build_edges(_presentation: Node3D) -> void:
 pass

func create_decor(_presentation: Node3D) -> RefCounted:
 return null

func build_study(_presentation: Node3D, parent: Node3D, origin: Vector3) -> void:
 parent.position = origin

func ramp_materials() -> Dictionary:
 # New themes inherit their existing deck and trim until they supply a ramp style.
 return {"deck": top_material, "edge": material(edge_trim_color),
  "support": material(edge_trim_color.darkened(0.45)), "accent": material(edge_trim_color.lightened(0.3))}

func _ramp_deck(base: Color, alternate: Color, kind: int) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = preload("res://scripts/themes/ramp_deck.gdshader")
 result.set_shader_parameter("base_color", base)
 result.set_shader_parameter("alternate_color", alternate)
 result.set_shader_parameter("surface_kind", kind)
 return result
