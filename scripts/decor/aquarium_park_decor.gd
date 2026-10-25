extends "res://scripts/decor/decor_skin.gd"
## Original low-poly aquatic architecture. Every node is presentation only.
var meshes: Dictionary = {}
var materials: Dictionary = {}

func _init(_presentation: Node3D) -> void:
 skin_id = "aquarium_park"
 var sizes := {
  "small": ["paper_lantern", "lotus_bowl", "coral_planter"],
  "medium": ["lantern_trio", "koi_display", "tide_basin", "wave_screen"],
  "large": ["waterside_pavilion", "reef_aquarium", "moon_gate"],
  "landmark": ["lantern_palace", "moon_bridge", "jellyfish_rotunda"],
 }
 for size: String in sizes:
  pools[size] = {}
  for hint: String in ["surface", "edge", "either"]: pools[size][hint] = sizes[size].duplicate()
 factory = build_variant
 var colors := {"stone":"304955", "deep":"152d41", "wood":"793237", "roof":"163c4e", "gold":"aa8352", "paper":"bc7d3d", "cyan":"40cbd0", "coral":"c777ac", "plant":"3b9695", "fish":"8ad8dc", "ivory":"d6d8c7"}
 for key: String in colors:
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(colors[key])
  mat.roughness = 0.58
  if key in ["gold", "roof"]: mat.metallic = 0.35
  if key in ["paper", "cyan", "fish", "coral"]:
   mat.emission_enabled = true
   mat.emission = Color(colors[key])
   mat.emission_energy_multiplier = 0.90 if key == "paper" else 0.35
   if key == "paper": mat.emission = Color("ff8b36")
  materials[key] = mat
 var roof_material := StandardMaterial3D.new()
 roof_material.vertex_color_use_as_albedo = true
 roof_material.roughness = 0.48
 roof_material.metallic = 0.2
 materials.roof_tiles = roof_material
 for key: String in ["water", "glass"]:
  var mat := ShaderMaterial.new()
  mat.shader = load("res://scripts/themes/aquarium_%s.gdshader" % key)
  materials[key] = mat

func primitive(kind: String) -> Mesh:
 if meshes.has(kind): return meshes[kind]
 var result: Mesh
 match kind:
  "box": result = BoxMesh.new()
  "roof": result = _roof_mesh()
  "shell": result = _shell_mesh()
  "orb":
   var sphere := SphereMesh.new()
   sphere.radius = 1.0
   sphere.height = 2.0
   sphere.radial_segments = 12
   sphere.rings = 6
   result = sphere
  "ring":
   var torus := TorusMesh.new()
   torus.inner_radius = 0.93
   torus.outer_radius = 1.0
   torus.rings = 24
   torus.ring_segments = 6
   result = torus
  _:
   var cylinder := CylinderMesh.new()
   cylinder.top_radius = 0.0 if kind == "cone" else 1.0
   cylinder.bottom_radius = 1.0
   cylinder.height = 1.0
   cylinder.radial_segments = 12
   cylinder.rings = 1
   result = cylinder
 meshes[kind] = result
 return result

func _roof_mesh() -> ArrayMesh:
 # Four hipped faces with a dipped edge and a raised outer lip.
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in 4:
  var turn := Basis(Vector3.UP,side*PI*0.5)
  for step in 24:
   var a := float(step)/24.0
   var b := float(step+1)/24.0
   var ya := 0.65*pow(1.0-a,1.8)+0.15*pow(a,8.0)
   var yb := 0.65*pow(1.0-b,1.8)+0.15*pow(b,8.0)
   var points := [Vector3(-a,ya,a),Vector3(a,ya,a),Vector3(b,yb,b),Vector3(-b,yb,b)]
   surface.set_color(Color("aa8352") if step == 23 else Color("163c4e"))
   for index: int in [0,1,2,0,2,3]: surface.add_vertex(turn*points[index])
 surface.generate_normals()
 return surface.commit()

