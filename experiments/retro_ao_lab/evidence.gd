extends "../retro_shadow_lab/evidence.gd"
const NAMES := ["off","native","coarse","clean8","clean4","clean3","clean2","ordered4","authored","continuous","clean5"]

func curve_shader() -> String:
 return """shader_type canvas_item;
#include "res://experiments/retro_ao_lab/bands.gdshaderinc"
void fragment() {
 const int counts[6] = {8,5,4,3,2,0};
 float a = contact_band(floor(FRAGCOORD.x)/256.0,0.5,counts[int(FRAGCOORD.y)]);
 COLOR = vec4(vec3(a),1.0);
}"""

func run(owner: Node) -> void:
 lab = owner
 out = lab.output
 var args := OS.get_cmdline_user_args()
 if "--first-authored" in args or "--first-native" in args:
  await first_use(lab.AO.AUTHORED if "--first-authored" in args else lab.AO.NATIVE)
  return
 var quick := "--quick" in OS.get_cmdline_user_args()
 lab.study_card = true
 lab.theme = "rooftop_run"
 if await lab.open_game():
  await check_curve()
  await compare("stairs", quick)
  await verify_stairs()
  if not quick:
   await ordered_study()
   await scale_study()
   await motion_strip("stairs")
   await shadow_pairs("stairs")
 await close_case()
 if not quick:
  for id: String in lab.Fixture.Registry.IDS:
   lab.study_card = false
   lab.theme = id
   if not await lab.open_game(): break
   await compare(id, false)
   if id in ["casino_night","aquarium_park"]: await lighting_control(id)
   if id == "rooftop_run": await motion_strip(id)
   if id == "aquarium_park": transparency_control()
   await close_case()
  lab.study_card = false
  await motion_fixtures()
  await crossing()
  lab.endless = false
  lab.act_index = 0
  lab.set_ao(0)
  if await lab.open_game():
   check(lab.fixture.authority_error().is_empty() and not lab.environment.ssao_enabled, "Replay loads the native foreground again")
   await close_case()
 lab.busy = true
 await frames(5)
 check(lab.contact.owners.is_empty(), "Released all experimental material owners")
 write_report(true)
 print("RETRO_AO_RESULT | rows=",rows.size()," failures=",lab.failures)
 lab.get_tree().quit(0 if lab.failures.is_empty() else 1)

func first_use(mode: int) -> void:
 lab.theme = "rooftop_run"
 if await lab.open_game():
  lab.set_ao(0)
  var reference := await image()
  for phase in ["first","repeat"]:
   var before := Report.pipelines()
   var start := Time.get_ticks_usec()
   lab.set_ao(mode)
   var activation := (Time.get_ticks_usec()-start)/1000.0
   var warm := await bench(24,false)
   var steady := await bench(120,false)
   var sample := await image()
   check(sample.get_data()!=reference.get_data(),phase + " AO is visible")
   rows.append({"runtime":"Isolated first use","phase":phase,"mode":NAMES[mode],"startup_ms":lab.open_ms,
    "activation_ms":activation,"warm24":warm.frame,"steady":steady.frame,"inventory":lab.contact.inventory(),
    "pipelines_before":before,"pipelines_after":Report.pipelines()})
   lab.set_ao(0)
   check((await image()).get_data()==reference.get_data(),phase + " exact restore")
  await close_case()
 await frames(5)
 write_report(true)
 print("RETRO_AO_FIRST_USE | mode=",NAMES[mode]," failures=",lab.failures)
 lab.get_tree().quit(0 if lab.failures.is_empty() else 1)

