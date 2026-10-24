class_name ZoneMarkers
extends Node3D
## Placeholder art adapter. All meshes and labels are collisionless.
var zone: ZoneRun
var markers: Array[MeshInstance3D] = []
var captions: Array[Label3D] = []
var entry_markers: Array[Node3D] = []

func _ready() -> void:
 name = "ZoneMarkers"
 if not zone.enabled:
  return
 for index in 3:
  var act: Dictionary = zone.acts[index]
  var marker := MeshInstance3D.new()
  if index < 2:
   var slab := BoxMesh.new()
   slab.size = Vector3((act.exit_right - act.exit_left) * TablePresentation.SCALE, 0.15, ZoneGate.THICKNESS * TablePresentation.SCALE)
   marker.mesh = slab
   marker.position = TablePresentation.map_point(Vector2((act.exit_left + act.exit_right) * 0.5, act.exit_y), 0.1)
  else:
   var portal := TorusMesh.new()
   portal.inner_radius = (ScoreAttack.GOAL_RADIUS - 5.0) * TablePresentation.SCALE
   portal.outer_radius = ScoreAttack.GOAL_RADIUS * TablePresentation.SCALE
   marker.mesh = portal
   marker.position = TablePresentation.map_point(act.goal_position, 0.04)
  add_child(marker)
  markers.append(marker)
  var caption := Label3D.new()
  caption.font_size = 25
  caption.pixel_size = 0.012
  caption.outline_size = 4
  caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  caption.position = marker.position + Vector3(0, 0.7, 0)
  add_child(caption)
  captions.append(caption)
  if index < 2:
   var entry := Node3D.new()
   add_child(entry)
   entry_markers.append(entry)
   var y: float = act.get("clear_y", act.exit_y)
   var mat := StandardMaterial3D.new()
   mat.albedo_color = Color("70ffba")
   mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
   var strip := MeshInstance3D.new()
   var strip_mesh := BoxMesh.new()
   strip_mesh.size = Vector3((act.exit_right - act.exit_left) * TablePresentation.SCALE, 0.015, 0.03)
   strip.mesh = strip_mesh
   strip.material_override = mat
   strip.position = TablePresentation.map_point(Vector2((act.exit_left + act.exit_right) * 0.5, y), 0.03)
   entry.add_child(strip)
   var hint := Label3D.new()
   hint.text = "ACT %d ENTRY" % (index + 2)
   hint.font_size = 22
   hint.pixel_size = 0.012
   hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
   hint.position = strip.position + Vector3(0, 0.35, 0)
   hint.modulate = Color("70ffba")
   entry.add_child(hint)
 zone.changed.connect(refresh)
 refresh()

func refresh() -> void:
 for index in markers.size():
  var past := index < zone.completed_acts
  var open := index == zone.active_act and zone.exit_unlocked and zone.state == ZoneRun.State.PLAYING
  if index < entry_markers.size():
   entry_markers[index].visible = open
  var color := Color("70ffba") if open else Color("f6ae52")
  if past:
   color = Color("67b6e6")
  var mat := StandardMaterial3D.new()
  mat.albedo_color = color
  mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  markers[index].material_override = mat
  markers[index].transparency = 0.8 if open and index < 2 else 0.0
  captions[index].modulate = color
  var state_text := " · OPEN" if open else " · LOCKED"
  if past:
   state_text = " · CLEARED" if index == 2 else " · CHECKPOINT"
  captions[index].text = ("ZONE PORTAL" if index == 2 else "ACT %d EXIT" % (index + 1)) + state_text
