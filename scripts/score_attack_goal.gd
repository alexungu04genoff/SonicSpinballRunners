class_name ScoreAttackGoal
extends Node3D
## Replaceable collisionless skin. Art hooks: challenge.changed, state, goal_position.
var challenge: ScoreAttack
var marker: MeshInstance3D
var caption: Label3D
var elapsed := 0.0

func _ready() -> void:
 name = "ScoreAttackGoal"
 var torus := TorusMesh.new()
 torus.inner_radius = (ScoreAttack.GOAL_RADIUS - 5.0) * TablePresentation.SCALE
 torus.outer_radius = ScoreAttack.GOAL_RADIUS * TablePresentation.SCALE
 torus.rings = 32
 torus.ring_segments = 8
 marker = MeshInstance3D.new()
 marker.mesh = torus
 marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(marker)
 caption = Label3D.new()
 caption.font_size = 28
 caption.pixel_size = 0.012
 caption.outline_size = 4
 caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 caption.position = Vector3(0, 0.65, 0)
 add_child(caption)
 challenge.changed.connect(refresh)
 refresh()

func refresh() -> void:
 visible = challenge.state != ScoreAttack.State.FREE_PLAY
 if not visible:
  return
 position = TablePresentation.map_point(challenge.goal_position, 0.04)
 var color := Color("f6ae52")
 caption.text = "GOAL LOCKED"
 if challenge.state == ScoreAttack.State.UNLOCKED:
  color = Color("70ffba")
  caption.text = "GOAL OPEN"
 elif challenge.state == ScoreAttack.State.COMPLETE:
  color = Color("ffe27a")
  caption.text = "CLEAR!"
 var mat := StandardMaterial3D.new()
 mat.albedo_color = color
 mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 marker.material_override = mat
 caption.modulate = color

func _process(delta: float) -> void:
 elapsed += delta
 # Pulse brightness only: the visible circle always matches the gameplay radius.
 if visible and challenge.state == ScoreAttack.State.UNLOCKED:
  marker.transparency = 0.18 + 0.18 * sin(elapsed * 5.0)
 else:
  marker.transparency = 0.0
