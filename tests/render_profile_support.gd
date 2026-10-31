extends RefCounted
## Shared reporting only; never changes renderer or project settings.

static func metadata() -> Dictionary:
 return {"renderer": RenderingServer.get_current_rendering_method(),
  "driver": RenderingServer.get_current_rendering_driver_name(),
  "api": RenderingServer.get_video_adapter_api_version(),
  "device": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info().string,
  "command_line": OS.get_cmdline_args(), "user_arguments": OS.get_cmdline_user_args()}

static func pipelines() -> Dictionary:
 return {"canvas": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
  "mesh": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
  "surface": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
  "draw": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
  "specialization": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)}

static func disable_native_input(node: Node) -> void:
 node.set_process_input(false)
 node.set_process_unhandled_input(false)
 node.set_process_unhandled_key_input(false)
 for child: Node in node.get_children(): disable_native_input(child)

static func timing(values: Array) -> Dictionary:
 if values.is_empty(): return {"count": 0}
 var ordered := values.duplicate()
 ordered.sort()
 return {"count": ordered.size(), "median_ms": ordered[ordered.size() / 2],
  "p95_ms": ordered[int(ordered.size() * 0.95)], "p99_ms": ordered[int(ordered.size() * 0.99)],
  "max_ms": ordered[-1], "frames_over_50_ms": ordered.filter(func(ms): return ms > 50.0).size(),
  "frames_over_100_ms": ordered.filter(func(ms): return ms > 100.0).size()}
