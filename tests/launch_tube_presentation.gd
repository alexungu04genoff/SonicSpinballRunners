extends SceneTree
## Canonical Prototype disk evidence for both optional presentations in all themes.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Visual = preload("res://scripts/authored_act/launch_tube_visual.gd")
const Mechanics = preload("res://scripts/authored_act/mechanics_presentation.gd")
const WORKSHOP := "res://data/acts/Experiments/Launch Tube Workshop.tres"
var checks := 0
var failures := 0

func _initialize() -> void:
 run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)

func entry_in(node: Node) -> Dictionary:
 if node.get_script() == Mechanics:
  for entry: Dictionary in node.gimmicks:
   if entry.kind == "launch_tube": return entry
 for child: Node in node.get_children():
  var found := entry_in(child)
  if not found.is_empty(): return found
 return {}

func capture(path: String) -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(path) == OK, "Canonical capture saves: " + path)

func run() -> void:
 root.size = Vector2i(1440, 1000)
 preload("res://scripts/diagnostics/shadow_review.gd").position_review_window(root)
 print("Tube review screen ", root.current_screen, " at ", DisplayServer.screen_get_position(root.current_screen))
 var output := "res://test-results/launch-tube/presentation"
 DirAccess.make_dir_recursive_absolute(output)
 var themes: Array = Fixture.Registry.IDS.duplicate()
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--themes="): themes = Array(argument.trim_prefix("--themes=").split(","))
 for theme: String in themes:
  for mode: String in ["exposed", "tunnel"]:
   var fixture := Fixture.new()
   var path := WORKSHOP if mode == "exposed" else "res://test-results/launch-tube/tunnel.tres"
   if not await fixture.open(self, path, theme, output):
    check(false, fixture.error)
    await fixture.close()
    continue
   var game: Node = fixture.game
   var tube: Node = game.ball.launch_tube
   var entry := entry_in(game.active.visual)
   check(is_instance_valid(tube) and not entry.is_empty(), "Disk recipe owns a live tube and animation: " + theme + "/" + mode)
   if not is_instance_valid(tube) or entry.is_empty():
    await fixture.close()
    continue
   check(entry.item.tube == tube and tube.properties.presentation == mode, "Animation binds the resident tube rather than its template")
   check(game.library.fallback_builds == 0 and fixture.still_current(), "Both disk receipts remain current with zero fallback")
   var fingerprint: String = game.active.document.fingerprint()
   check(entry.root.find_children("*", "Light3D", true, false).is_empty(), "Tube adds no dynamic lights")
   check(entry.root.find_children("*", "GPUParticles3D", true, false).is_empty() and entry.root.find_children("*", "CPUParticles3D", true, false).is_empty(), "Tube adds no particle systems")
   tube.phase = tube.Phase.CHARGING
   tube.charge = 1.0
   tube.visual_time = 0.125
   Visual.update(entry)
   check(entry.head.position.z < entry.spring_length and entry.coil.scale.z < 0.6, "Full charge retracts the plunger head and compresses its spring against the fixed seat")
   check(entry.lights.all(func(light: Node3D): return light.visible) and is_equal_approx(entry.grip.scale.z, 0.7), "Full charge enables eight indicators and compression")
   check(absf(entry.grip.rotation.z) > 0.1 and not entry.pulse.visible and not entry.burst.visible, "Charge spins without a premature traversal or exit effect")
   game.presentation.camera_settings.zoom = 0.6
   game.presentation.reset_camera(Vector2(270, 330))
   game._process(0.0)
   await capture(output.path_join(theme + "-" + mode + "-charge.png"))
   tube.phase = tube.Phase.OUTBOUND
   tube.distance = float(tube.path.length) * 0.5
   Visual.update(entry)
   check(is_equal_approx(entry.head.position.z, entry.spring_length) and is_equal_approx(entry.coil.scale.z, 1.0), "Firing extends the plunger and restores the full coil length")
   check(entry.pulse.visible and not entry.burst.visible, "Contained traversal has one bounded pulse")
   entry.item.properties.feedback_strength = 0.0
   Visual.update(entry)
   check(not entry.pulse.visible and not entry.burst.visible and entry.lights.all(func(light: Node3D): return not light.visible) and is_equal_approx(entry.grip.scale.z, 1.0) and is_zero_approx(entry.grip.rotation.z) and tube.phase == tube.Phase.OUTBOUND and is_equal_approx(tube.distance, float(tube.path.length) * 0.5), "Zero feedback quiets the machine without changing traversal")
   entry.item.properties.feedback_strength = 1.0
   tube.contained = false
   tube.exit_flash = 0.28
   Visual.update(entry)
   check(entry.burst.visible and not entry.pulse.visible and entry.burst.scale.is_equal_approx(Vector3.ONE), "Successful exit starts one restrained burst")
   tube.exit_flash = 0.0
   Visual.update(entry)
   check(not entry.burst.visible, "Exit burst expires completely")
   check(game.active.document.fingerprint() == fingerprint, "Presentation never modifies terrain or authored data")
   tube.contained = true
   await fixture.close()
 print("RESULT | Launch Tube presentation | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
