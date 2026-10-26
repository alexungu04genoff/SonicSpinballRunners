extends RefCounted
## Offline-only deduplication. Procedural ImageTextures otherwise get embedded
## again in every Act/theme file; imported textures already share external paths.
const DIRECTORY := "res://data/endless/assets.bake"
const VisualDetail = preload("res://scripts/endless/visual_detail.gd")
var visited := {}
var error := ""
var materials: Dictionary = {}

func share(value: Variant) -> Variant:
 if value is Array:
  for i in value.size(): value[i] = share(value[i])
 elif value is Dictionary:
  for key: Variant in value: value[key] = share(value[key])
 elif value is Resource:
  var resource: Resource = value
  var id := resource.get_instance_id()
  if resource is Material: materials[id] = resource
  if visited.has(id): return visited[id]
  visited[id] = resource
  if not resource.resource_path.is_empty() and not resource.resource_path.contains("::"): return resource
  if resource is ImageTexture:
   var image: Image = resource.get_image()
   var digest := HashingContext.new()
   digest.start(HashingContext.HASH_SHA256)
   digest.update(var_to_bytes([image.get_width(), image.get_height(), image.get_format(), image.has_mipmaps()]))
   digest.update(image.get_data())
   var path := DIRECTORY.path_join(digest.finish().hex_encode() + ".res")
   DirAccess.make_dir_recursive_absolute(DIRECTORY)
   # Image.load_from_file can retain the PNG's resource path. Embed pixels in
   # the bank file so it does not refer to an editor-only Image import.
   var pixels := Image.create_from_data(image.get_width(), image.get_height(), image.has_mipmaps(), image.get_format(), image.get_data())
   if not FileAccess.file_exists(path):
    var result := ResourceSaver.save(ImageTexture.create_from_image(pixels), path, ResourceSaver.FLAG_COMPRESS)
    if result != OK:
     error = "Could not save shared bake texture: " + error_string(result)
     return resource
   # Return the same canonical resource, rather than assigning one path to two
   # objects (take_over_path would clear the previous object's external path).
   var canonical: Resource = load(path)
   if not canonical is ImageTexture:
    error = "Invalid shared bake texture: " + path
    return resource
   if not canonical.get_image().resource_path.is_empty():
    canonical.set_image(pixels)
    var result := ResourceSaver.save(canonical, path, ResourceSaver.FLAG_COMPRESS)
    if result != OK: error = "Could not update shared bake texture: " + error_string(result)
   visited[id] = canonical
   return canonical
  elif resource is PrimitiveMesh:
   var arrays: Array = VisualDetail.primitive(resource).get_mesh_arrays()
   var mesh := ArrayMesh.new()
   mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
   mesh.custom_aabb = resource.custom_aabb
   mesh.surface_set_material(0, share(resource.material))
   if resource.material == null:
    var digest := HashingContext.new()
    digest.start(HashingContext.HASH_SHA256)
    digest.update(var_to_bytes([arrays, resource.custom_aabb]))
    var path := DIRECTORY.path_join("mesh_" + digest.finish().hex_encode() + ".res")
    DirAccess.make_dir_recursive_absolute(DIRECTORY)
    if not FileAccess.file_exists(path):
     var result := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
     if result != OK: error = "Could not save shared bake mesh: " + error_string(result)
    mesh = load(path)
   visited[id] = mesh
   return mesh
  elif resource is PackedScene:
   # Recipes contain one node per PackedScene. Repack that node with canonical
   # texture references; SceneState itself does not expose property setters.
   var node: Node = resource.instantiate()
   for property: Dictionary in node.get_property_list():
    if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script": _share_property(node, property.name)
   resource.pack(node)
   node.free()
  else:
   for property: Dictionary in resource.get_property_list():
    if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script": _share_property(resource, property.name)
 return value

func _share_property(object: Object, property: String) -> void:
 var previous: Variant = object.get(property)
 if previous is Resource:
  var replacement: Variant = share(previous)
  if replacement != previous: object.set(property, replacement)
 elif previous is Array or previous is Dictionary:
  var before: Variant = previous.duplicate(true)
  var replacement: Variant = share(previous)
  if replacement != before: object.set(property, replacement)
