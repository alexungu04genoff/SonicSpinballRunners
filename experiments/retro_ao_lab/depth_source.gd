extends CompositorEffect
## Forward+ resolves MSAA depth to an R32F storage image. Keep a private copy
## so a material never holds a viewport texture invalidated by a resize.
signal depth_ready
const COPY := """#version 450
layout(local_size_x=8, local_size_y=8) in;
layout(set=0,binding=0,r32f) readonly uniform image2D src;
layout(set=0,binding=1,r32f) writeonly uniform image2D dst;
void main() {
 ivec2 p=ivec2(gl_GlobalInvocationID.xy);
 if (all(lessThan(p,imageSize(dst)))) { imageStore(dst,p,imageLoad(src,p)); }
}"""
var depth: Texture2DRD
var shader := RID()
var pipeline := RID()
var current := RID()
var current_size := Vector2i.ZERO
var targets := {} # Owned by the render thread until the material is rebound.

func _init() -> void:
 effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_OPAQUE
 access_resolved_depth = true

func _render_callback(_type: int, data: RenderData) -> void:
 var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
 if not buffers or buffers.get_msaa_3d() == RenderingServer.VIEWPORT_MSAA_DISABLED: return
 var rd := RenderingServer.get_rendering_device()
 var src := buffers.get_depth_layer(0)
 if not rd.texture_is_valid(src): return
 if not pipeline.is_valid():
  var source := RDShaderSource.new()
  source.source_compute = COPY
  shader = rd.shader_create_from_spirv(rd.shader_compile_spirv_from_source(source))
  pipeline = rd.compute_pipeline_create(shader)
 var size := buffers.get_internal_size()
 if current_size != size:
  var format := RDTextureFormat.new()
  format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
  format.width = size.x
  format.height = size.y
  format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
  var target := rd.texture_create(format,RDTextureView.new())
  if not target.is_valid(): return
  targets[target] = true
  publish.call_deferred(target, current)
  current = target
  current_size = size
 var dst := current
 var bindings: Array[RDUniform] = []
 for texture: RID in [src,dst]:
  var uniform := RDUniform.new()
  uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
  uniform.binding = bindings.size()
  uniform.add_id(texture)
  bindings.append(uniform)
 var set_rid := UniformSetCacheRD.get_cache(shader,0,bindings)
 var list := rd.compute_list_begin()
 rd.compute_list_bind_compute_pipeline(list,pipeline)
 rd.compute_list_bind_uniform_set(list,set_rid,0)
 rd.compute_list_dispatch(list,ceili(size.x/8.0),ceili(size.y/8.0),1)
 rd.compute_list_end()

func publish(texture: RID, previous: RID) -> void:
 if not enabled: return
 depth = Texture2DRD.new()
 depth.texture_rd_rid = texture
 depth_ready.emit()
 if previous.is_valid(): RenderingServer.call_on_render_thread(retire.bind(previous))

func retire(texture: RID) -> void:
 if targets.erase(texture): RenderingServer.get_rendering_device().free_rid(texture)

func release() -> void:
 enabled = false
 depth = null
 RenderingServer.call_on_render_thread(dispose)

func dispose() -> void:
 var rd := RenderingServer.get_rendering_device()
 if not rd: return
 for texture: RID in targets: rd.free_rid(texture)
 targets.clear()
 if shader.is_valid(): rd.free_rid(shader)
