extends RefCounted
## Additional limb phrasing for the local study rig, sampled once when it loads.
const READY := "Launch Ready"
const LIMBS := ["UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Thigh_L", "Thigh_R", "Calf_L", "Calf_R", "Spine1", "Head", "HairBack1", "HairSideA1_L", "HairSideA1_R", "SkirtBack2"]

# Keep each brief milestone readable while the shared camera-relative turn plays.
const TRICKS := {
 "Victory Reach": {"UpperArm_L": Vector3(-18, 0, 26), "ForeArm_L": Vector3(-7, 0, 13), "Spine1": Vector3(-5, 9, 0)},
 "Victory Guard": {"UpperArm_R": Vector3(-26, -15, -16), "ForeArm_R": Vector3(-32, 0, -22), "Spine1": Vector3(8, -12, 0)},
 "Victory Kick": {"Thigh_L": Vector3(24, 0, 19), "Calf_L": Vector3(-10, 0, 8), "UpperArm_R": Vector3(0, 0, -18)},
}

static func prepare(player: AnimationPlayer, skeleton: Skeleton3D) -> void:
 var ready: Animation = player.get_animation("Hover").duplicate()
 player.get_animation_library("").add_animation(READY, ready)
 for clip: String in player.get_animation_list():
  var anim := player.get_animation(clip)
  for track in anim.get_track_count():
   var bone := str(anim.track_get_path(track).get_concatenated_subnames())
   var index := skeleton.find_bone(bone)
   if index < 0: continue
   if clip == READY and (bone in ["Root", "Hips", "Pelvis"] or bone.begins_with("Thigh") or bone.begins_with("Calf") or bone.begins_with("Foot") or bone.begins_with("Toe")):
    var rest := skeleton.get_bone_rest(index)
    for k in anim.track_get_key_count(track):
     if anim.track_get_type(track) == Animation.TYPE_ROTATION_3D: anim.track_set_key_value(track, k, rest.basis.get_rotation_quaternion())
     elif anim.track_get_type(track) == Animation.TYPE_POSITION_3D: anim.track_set_key_value(track, k, rest.origin)
   elif anim.track_get_type(track) == Animation.TYPE_ROTATION_3D and bone in LIMBS:
    var axes := skeleton.get_bone_global_rest(index).basis.orthonormalized()
    if clip in TRICKS:
     if TRICKS[clip].has(bone):
      var turn := local_rotation(axes, TRICKS[clip][bone])
      for key in anim.track_get_key_count(track):
       var base: Quaternion = anim.track_get_key_value(track, key)
       anim.track_set_key_value(track, key, (base * turn).normalized())
    else:
     animate_track(anim, track, bone, axes, clip)

static func local_rotation(axes: Basis, degrees: Vector3) -> Quaternion:
 return (axes.inverse() * Basis.from_euler(degrees * PI / 180.0) * axes).get_rotation_quaternion()

static func animate_track(anim: Animation, track: int, bone: String, rest_frame: Basis, clip: String) -> void:
 var steps := maxi(2, ceili(anim.length * 30.0))
 var keys: Array[Quaternion] = []
 for i in steps + 1:
  var phase := float(i) / steps
  var degrees := offset(clip, bone, phase)
  var local := local_rotation(rest_frame, degrees)
  keys.append((anim.rotation_track_interpolate(track, phase * anim.length) * local).normalized())
 for i in range(anim.track_get_key_count(track) - 1, -1, -1): anim.track_remove_key(track, i)
 for i in keys.size(): anim.rotation_track_insert_key(track, anim.length * i / steps, keys[i])

static func offset(clip: String, bone: String, phase: float) -> Vector3:
 var side := -1.0 if bone.ends_with("_R") else 1.0
 var wave := sin(TAU * phase)
 var follow := sin(TAU * (phase - 0.12))
 var accent := 1.0
 if clip == READY or clip == "Hover": accent = 0.32
 elif clip == "Boost Hover": accent = 0.60
 elif clip == "Ring Dash": accent = 0.82
 var swing := wave * side * accent
 var lag := follow * side * accent
 if bone.begins_with("UpperArm"): return Vector3(22.0 * swing, 0, 13.0 * wave * accent * side)
 if bone.begins_with("ForeArm"): return Vector3(16.0 * lag, 0, 6.0 * lag)
 if bone.begins_with("Thigh"): return Vector3(-15.0 * swing, 0, 4.0 * swing)
 if bone.begins_with("Calf"): return Vector3(12.0 * lag, 0, 0)
 if bone == "Spine1": return Vector3(3.0 * wave, 6.0 * wave, 2.0 * follow) * accent
 if bone == "Head": return Vector3(-2.0 * follow, -4.0 * wave, -2.0 * wave) * accent
 return Vector3(7.0 * follow, 0, 4.0 * lag) * accent
