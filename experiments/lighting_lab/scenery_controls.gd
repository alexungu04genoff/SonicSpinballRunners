extends VBoxContainer
## Authored Act/theme composition controls; atmosphere presets stay lab-only.
const Settings := preload("res://scripts/themes/scenery_settings.gd")
const DENSITIES := [0.5, 0.75, 1.0, 1.25, 1.5]
var lab: CanvasLayer
var seed_field: SpinBox
var density_field: OptionButton
var random_button: Button
var description: Label
var diagnostics: Label
var drafts := {}
var values := Settings.DEFAULTS.duplicate()
var act_path := ""
var theme_id := ""
var rng := RandomNumberGenerator.new()

func install(owner_lab: CanvasLayer) -> void:
 lab = owner_lab
 rng.randomize()
 description = _label("")
 _label("Scenery seed")
 seed_field = SpinBox.new()
 seed_field.max_value = Settings.MAX_SEED
 seed_field.step = 1
 seed_field.value_changed.connect(func(value: float): change({"seed": int(value), "density": values.density}))
 add_child(seed_field)
 random_button = lab._button(self, "Randomize", randomize_seed)
 _label("Scenery Density")
 density_field = OptionButton.new()
 for title: String in ["0.50 · Sparse", "0.75 · Light", "1.00 · Normal", "1.25 · Dense", "1.50 · Very Dense"]:
  density_field.add_item(title)
 density_field.item_selected.connect(func(index: int):
  if index < DENSITIES.size(): change({"seed": values.seed, "density": DENSITIES[index]})
 )
 add_child(density_field)
 var views := HBoxContainer.new()
 add_child(views)
 lab._button(views, "Inspect left", frame_edge.bind(-1))
 lab._button(views, "Inspect right", frame_edge.bind(1))
 diagnostics = _label("")
 _label("Save writes this Act/theme's scenery inputs. Then bake Prototype or Endless. Shared far scenery stays fixed. Short Acts may reject extra groups to preserve spacing.")

func _label(text: String) -> Label:
 var label := Label.new()
 label.text = text
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size", 13)
 add_child(label)
 return label

func bind_context() -> void:
 act_path = lab.game.playfield.document.resource_path
 theme_id = lab.game.theme_id
 var supported := theme_id in Settings.THEMES and not act_path.is_empty()
 seed_field.editable = supported
 random_button.disabled = not supported
 density_field.disabled = not supported
 description.text = act_path.get_file().get_basename() + " / " + lab.game.presentation.theme_definition.display_name
 if not supported: description.text += "\nThis theme keeps its authored composition."
 var saved := Settings.read(act_path, theme_id)
 values = drafts.get(_key(), {"seed": saved.seed, "density": saved.density}).duplicate()
 _sync()
 if not saved.error.is_empty(): lab.message.text = saved.error
 if supported and drafts.has(_key()): lab.preview_scenery(values)
 update_diagnostics.call_deferred()

func _key() -> String: return act_path + "::" + theme_id

func _sync() -> void:
 seed_field.set_value_no_signal(values.seed)
 if density_field.item_count > DENSITIES.size(): density_field.remove_item(DENSITIES.size())
 var index := DENSITIES.find(float(values.density))
 if index < 0:
  density_field.add_item("%.2f · Custom" % values.density)
  index = DENSITIES.size()
 density_field.select(index)

func change(selected: Dictionary) -> void:
 if theme_id not in Settings.THEMES or not Settings.valid(selected): return
 values = selected.duplicate()
 drafts[_key()] = values.duplicate()
 _sync()
 lab.preview_scenery(values)
 lab.message.text = "Unsaved scenery · " + act_path.get_file() + " / " + theme_id
 update_diagnostics.call_deferred()

func randomize_seed() -> void:
 var next := rng.randi_range(1, Settings.MAX_SEED)
 if next == values.seed: next = (next % Settings.MAX_SEED) + 1
 change({"seed": next, "density": values.density})

func save() -> void:
 seed_field.apply()
 var error := Settings.save(act_path, theme_id, values)
 lab.message.text = "Saved scenery. Re-bake this Act/theme." if error == OK else "Scenery save failed: " + error_string(error)
 lab.message.tooltip_text = ProjectSettings.globalize_path(Settings.path_for(act_path))

func reload() -> void:
 var saved := Settings.read(act_path, theme_id)
 if not saved.error.is_empty():
  lab.message.text = saved.error
  return
 change({"seed": saved.seed, "density": saved.density})
 lab.message.text = "Reloaded saved scenery."

func reset() -> void: change(Settings.DEFAULTS)

func frame_edge(side: int) -> void:
 var p: Node3D = lab.game.presentation
 p.set_camera_preset(p.CameraPreset.DRAMATIC_PINBALL)
 p.camera_settings.screen_target_y = 0.55
 p.set_camera_value("zoom", 1.3)
 p.set_camera_follow(true)
 var bounds: Rect2 = p.table_bounds
 p.reset_camera(bounds.position + bounds.size * Vector2(0.19 if side < 0 else 0.81, 0.877))
 var focus: Vector2 = p.camera_focus
 focus.x = bounds.position.x + bounds.size.x * (0.04 if side < 0 else 0.96)
 var distance: float = p._camera_offset.length()
 p.set_camera_follow(false)
 p.overview_zoom = 1.0
 p.reset_camera()
 p.overview_zoom = p._camera_offset.length() / distance
 p.overview_focus = focus
 p.reset_camera()

func update_diagnostics() -> void:
 var counts := {"instances": 0, "draw_groups": 0, "shadows": 0, "lights": 0}
 for child: Node in lab.game.presentation.scenery_root.get_children():
  if child.get_meta("atmosphere_scenery", "") != "local": continue
  var pending: Array[Node] = [child]
  while not pending.is_empty():
   var node: Node = pending.pop_back()
   pending.append_array(node.get_children())
   if node is Light3D: counts.lights += 1
   if not node is GeometryInstance3D: continue
   if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: counts.shadows += 1
   if node is MeshInstance3D and node.mesh != null:
    counts.instances += 1
    counts.draw_groups += node.mesh.get_surface_count()
   elif node is MultiMeshInstance3D and node.multimesh != null:
    counts.instances += node.multimesh.instance_count
    counts.draw_groups += node.multimesh.mesh.get_surface_count()
 diagnostics.text = "Local: %d groups · %d mesh instances\n%d mesh surfaces · %d shadow casters · %d lights\nSurface counts are preview estimates, not GPU draw calls." % [lab.game.presentation.scenery_group_count, counts.instances, counts.draw_groups, counts.shadows, counts.lights]
