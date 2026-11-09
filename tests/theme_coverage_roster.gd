extends SceneTree
## Discover the supported roster and propose evidence-only gameplay targets.
const Plan = preload("res://scripts/prototype/run_plan.gd")
const Themes = preload("res://scripts/themes/theme_registry.gd")

func _initialize() -> void:
 var rows: Array = []
 for path: String in Plan.source_paths():
  var act: Resource = Plan.Document.load_document(path).document
  var targets := {}
  for tier: String in ["mid", "upper"]:
   var fraction := 0.50 if tier == "mid" else 0.20
   var desired: Vector2 = act.terrain_bounds().size * Vector2(0.5, fraction)
   var chosen: Vector2 = desired
   var nearest := INF
   var candidates: Array = act.gameplay_objects.duplicate()
   if tier == "upper": candidates.append({"position": act.goal_center()})
   for object: Dictionary in candidates:
    var at: Vector2 = object.position
    # Longitudinal tier first, then central framing. Anchor to actual hardware.
    var distance := absf(at.y - desired.y) * 3.0 + absf(at.x - desired.x)
    if distance < nearest:
     nearest = distance
     chosen = at
   targets[tier] = [chosen.x, chosen.y]
  rows.append({"path": path, "title": path.get_file().get_basename(), "authored_title": act.title, "fingerprint": act.fingerprint(),
   "source_sha256": FileAccess.get_sha256(path), "decor_slots": act.decor_slots.size(), "spawn": [act.spawn_position.x, act.spawn_position.y],
   "targets": targets})
 var report := {"acts": rows, "themes": Themes.IDS, "view_count": rows.size() * Themes.IDS.size() * 3,
  "target_policy": "Spawn uses the canonical camera. Mid/upper targets use actual authored hardware nearest the central 50%/20% terrain bands; upper also considers Goal. Evidence-only; visually review each framing before accepting it."}
 DirAccess.make_dir_recursive_absolute("res://test-results/theme-coverage")
 var file := FileAccess.open("res://test-results/theme-coverage/roster.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 print(JSON.stringify(report))
 quit()
