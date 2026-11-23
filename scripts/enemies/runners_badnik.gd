extends RefCounted
## Original Runners rigs are local assets. All patrol and contact state stays in 2D.
const Assets = preload("res://experiments/visual_lab/runners_sonic_assets.gd")
const STYLES := {
 "beeton": {"prefix": "bee", "move": "move", "scale": 0.40},
 "ganigani": {"prefix": "gan", "move": "move", "scale": 0.28},
 "eggpawn": {"prefix": "epn", "move": "run", "scale": 0.31},
}
const BLEND_SECONDS := 0.22
static var scenes := {}

static func bind(entry: Dictionary) -> bool:
 var id: String = entry.item.skin
 var style: Dictionary = STYLES[id]
 if not scenes.has(id):
  var source := Assets.animated_scene(id)
  if source == null: return false
  var player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
  if not player:
   source.free()
   return false
  for verb: String in ["idle", style.move]:
   for side: String in ["_loop", "_r_loop"]:
    var name: String = style.prefix + "_" + verb + side
    if not player.has_animation(name):
     source.free()
     return false
    player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
  if id == "beeton":
   # Runners' right idle bakes a 135-degree stage turn into the Reference node.
   # Both idles now share our camera-facing pivot while the joints keep their motion.
   var idle := player.get_animation("bee_idle_r_loop")
   var track := idle.find_track(^"enm_beeton/Reference", Animation.TYPE_ROTATION_3D)
   if track >= 0:
    for key in idle.track_get_key_count(track): idle.track_set_key_value(track, key, Quaternion.IDENTITY)
  var packed := PackedScene.new()
  var result := packed.pack(source)
  source.free()
  if result != OK: return false
  scenes[id] = packed
 var rig: Node3D = scenes[id].instantiate()
 rig.name = "Runners" + id.capitalize()
 rig.scale = Vector3.ONE * float(style.scale)
 entry.body.add_child(rig)
 var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 entry.player = player
 return true

static func advance(entry: Dictionary, moving: bool, delta: float) -> void:
 var style: Dictionary = STYLES[entry.item.skin]
 var verb: String = style.move if moving else "idle"
 var side := "_r_loop" if entry.item.direction > 0.0 else "_loop"
 var clip: String = style.prefix + "_" + verb + side
 var player: AnimationPlayer = entry.player
 if player.current_animation != clip: player.play(clip, BLEND_SECONDS)
 player.advance(delta)