func compare(label: String, quick: bool) -> void:
 var pose: Dictionary = lab.fixture.state()
 check(lab.fixture.authority_error().is_empty(), label + " disk-backed Prototype")
 lab.set_ao(0)
 var reference := await shot(label + "-off")
 var original: Dictionary = lab.original.duplicate()
 original.ssao_enabled = false # The study's Off reference disables production SSAO.
 for m in NAMES.size():
  var before := Report.pipelines()
  var start := Time.get_ticks_usec()
  lab.set_ao(m)
  var activate := (Time.get_ticks_usec() - start) / 1000.0
  var warm := await bench(24,false)
  var pic := reference if m == 0 else await shot(label + "-" + NAMES[m])
  if m > 0 and label == "stairs":
   check(pic.get_data() != reference.get_data(), "Visible stair response " + NAMES[m])
  if m >= 3:
   check(lab.contact.inventory().receivers > 0,label + " material coverage " + NAMES[m])
  var settled := await bench(45 if quick else 120,false)
  if not quick and label in ["stairs","rooftop_run"]:
   settled["pan"] = (await bench(90,true)).frame
   lab.camera(lab.start_focus)
  settled.merge({"fixture":label,"mode":NAMES[m],"startup_ms":lab.open_ms,"activation_ms":activate,
   "warm24":warm.frame,"pipelines_before":before,"pipelines_after":Report.pipelines(),"inventory":lab.contact.inventory()})
  rows.append(settled)
  write_report(false)
 lab.set_ao(0)
 check(reference.get_data() == (await image()).get_data(), label + " AO off exact pixels")
 var normal_strength: float = lab.strength
 lab.strength = 0.0
 for m in [4,8]:
  lab.set_ao(m)
  check(reference.get_data() == (await image()).get_data(),label + " original material at zero strength " + NAMES[m])
 lab.strength = normal_strength
 lab.set_ao(0)
 check(lab.fixture.state() == pose, label + " held simulation and camera")
 for p: String in original: check(lab.environment.get(p) == original[p],label + " restored " + p)
 check(not FileAccess.file_exists(lab.Review.Options.settings_path), label + " preferences isolated")
 var background_clean := true
 for index: int in lab.game.backgrounds:
  background_clean = background_clean and not lab.game.backgrounds[index].layer.atmosphere.environment.ssao_enabled
 check(background_clean,label + " backdrop AO off")
 if quick:
  lab.layer.show()
  lab.ao_choice.item_selected.emit(lab.AO.AUTHORED)
  check(lab.treatment == lab.AO.AUTHORED, "Native AO menu selection")
  await shot("controls")
  lab.layer.hide()
 lab.set_ao(0)

func watch_owners() -> Dictionary:
 var watched: Dictionary = super()
 for obj: Object in [lab.compositor,lab.depth]:
  if obj: watched[str(obj)] = weakref(obj)
 for owner: Dictionary in lab.contact.owners.values():
  for mat: Material in owner.materials.values(): watched[str(mat)] = weakref(mat)
 return watched

func verify_stairs() -> void:
 for mode in [lab.AO.NATIVE, lab.AO.COARSE]:
  lab.set_ao(mode)
  var original := await image()
  var intensity: float = lab.environment.ssao_intensity
  lab.native_gain_control.value = 100.0
  check(is_equal_approx(lab.environment.ssao_intensity, 100.0 * intensity), "100× native SSAO intensity " + NAMES[mode])
  check(original.get_data() != (await image()).get_data(), "100× contact visible under full Retro " + NAMES[mode])
  lab.native_gain_control.value = 1.0
  check(original.get_data() == (await image()).get_data(), "1× restores the reference " + NAMES[mode])
 for m in [lab.AO.CLEAN8,lab.AO.CLEAN5,lab.AO.CLEAN4,lab.AO.CLEAN3,lab.AO.CLEAN2]:
  lab.set_ao(m)
  var clean := await image()
  lab.anchor = 0
  lab.matrix = 2
  lab.cell = 0.15
  lab.transition = 0.10
  lab.apply_treatment()
  check(clean.get_data() == (await image()).get_data(), "Clean response independent of all pattern settings " + NAMES[m])
  lab.anchor = 2
  lab.matrix = 4
  lab.cell = 0.045
  lab.transition = 0.55
 lab.set_ao(8)
 check(not lab.environment.ssao_enabled and lab.game.presentation.camera.compositor == lab.prior_compositor,"Authored mode needs no screen-space AO")
 lab.set_ao(0)