func _shell_mesh() -> ArrayMesh:
 # Open cylinder: a single front shell keeps fish visible without stacked panes.
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 32:
  var a := TAU*i/32.0
  var b := TAU*(i+1)/32.0
  var points := [Vector3(cos(a),-0.5,sin(a)),Vector3(cos(a),0.5,sin(a)),Vector3(cos(b),0.5,sin(b)),Vector3(cos(b),-0.5,sin(b))]
  for index: int in [0,2,1,0,3,2]:
   surface.set_normal(Vector3(points[index].x,0,points[index].z))
   surface.add_vertex(points[index])
 return surface.commit()

func piece(root: Node3D, kind: String, color: String, at: Vector3, size: Vector3) -> MeshInstance3D:
 var mesh := MeshInstance3D.new()
 mesh.mesh = primitive(kind)
 mesh.material_override = materials[color]
 mesh.position = at
 mesh.scale = size
 if color in ["glass", "water", "paper", "fish"]: mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(mesh)
 return mesh

func box(root: Node3D, color: String, at: Vector3, size: Vector3) -> MeshInstance3D:
 return piece(root,"box",color,at,size)

func bar(root: Node3D, color: String, a: Vector3, b: Vector3, width: float) -> void:
 var part := box(root,color,(a+b)*0.5,Vector3(width,a.distance_to(b),width))
 part.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func roof(root: Node3D, at: Vector3, width: float, depth: float) -> void:
 piece(root,"roof","roof_tiles",at,Vector3(width*0.51,width*0.48,depth*0.51))

func lantern(root: Node3D, at: Vector3, radius: float) -> void:
 piece(root,"orb","paper",at,Vector3(radius,radius*1.2,radius))
 for side: int in [-1,1]:
  piece(root,"pipe","gold",at+Vector3.UP*radius*side,Vector3(radius*0.65,radius*0.15,radius*0.65))
 for i in 4:
  var angle := i*PI*0.5
  bar(root,"wood",at+Vector3(cos(angle)*radius*0.91,-radius*0.7,sin(angle)*radius*0.91),at+Vector3(cos(angle)*radius*0.91,radius*0.7,sin(angle)*radius*0.91),radius*0.07)
 bar(root,"gold",at-Vector3.UP*radius*1.2,at-Vector3.UP*radius*1.8,radius*0.12)

func coral(root: Node3D, at: Vector3, height: float) -> void:
 bar(root,"plant",at,at+Vector3.UP*height,height*0.055)
 for i in 4:
  var side := -1.0 if i%2 == 0 else 1.0
  var joint := at+Vector3(0,height*(0.22+i*0.15),0)
  var tip := joint+Vector3(side*height*(0.36-i*0.05),height*0.22,0.04)
  bar(root,"coral",joint,tip,height*0.045)
  bar(root,"coral",tip,tip+Vector3.UP*height*0.16,height*0.035)

func fish(root: Node3D, at: Vector3, length: float, angle: float) -> void:
 var group := Node3D.new()
 group.name = "DecorativeFish"
 root.add_child(group)
 group.position = at
 group.rotation.y = angle
 piece(group,"orb","fish",Vector3.ZERO,Vector3(length*0.38,length*0.14,length*0.12))
 var tail := piece(group,"cone","coral",Vector3(-length*0.40,0,0),Vector3(length*0.17,length*0.24,length*0.05))
 tail.rotation.z = -PI*0.5
 piece(group,"orb","deep",Vector3(length*0.23,length*0.035,length*0.10),Vector3.ONE*length*0.025)

