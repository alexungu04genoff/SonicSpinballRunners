extends RefCounted
## Native contact shading calibrated to the Retro AO Lab's subtle reference.
const KEY := "ssao/strength"
const RADIUS_KEY := "ssao/radius"
const CONTRAST_KEY := "ssao/contrast"
const LEVELS_KEY := "ssao/levels"
const REFERENCE_POWER := 1.08
const DEFAULT_GAIN := 8.0
const MAX_GAIN := 100.0
const REFERENCE_STRENGTH := 0.62
const REFERENCE_RADIUS := 0.42
const MIN_RADIUS := 0.06
const MAX_RADIUS := 1.5
const INTENSITY_SCALE := 1.55

static func apply(environment: Environment, gain: float, radius := REFERENCE_RADIUS, power := REFERENCE_POWER, strength := REFERENCE_STRENGTH) -> void:
 if gain <= 0.0 or RenderingServer.get_current_rendering_method() != "forward_plus":
  if environment.ssao_enabled: environment.ssao_enabled = false
  return
 if not environment.ssao_enabled:
  environment.ssao_detail = 0.08
  environment.ssao_horizon = 0.09
  environment.ssao_sharpness = 0.88
  environment.ssao_light_affect = 0.0
  environment.ssao_ao_channel_affect = 0.0
 environment.ssao_radius = radius
 environment.ssao_power = power
 environment.ssao_intensity = INTENSITY_SCALE * strength * gain
 if not environment.ssao_enabled: environment.ssao_enabled = true
