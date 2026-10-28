extends Node3D
## Small live indicators use authoritative feature state, never award points.
var spinners: Array[Dictionary] = []
var flashes: Array[Dictionary] = []

func configure(mechanics: Node, ring_field: RingField, owner_id: String) -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 for item: Dictionary in mechanics.items:
  if item.type != "spinner" or not item.properties.completion_enabled: continue
  var label := _label(TablePresentation.map_point(item.position, 0.42))
  spinners.append({"item": item, "label": label})
 ring_field.rack_completed.connect(func(at: Vector2, source_id: String):
  if not source_id.begins_with(owner_id + ":"): return
  var label := _label(TablePresentation.map_point(at, 0.35))
  label.text = "RACK COMPLETE"
  label.modulate = Color("ffe07a")
  flashes.append({"label": label, "remaining": 1.0})
 )

func _label(at: Vector3) -> Label3D:
 var label := Label3D.new()
 label.position = at
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.font_size = 32
 label.pixel_size = 0.002
 add_child(label)
 return label

func _process(delta: float) -> void:
 for entry: Dictionary in spinners:
  var item: Dictionary = entry.item
  entry.label.text = "+%d" % int(item.properties.completion_bonus) if float(item.pulse) > 0.0 else "%d / %d" % [int(item.goal_ticks), int(item.properties.target_ticks)]
  entry.label.modulate = Color("ffe07a") if float(item.pulse) > 0.0 else Color("dbe7ef")
 for index in range(flashes.size() - 1, -1, -1):
  flashes[index].remaining -= delta
  if flashes[index].remaining <= 0.0:
   flashes[index].label.queue_free()
   flashes.remove_at(index)