func ordered_study() -> void:
 for item in [[2,0.025,0.35],[2,0.075,0.55],[4,0.045,0.55],[4,0.10,0.80]]:
  lab.matrix = item[0]
  lab.cell = item[1]
  lab.transition = item[2]
  lab.set_ao(lab.AO.ORDERED)
  await shot("ordered-%d-%03d" % [lab.matrix,roundi(lab.cell*1000)])
 lab.matrix = 4
 lab.cell = 0.045
 lab.transition = 0.55
 lab.set_ao(0)

func scale_study() -> void:
 for percent in [85,100]:
  lab.set_scale_percent(percent)
  for m in [0,1,2,3,4,7,8,9]:
   var before := Time.get_ticks_usec()
   lab.set_ao(m)
   var elapsed := (Time.get_ticks_usec()-before)/1000.0
   var warm := await bench(24,false)
   await shot("scale-%d-%s" % [percent,NAMES[m]])
   var settled := await bench(120,true)
   lab.camera(lab.start_focus)
   var size := Vector2i.ZERO
   if m in [3,4,7,9] and lab.depth.depth:
    size = lab.depth.depth.get_size()
    check(size.x > 0,"Resolved foreground depth at %d%%" % percent)
   rows.append({"runtime":"Scale","mode":NAMES[m],"scale":percent,"activation_ms":elapsed,"warm24":warm.frame,
    "pan":settled.frame,"depth_size":[size.x,size.y],"view_size":str(lab.game.view.size)})
  lab.set_ao(0)
 lab.set_scale_percent(85)

func motion_strip(label: String) -> void:
 var zoom: float = lab.game.presentation.camera_settings.zoom
 var slider: Node3D = lab.game.active.visual.get_node_or_null("ContactStudy/Slider")
 var poses := [0,1,2,3,4,8,7,7,7]
 for index in poses.size():
  lab.anchor = maxi(0,index - 6) if index >= 6 else 2
  lab.game.presentation.camera_settings.zoom = zoom
  lab.camera(lab.start_focus)
  if slider: slider.position.x = 1.10
  lab.spin(0.0)
  lab.set_ao(poses[index])
  await frames(5)
  var last: Image
  for tick in 24:
   var t := tick / 23.0
   lab.game.presentation.camera_settings.zoom = zoom * (1.0 + t * 0.20)
   lab.camera(lab.start_focus + Vector2(48*t*t,-18*t))
   if slider: slider.position.x = lerpf(1.10,-0.95,t)
   lab.spin(t * PI)
   await lab.get_tree().process_frame
   await RenderingServer.frame_post_draw
   last = lab.get_window().get_texture().get_image()
   var img := last.get_region(Rect2i(200,110,900,630))
   img.resize(540,378,Image.INTERPOLATE_LANCZOS)
   check(img.save_png(out.path_join("motion-%s-%d-%02d.png" % [label,index,tick])) == OK, "Motion frame %s/%d/%d" % [label,index,tick])
  var held := await image()
  rows.append({"runtime":"Disocclusion","fixture_name":label,"mode":NAMES[poses[index]],
   "anchor":lab.anchor,"first_matches_held":last.get_data()==held.get_data()})
  check(lab.full_retro_active(),"Motion strip kept full Retro %s/%d" % [label,index])
 lab.anchor = 2
 if slider: slider.position.x = 1.10
 lab.game.presentation.camera_settings.zoom = zoom
 lab.camera(lab.start_focus)
 lab.set_ao(0)

