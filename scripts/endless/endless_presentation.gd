extends "res://scripts/presentation.gd"
## Persistent camera and player presentation; streamed roots own their local art.
var touring := false
var tour_focus := Vector2.ZERO

func build_authored(_runtime: Dictionary, bounds: Rect2, cell_size: float) -> void:
 authored_mode = true
 authored_cell_size = cell_size
 var saved_rings := ring_field.rings
 ring_field.rings = []
 flippers = []
 _build_shared(bounds)
 ring_field.rings = saved_rings
 get_node("TableFloor").queue_free()
 camera.far = 180.0

func _clamp_focus(point: Vector2) -> Vector2:
 # A growing connected course has no camera stop at the active Act's top edge.
 return point

func _update_camera(delta: float) -> void:
 if touring:
  camera_focus = tour_focus
  camera_target = tour_focus
  camera.position = map_point(tour_focus) + _camera_offset
 else:
  super._update_camera(delta)

func _on_ring_claimed(index: int) -> void:
 if index >= ring_visuals.size(): return
 var visual := ring_visuals[index]
 visual.global_position = map_point(ring_field.rings[index].position, ring_height())
 visual.scale = Vector3.ONE
 visual.visible = true
 ring_pickups[index] = {"start": visual.global_position, "elapsed": 0.0}

func clear_ring_pickups() -> void:
 ring_pickups.clear()
 for i in mini(ring_visuals.size(), ring_field.rings.size()):
  ring_visuals[i].visible = ring_field.rings[i].active
  ring_visuals[i].global_position = map_point(ring_field.rings[i].position, ring_height())
  ring_visuals[i].scale = Vector3.ONE

func _update_ring_visuals(delta: float) -> void:
 for i in ring_visuals.size():
  var visual := ring_visuals[i]
  if ring_pickups.has(i):
   var pickup: Dictionary = ring_pickups[i]
   pickup.elapsed = minf(float(pickup.elapsed) + delta, RING_PICKUP_DURATION)
   var progress: float = pickup.elapsed / RING_PICKUP_DURATION
   visual.global_position = (pickup.start as Vector3).lerp(ball_visual.global_position, progress * progress)
   visual.scale = Vector3.ONE * lerpf(1.0, 0.25, smoothstep(0.7, 1.0, progress))
   if progress >= 1.0:
    visual.visible = false
    ring_pickups.erase(i)
  else:
   visual.visible = ring_field.rings[i].active

func build_study(_parent: Node3D, _origin: Vector3) -> void:
 pass

func _floor_line(_a: Vector2, _b: Vector2, _mat: Material) -> void:
 pass # Streamed Act recipes own the complete visible floor.
