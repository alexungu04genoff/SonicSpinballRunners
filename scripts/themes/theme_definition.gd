extends RefCounted
## Presentation-only theme contract. No Act records or gameplay systems live here.
const Atmosphere := preload("res://scripts/themes/theme_atmosphere.gd")
const SceneryLayout := preload("res://scripts/themes/scenery_layout.gd")
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

func _set_instance_transform(multimesh: MultiMesh, index: int, transform: Transform3D) -> void:
 multimesh.set_instance_transform(index, transform)
 if DisplayServer.get_name() != "headless": return
 # The dummy renderer discards instance buffers. Keep authoring transforms on
 # the resource until the offline recipe captures them into its own CPU buffer.
 var transforms: Array = multimesh.get_meta("offline_transforms", [])
 if transforms.size() != multimesh.instance_count:
  transforms.resize(multimesh.instance_count)
  transforms.fill(Transform3D.IDENTITY)
 transforms[index] = transform
 multimesh.set_meta("offline_transforms", transforms)

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

func scenery_layout(p: Node3D) -> SceneryLayout:
 return SceneryLayout.new(p.scenery_settings, theme_id)

func scenery_side_edge(p: Node3D, side: int, center_y: float, half_span_y: float = 0.0) -> float:
 # All coordinates are Act pixels. Find the outermost floor edge across a prop's
 # entire longitudinal footprint, including bends between its endpoints. This
 # also accepts the rectangular outlines used by streamed background baking.
 var bounds: Rect2 = p.table_bounds
 var fallback: float = bounds.position.x if side < 0 else bounds.end.x
 var outlines: Array = p._outlines
 if p.authored_mode and not p.authored_floor_outline.is_empty():
  outlines = [p.authored_floor_outline]
 var low := maxf(bounds.position.y, center_y - half_span_y)
 var high := minf(bounds.end.y, center_y + half_span_y)
 if low > high: return fallback
 var edge := INF if side < 0 else -INF
 for outline: PackedVector2Array in outlines:
  for i in outline.size():
   var a := outline[i]
   var b := outline[(i + 1) % outline.size()]
   if a.y >= low and a.y <= high:
    edge = minf(edge, a.x) if side < 0 else maxf(edge, a.x)
   if is_equal_approx(a.y, b.y): continue
   for y: float in [low, high]:
    if y < minf(a.y, b.y) or y > maxf(a.y, b.y): continue
    var x := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
    edge = minf(edge, x) if side < 0 else maxf(edge, x)
 return edge if is_finite(edge) else fallback

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