func lighting_control(label: String) -> void:
 var e: Environment = lab.environment
 var saved := [e.ambient_light_energy,e.ambient_light_sky_contribution,e.ambient_light_source,e.reflected_light_source]
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_energy = 0.0
 e.ambient_light_sky_contribution = 0.0
 e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
 lab.set_ao(0)
 var off := await shot(label + "-direct-off")
 for m in [1,4,8]:
  lab.set_ao(m)
  var sample := await shot(label + "-direct-" + NAMES[m])
  rows.append({"runtime":"Direct light","fixture_name":label,"mode":NAMES[m],"exact":sample.get_data()==off.get_data()})
  check(e.ssao_light_affect == 0.0, label + " zero direct-light affect")
 lab.set_ao(0)
 e.ambient_light_energy = saved[0]
 e.ambient_light_sky_contribution = saved[1]
 e.ambient_light_source = saved[2]
 e.reflected_light_source = saved[3]

func transparency_control() -> void:
 lab.set_ao(lab.AO.AUTHORED)
 var opaque_ids := {}
 for owner: Dictionary in lab.contact.owners.values():
  for slot: Array in owner.slots: opaque_ids[slot[0].get_ref().get_instance_id()] = true
 var inspected := 0
 var treated := 0
 for entry: Dictionary in Audit.viewports(lab.game):
  if entry.role in ["output","composite","warmup"]: continue
  for node: GeometryInstance3D in entry.node.find_children("*","GeometryInstance3D",true,false):
   var mesh := Audit.mesh_of(node)
   if not mesh: continue
   for index in mesh.get_surface_count():
    var mat: Material = node.material_override
    if mat == null and node is MeshInstance3D: mat = node.get_active_material(index)
    if mat == null: mat = mesh.surface_get_material(index)
    if Audit.material_state(mat).transparent:
     inspected += 1
     if opaque_ids.has(node.get_instance_id()): treated += 1
 check(inspected > 0 and treated == 0, "Aquarium alpha slots %d, treated %d" % [inspected,treated])
 lab.set_ao(0)

func shadow_pairs(label: String) -> void:
 for item in [[0,0],[0,8],[5,8],[2,8]]:
  lab.set_mode(item[0])
  lab.set_ao(item[1])
  await shot("pair-%s-%d-%d" % [label,item[0],item[1]])
  var sample := await bench(120,false)
  sample.merge({"runtime":"Shadow pair","fixture_name":label,
   "shadow_mode":lab.MODES[item[0]],"mode":NAMES[item[1]]})
  rows.append(sample)
 lab.set_mode(0)
 lab.set_ao(0)

func tube_study() -> void:
 for m in [0,1,2,3,4,7,8]:
  lab.set_ao(m)
  await shot("tube-"+NAMES[m])
 await shadow_pairs("tube")
 set_fixture_treatment()
 lab.set_motion(2)
 for i in 4: await lab.get_tree().physics_frame
 lab.set_motion(0)
 var position: Vector2 = lab.game.ball.position
 await frames(5)
 check(lab.get_tree().paused and position == lab.game.ball.position,"Pause holds the real Workshop ball before resume")

func set_fixture_treatment() -> void:
 lab.set_mode(0)
 lab.set_ao(lab.AO.AUTHORED)

func crossing_modes() -> Array:
 return [0,1,4,8]

func set_crossing_mode(m: int) -> void:
 lab.set_mode(0)
 lab.set_ao(m)

func crossing_extras() -> Dictionary:
 var extra := {"ao":NAMES[lab.treatment],"ao_inventory":lab.contact.inventory()}
 if not lab.contact.active: return extra
 var g: Node = lab.game
 var old_ids: Array = lab.contact.owners.keys()
 var next: RefCounted
 for act: RefCounted in g.resident:
  if act.ready and act.plan.sequence >= 3: next = act
 if not next: check(false,"Ready Act available for retirement"); return extra
 g._activate(next)
 g.presentation.camera_focus = next.bounds().position
 g._retire_behind()
 lab.contact.sync(g,true)
 var removed := old_ids.filter(func(id): return not lab.contact.owners.has(id)).size()
 check(removed > 0,"Released retired Act AO owners, " + NAMES[lab.treatment])
 extra["retired_owners"] = removed
 return extra
