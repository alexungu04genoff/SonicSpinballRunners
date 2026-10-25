extends SceneTree
## Exact 120 Hz trajectories under identical input. Each run uses a fresh process:
## recycling PhysicsServer bodies in one process changes collision tie ordering,
## including in an OFF-versus-OFF control. No numeric tolerance masks differences.
const Filter := preload("res://scripts/retro/retro_filter.gd")
const OUTPUT := "res://test-results/retro-replay-%d.bin"

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--retro-replay="):
   await record(int(argument.trim_prefix("--retro-replay=")))
   return
 var baseline: Array = []
 var failures := 0
 for index in 8:
  var output: Array = []
  var result := OS.execute(OS.get_executable_path(), PackedStringArray([
   "--headless", "--path", ProjectSettings.globalize_path("res://"), "--fixed-fps", "120",
   "--script", "res://tests/retro_physics_regression.gd", "--", "--retro-replay=%d" % index,
  ]), output, true)
  if result != 0:
   failures += 1
   push_error("Replay process failed: %s" % output)
   continue
  var file := FileAccess.open(OUTPUT % index, FileAccess.READ)
  var trace: Array = file.get_var()
  if index == 0:
   baseline = trace
  var label: String = Filter.NAMES[index] if index < 5 else ["live switching every 60 ticks", "all four effects stacked", "live stacking and tuning"][index - 5]
  if trace != baseline or trace.size() != 600:
   failures += 1
   push_error("FAIL | Different 600-tick trajectory: " + label)
   for tick in mini(trace.size(), baseline.size()):
    if trace[tick] != baseline[tick]:
     print("FIRST_DIFFERENCE | tick ", tick, " | OFF ", baseline[tick], " | preset ", trace[tick])
     break
  else:
   print("PASS | Identical trajectory, score, rings, drains and flipper angles: ", label)
 print("RESULT | Retro physics | 8 checks | %d failures" % failures)
 quit(0 if failures == 0 else 1)

func record(index: int) -> void:
 if Engine.physics_ticks_per_second != 120:
  push_error("Expected the project's unchanged 120 Hz physics timestep")
  quit(1)
  return
 var game: Node = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.generation_seed = 18
 root.add_child(game)
 game.retro_filter.set_preset(index if index < 5 else 0)
 if index == 6:
  game.retro_filter.set_effects(Filter.ORDER)
 game.retro_controls.hide()
 game.controls.virtual_enabled = true
 for _i in 3:
  await physics_frame
 game.launch_ball()
 var trace: Array = []
 for tick in 600:
  if index == 5 and tick % 60 == 0:
   game.retro_filter.cycle()
  if index == 7 and tick % 30 == 0:
   game.retro_filter.toggle_effect(Filter.ORDER[(tick / 30) % 4])
   game.retro_controls.fields.crt_cell_size.value = 6 + tick % 11
   game.retro_controls.fields.crt_glow.value = (tick % 90) / 100.0
   game.retro_controls.fields.pixel_resolution_divisor.value = 1 + (tick / 30) % 4
  game.controls.virtual_left = tick % 90 < 35
  game.controls.virtual_right = tick % 110 < 40
  game.controls.virtual_steering = 0.35 if tick % 180 < 90 else -0.35
  await physics_frame
  trace.append([game.ball.position, game.ball.linear_velocity, game.score, game.rings_collected,
   game.ball_number, game.flippers[0].rotation, game.flippers[1].rotation])
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var file := FileAccess.open(OUTPUT % index, FileAccess.WRITE)
 file.store_var(trace)
 file.close()
 game.queue_free()
 await process_frame
 quit()
