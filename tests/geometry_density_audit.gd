extends SceneTree
## CPU mesh accounting, not a rendering fixture. Counts instances, including
## off-camera geometry; shadow-only meshes are reported separately.
const Themes = preload("res://scripts/themes/theme_registry.gd")
const Presentation = preload("res://scripts/themes/themed_presentation.gd")
const Detail = preload("res://scripts/endless/visual_detail.gd")
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
var output := "res://test-results/geometry-density/audit.json"
var act := "res://data/acts/Authored/First Try Smooth Decor.tres"

func _initialize() -> void:
 run.call_deferred()

static func counts(mesh: Mesh) -> Dictionary:
 var result := {"vertices": 0, "triangles": 0}
 for surface in mesh.get_surface_count():
  var arrays := mesh.surface_get_arrays(surface)
  var vertices: int = arrays[Mesh.ARRAY_VERTEX].size()
  var indices: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else 0
  result.vertices += vertices
  result.triangles += (indices if indices > 0 else vertices) / 3
 return result

static func add(target: Dictionary, mesh: Mesh, multiplier: int, shadow: int) -> void:
 var size := counts(mesh)
 target.mesh_instances += multiplier
 target.vertices += size.vertices * multiplier
 target.triangles += size.triangles * multiplier
 if shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
  target.shadow_triangles += size.triangles * multiplier
 if shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
  target.shadow_only_triangles += size.triangles * multiplier

static func empty() -> Dictionary:
 return {"vertices": 0, "triangles": 0, "shadow_triangles": 0, "shadow_only_triangles": 0, "mesh_instances": 0}

static func tree_counts(node: Node, convert := false) -> Dictionary:
 var total := empty()
 var pending: Array[Node] = [node]
 while not pending.is_empty():
  var current: Node = pending.pop_back()
  pending.append_array(current.get_children())
  if current is MeshInstance3D and current.mesh != null:
   var mesh: Mesh = current.mesh
   if convert and mesh is PrimitiveMesh: mesh = Detail.primitive(mesh)
   add(total, mesh, 1, current.cast_shadow)
 return total

static func recipe_counts(recipe: Resource) -> Dictionary:
 var total := empty()
 var groups := {}
 var ancestry: Array[String] = []
 var instances := {}
 for record: Dictionary in recipe.records:
  var node: Node = record.scene.instantiate()
  var group: String = ancestry[record.parent] if record.parent >= 0 else "other"
  if node.has_meta("decor_variant"):
   group = str(node.get_meta("decor_variant"))
   instances[group] = int(instances.get(group, 0)) + 1
  elif node.name in ["StarBumper", "StripedFlipper"]: group = str(node.name)
  ancestry.append(group)
  var mesh: Mesh = record.get("instance_mesh")
  var multiplier: int = record.instance_buffer.size() / 12 if record.has("instance_buffer") else 1
  if node is MeshInstance3D: mesh = node.mesh
  if mesh != null:
   if not groups.has(group): groups[group] = empty()
   add(total, mesh, multiplier, node.cast_shadow)
   add(groups[group], mesh, multiplier, node.cast_shadow)
  node.free()
 total["groups"] = groups
 total["retained_decor_roots"] = instances
 total["batch_stats"] = recipe.batch_stats
 total["dynamic_rings"] = recipe.rings.size()
 total["dynamic_bumpers"] = recipe.bumpers.size()
 total["dynamic_flippers"] = recipe.flippers.size()
 total["animation_bindings"] = recipe.animations.size()
 if not recipe.rings.is_empty():
  var ring: MeshInstance3D = recipe.records[recipe.rings[0]].scene.instantiate()
  total["ring_mesh"] = counts(ring.mesh)
  ring.free()
 return total

func run() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
  if argument.begins_with("--act="): act = argument.trim_prefix("--act=")
 var report := {"act": act, "themes": {}, "complete": true}
 var document: Resource = Document.load_document(act).document
 for theme: String in Themes.IDS:
  var p := Presentation.new()
  p.set_theme_definition(Themes.create(theme))
  var variants := {}
  for hints: Dictionary in p.decor_skin.pools.values():
   for pool: Array in hints.values():
    for variant: String in pool:
     if variants.has(variant): continue
     var prop: Node3D = p.decor_skin.factory.call(variant)
     variants[variant] = {"source": tree_counts(prop), "primitive_conversion": tree_counts(prop, true)}
     prop.free()
  var entry := {"decor": variants}
  for kind: String in ["act", "background"]:
   var path := Bake.path_for(act, theme) if kind == "act" else Bake.theme_path(theme)
   var baked: Resource = load(path)
   entry[kind] = recipe_counts(baked.visual_recipe)
   entry[kind]["fresh"] = baked.matches(document, theme) if kind == "act" else baked.matches_pipeline(theme)
   if not entry[kind].fresh:
    report.complete = false
    push_error("Density audit encountered stale data: " + path)
   entry[kind]["bytes"] = FileAccess.get_file_as_bytes(path).size()
   entry[kind]["pipeline"] = baked.pipeline_fingerprint
  report.themes[theme] = entry
  print("DENSITY | ", theme, " | act triangles=", entry.act.triangles, " background=", entry.background.triangles)
  p.free()
  await process_frame
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file := FileAccess.open(output, FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 quit(0 if report.complete else 1)
