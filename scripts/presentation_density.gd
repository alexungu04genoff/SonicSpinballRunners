extends RefCounted
## Collisionless geometry vocabulary. Explicit families prevent small props from
## inheriting hardware density. Terrain contours and bake safety caps are separate.
enum Family { TINY, ORDINARY, HARDWARE, HERO }
const SIDES := [6, 8, 16, 24]
const LATITUDES := [2, 3, 7, 7]
const RING_SIDES := 12
const RING_TUBE_SIDES := 6

static func sphere(radius: float, family := Family.ORDINARY) -> SphereMesh:
 var mesh := SphereMesh.new()
 mesh.radius = radius
 mesh.height = radius * 2.0
 mesh.radial_segments = SIDES[family]
 mesh.rings = LATITUDES[family]
 return mesh

static func cylinder(radius: float, height: float, family := Family.ORDINARY) -> CylinderMesh:
 var mesh := CylinderMesh.new()
 mesh.top_radius = radius
 mesh.bottom_radius = radius
 mesh.height = height
 mesh.radial_segments = SIDES[family]
 mesh.rings = 1
 return mesh
