extends SubViewportContainer
## Independent scenery layers crossfade behind the single gameplay viewport.
## Each keeps its original sky and lights; sky radiance is not rebuilt by a fade.
var view: SubViewport
var camera: Camera3D
var scenery: Node3D
var environment: WorldEnvironment
var light: DirectionalLight3D

func configure(game: Node, entry: Dictionary, library: Node) -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 stretch = true
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 modulate.a = 0.0
 view = SubViewport.new()
 view.size = game.view.size
 view.own_world_3d = true
 view.msaa_3d = game.view.msaa_3d
 view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 add_child(view)
 environment = WorldEnvironment.new()
 environment.environment = library.environments[entry.theme]
 view.add_child(environment)
 light = DirectionalLight3D.new()
 var style: Dictionary = library.lights[entry.theme]
 light.rotation = style.rotation
 light.light_color = style.color
 light.light_energy = style.energy
 view.add_child(light)
 camera = Camera3D.new()
 view.add_child(camera)
 camera.current = true
 scenery = Node3D.new()
 scenery.process_mode = Node.PROCESS_MODE_DISABLED
 scenery.position = TablePresentation.map_point(Vector2(entry.offset) - Vector2(0, 1200))
 view.add_child(scenery)

func follow(source: Camera3D, viewport_size: Vector2i, weight: float, warming := false) -> void:
 if view.size != viewport_size: view.size = viewport_size
 camera.transform = source.global_transform
 camera.projection = source.projection
 camera.fov = source.fov
 camera.size = source.size
 camera.near = source.near
 camera.far = source.far
 camera.keep_aspect = source.keep_aspect
 modulate.a = weight
 var running := weight > 0.0 or warming
 scenery.process_mode = Node.PROCESS_MODE_ALWAYS if running else Node.PROCESS_MODE_DISABLED
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if running else SubViewport.UPDATE_DISABLED
