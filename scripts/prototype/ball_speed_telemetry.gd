extends RefCounted
## Fixed-memory 10 Hz samples of ordinary table motion; no RNG or retained trace.
const INTERVAL := 0.1
const BIN_WIDTH := 20.0
const BIN_COUNT := 512
var _bins := PackedInt64Array()
var _elapsed := 0.0
var _count := 0
var _sum := 0.0
var _maximum := 0.0
var _overflow := 0

func _init() -> void: reset()

func reset() -> void:
 _bins.resize(BIN_COUNT + 1)
 _bins.fill(0)
 _elapsed = 0.0
 _count = 0
 _sum = 0.0
 _maximum = 0.0
 _overflow = 0

func observe(delta: float, speed: float, eligible: bool) -> void:
 if not eligible or not is_finite(speed) or speed < 0.0:
  _elapsed = 0.0
  return
 if not is_finite(delta) or delta <= 0.0: return
 _elapsed += delta
 if _elapsed + 0.0000001 < INTERVAL: return
 # At most one observation per physics callback; never fabricate catch-up samples.
 _elapsed = fmod(_elapsed, INTERVAL) if _elapsed >= INTERVAL else 0.0
 var bucket := BIN_COUNT if speed >= BIN_COUNT * BIN_WIDTH else floori(speed / BIN_WIDTH)
 _bins[bucket] += 1
 _count += 1
 _sum += speed
 _maximum = maxf(_maximum, speed)
 if bucket == BIN_COUNT: _overflow += 1

func _percentile(fraction: float) -> Variant:
 if _count == 0: return null
 var rank := ceili(_count * fraction)
 var cumulative := 0
 for i in _bins.size():
  cumulative += _bins[i]
  if cumulative >= rank: return i * BIN_WIDTH
 return null

func snapshot() -> Dictionary:
 return {"samples": _count, "average": _sum / _count if _count > 0 else null,
  "median": _percentile(0.5), "p95": _percentile(0.95), "max": _maximum if _count > 0 else null,
  "sample_interval_seconds": INTERVAL, "percentile_bin_width": BIN_WIDTH,
  "overflow_samples": _overflow, "overflow_speed": BIN_COUNT * BIN_WIDTH}
