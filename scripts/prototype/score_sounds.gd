extends Node
## Short original synthesized cues. Presentation consumes score/state, never awards it.
var game: Node
var enabled := true
var players: Array[AudioStreamPlayer] = []
var cues: Dictionary = {}
var last_tick := -1000
var previous_unlocked := false
var previous_ball := 1
var previous_act := 0

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 for i in 4:
  var player := AudioStreamPlayer.new()
  player.volume_db = -18.0
  add_child(player)
  players.append(player)
 for entry: Array in [["ring", 880.0, 0.08], ["bumper", 220.0, 0.1], ["feature", 660.0, 0.22], ["unlock", 1046.5, 0.35], ["drain", 146.8, 0.24], ["act", 784.0, 0.3]]:
  cues[entry[0]] = _tone(float(entry[1]), float(entry[2]))
 if is_instance_valid(game.scorecraft): game.scorecraft.score_awarded.connect(_on_award)
 game.completed.connect(func(result: Dictionary): _play("unlock" if result.won else "drain"))

func _tone(frequency: float, duration: float) -> AudioStreamWAV:
 var stream := AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = 22050
 var samples := int(duration * stream.mix_rate)
 var bytes := PackedByteArray()
 bytes.resize(samples * 2)
 for i in samples:
  var time := float(i) / stream.mix_rate
  var envelope := minf(time / 0.005, 1.0) * pow(1.0 - float(i) / samples, 2.0)
  var value := (sin(TAU * frequency * time) + 0.2 * sin(TAU * frequency * 2.0 * time)) * envelope
  bytes.encode_s16(i * 2, int(value * 18000))
 stream.data = bytes
 return stream

func _play(cue: String) -> void:
 if not enabled: return
 var player: AudioStreamPlayer = players[0]
 for candidate: AudioStreamPlayer in players:
  if not candidate.playing: player = candidate; break
 player.stream = cues[cue]
 player.play()

func _on_award(details: Dictionary) -> void:
 if details.kind in ["ring_rack", "switch_bank", "spinner_goal", "lane_set"]:
  _play("feature")
 elif Time.get_ticks_msec() - last_tick > 65:
  last_tick = Time.get_ticks_msec()
  _play("ring" if details.kind == "ring" else "bumper")

func _process(_delta: float) -> void:
 if not game.started or game.closing: return
 if game.exit_unlocked and not previous_unlocked: _play("unlock")
 if game.ball_number > previous_ball: _play("drain")
 if game.active_sequence > previous_act: _play("act")
 previous_unlocked = game.exit_unlocked
 previous_ball = game.ball_number
 previous_act = game.active_sequence
