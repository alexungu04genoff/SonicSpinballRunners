extends SceneTree
## Read-only disk authority for the base-game motion pass. Never repairs bakes.
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Plan = preload("res://scripts/endless/endless_plan.gd")
const Prototype = preload("res://scripts/prototype/run_plan.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Motion = preload("res://scripts/theme_motion/registry.gd")
var output := "res://test-results/theme-motion/bake-audit.json"
var before_path := "res://test-results/theme-motion/bake-sizes-before.json"
var before := {}
var rows: Array[Dictionary] = []
var stale: Array[Dictionary] = []
var problems: Array[String] = []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: problems.append(label)

func run() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
  if argument.begins_with("--before="): before_path = argument.trim_prefix("--before=")
 if FileAccess.file_exists(before_path):
  var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(before_path))
  if previous is Array:
   for entry: Dictionary in previous: before[str(entry.path).trim_prefix("res://").replace("\\", "/")] = int(entry.bytes)
 var pools := {"prototype":Prototype.source_paths(), "endless":Plan.PATHS}
 for theme: String in Motion.IDS:
  var fingerprint := Bake.pipeline_hash(theme)
  _audit(Bake.theme_path(theme), theme, "shared", "", fingerprint)
  for pool: String in pools:
   for path: String in pools[pool]:
    _audit(Bake.path_for(path, theme), theme, pool, path, fingerprint)
    await process_frame
 var summary := {}
 for row: Dictionary in rows:
  if not summary.has(row.theme): summary[row.theme] = {"files":0,"bytes":0,"before_bytes":0,"delta_bytes":0,"records":0,"motion_bindings":0,"fresh":true}
  var item: Dictionary = summary[row.theme]
  item.files += 1
  item.bytes += int(row.get("bytes", 0))
  item.before_bytes += int(row.get("before_bytes", 0))
  item.delta_bytes += int(row.get("delta_bytes", 0))
  item.records += int(row.get("records", 0))
  item.motion_bindings += int(row.get("motion_binding_count", 0))
  item.fresh = item.fresh and row.fresh
 var report := {"scope":Motion.IDS, "authority":"Validated disk recipes", "complete":problems.is_empty(),
  "checks":checks,"failures":problems.size(),"problems":problems,"stale":stale,"summary":summary,"recipes":rows,
  "limitations":["File bytes exclude external shared bake assets.", "Record/material/signature counts are resident recipe inventories, not rendered draws or frame costs.", "Before snapshot contains file bytes only; record/material deltas are unavailable."]}
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file := FileAccess.open(output, FileAccess.WRITE)
 if file == null:
  push_error("Cannot write Theme Motion bake audit: " + output)
  quit(1)
  return
 file.store_string(JSON.stringify(report, "  "))
 file.close()
 for entry: Dictionary in stale: print("MOTION_STALE | ", entry.theme, " | ", entry.pool, " | ", entry.path)
 print("RESULT | Theme Motion disk audit | %d files | %d checks | %d failures | %s" % [rows.size(), checks, problems.size(), output])
 quit(0 if problems.is_empty() else 1)

