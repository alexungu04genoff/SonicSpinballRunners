extends Node3D
## Collisionless Eggmobile for the local Runners gameplay preview.
const Assets = preload("res://experiments/visual_lab/runners_sonic_assets.gd")
const VictoryTurn = preload("res://scripts/prototype/victory_turn.gd")
const LoopPath = preload("res://scripts/authored_act/loop_path.gd")
const TRICKS := ["egm_atk_missile_start", "egm_atk_tackle_loop", "egm_damage_hatch_open_right_loop", "egm_event_01"]
const TRICK_FRAMES := [3, 12, 0, 63]
const TRICK_YAWS := [120.0, 122.0, 68.0, 84.0]
const TURN_RATE := 20.0
const MIN_SPEED := 4.0

var game: Node
var model: Node3D
var bomb: Node3D
var art := Node3D.new()
var player: AnimationPlayer
var mounts := {}
var radius: float
var yaw := 0.0
var pitch := 0.0
var bank := 0.0
var headed := false
var loop_side := Vector3.ZERO
var trick_index := -1
var elapsed := 0.0
var clip_elapsed := 0.0

func setup(owner_game: Node, directory: String) -> bool:
 set_process(false)
 game = owner_game
 var pose = game.combo_celebration.character_pose
 radius = pose.radius
 add_child(art)
 model = load_model(directory.path_join("eggmobile.glb"))
 bomb = load_model(directory.path_join("bomb.glb"))
 if not model or not bomb: return false
 art.add_child(model)
 game.presentation.add_child(bomb)
 bomb.hide()
 player = model.find_child("AnimationPlayer", true, false)
 if not player: return false
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 for mount: String in ["Body", "Booster_L", "Booster_R", "BombPoint"]:
  var node := model.find_child(mount, true, false) as Node3D
  if node:
   mounts[mount] = [node, -1]
   continue
  for skeleton: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
   var index := skeleton.find_bone(mount)
   if index >= 0:
    mounts[mount] = [skeleton, index]
    break
  if not mounts.has(mount): return false
 for root: Node in [pose, game.character.spin_root, pose.motion_rig, pose.action_shell]:
  if root is GeometryInstance3D: root.layers = 0
  for part: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false): part.layers = 0
 game.scorecraft.builder_hit_resolved.connect(_on_builder_hit)
 process_priority = 100
 set_process(true)
 return true

func _on_builder_hit(hits: int, _points: int) -> void:
 if hits in [2, 3, 4, 5, 8] or (hits >= 10 and hits % 5 == 0):
  trick_index = (trick_index + 1) % TRICKS.size()

func load_model(path: String) -> Node3D:
 var document := GLTFDocument.new()
 var state := Assets.read_state(path, document)
 return document.generate_scene(state, 60, false, false) if state else null

func mount_position(id: String) -> Vector3:
 var mount: Node3D = mounts[id][0]
 var index: int = mounts[id][1]
 return mount.global_position if index < 0 else mount.to_global(mount.get_bone_global_pose(index).origin)

func nose() -> Vector3:
 return mount_position("Body") - (mount_position("Booster_L") + mount_position("Booster_R")) * 0.5

func sample_clip(clip: String, time: float) -> void:
 if player.current_animation != clip:
  Assets.start_clip(model, player, clip)
 var length := player.current_animation_length
 player.seek(fposmod(time, length) if clip.ends_with("_loop") else minf(time, length), true)

func travel_velocity() -> Vector3:
 var ball: PlaygroundBall = game.ball
 if ball.has_track_frame: return -ball.track_frame.z * ball.track_speed
 var velocity: Vector2 = game.character.roll_velocity()
 return Vector3(velocity.x, 0, velocity.y)

