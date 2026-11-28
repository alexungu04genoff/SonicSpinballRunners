extends RefCounted
## Art direction for Big props at one authored cell per model unit.
## These proportions apply only to placed decor. Themes also use some of the
## source models as parts of distant scenery or composite landmarks.
const PROPORTIONS := {
 "green_hill": {
  "palm": Vector3(0.93, 1.16, 0.93), "palm_left": Vector3(0.93, 1.16, 0.93),
  "tall_rock": Vector3(1.22, 1.12, 1.32), "checker_pedestal": Vector3(1.18, 1.02, 1.12),
 },
 "casino_night": {
  "star_lantern": Vector3(1.30, 0.93, 1.30), "reel_tower": Vector3(1.22, 0.96, 1.16),
  "casino_pylon": Vector3(1.35, 1.0, 1.28),
 },
 "ice_cap": {
  "alpine_fir": Vector3(1.19, 1.12, 1.19), "icicle_grotto": Vector3(1.26, 1.14, 1.38),
  "glacier_sail": Vector3(1.10, 1.07, 1.22),
 },
 "rooftop_run": {
  "roof_pavilion": Vector3(1.24, 1.02, 1.20), "garden_arch": Vector3(1.14, 1.16, 1.32),
  "cypress_terrace": Vector3(1.22, 1.10, 1.24),
 },
 "aquarium_park": {
  "waterside_pavilion": Vector3(1.32, 1.02, 1.22), "reef_aquarium": Vector3(1.39, 1.07, 1.39),
  "moon_gate": Vector3(1.16, 1.16, 1.30),
 },
 "egg_fleet": {
  "bridge_tower": Vector3(1.10, 0.91, 1.14), "twin_engines": Vector3(0.93, 0.93, 1.25),
  "stabilizer_fins": Vector3(1.11, 0.88, 1.32),
 },
}

static func shape_model(model: Node3D, theme_id: String, variant: String) -> Node3D:
 var proportions: Vector3 = PROPORTIONS.get(theme_id, {}).get(variant, Vector3.ONE)
 if proportions == Vector3.ONE: return model
 # The outer node receives the authored yaw, mirror and scale at placement.
 var anchor := Node3D.new()
 anchor.name = model.name
 anchor.add_child(model)
 model.scale *= proportions
 return anchor