func tank(root: Node3D, at: Vector3, radius: float, height: float, jelly := false) -> void:
 piece(root,"pipe","stone",at+Vector3.UP*0.06,Vector3(radius*1.1,0.12,radius*1.1))
 piece(root,"pipe","deep",at+Vector3.UP*0.13,Vector3(radius,0.03,radius))
 piece(root,"shell","glass",at+Vector3.UP*(height*0.5+0.14),Vector3(radius,height,radius))
 for y: float in [0.16,height+0.14]:
  piece(root,"ring","gold",at+Vector3.UP*y,Vector3(radius,1,radius))
 for i in 4:
  var angle := PI*0.25+i*PI*0.5
  var foot := at+Vector3(cos(angle)*radius,0.14,sin(angle)*radius)
  bar(root,"wood",foot,foot+Vector3.UP*height,radius*0.045)
 piece(root,"pipe","water",at+Vector3.UP*0.17,Vector3(radius*0.96,0.015,radius*0.96))
 if jelly:
  for i in 3:
   var pos := at+Vector3((i-1)*radius*0.5,height*(0.52+(i%2)*0.22),sin(i*2.0)*radius*0.25)
   piece(root,"orb","cyan",pos,Vector3(radius*0.19,radius*0.10,radius*0.19))
   for j in 4:
    var top := pos+Vector3((j-1.5)*radius*0.08,-radius*0.02,0)
    bar(root,"fish",top,top+Vector3(sin(j)*radius*0.06,-height*0.23,0),radius*0.012)
 else:
  for i in 4: fish(root,at+Vector3(sin(i*2.2)*radius*0.5,0.25+height*(0.2+i*0.14),cos(i*2.2)*radius*0.45),radius*0.55,i*1.2)
  coral(root,at+Vector3(-radius*0.35,0.18,0),height*0.48)

func pavilion(root: Node3D, at: Vector3, width: float, height: float, depth: float) -> void:
 box(root,"stone",at+Vector3.UP*0.07,Vector3(width,0.14,depth))
 box(root,"wood",at+Vector3.UP*0.16,Vector3(width*0.94,0.05,depth*0.94))
 for x: int in [-1,1]:
  for z: int in [-1,1]:
   var foot := at+Vector3(x*width*0.35,0.18,z*depth*0.35)
   bar(root,"wood",foot,foot+Vector3.UP*height,width*0.065)
   lantern(root,foot+Vector3(0,height*0.80,0),width*0.065)
 roof(root,at+Vector3.UP*(height+0.18),width*1.12,depth*1.12)
 box(root,"wood",at+Vector3(0,height*0.84,-depth*0.35),Vector3(width*0.76,0.06,0.06))

func bridge(root: Node3D, width: float, depth: float) -> void:
 for i in 12:
  var x := (float(i)/11.0-0.5)*width*0.92
  var y := 0.18+0.43*(1.0-pow(x/(width*0.5),2.0))
  box(root,"wood",Vector3(x,y,0),Vector3(width/11.0,0.09,depth*0.72))
  for side: int in [-1,1]:
   var at := Vector3(x,y,side*depth*0.36)
   bar(root,"wood",at,at+Vector3.UP*0.33,0.035)
   if i < 11:
    var next_x := (float(i+1)/11.0-0.5)*width*0.92
    var next_y := 0.18+0.43*(1.0-pow(next_x/(width*0.5),2.0))
    bar(root,"gold",at+Vector3.UP*0.33,Vector3(next_x,next_y+0.33,side*depth*0.36),0.035)
 for side: int in [-1,1]:
  box(root,"stone",Vector3(side*width*0.42,0.10,0),Vector3(width*0.14,0.20,depth))
  lantern(root,Vector3(side*width*0.42,0.75,depth*0.38),0.095)

