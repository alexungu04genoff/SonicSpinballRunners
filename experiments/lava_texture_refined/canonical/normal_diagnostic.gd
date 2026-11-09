extends SceneTree
## Same-frame diagnostic in the real disk-loaded Prototype, with no source edits.
const Fixture=preload("res://tests/prototype_appearance_fixture.gd")
const Materials=preload("res://scripts/themes/lava_selected_materials.gd")
const OUTPUT:="res://experiments/lava_texture_refined/canonical/"
func _initialize() -> void:
 Engine.time_scale=0.0
 call_deferred("run")
func settled() -> void:
 for frame in 12:await process_frame
 await RenderingServer.frame_post_draw
func run() -> void:
 root.size=Vector2i(1440,1000)
 root.gui_disable_input=true
 preload("res://scripts/rendering_options.gd").settings_path=OUTPUT+"isolated-graphics.cfg"
 var fixture:=Fixture.new()
 if not await fixture.open(self,"res://data/acts/Authored/RampMania.tres","lava_reef",OUTPUT):
  push_error(fixture.error)
  await fixture.close()
  quit(1)
  return
 fixture.game.hud.hide()
 assert(fixture.receipt.retro_mode=="production")
 var materials:=Materials.bound_materials(fixture.game)
 var state:=fixture.state()
 var geometry: bool=OS.get_cmdline_user_args().has("--geometry-study")
 var variants: Array=[{"name":"normal-only","normal":0.85,"depth":0.0},{"name":"normal-extreme","normal":6.0,"depth":0.0}]
 if geometry:variants=[{"name":"normal-only","normal":0.85,"depth":0.0},{"name":"geometry-shallow","normal":0.85,"depth":0.32}]
 for variant: Dictionary in variants:
  for material: ShaderMaterial in materials:
   # Only the floor family changes; all surrounding materials stay canonical.
   if not material.get_meta("lava_floor",false):continue
   material.set_shader_parameter("geometry_strength",variant.depth)
   material.set_shader_parameter("relief_strength",0.0 if material.get_meta("lava_visual_relief",false) else variant.normal)
  await settled()
  assert(fixture.state()==state)
  assert(root.get_texture().get_image().save_png(OUTPUT+variant.name+".png")==OK)
 assert(fixture.still_current() and fixture.authority_error().is_empty())
 var receipt:=fixture.receipt.duplicate(true)
 receipt["variants"]=variants
 receipt["state"]=state
 receipt["geometry_disabled_for_normal_diagnostic"]=not geometry
 var file:=FileAccess.open(OUTPUT+("geometry-study.json" if geometry else "normal-diagnostic.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "))
 file.close()
 Materials.set_detail(fixture.game,true)
 print("LAVA_DIAGNOSTIC | ",variants," | same camera and state | zero source edits")
 await fixture.close()
 quit()
