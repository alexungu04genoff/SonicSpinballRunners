extends "../retro_shadow_lab/lab.gd"
const Contact = preload("receivers.gd")
const Depth = preload("depth_source.gd")
enum AO { OFF, NATIVE, COARSE, CLEAN8, CLEAN4, CLEAN3, CLEAN2, ORDERED, AUTHORED, CONTINUOUS }
const LABELS := ["AO off", "Native subtle", "Coarse SSAO", "Clean 8", "Clean 4", "Clean 3", "Clean 2", "Ordered 4", "Authored faces", "Continuous contact"]
const BANDS := [0, 0, 0, 8, 4, 3, 2, 4, 0, 0]
const ENV_FIELDS := ["ssao_enabled", "ssao_radius", "ssao_intensity", "ssao_power", "ssao_detail", "ssao_horizon", "ssao_sharpness", "ssao_light_affect", "ssao_ao_channel_affect"]
var contact := Contact.new()
var depth: CompositorEffect
var compositor: Compositor
var prior_compositor: Compositor
var environment: Environment
var original := {}
var treatment := AO.OFF
var strength := 0.62
var radius := 0.42
var anchor := 2
var matrix := 4
var cell := 0.045
var transition := 0.55
var ao_choice: OptionButton
var scale_choice: OptionButton
var dither_controls: HBoxContainer

func _ready() -> void:
 output = "user://retro-ao-lab"
 if "--stairs" in OS.get_cmdline_user_args(): study_card = true
 super()

func build_ui() -> void:
 add_child(layer)
 layer.layer = 120
 var frame := PanelContainer.new()
 layer.add_child(frame)
 frame.add_child(panel)
 var box := row()
 ao_choice = choice(box, LABELS, treatment, set_ao)
 mode_choice = choice(box, ["Native shadows", "Clean 8 shadows", "Clean 4 shadows"], 0, func(i): set_mode([0,5,2][i]))
 choice(box, ["Profile A", "Profile B", "Profile C"], profile, set_profile)
 scale_choice = choice(box, ["75% scale", "85% scale", "100% scale"], 1, func(i): set_scale_percent([75,85,100][i]))
 box = row()
 theme_choice = choice(box, Fixture.Registry.NAMES, Fixture.Registry.IDS.find(theme), func(i): theme = Fixture.Registry.IDS[i]; open_game())
 choice(box, ["First Try", "RampMania", "Side to Side", "Launch Tube", "Stair study", "Endless tour"], 4 if study_card else 0, select_fixture)
 camera_choice = choice(box, ["Dramatic", "Wide", "Real", "Top-down"], 0, func(i): if game: game.select_play_camera(game.PLAY_CAMERAS[i]); camera(start_focus))
 focus_choice = choice(box, ["Serve", "Ring row", "Raised edge", "Act center"], 0, set_focus)
 choice(box, ["Hold pose", "Pan + spin", "Play Act / tour"], 0, set_motion)
 box = row()
 number(box,"AO strength",0.0,1.0,0.02,strength,func(v): strength = v; apply_treatment())
 number(box,"Radius",0.06,1.5,0.02,radius,func(v): radius = v; apply_treatment())
 zoom = number(box,"Zoom",0.6,2.5,0.05,1.3,func(v): if game: game.presentation.camera_settings.zoom = v; camera(start_focus))
 blur = number(box,"Shadow blur",0.5,2.0,0.05,1.0,func(v): if game: game.presentation._key_light.shadow_blur = v)
 angle = number(box,"Sun °",0,5,0.05,0.0,func(v): if game: game.presentation._key_light.light_angular_distance = v)
 dither_controls = row()
 var pattern_label := Label.new()
 pattern_label.text = "Saturn/Dreamcast-inspired pattern"
 dither_controls.add_child(pattern_label)
 choice(dither_controls, ["Screen", "Object", "World"], anchor, func(i): anchor = i; apply_treatment())
 choice(dither_controls, ["Bayer 2×2", "Bayer 4×4"], 1, func(i): matrix = [2,4][i]; apply_treatment())
 number(dither_controls,"Cell",0.015,0.20,0.005,cell,func(v): cell = v; apply_treatment())
 number(dither_controls,"Transition",0,1,0.05,transition,func(v): transition = v; apply_treatment())
 dither_controls.hide()
 panel.add_child(status)

