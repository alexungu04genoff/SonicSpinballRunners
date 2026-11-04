extends RefCounted
## Read-only authored facts. These are not validation or predictions of play quality.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Rings = preload("res://scripts/act_editor/ring_trails.gd")
const RailRings = preload("res://scripts/authored_act/rail_rings.gd")
const Dimensions = preload("res://scripts/act_dimensions.gd")
const FEATURED_FAMILIES := {
 "drop_target_bank": "Drop Targets", "switch_target": "Switch", "wall_switch": "Switch",
 "one_way_gate": "One-Way Gate", "diverter": "Diverter", "elevated_rail": "Elevated Rail",
 "dash_panel": "Dash Panel", "spinner": "Spinner", "lane_barrier": "Lane Barrier",
 "magnetic_field": "Magnetic Field",
}

static func summarize(document: Resource) -> Dictionary:
 var counts := {}
 for definition: Dictionary in Objects.definitions(): counts[definition.id] = 0
 var families := PackedStringArray()
 var pattern_rings := 0
 var rail_rings := 0
 var gates := PackedFloat64Array()
 var target_spacing := PackedFloat64Array()
 for trail: Dictionary in document.ring_trails: pattern_rings += Rings.positions(trail).size()
 for item: Dictionary in document.gameplay_objects:
  var type := str(item.type)
  counts[type] = int(counts.get(type, 0)) + 1
  if FEATURED_FAMILIES.has(type) and not families.has(FEATURED_FAMILIES[type]):
   families.append(FEATURED_FAMILIES[type])
  var properties := Objects.properties(item)
  match type:
   "elevated_rail": rail_rings += RailRings.samples(item, properties).size()
   "one_way_gate": gates.append(float(properties.width))
   "drop_target_bank": target_spacing.append(float(properties.spacing))
 if not document.switch_banks.is_empty() and not families.has("Switch"): families.append("Switch")
 families.sort()
 gates.sort()
 target_spacing.sort()
 var rings := pattern_rings + rail_rings
 var ball_diameter: float = 2.0 * Dimensions.BALL_RADIUS_CELLS * document.cell_size
 var goal_diameter: float = document.goal_diameter_cells * document.cell_size
 var hints := PackedStringArray()
 if counts.buzz_bomber == 0: hints.append("No Buzz Bombers are authored; review the intended enemy role.")
 if rings == 0: hints.append("No Rings are authored; review how routes are taught or rewarded.")
 if counts.slingshot == 0: hints.append("No Slingshots are authored; review the intended rebound vocabulary.")
 if families.size() > 3: hints.append("%d featured mechanic families are present; review whether the Act has a clear mechanical identity." % families.size())
 if goal_diameter < ball_diameter * 2.0: hints.append("Goal diameter is below two base Ball diameters; playtest its attack angles.")
 return {"counts": counts, "pattern_rings": pattern_rings, "rail_rings": rail_rings, "rings": rings,
  "families": families, "hints": hints, "ball_diameter": ball_diameter, "goal_diameter": goal_diameter,
  "gate_widths": gates, "target_spacings": target_spacing,
  "goal": "Authored" if document.goal_position is Vector2 else ("Default: Spawn" if document.spawn_position is Vector2 else "Default: table center"),
  "spawn": document.spawn_position is Vector2}

static func scale_text(label: String, values: PackedFloat64Array, ball: float) -> String:
 if values.is_empty(): return ""
 var low := values[0]
 var high := values[values.size() - 1]
 if is_equal_approx(low, high): return "%s: %.1f px · %.2f× Ball" % [label, low, low / ball]
 return "%s: %.1f–%.1f px · %.2f–%.2f× Ball" % [label, low, high, low / ball, high / ball]
