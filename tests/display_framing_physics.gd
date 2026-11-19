extends SceneTree
## Fresh-process exact physics traces: reference, fixed framing, live aspect changes.
const Contract = preload("res://scripts/display_framing.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--display-replay="):
   await record(int(argument.trim_prefix("--display-replay=")))
   return
 var baseline: Array = []
 var failures := 0
 for index in 3:
  var output: Array = []
  var status := OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--fixed-fps","120","--script","res://tests/display_framing_physics.gd","--","--display-replay=%d"%index]),output,true)
  if status != 0:
   failures += 1
   push_error("Display physics subprocess failed: "+str(output))
   continue
  var trace: Array = FileAccess.open("user://display-replay-%d.bin"%index,FileAccess.READ).get_var()
  if index==0: baseline=trace
  if trace.size()!=600 or trace!=baseline:
   failures += 1
   push_error("Display contract changed exact 600-tick trace: "+str(index))
  else: print("PASS | Display physics case ",index," exact trajectory/velocity/score/rings/drains/flippers")
 print("RESULT | Display framing physics | 3 checks | %d failures"%failures)
 quit(1 if failures else 0)

func record(index: int) -> void:
 var game: Node = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 root.add_child(game)
 if index>0: Contract.attach(game)
 game.retro_controls.hide()
 game.controls.virtual_enabled = true
 for frame in 3: await physics_frame
 game.launch_ball()
 var trace: Array = []
 var sizes := [Vector2i(1280,720),Vector2i(1600,1200),Vector2i(3440,1440),Vector2i(3840,2160)]
 for tick in 600:
  if index==2 and tick%60==0: root.size=sizes[(tick/60)%sizes.size()]
  game.controls.virtual_left=tick%90<35
  game.controls.virtual_right=tick%110<40
  game.controls.virtual_steering=0.35 if tick%180<90 else -0.35
  await physics_frame
  trace.append([game.ball.position,game.ball.linear_velocity,game.score,game.rings_collected,game.ball_number,game.flippers[0].rotation,game.flippers[1].rotation])
 var file := FileAccess.open("user://display-replay-%d.bin"%index,FileAccess.WRITE)
 file.store_var(trace)
 file.close()
 game.queue_free()
 await process_frame
 quit()
