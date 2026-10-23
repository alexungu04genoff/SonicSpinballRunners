extends "res://tests/grid_chunk_regression.gd"
## Rounded Easy routes and reviewed v10 layouts include side and upper recovery.
const V10_MODE_GEOMETRY := {
 "0/1/8": "fd803d4dff3e24b817b41318df704e7e4b1971d0b97065b52c834ed8caf5457c",
 "0/1/23": "09704fc8bda4e07547c203ad3522b867f09d1813f04859dd1a6403bc931ff2df",
 "1/1/8": "4205e493475a3d64b2421b6d32dc3eff84a61e986c04d5cceef566ef05e12c68",
 "1/2/8": "45116940e5b7f4060437f68eae1775a9652c259060e7906a9cd7a5c59a032b8f",
 "2/1/8": "7c44d4b0e22ae9d3fb46478de1103e939f02697e4596ddb2f8b201a7af059f8c",
 "2/2/8": "6f7364fa66730d8acaec6c2be39fb23182572c8ba35d06bbbe37bca3c7b43364",
}

func create_grid_game(mode: int) -> void:
 game = load("res://scenes/playground.tscn").instantiate()
 game.generation_seed = 8
 game.generation_difficulty = TableGenerator.Difficulty.EASY
 game.generation_grid_mode = mode
 root.add_child(game)
 await frames(4)
 game.controls.virtual_enabled = true
 game.presentation.set_process(false)
 game.ring_field.set_physics_process(false)

func run() -> void:
 var host = load("res://scripts/game.gd").new()
 var preserved := true
 for key: String in V10_MODE_GEOMETRY:
  var parts := key.split("/")
  preserved = preserved and geometry_hash(host._generate_layout(int(parts[2]), int(parts[1]), int(parts[0]))) == V10_MODE_GEOMETRY[key]
 for key: String in V10_GEOMETRY:
  var parts := key.split("/")
  preserved = preserved and geometry_hash(host._generate_layout(int(parts[1]), int(parts[0]), 0)) == V10_GEOMETRY[key]
 check(preserved, "Existing catalogue and grid Normal/Hard reproduce reviewed v10 geometry and paddle fingerprints")
 var compiled: Array[ChunkData] = []
 for recipe: GridChunkRecipe in host.GRID_EASY_RECIPES:
  var result := GridChunkCompiler.compile(recipe)
  check(result.valid, "Easy recipe compiles with connected walls and full paddle clearance: " + recipe.recipe_id, str(result.errors))
  if not result.valid:
   host.free()
   quit(1)
   return
  compiled.append(result.chunk)
 var deterministic := true
 var easy := true
 var broad := true
 var signatures: Dictionary = {}
 for mode in [1, 2]:
  var tops: Dictionary = {}
  for seed_value in range(1, 13):
   var first: Dictionary = host._generate_layout(seed_value, TableGenerator.Difficulty.EASY, mode)
   var repeated: Dictionary = host._generate_layout(seed_value, TableGenerator.Difficulty.EASY, mode)
   deterministic = deterministic and first.signature == repeated.signature and geometry_hash(first) == geometry_hash(repeated)
   easy = easy and first.valid and first.preference_available and not first.used_fallback and first.difficulty_estimate.band == TableGenerator.Difficulty.EASY and TableGenerator.validate_course(first.chunks).valid
   broad = broad and first.chunks[1].grid_dimensions.x == 8 and flippers_clear(first.chunks[1])
   for junction: Dictionary in first.junctions:
    # Only the existing 5px grid/legacy inset difference remains, below rail radius.
    broad = broad and junction.difficulty_estimate.largest_ledge <= 5.01 and junction.passage.size.x >= 618.0
   for rail: PackedVector2Array in first.chunks[1].rails:
    for i in range(rail.size() - 1):
     var delta := rail[i + 1] - rail[i]
     broad = broad and absf(delta.y) > 0 and absf(delta.x / delta.y) <= 0.5
   tops[first.chunks[0].chunk_id] = true
   signatures[first.signature] = true
   print("GRID EASY | ", first.signature)
  check(tops.size() == 2, "Easy retains both broad upper designs through seeded selection: mode %d" % mode)
 check(easy and deterministic, "24 grid Easy configurations repeat valid in-tier layouts without a Normal fallback")
 check(broad, "Easy has wide junctions, no large shoulders, gentle banks and clear paddle swings")
 check(compact_geometry(compiled[0]) != compact_geometry(compiled[1]) and signatures.size() >= 4, "Easy base and variant remain distinct and preserve seeded variety")
 host.free()
 await grid_runtime_checks(compiled)
 print("RESULT | Grid Easy | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
