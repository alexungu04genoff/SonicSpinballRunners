class_name CharacterFeedback
extends Node3D
## Minimal replaceable art adapter. All markers and placeholders are collisionless.
var game: Node
var marker: MeshInstance3D
var placeholder: MeshInstance3D
var caption: Label3D

func _ready() -> void:
 marker = MeshInstance3D.new()
 var torus := TorusMesh.new()
 torus.inner_radius = 0.34
 torus.outer_radius = 0.42
 marker.mesh = torus
 add_child(marker)
 caption = Label3D.new()
 caption.font_size = 26
 caption.pixel_size = 0.012
 caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 caption.position.y = 0.6
 marker.add_child(caption)
 placeholder = MeshInstance3D.new()
 var sphere := SphereMesh.new()
 sphere.radius = 0.14
 sphere.height = 0.28
 placeholder.mesh = sphere
 var material := StandardMaterial3D.new()
 material.albedo_color = Color("ffb54a")
 placeholder.material_override = material
 add_child(placeholder)
 var highlight := StandardMaterial3D.new()
 highlight.albedo_color = game.specials.definition.color
 highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 marker.material_override = highlight

func _process(_delta: float) -> void:
 var tails: bool = game.character_id == "tails"
 placeholder.visible = tails
 placeholder.position = TablePresentation.map_point(game.ball.position, 0.2)
 var sonic := get_parent().get_node_or_null("SonicVisualAdapter")
 if sonic:
  sonic.visible = not tails
 if tails:
  game.presentation.ball_visual.visible = false
 marker.visible = false
 if is_instance_valid(game.specials.target):
  marker.visible = true
  marker.position = TablePresentation.map_point(game.specials.target.global_position, 0.12)
  caption.text = "HOMING" if game.specials.homing_remaining > 0 else "LOCK ON"
 elif game.specials.flight_remaining > 0:
  marker.visible = true
  marker.position = TablePresentation.map_point(game.ball.position, 0.12)
  caption.text = "FLIGHT"
