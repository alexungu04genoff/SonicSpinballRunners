extends RefCounted
## One promotion decision per theme. Diagnostic selection never writes preferences.
const IDS := ["green_hill", "chemical_plant", "rooftop_run", "casino_night", "sky_sanctuary", "ice_cap", "aquarium_park"]
const THEMES := IDS
const PRODUCTION := {"green_hill":"C", "chemical_plant":"C", "rooftop_run":"C", "casino_night":"B", "sky_sanctuary":"C", "ice_cap":"C", "aquarium_park":"C"}
const TIERS := ["NATIVE", "STATIC", "SIGNATURE", "FULL"]
const SYSTEMS := {
 "green_hill_ocean":"green_hill", "green_hill_cloud":"green_hill",
 "chemical_reservoir":"chemical_plant", "rooftop_canal":"rooftop_run",
 "sanctuary_clouds":"sky_sanctuary", "sanctuary_cloud_volume":"sky_sanctuary",
 "ice_aurora":"ice_cap", "ice_lake":"ice_cap", "ice_snow":"ice_cap",
 "aquarium_water":"aquarium_park"
}
const CONCEPTS := {
 "green_hill":["Current ocean and Flickies", "Bounded cloud travel", "Broad coastal tide"],
 "chemical_plant":["Current reservoir ripple", "Directional fluid transport", "Reservoir circulation"],
 "rooftop_run":["Current canal reflection", "Architectural clock hands", "Distant balloon drift"],
 "casino_night":["Current static theatrical scenery", "Staggered sign illumination", "Mechanical rotating signs"],
 "sky_sanctuary":["Current static clouds and ruins", "Broad cloud-bank drift", "Cloud-sea advection"],
 "ice_cap":["Current aurora, snow and frozen lake", "Current retained; no additional motion", "Current retained; no additional motion"],
 "aquarium_park":["Current animated water", "Broad water caustic travel", "Bounded tank-fish route"]
}

static func description(theme: String, candidate := "C") -> String:
 return str(CONCEPTS.get(theme, ["Excluded", "Excluded", "Excluded"])[["C", "A", "B"].find(candidate)]) if candidate in ["C", "A", "B"] else "Invalid candidate"

static func shader_id(material: Material) -> String:
 if not material is ShaderMaterial or material.shader == null: return ""
 var path: String = material.shader.get_meta("atmosphere_source_path", material.shader.resource_path)
 return str(material.get_meta("atmosphere_shader_id", path.get_file().get_basename()))

static func primary(theme: String, candidate: String, system: String) -> bool:
 match theme:
  "green_hill": return system == "green_hill_ocean"
  "chemical_plant": return system == "chemical_reservoir"
  "rooftop_run": return system == "rooftop_canal" if candidate == "C" else system == "binding"
  "casino_night": return system == "binding"
  "sky_sanctuary": return system == ("sanctuary_clouds" if candidate == "B" else "sanctuary_cloud_volume")
  "ice_cap": return system == "ice_aurora"
  "aquarium_park": return system == "binding" if candidate == "B" else system == "aquarium_water"
 return false

static func binding_error(value: Variant) -> String:
 if not value is Dictionary: return "Theme Motion binding must be a dictionary."
 if value.get("kind", "") not in ["rotate", "drift", "signal"]: return "Unknown Theme Motion binding kind."
 if value.get("candidate", "") not in ["A", "B"]: return "Theme Motion binding needs candidate A or B."
 var period: Variant = value.get("period", 0.0)
 var amplitude: Variant = value.get("amplitude", 0.0)
 var phase: Variant = value.get("phase", 0.0)
 if not (period is float or period is int) or not is_finite(float(period)) or float(period) <= 0.0: return "Theme Motion period must be finite and positive."
 if not (amplitude is float or amplitude is int) or not is_finite(float(amplitude)): return "Theme Motion amplitude must be finite."
 if not (phase is float or phase is int) or not is_finite(float(phase)): return "Theme Motion phase must be finite."
 if value.kind != "signal":
  var axis: Variant = value.get("axis")
  if not axis is Vector3 or not axis.is_finite() or axis.length_squared() < 0.000001: return "Theme Motion axis must be a finite nonzero vector."
 return ""
