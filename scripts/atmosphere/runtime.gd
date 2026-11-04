extends RefCounted
## One owner per resident Zone; no mutation of cached recipes or source materials.
const Fields := preload("res://scripts/atmosphere/fields.gd")
const Options := preload("res://scripts/rendering_options.gd")
const Bindings := preload("res://scripts/atmosphere/material_bindings.gd")
var bindings := Bindings.new()
var values := {}
var lighting := {}
const LIGHT_FIELDS := ["light_color", "light_energy", "light_specular", "light_angular_distance", "shadow_opacity", "shadow_bias", "shadow_normal_bias", "directional_shadow_max_distance", "shadow_enabled"]
var environment: Environment
var sun: DirectionalLight3D

func configure(theme: String, variant: Dictionary, original: Environment, light: DirectionalLight3D) -> void:
 values = Fields.appearance_values(variant.get("values", {}))
 sun = light
 environment = original.duplicate()
 if original.sky != null:
  environment.sky = original.sky.duplicate()
  environment.sky.sky_material = original.sky.sky_material.duplicate()
 bindings.begin_theme(theme)
 preload("res://scripts/atmosphere/fields.gd").apply_shadow_defaults(sun)
 apply_properties(values, environment, sun)
 for property: String in LIGHT_FIELDS: lighting[property] = sun.get(property)
 lighting["quaternion"] = sun.quaternion

func attach(root: Node, include_sky := false, scenery := false) -> void:
 bindings.append_root(root, environment.sky.sky_material if include_sky and environment.sky != null else null, scenery)
 bindings.apply(float(values.get("emission", 1.0)))
 bindings.apply_palette(values, sun, values.has("sun_pitch") or values.has("sun_yaw"))

static func apply_properties(source: Dictionary, target: Environment, light: DirectionalLight3D) -> void:
 for key: String in source:
  if key == Fields.LEGACY_SHADOW_MODE: continue
  if key.begins_with("env/"): target.set(key.trim_prefix("env/"), source[key])
  elif key.begins_with("sun/"): light.set(key.trim_prefix("sun/"), source[key])
  elif key == "sun_pitch": light.rotation_degrees.x = source[key]
  elif key == "sun_yaw": light.rotation_degrees.y = source[key]
  elif key.begins_with("sky/") and target.sky != null and target.sky.sky_material is ProceduralSkyMaterial:
   target.sky.sky_material.set(key.trim_prefix("sky/"), source[key])
 Options.register_light(light)
