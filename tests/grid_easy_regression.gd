extends "res://tests/grid_chunk_regression.gd"
## Grid Easy has broad authored recipes; other modes retain their v8 geometry.
const PRESERVED_V8 := {
 "0/1/8": "93c852ba719b97ab2e95789ac3e71960d5aae695aa49423f450ce48d8ceafbe1",
 "0/1/23": "057e838cd778ed62601dc82ef767dfb9f65befeeb62133fdc503586c2250c7a4",
 "1/1/8": "33dd0020af32c87b6ca4d6c074e17db27dfae7b8ad8c06afaa8c5f8900d6e3d6",
 "1/2/8": "a1bab9bf9c4c65a9a140db729ea582ec75443b65e3a41e03e5af71fba0361cd6",
 "2/1/8": "e36925014baf7a29819febcccd1fc87ecfe26bac4e5e4c13ed37a8a46d6e387f",
 "2/2/8": "b12a5827c839f24dc916623d404755299eb0a83c26bb7a69aa0e42fc5806c71a",
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
 for key: String in PRESERVED_V8:
  var parts := key.split("/")
  preserved = preserved and geometry_hash(host._generate_layout(int(parts[2]), int(parts[1]), int(parts[0]))) == PRESERVED_V8[key]
 for key: String in V6_GEOMETRY:
  var parts := key.split("/")
  preserved = preserved and geometry_hash(host._generate_layout(int(parts[1]), int(parts[0]), 0)) == V6_GEOMETRY[key]
 check(preserved, "Existing catalogue and grid Normal/Hard preserve independently captured geometry fingerprints")
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
