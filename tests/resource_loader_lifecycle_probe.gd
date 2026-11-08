extends SceneTree
## Loader-only control: no Session, instantiated scenes, gameplay or project caches.
var mode := "threaded"
var output := "res://test-results/lifecycle-audit/loader-threaded.json"
var rows: Array[Dictionary] = []
var existing_resource := "res://data/acts/Authored/RampMania.bake/green_hill.res"

func _initialize() -> void: call_deferred("run")

func census() -> Dictionary:
 return {"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
  "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
  "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}

func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--loader-mode="): mode = arg.trim_prefix("--loader-mode=")
  if arg.begins_with("--loader-output="): output = arg.trim_prefix("--loader-output=")
  if arg.begins_with("--loader-resource="): existing_resource = arg.trim_prefix("--loader-resource=")
 if mode not in ["threaded", "threaded_single", "synchronous", "plain_thread"]: quit(1); return
 for cycle in 6:
  var resource_path := existing_resource
  await process_frame
  var before := census()
  var resource: Resource
  if mode in ["threaded", "threaded_single"]:
   if ResourceLoader.load_threaded_request(resource_path, "", mode == "threaded") != OK: quit(1); return
   while ResourceLoader.load_threaded_get_status(resource_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS: await process_frame
   resource = ResourceLoader.load_threaded_get(resource_path)
  elif mode == "plain_thread":
   var thread := Thread.new()
   thread.start(ResourceLoader.load.bind(resource_path))
   while thread.is_alive(): await process_frame
   resource = thread.wait_to_finish()
  else:
   resource = ResourceLoader.load(resource_path)
  if resource == null: quit(1); return
  var reference: WeakRef = weakref(resource)
  resource = null
  for frame in 8: await process_frame
  var released := reference.get_ref() == null
  reference = null
  await process_frame
  var record := {"cycle": cycle, "mode": mode, "resource": existing_resource, "before": before, "after": census(), "resource_released": released}
  rows.append(record)
  print("LOADER_LIFECYCLE | ", JSON.stringify(record))
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file := FileAccess.open(output, FileAccess.WRITE)
 file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(), "rows": rows}, "  "))
 file.close()
 quit(0)
