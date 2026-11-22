extends RefCounted
## Camera-relative presentation shared by held and animated victory poses.
static func basis(view: Basis, progress: float) -> Basis:
 var phase := smoothstep(1.0 / 6.0, 5.0 / 6.0, progress)
 return view.orthonormalized() * Basis(Vector3.UP, lerpf(-PI / 6.0, PI / 6.0, phase))
