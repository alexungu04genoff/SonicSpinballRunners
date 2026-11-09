extends SceneTree
## Read-only receipt for the five Lava Reef Prototype variants after authoring.
const Bake=preload("res://scripts/endless/geometry_bake.gd")
const Plan=preload("res://scripts/prototype/run_plan.gd")
const Document=preload("res://scripts/act_editor/act_geometry.gd")
func _initialize() -> void:
 var fingerprint:=Bake.pipeline_hash("lava_reef")
 var shared: Resource=load(Bake.theme_path("lava_reef"))
 var report: Dictionary={"current_pipeline":fingerprint,"theme_pipeline":shared.pipeline_fingerprint,"acts":[]}
 for path: String in Plan.source_paths():
  var source: Dictionary=Document.load_document(path)
  var baked: Resource=load(Bake.path_for(path,"lava_reef"))
  report.acts.append({"path":path,"pipeline":baked.pipeline_fingerprint,"current":baked.matches(source.document,"lava_reef",fingerprint)})
 var file:=FileAccess.open("res://experiments/lava_texture_refined/phase3/freshness.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 file.close()
 print("LAVA_FRESHNESS | ",JSON.stringify(report))
 quit()
