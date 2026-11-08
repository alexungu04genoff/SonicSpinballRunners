extends CanvasLayer
## Explicit developer overlay, including portable Prototype playtests. No saves.
const Options = preload("res://scripts/rendering_options.gd")
var label: Label

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 layer = 110
 label = Label.new()
 label.position = Vector2(650, 12)
 label.add_theme_font_size_override("font_size", 16)
 label.add_theme_color_override("font_outline_color", Color.BLACK)
 label.add_theme_constant_override("outline_size", 5)
 add_child(label)
 _refresh()

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 var profile := Options.pixel_profile()
 if event.keycode == KEY_F6:
  profile.msaa = Options.PROFILE_MSAA[(Options.PROFILE_MSAA.find(profile.msaa) + 1) % Options.PROFILE_MSAA.size()]
 elif event.keycode == KEY_F7:
  profile.scale_percent = Options.PROFILE_SCALES[(Options.PROFILE_SCALES.find(profile.scale_percent) + 1) % Options.PROFILE_SCALES.size()]
 else: return
 Options.set_pixel_profile(profile.msaa, profile.scale_percent, profile.fxaa_override)
 _refresh()
 get_viewport().set_input_as_handled()

func _refresh() -> void:
 var profile := Options.pixel_profile()
 label.text = "PROFILE ONLY · F6 MSAA: %s · F7 3D: %d%%" % ["Off" if profile.msaa == 0 else str(profile.msaa) + "×", profile.scale_percent]