func place_study() -> void:
 preload("stairs.gd").place(game)
 game.presentation.camera_settings.zoom = 0.65

func open_game() -> bool:
 if not await super(): return false
 environment = game.presentation._world_environment.environment
 for property: String in ENV_FIELDS: original[property] = environment.get(property)
 prior_compositor = game.presentation.camera.compositor
 depth = Depth.new()
 depth.depth_ready.connect(update_depth)
 compositor = Compositor.new()
 if prior_compositor: compositor.compositor_effects = prior_compositor.compositor_effects.duplicate()
 var effects := compositor.compositor_effects.duplicate()
 effects.append(depth)
 compositor.compositor_effects = effects
 apply_treatment()
 return true

func set_profile(index: int) -> void:
 super(index)
 scale_choice.select([75,85,100].find(Review.Options.quality().scale_percent))

func set_scale_percent(value: int) -> void:
 Review.Options.update_quality({"scale_percent": value}, false)
 scale_choice.select([75,85,100].find(value))
 refresh()

func set_mode(index: int) -> void:
 # The shadow overlay must specialize the original material even when AO
 # is already active. Both treatments then share the original opaque pass.
 if game: contact.sync(game,false)
 super(index)
 if environment and game: contact.sync(game, treatment >= AO.CLEAN8)

func set_ao(value: int) -> void:
 treatment = value
 ao_choice.select(value)
 dither_controls.visible = value == AO.ORDERED
 apply_treatment()

func quality(native: bool, coarse: bool) -> void:
 var prefix := "rendering/environment/ssao/"
 RenderingServer.environment_set_ssao_quality(
  RenderingServer.ENV_SSAO_QUALITY_LOW if coarse else (RenderingServer.ENV_SSAO_QUALITY_MEDIUM if native else ProjectSettings.get_setting(prefix+"quality")),
  coarse if (native or coarse) else ProjectSettings.get_setting(prefix+"half_size"),
  ProjectSettings.get_setting(prefix+"adaptive_target"), 1 if coarse else (2 if native else ProjectSettings.get_setting(prefix+"blur_passes")),
  ProjectSettings.get_setting(prefix+"fadeout_from"), ProjectSettings.get_setting(prefix+"fadeout_to"))

func apply_treatment() -> void:
 if not environment or not game: return
 var native := treatment == AO.NATIVE
 var coarse := treatment == AO.COARSE
 quality(native, coarse)
 for property: String in original: environment.set(property, original[property])
 if native or coarse:
  environment.ssao_radius = radius
  environment.ssao_intensity = 1.55 * strength
  environment.ssao_power = 1.08
  environment.ssao_detail = 0.08
  environment.ssao_horizon = 0.09
  environment.ssao_sharpness = 0.88
  environment.ssao_light_affect = 0.0
  environment.ssao_ao_channel_affect = 0.0
  environment.ssao_enabled = true
 var custom := treatment >= AO.CLEAN8
 var reads_depth := custom and treatment != AO.AUTHORED
 game.presentation.camera.compositor = compositor if reads_depth else prior_compositor
 contact.apply({"contact_depth": depth.depth if reads_depth else null, "contact_radius": radius,
  "contact_strength": strength, "contact_levels": BANDS[treatment], "face_study": treatment == AO.AUTHORED,
  "contact_ordered": treatment == AO.ORDERED, "contact_anchor": anchor, "contact_matrix": matrix,
  "contact_cell": cell, "contact_transition": transition})
 contact.sync(game, custom)
 refresh()

func update_depth() -> void:
 if treatment >= AO.CLEAN8 and treatment != AO.AUTHORED and depth:
  contact.settings.contact_depth = depth.depth
  contact.apply(contact.settings)

func _process(delta: float) -> void:
 super(delta)
 if not busy and game and environment: contact.sync(game, treatment >= AO.CLEAN8)

func refresh() -> void:
 if not game or not game.started: return
 status.text = "%s   ·   Full Retro   ·   %s   ·   %d%%   ·   F1 controls" % [str(game.active.plan.theme).capitalize(), LABELS[treatment], Review.Options.quality().scale_percent]

func release() -> void:
 contact.clear()
 if environment and is_instance_valid(game):
  game.presentation.camera.compositor = prior_compositor
  for property: String in original: environment.set(property, original[property])
  quality(false,false)
 original.clear()
 if depth: depth.release()
 environment = null
 compositor = null
 prior_compositor = null
 depth = null
 await super()