func _audit(path: String, theme: String, pool: String, source: String, fingerprint: String) -> void:
 var row := {"theme":theme,"pool":pool,"path":path,"source":source,"fresh":false,"bytes":0,"before_bytes":0,"delta_bytes":0}
 rows.append(row)
 var bare := path.trim_prefix("res://")
 var stream := FileAccess.open(path, FileAccess.READ)
 if stream != null:
  row.bytes = stream.get_length()
  stream.close()
 row.before_bytes = int(before.get(bare, 0))
 row.delta_bytes = int(row.bytes) - int(row.before_bytes)
 var baked: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) if ResourceLoader.exists(path) else null
 if not baked is Bake:
  stale.append({"theme":theme,"pool":pool,"path":path,"source":source,"reason":"missing or invalid resource"})
  check(false, "Missing/invalid recipe: " + path)
  return
 var document: Resource = Document.load_document(source).document if not source.is_empty() else null
 row.fresh = baked.matches_pipeline(theme, fingerprint) if source.is_empty() else document != null and baked.matches(document, theme, fingerprint)
 check(row.fresh, "Fresh disk recipe: " + path)
 if not row.fresh: stale.append({"theme":theme,"pool":pool,"path":path,"source":source,"reason":"source/scenery/pipeline fingerprint mismatch"})
 row.pipeline = baked.pipeline_fingerprint
 row.expected_pipeline = fingerprint
 if document != null: check(baked.has_validated_collisions(document), "Validated collision receipt: " + path)
 var recipe: Resource = baked.visual_recipe
 check(recipe != null and not recipe.records.is_empty(), "Nonempty visual recipe: " + path)
 if recipe == null: return
 check(recipe.has_warm_manifest(), "Saved warm manifest: " + path)
 row.records = recipe.records.size()
 row.record_delta = null
 row.batch_stats = recipe.batch_stats
 row.animation_bindings = recipe.animations.size()
 row.motion_binding_count = 0
 row.motion_bindings = {}
 row.native_environment_scripts = 0
 row.instance_count = 0
 row.shadow_eligible_records = 0
 var signatures := {}
 var materials := {}
 var shaders := {}
 var systems := {}
 var transparent := {}
 var finite := true
 var valid_bindings := true
 for animation: Dictionary in recipe.animations:
  if animation.script == preload("res://scripts/decor/island_flicky.gd"): row.native_environment_scripts += 1
 for record: Dictionary in recipe.records:
  for signature: String in record.get("warm_signatures", PackedStringArray()): signatures[signature] = true
  var node: Node = record.scene.instantiate()
  if node is Node3D: finite = finite and node.transform.origin.is_finite() and node.basis.x.is_finite() and node.basis.y.is_finite() and node.basis.z.is_finite()
  if node.has_meta("theme_motion"):
   var spec: Variant = node.get_meta("theme_motion")
   var problem := Motion.binding_error(spec)
   valid_bindings = valid_bindings and problem.is_empty() and node is Node3D
   if problem.is_empty():
    var key := str(spec.candidate) + ":" + str(spec.kind)
    row.motion_bindings[key] = int(row.motion_bindings.get(key, 0)) + 1
    row.motion_binding_count += 1
  if node is GeometryInstance3D:
   finite = finite and is_finite(node.extra_cull_margin) and node.extra_cull_margin >= 0.0
   if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: row.shadow_eligible_records += 1
   _material(node.material_override, materials, shaders, systems, transparent)
   _material(node.material_overlay, materials, shaders, systems, transparent)
   var mesh: Mesh = node.mesh if node is MeshInstance3D else record.get("instance_mesh")
   if mesh != null:
    var bounds := mesh.get_aabb()
    finite = finite and bounds.position.is_finite() and bounds.size.is_finite()
    if node.material_override == null:
     for surface in mesh.get_surface_count(): _material(node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface), materials, shaders, systems, transparent)
   if record.has("instance_buffer"):
    row.instance_count += record.instance_buffer.size() / 12
    var bounds: AABB = record.instance_bounds
    finite = finite and bounds.position.is_finite() and bounds.size.is_finite()
  node.free()
 check(finite, "Finite node/mesh/instance bounds: " + path)
 check(valid_bindings, "Explicit valid motion bindings: " + path)
 row.warm_signatures = signatures.size()
 row.materials = materials.size()
 row.shaders = shaders.size()
 row.environment_shader_systems = systems.keys()
 row.transparent_materials = transparent.size()
 row.finite = finite
 row.valid_bindings = valid_bindings

func _material(material: Material, materials: Dictionary, shaders: Dictionary, systems: Dictionary, transparent: Dictionary) -> void:
 if material == null or materials.has(material.get_instance_id()): return
 materials[material.get_instance_id()] = true
 if material is ShaderMaterial and material.shader != null:
  shaders[material.shader.code.sha256_text()] = true
  var id := Motion.shader_id(material)
  if id in Motion.SYSTEMS: systems[id] = true
  if RegEx.create_from_string("\\bALPHA\\s*=").search(material.shader.code) != null: transparent[material.get_instance_id()] = true
 elif material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
  transparent[material.get_instance_id()] = true
 _material(material.next_pass, materials, shaders, systems, transparent)
