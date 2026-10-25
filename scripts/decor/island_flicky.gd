extends Node3D
## Decorative animation only: local time, no physics, RNG, timers or gameplay state.
const CYCLE := 4.8
var animation_time := 0.0
var phase := 0.0
var pose := Node3D.new()
var head := Node3D.new()
var wings: Array[Node3D] = []

func _init(p: Node3D, index: int) -> void:
 name = "Flicky%d" % (index + 1)
 # The main game's UI ancestor processes while paused; decor must not inherit it.
 process_mode = Node.PROCESS_MODE_PAUSABLE
 phase = index * CYCLE / 3.0
 add_child(pose)
 pose.name = "Pose"
 var blue: Material = p.material(Color("279ee9"))
 var wing_blue: Material = p.material(Color("2175c9"))
 var white: Material = p.material(Color("fff5dc"))
 var black: Material = p.material(Color("182b44"))
 var yellow: Material = p.material(Color("ffc637"))
 var orange: Material = p.material(Color("ee9227"))
 _ellipsoid(p, pose, Vector3(0, .125, 0), Vector3(.15, .18, .14), blue)
 _ellipsoid(p, pose, Vector3(0, .12, .052), Vector3(.105, .125, .055), white)
 pose.add_child(head)
 head.position = Vector3(0, .225, .025)
 _ellipsoid(p, head, Vector3.ZERO, Vector3(.18, .16, .16), blue)
 for side: int in [-1, 1]:
  _ellipsoid(p, head, Vector3(side * .037, .012, .066), Vector3(.066, .085, .036), white)
  _ellipsoid(p, head, Vector3(side * .036, .013, .083), Vector3(.029, .046, .018), black)
  _ellipsoid(p, head, Vector3(side * .036 - .006, .025, .092), Vector3(.01, .014, .008), white)
  _ellipsoid(p, pose, Vector3(side * .041, .018, .035), Vector3(.048, .036, .09), orange)
  var hinge := Node3D.new()
  hinge.position = Vector3(side * .066, .155, 0)
  pose.add_child(hinge)
  wings.append(hinge)
  _ellipsoid(p, hinge, Vector3(side * .026, -.04, 0), Vector3(.045, .115, .085), wing_blue)
 var beak: CylinderMesh = p.cylinder(.035, .08)
 beak.top_radius = 0
 beak.radial_segments = 6
 var beak_node: MeshInstance3D = p.mesh_node(beak, yellow, Vector3(0, -.022, .105), head)
 beak_node.rotation.x = PI / 2.0
 for i in 2:
  var feather := _ellipsoid(p, head, Vector3((i - .5) * .035, .082, -.025), Vector3(.035, .085 - i * .015, .04), blue)
  feather.rotation.x = -.4
 var tail := _ellipsoid(p, pose, Vector3(0, .11, -.09), Vector3(.075, .04, .13), wing_blue)
 tail.rotation.x = -.35
 set_animation_time(0)

func _ellipsoid(p: Node3D, parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
 var mesh := SphereMesh.new()
 mesh.radius = .5
 mesh.height = 1.0
 mesh.radial_segments = 8
 mesh.rings = 4
 var visual: MeshInstance3D = p.mesh_node(mesh, material, at, parent)
 visual.scale = size
 return visual

func _process(delta: float) -> void:
 set_animation_time(animation_time + delta)

func set_animation_time(seconds: float) -> void:
 # A bounded, repeatable cycle also allows deterministic gallery captures.
 animation_time = fposmod(seconds, CYCLE)
 var t := fposmod(animation_time + phase, CYCLE)
 var hop := 0.0
 if t < .48:
  hop = sin(PI * t / .48)
 elif t >= .72 and t < 1.20:
  hop = sin(PI * (t - .72) / .48)
 pose.position.y = hop * .105
 pose.rotation.z = sin(TAU * t / CYCLE) * .035
 head.rotation.y = sin(TAU * t / CYCLE) * .28
 var flutter := hop * (.65 + .3 * sin(t * TAU * 7.0))
 for i in wings.size():
  wings[i].rotation.z = (1 if i == 0 else -1) * (.12 + flutter)
