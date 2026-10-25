extends RefCounted
## Presentation-only theme contract. No Act records or gameplay systems live here.
var theme_id := ""
var display_name := ""
var floor_material: Material
var top_material: Material
var side_material: Material
var cliff_material: Material
var edge_trim_color := Color("638697")

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
