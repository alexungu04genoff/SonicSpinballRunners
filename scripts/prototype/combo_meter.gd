extends MeshInstance3D
## Colored progress sits above the original, permanently visible white contact ring.
var game: Node
var material := ShaderMaterial.new()

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 var plane := PlaneMesh.new()
 plane.size = Vector2.ONE * game.ball.radius * TablePresentation.SCALE * 2.24
 mesh = plane
 position.y = 0.025
 material.shader = preload("res://scripts/prototype/combo_meter.gdshader")
 material_override = material
 cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(_delta: float) -> void:
 material.set_shader_parameter("tier", game.scorecraft.multiplier)
 material.set_shader_parameter("remaining", clampf(game.scorecraft.remaining / maxf(0.5, game.scorecraft.config.combo_window), 0.0, 1.0))
