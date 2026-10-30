extends Control
## Offline authoring step. This screen never starts an endless session.
const Builder = preload("res://scripts/endless/template_builder.gd")
const Plan = preload("res://scripts/endless/endless_plan.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")
const PrototypePlan = preload("res://scripts/prototype/run_plan.gd")
var ball: PlaygroundBall
var tuning: PhysicsTuning
var controls: PlaygroundInput
var view: SubViewport
var status: Label
var progress: ProgressBar
var library: Node

func _ready() -> void:
 DisplayServer.window_set_title("Bake Act Presentation")
 var panel := VBoxContainer.new()
 panel.position = Vector2(32, 32)
 panel.custom_minimum_size = Vector2(780, 0)
 add_child(panel)
 var heading := Label.new()
 heading.text = "Bake verified Acts for streaming"
 heading.add_theme_font_size_override("font_size", 28)
 panel.add_child(heading)
 var description := Label.new()
 description.text = "Bakes collision, optimized meshes, flat surface materials, scenery and warm-up plans to disk.\nEndless loads these files and stages live instances and device-specific graphics ahead. Your saved Act stays unchanged."
 panel.add_child(description)
 status = Label.new()
 status.text = "Choose a saved Act to bake."
 panel.add_child(status)
 progress = ProgressBar.new()
 panel.add_child(progress)
 var paths: Array = []
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--act="): paths.append(argument.trim_prefix("--act="))
 if "--pool" in OS.get_cmdline_user_args(): paths = Plan.PATHS.duplicate()
 if "--prototype" in OS.get_cmdline_user_args():
  paths = PrototypePlan.source_paths()
  if paths.size() < PrototypePlan.ACTS_PER_ZONE:
   push_error("Prototype baking requires at least three Acts in data/acts/Authored.")
   get_tree().quit(1)
   return
 if paths.is_empty():
  var dialog := FileDialog.new()
  dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
  dialog.access = FileDialog.ACCESS_FILESYSTEM
  dialog.filters = PackedStringArray(["*.tres ; Authored Act"])
  dialog.current_dir = ProjectSettings.globalize_path("res://data/acts")
  add_child(dialog)
  dialog.file_selected.connect(func(path: String): bake([path]))
  dialog.popup_centered_ratio(0.8)
 else:
  bake(paths)

func bake(paths: Array) -> void:
 var world := Node2D.new()
 world.process_mode = Node.PROCESS_MODE_DISABLED
 add_child(world)
 tuning = PhysicsTuning.new()
 world.add_child(tuning)
 controls = PlaygroundInput.new()
 world.add_child(controls)
 ball = PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 world.add_child(ball)
 view = SubViewport.new()
 view.msaa_3d = Viewport.MSAA_4X
 add_child(view)
 library = Builder.new()
 add_child(library)
 library.progress.connect(func(message: String): status.text = message)
 library.prepare(self, paths, false)
 var themes: Array = Registry.IDS.duplicate()
 if "--prototype" in OS.get_cmdline_user_args(): themes = PrototypePlan.THEMES.duplicate()
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--theme="): themes = [argument.trim_prefix("--theme=")]
 progress.max_value = paths.size() * themes.size()
 for theme_id: String in themes:
  if theme_id not in Registry.IDS:
   library.error = "Unknown theme: " + theme_id
   break
  for id in paths.size():
   if not library.error.is_empty(): break
   while not library.trim([{"theme": theme_id, "id": id}], 1, 0 if library.themes.has(theme_id) else 1):
    await get_tree().process_frame
   library.request(theme_id, id)
   while library.busy: await get_tree().process_frame
   progress.value += 1
 if library.error.is_empty():
  status.text = "Bake complete. Act sidecars and shared theme assets are ready.\nEndless mode loads visual recipes directly and prepares graphics ahead."
  print("ACT_BAKE_COMPLETE | Acts=", paths.size(), " variants=", int(progress.value))
 else:
  status.text = library.error
  push_error(library.error)
 if DisplayServer.get_name() == "headless" or "--quit-after-bake" in OS.get_cmdline_user_args():
  get_tree().quit(0 if library.error.is_empty() else 1)
