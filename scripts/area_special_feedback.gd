class_name AreaSpecialFeedback
extends Node3D
## Collisionless table-impact ring. Prepared once, then animated without allocation.
var game: Node
var effect: MeshInstance3D
var remaining := 0.0
var radius := 0.0
var material: StandardMaterial3D

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 effect = MeshInstance3D.new()
 var ring := TorusMesh.new()
 ring.inner_radius = 0.94
 ring.outer_radius = 1.0
 effect.mesh = ring
 material = game.presentation.material(Color("ff6052"))
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 effect.material_override = material
 effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(effect)
 clear()
 game.specials.area_started.connect(show_area)
 game.specials.character_changed.connect(func(_id: String): clear())
 game.specials.effects_cleared.connect(func(_reason: String): clear())

func clear() -> void:
 remaining = 0.0
 effect.visible = false

func show_area(_source: String, origin: Vector2, size: Vector2) -> void:
 effect.position = TablePresentation.map_point(origin, 0.45)
 radius = size.x * TablePresentation.SCALE
 material.albedo_color = game.specials.definition.color.lightened(0.4)
 remaining = 0.3
 effect.visible = true
 _animate()

func _animate() -> void:
 var progress := 1.0 - remaining / 0.3
 var spread := lerpf(0.08, 1.0, ease(progress, 0.4)) * radius
 effect.scale = Vector3(spread, maxf(0.01, (1.0 - progress) * 0.7), spread)
 effect.position.y = lerpf(0.45, 0.12, minf(1.0, progress * 4.0))

func _process(delta: float) -> void:
 if remaining <= 0.0: return
 remaining = maxf(0.0, remaining - delta)
 _animate()
 if remaining == 0.0: clear()
