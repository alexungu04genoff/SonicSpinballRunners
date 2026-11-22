extends RefCounted
## One upright revolution with adjacent entry/exit lanes. Distances are true
## 3D arc lengths in authored physics pixels. The authored anchor is the mouth.
const RADIUS := 72.0
const LEAD := 36.0
const HALF_WIDTH := 23.0
const LANE_SHIFT := 54.0
const ARC := sqrt((TAU * RADIUS) ** 2 + LANE_SHIFT ** 2)
const LENGTH := 2.0 * LEAD + ARC
const PITCH_ANGLE := atan2(LANE_SHIFT, TAU * RADIUS)
const CONE := PI / 6.0
const STEPS := 24
const POINTS := 1000
const RIDE_SECONDS := 2.0
# The flared banks start on the rising tread and end at the outside of each shoulder.
const BANK_START_ANGLE := PI / 5.0
const BANK_DEPTH := RADIUS * 0.14

static func angle_at(distance: float) -> float:
 return TAU * clampf((distance - LEAD) / ARC, 0.0, 1.0)

static func forward(item: Dictionary) -> Vector2:
 var hand := -1.0 if item.get("properties", {}).get("direction", "clockwise") == "counter-clockwise" else 1.0
 return (Vector2.UP * hand).rotated(deg_to_rad(float(item.rotation_degrees)))

static func local_frame(distance: float, clockwise: bool) -> Basis:
 var hand := 1.0 if clockwise else -1.0
 var a := angle_at(distance)
 var pitch := hand * PITCH_ANGLE
 var inward := Vector3(0, cos(a), hand * sin(a)).rotated(Vector3.UP, pitch)
 var tangent := Vector3(LANE_SHIFT / TAU, RADIUS * sin(a), -hand * RADIUS * cos(a)).rotated(Vector3.UP, pitch)
 return Basis.looking_at(tangent.normalized(), inward)

static func local_sample(distance: float, clockwise: bool) -> Vector3:
 var hand := 1.0 if clockwise else -1.0
 var tangent := Vector3.FORWARD * hand
 if distance <= LEAD: return tangent * distance
 var angle := angle_at(distance)
 # Rotate the helix so its derivative at each end exactly matches the apron.
 var arc_point := Vector3(LANE_SHIFT * angle / TAU, RADIUS * (1.0 - cos(angle)), -hand * RADIUS * sin(angle))
 return tangent * (LEAD + maxf(0.0, distance - LEAD - ARC)) + arc_point.rotated(Vector3.UP, hand * PITCH_ANGLE)

static func sample(item: Dictionary, distance: float) -> Vector3:
 var scale_value := float(item.properties.scale)
 var point := local_sample(distance / scale_value, item.properties.direction == "clockwise") * scale_value
 var xy := Vector2(item.position) + Vector2(point.x, point.z).rotated(deg_to_rad(float(item.rotation_degrees)))
 return Vector3(xy.x, point.y, xy.y)

static func distances() -> PackedFloat32Array:
 var values := PackedFloat32Array([0.0])
 for i in STEPS + 1: values.append(LEAD + ARC * i / STEPS)
 values.append(LENGTH)
 return values

static func outline(props: Dictionary) -> PackedVector2Array:
 var points := PackedVector2Array()
 for d in distances():
  var p := local_sample(d, props.direction == "clockwise")
  points.append(Vector2(p.x, p.z) * float(props.scale))
 return points

## Two ground-level footprints, in local Act pixels. The space between them
## stays open across the bore, including beneath the high section of track.
static func ground_banks(props: Dictionary) -> Array[PackedVector2Array]:
 var banks: Array[PackedVector2Array] = []
 var clockwise: bool = props.direction == "clockwise"
 for flank: float in [1.0, -1.0]:
  var corners := PackedVector2Array()
  for angle: float in [BANK_START_ANGLE, PI * 0.5]:
   var station := LEAD + ARC * (angle if flank > 0.0 else TAU - angle) / TAU
   var frame := local_frame(station, clockwise)
   var center := local_sample(station, clockwise)
   if angle > BANK_START_ANGLE: center -= frame.y * BANK_DEPTH
   for side: float in [-1.0, 1.0]:
    var edge := center + side * HALF_WIDTH * frame.x
    corners.append(Vector2(edge.x, edge.z) * float(props.scale))
  var hull := Geometry2D.convex_hull(corners)
  hull.resize(hull.size() - 1) # Godot closes the hull by repeating its first point.
  banks.append(hull)
 return banks

static func entry_fraction(start: Vector2, end: Vector2, velocity: Vector2, item: Dictionary, ball_radius: float) -> float:
 var forward := forward(item)
 var along := velocity.dot(forward)
 if along < float(item.properties.entry_speed) or along < velocity.length() * cos(CONE): return -1.0
 var a := (start - Vector2(item.position)).dot(forward)
 var b := (end - Vector2(item.position)).dot(forward)
 if a > 0.0 or b <= 0.0: return -1.0
 var t := -a / (b - a)
 var clearance := HALF_WIDTH * float(item.properties.scale) - ball_radius
 var offset := (start.lerp(end, t) - Vector2(item.position)).dot(forward.orthogonal())
 return t if absf(offset) <= clearance else -1.0