func build_variant(variant: String) -> Node3D:
 var root := Node3D.new()
 root.name = variant.to_pascal_case()
 match variant:
  "paper_lantern":
   box(root,"stone",Vector3(0,0.035,0),Vector3(0.24,0.07,0.24))
   bar(root,"wood",Vector3.ZERO,Vector3(0,0.42,0),0.035)
   lantern(root,Vector3(0,0.32,0),0.105)
  "lotus_bowl":
   piece(root,"pipe","stone",Vector3(0,0.04,0),Vector3(0.18,0.08,0.18))
   piece(root,"pipe","water",Vector3(0,0.085,0),Vector3(0.155,0.01,0.155))
   for i in 6:
    var a := TAU*i/6.0
    var petal := piece(root,"orb","coral",Vector3(cos(a)*0.055,0.11,sin(a)*0.055),Vector3(0.035,0.025,0.08))
    petal.rotation.y = -a+PI*0.5
   piece(root,"orb","paper",Vector3(0,0.13,0),Vector3.ONE*0.028)
  "coral_planter":
   box(root,"stone",Vector3(0,0.035,0),Vector3(0.30,0.07,0.23))
   coral(root,Vector3(-0.05,0.07,0),0.35)
   coral(root,Vector3(0.08,0.07,0.03),0.22)
  "lantern_trio":
   box(root,"stone",Vector3(0,0.04,0),Vector3(0.50,0.08,0.32))
   for i in 3:
    var at := Vector3((i-1)*0.18,0.0,0)
    var h := 0.52+(i%2)*0.18
    bar(root,"wood",at,at+Vector3.UP*h,0.025)
    lantern(root,at+Vector3.UP*(h-0.09),0.09)
  "koi_display":
   box(root,"stone",Vector3(0,0.05,0),Vector3(0.66,0.10,0.40))
   box(root,"glass",Vector3(0,0.34,0),Vector3(0.59,0.47,0.34))
   for side: int in [-1,1]:
    for back: int in [-1,1]:
     bar(root,"wood",Vector3(side*0.30,0.1,back*0.17),Vector3(side*0.30,0.59,back*0.17),0.025)
   box(root,"gold",Vector3(0,0.59,0),Vector3(0.64,0.035,0.39))
   fish(root,Vector3(-0.11,0.29,0.03),0.25,0)
   fish(root,Vector3(0.12,0.43,-0.03),0.21,PI)
  "tide_basin":
   box(root,"stone",Vector3(0,0.09,0),Vector3(0.65,0.18,0.46))
   box(root,"water",Vector3(0,0.185,0),Vector3(0.55,0.01,0.36))
   for side: int in [-1,1]:
    box(root,"wood",Vector3(side*0.28,0.26,-0.12),Vector3(0.04,0.25,0.04))
   bar(root,"gold",Vector3(-0.28,0.37,-0.12),Vector3(0.28,0.37,-0.12),0.035)
   lantern(root,Vector3(0,0.33,-0.12),0.065)
  "wave_screen":
   box(root,"stone",Vector3(0,0.035,0),Vector3(0.70,0.07,0.25))
   box(root,"deep",Vector3(0,0.31,0),Vector3(0.60,0.49,0.06))
   for i in 9:
    var x := (i-4)*0.064
    box(root,"cyan",Vector3(x,0.27+sin(i*0.6)*0.08,0.035),Vector3(0.032,0.11,0.008))
   roof(root,Vector3(0,0.53,0),0.72,0.29)
  "waterside_pavilion": pavilion(root,Vector3.ZERO,0.87,0.75,0.72)
  "reef_aquarium": tank(root,Vector3.ZERO,0.42,1.02)
  "moon_gate":
   box(root,"stone",Vector3(0,0.07,0),Vector3(0.94,0.14,0.48))
   var ring := piece(root,"ring","wood",Vector3(0,0.61,0),Vector3(0.45,0.9,0.45))
   ring.rotation.x = PI*0.5
   roof(root,Vector3(0,1.04,0),1.05,0.46)
   for side: int in [-1,1]: lantern(root,Vector3(side*0.37,0.83,0.1),0.07)
  "lantern_palace":
   pavilion(root,Vector3.ZERO,2.66,0.82,0.87)
   pavilion(root,Vector3(0,1.05,0),1.75,0.67,0.76)
   box(root,"deep",Vector3(0,0.53,-0.23),Vector3(2.05,0.64,0.12))
   for i in 7: box(root,"paper",Vector3((i-3)*0.26,0.56,-0.15),Vector3(0.13,0.30,0.025))
  "moon_bridge": bridge(root,2.90,0.90)
  "jellyfish_rotunda":
   tank(root,Vector3.ZERO,0.76,1.05,true)
   roof(root,Vector3(0,1.21,0),1.55,1.55)
 return root