func steer(velocity: Vector3, delta: float) -> void:
 var target_pitch := 0.0
 var target_bank := 0.0
 if velocity.length() > MIN_SPEED:
  var horizontal := Vector2(velocity.x, velocity.z)
  if horizontal.length() > velocity.length() * 0.10:
   var target := atan2(velocity.x, velocity.z)
   var turn := angle_difference(yaw, target)
   target_bank = clampf(-turn * 0.22, -0.17, 0.17)
   yaw = rotate_toward(yaw, target, TURN_RATE * delta) if headed else target
   headed = true
  target_pitch = clampf(-asin(clampf(velocity.normalized().y, -1, 1)), -0.48, 0.48)
 pitch = lerpf(pitch, target_pitch, 1.0 - exp(-14.0 * delta))
 bank = lerpf(bank, target_bank, 1.0 - exp(-13.0 * delta))

func _process(delta: float) -> void:
 if not player: return
 elapsed += delta
 var ball: PlaygroundBall = game.ball
 var velocity := travel_velocity()
 var at: Vector3 = game.character.spin_root.global_position
 var lift := radius * (0.34 + 0.10 * sin(elapsed * TAU / 1.6))
 var scale_factor := 1.0
 var clip := "egm_move_fast_loop" if velocity.length() > 240 else ("egm_move_loop" if velocity.length() > MIN_SPEED else "egm_idle_loop")
 var time := -1.0
 var card = game.combo_celebration
 var trick := false
 var remaining: float = game.specials.smash_remaining
 bomb.hide()
 if is_instance_valid(game.transfer):
  if game.transfer.proxy: game.transfer.proxy.hide()
  var progress: float = game.transfer.elapsed / game.transfer.DURATION
  scale_factor = 1.0 - smoothstep(0.0, 0.35, progress) if progress < 0.35 else smoothstep(0.65, 1.0, progress)
  at = TablePresentation.map_point(ball.position, game.presentation.ball_height())
 elif ball.in_loop:
  if loop_side.is_zero_approx():
   loop_side = Vector3(ball.track_frame.x.x, 0, ball.track_frame.x.z).normalized()
   if loop_side.dot(game.presentation.camera.global_position - at) < 0: loop_side = -loop_side
  var size: float = ball.loop_item.properties.scale
  var distance: float = game.active.runtime.mechanics.progress / size
  var blend := smoothstep(0.0, LoopPath.LEAD, minf(distance, LoopPath.LENGTH - distance))
  at += loop_side * blend * (LoopPath.HALF_WIDTH * size * TablePresentation.SCALE + radius * 1.15)
 elif remaining > 0:
  var beat := 2.0 - remaining
  clip = "egm_atk_bomb_start" if beat < 1.0 else "egm_atk_bomb_loop"
  time = fmod(beat, 1.0)
  at = TablePresentation.map_point(game.specials.smash_origin, game.presentation.ball_height())
  lift += radius * 6.0 * smoothstep(0, 1, beat)
 elif card.trick_remaining > 0 and trick_index >= 0:
  trick = true
  clip = TRICKS[trick_index]
  time = TRICK_FRAMES[trick_index] / 60.0
 if not ball.in_loop: loop_side = Vector3.ZERO
 if remaining <= 0 and not is_instance_valid(game.transfer): steer(velocity, delta)
 clip_elapsed = clip_elapsed + delta if player.current_animation == clip else 0.0
 sample_clip(clip, clip_elapsed if time < 0 else time)
 # Convert the authored nose into local space before composing the world steering.
 var local_nose := art.global_basis.inverse() * nose()
 var facing := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, bank) * Basis(Vector3.UP, -atan2(local_nose.x, local_nose.z))
 if trick:
  var progress: float = 1.0 - card.trick_remaining / card.trick_duration
  facing = VictoryTurn.basis(game.presentation.camera.global_basis, progress) * Basis(Vector3.UP, deg_to_rad(TRICK_YAWS[trick_index]))
 global_position = at + Vector3.UP * lift
 art.basis = facing.scaled(Vector3.ONE * radius * 1.23 * maxf(0.001, scale_factor))
 if remaining > 0.0 and remaining <= 1.0:
  bomb.show()
  bomb.scale = Vector3.ONE * radius * 0.67
  bomb.global_position = mount_position("BombPoint").lerp(at - Vector3.UP * radius * 0.70, pow(1.0 - remaining, 2.0))
