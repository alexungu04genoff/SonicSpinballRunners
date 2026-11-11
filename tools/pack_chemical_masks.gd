extends SceneTree
## Losslessly repack the selected source masks; never regenerate approved artwork.
## Run headlessly after updating source masks. -- --check verifies without writing.
const Maps = preload("res://scripts/themes/chemical_material_maps.gd")
const CHANNELS := ["roughness", "ao", "metallic"]

func _initialize() -> void:
 var verify := "--check" in OS.get_cmdline_user_args()
 var failures := 0
 for id: String in Maps.STRENGTH:
  var masks: Array[PackedByteArray] = []
  var size := Vector2i.ZERO
  for channel: String in CHANNELS:
   var image := Image.load_from_file(ProjectSettings.globalize_path(Maps.ROOT + id + "_" + channel + ".png"))
   if image == null or image.is_empty() or (size != Vector2i.ZERO and image.get_size() != size):
    push_error("Missing or mismatched Chemical Plant mask: " + id + "_" + channel)
    quit(1)
    return
   size = image.get_size()
   image.convert(Image.FORMAT_RGBA8)
   masks.append(image.get_data())
  var pixels := PackedByteArray()
  pixels.resize(size.x * size.y * 3)
  for pixel in size.x * size.y:
   for channel in 3: pixels[pixel * 3 + channel] = masks[channel][pixel * 4]
  var path := Maps.ROOT + id + "_response.png"
  var packed := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGB8, pixels)
  if verify:
   var saved := Image.load_from_file(ProjectSettings.globalize_path(path))
   if saved == null or saved.is_empty():
    failures += 1
   else:
    saved.convert(Image.FORMAT_RGB8)
    if saved.get_size() != size or saved.get_data() != pixels: failures += 1
  elif packed.save_png(path) != OK:
   failures += 1
  print("CHEMICAL_MASK | ", id, " | ", size, " | ", "checked" if verify else "packed")
 print("CHEMICAL_MASK_PACK | ", Maps.STRENGTH.size(), " maps | failures=", failures)
 quit(1 if failures else 0)
