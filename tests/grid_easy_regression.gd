extends "res://tests/grid_chunk_regression.gd"
## Rounded Easy routes and reviewed v11 layouts include side and upper recovery.
## Only the two added lower-funnel segments differ from these modes' v10 fingerprints.
const V11_MODE_GEOMETRY := {
 "0/1/8": "f8eb3b5e4d77539e5e9035f31f2c6ef307929a343053633beadaafa2ea16f286",
 "0/1/23": "f3c50b323665e6af8573810f078fb9787c6f63e7f99d1d6f7e147a0a9c35efba",
 "1/1/8": "0220dc8919dfbc9f998c7ec72c6f6946a58ea4820ad4cfca13b12b27744b1a9b",
 "1/2/8": "23ebc622d220b9edd95cd67be9dc7fa0d01c92cd6a8fb990241ceba1d3ce3d9a",
 "2/1/8": "8c2c75379ec69752eb6bb3b546584b88fce1d23188d5a6bcacda587f20aa962a",
 "2/2/8": "cdc4e79e39bd11274d79086a0de4469ee9d486f28343d8db89b0ee848befc63d",
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
 for key: String in V11_MODE_GEOMETRY:
  var parts := key.split("/")
  preserved = preserved and geometry_hash(host._generate_layout(int(parts[2]), int(parts[1]), int(parts[0]))) == V11_MODE_GEOMETRY[key]
 for key: String in V11_GEOMETRY:
  var parts := key.split("/")
  preserved = preserved and geometry_hash(host._generate_layout(int(parts[1]), int(parts[0]), 0)) == V11_GEOMETRY[key]
 check(preserved, "Existing catalogue and grid Normal/Hard reproduce reviewed v11 drain geometry and paddle fingerprints")
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
