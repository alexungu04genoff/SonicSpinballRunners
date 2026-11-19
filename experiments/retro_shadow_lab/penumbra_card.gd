extends RefCounted
## A neutral reference under the foreground's real key. The ring is a visible
## caster and the card is an ordinary opaque receiver in the same 3D viewport.
static func place(game: Node) -> void:
 var root := Node3D.new()
 root.name = "PenumbraStudy"
 game.active.visual.add_child(root)
 root.global_position = TablePresentation.map_point(game.ball.position) + Vector3.UP * 0.42
 var card := MeshInstance3D.new()
 var box := BoxMesh.new()
 box.size = Vector3(5.8, 0.08, 4.8)
 card.mesh = box
 var surface := ShaderMaterial.new()
 var matte := Shader.new()
 matte.code = """shader_type spatial;
render_mode specular_disabled;
void fragment() {
 ALBEDO = vec3(0.49, 0.52, 0.54);
 ROUGHNESS = 1.0;
}"""
 surface.shader = matte
 surface.set_meta("atmosphere_hue", "terrain_ground")
 card.material_override = surface
 root.add_child(card)
 var caster := MeshInstance3D.new()
 var ring := TorusMesh.new()
 ring.outer_radius = 0.87
 ring.inner_radius = 0.51
 ring.rings = 32
 ring.ring_segments = 12
 caster.mesh = ring
 var gold := StandardMaterial3D.new()
 gold.albedo_color = Color("#edab34")
 gold.metallic = 0.35
 gold.roughness = 0.34
 caster.material_override = gold
 root.add_child(caster)
 var sun: Vector3 = game.presentation._key_light.global_basis.z.normalized()
 var height := 1.45
 caster.position = Vector3(sun.x * height / maxf(0.2, sun.y), height, sun.z * height / maxf(0.2, sun.y))
 caster.rotation_degrees = Vector3(25, 0, -18)
