class_name AreaSpecialFeedback
extends Node3D
## Replaceable, collisionless outlines for the two prototype abilities.
var game: Node
var effect: Node3D
var remaining := 0.0
var glide: MeshInstance3D

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 var ring := TorusMesh.new()
 ring.inner_radius = 0.25
 ring.outer_radius = 0.29
 glide = MeshInstance3D.new()
 glide.mesh = ring
 glide.material_override = game.presentation.material(Color("ff6052"))
 add_child(glide)
 game.specials.area_started.connect(show_area)
 game.specials.glide_ended.connect(func(_reason: String): glide.visible = false)
 game.specials.character_changed.connect(func(_id: String): clear())
 game.specials.effects_cleared.connect(func(_reason: String): clear())

func clear() -> void:
 remaining = 0.0
 if is_instance_valid(effect):
  effect.queue_free()
  effect = null

func show_area(source: String, origin: Vector2, size: Vector2) -> void:
 clear()
 effect = Node3D.new()
 add_child(effect)
 var material: StandardMaterial3D = game.presentation.material(game.specials.definition.color.lightened(0.2))
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 var points := PackedVector2Array()
 if source == "chaos_blast":
  for step in 49:
   points.append(origin + Vector2.from_angle(step * TAU / 48.0) * size.x)
 else:
  points = PackedVector2Array([origin + Vector2(-size.x / 2, 0), origin + Vector2(-size.x / 2, -size.y), origin + Vector2(size.x / 2, -size.y), origin + Vector2(size.x / 2, 0)])
 for index in range(points.size() - 1):
  game.presentation.line(points[index], points[index + 1], 0.035, 0.22, material, effect)
 remaining = 0.3

func _process(delta: float) -> void:
 glide.visible = game.specials.glide_remaining > 0.0
 glide.position = TablePresentation.map_point(game.ball.position, 0.22)
 if remaining > 0.0:
  remaining -= delta
  if remaining <= 0.0:
   clear()
