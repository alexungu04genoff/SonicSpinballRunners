extends RefCounted
## Editor-only tuning in construction cells. Never rescales authored coordinates.
const ROUND_RADIUS_CELLS := 0.25
const SLING_HEIGHT_CELLS := 0.60
const FLIPPER_LENGTH_CELLS := 0.65 # Pivot-to-tip centerline; caps give 0.75 overall.
const FLIPPER_RADIUS_CELLS := 0.05
const RING_RADIUS_CELLS := 0.09 # 0.18-cell collectible diameter.
const RING_HANDLE_RADIUS_CELLS := 0.06

const SPAWN_RADIUS_CELLS := 0.12
const PIVOT_RADIUS_CELLS := 0.045
const CROSSHAIR_RADIUS_CELLS := 0.08
const ARROW_LENGTH_CELLS := 0.18
const ARROW_HEAD_CELLS := 0.08
const CONNECTOR_HANDLE_CELLS := 0.08
const OUTLINE_PIXELS := 1.5
const SELECTED_OUTLINE_PIXELS := 3.0
const LABEL_GAP_PIXELS := 6.0

static func marker_unit(cell_pixels: float) -> float:
 # Small annotations remain legible when zoomed out and unobtrusive when zoomed in.
 # Object silhouettes themselves always use the exact cell-relative dimensions.
 return clampf(cell_pixels, 16.0, 64.0)
