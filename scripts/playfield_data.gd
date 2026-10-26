class_name PlayfieldData
extends RefCounted
## The geometry supplied to the existing game, independent of its level source.
## Holds references to bodies owned by the game; never constructs a second engine.
const RingTrails = preload("res://scripts/act_editor/ring_trails.gd")

var source := "authored"
var bounds := Rect2()
var terrain_bounds := Rect2()
var spawn := Vector2.ZERO
var ring_positions := PackedVector2Array()
var bumpers: Array[Node2D] = []
var terrain_bodies: Array[StaticBody2D] = []
var authored_runtime: Dictionary = {}
var document: Resource
var _bumper_radii: Dictionary = {}
var _glide_surfaces: Array[StaticBody2D] = []

static func from_authored(act: Resource, compiled: Dictionary) -> PlayfieldData:
 # The caller has already validated and compiled the Act. Keep its exact source
 # values and existing bodies; no normalization, generation or fake chunks.
 var result := PlayfieldData.new()
 result.source = "authored"
 result.document = act
 result.authored_runtime = compiled
 result.terrain_bounds = act.terrain_bounds()
 result.bounds = Rect2(result.terrain_bounds.position, act.red_gutter_bounds().end - result.terrain_bounds.position)
 result.spawn = act.spawn_position
 for trail: Dictionary in act.ring_trails:
  result.ring_positions.append_array(RingTrails.positions(trail))
 for item: Dictionary in compiled.objects:
  if item.type in ["round_bumper", "triangle_bumper"]:
   result._add_bumper(item.body, float(item.radius) if item.type == "round_bumper" else 0.0)
 for item: Dictionary in compiled.terrain:
  result.terrain_bodies.append(item.body)
  result._glide_surfaces.append(item.body)
 return result

func _add_bumper(body: Node2D, radius: float) -> void:
 if not bumpers.has(body):
  bumpers.append(body)
 _bumper_radii[body.get_instance_id()] = radius

func bumper_radius(body: Node2D) -> float:
 # Only circles expose a radial face. Slings keep their original anchor targeting.
 return float(_bumper_radii.get(body.get_instance_id(), 0.0)) if is_instance_valid(body) else 0.0

func is_glide_surface(body: Node2D) -> bool:
 return is_instance_valid(body) and _glide_surfaces.has(body)
