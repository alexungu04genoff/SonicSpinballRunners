extends Resource
## Session-only presentation tuning. Divisors keep the current world aspect ratio.
## At the normal 1280x690 world area, divisor 2 renders 640x345 (HUD is separate).

@export_group("Pixel / Dither")
@export_range(1, 4, 0.1) var pixel_resolution_divisor := 2.0
@export_range(1, 256, 1) var pixel_color_levels := 32.0
@export_range(0, 1, 0.05) var pixel_dither_strength := 0.65

@export_group("N64-ish")
@export_range(1, 4, 0.1) var n64_resolution_divisor := 2.0
@export_range(1, 256, 1) var n64_color_levels := 24.0
@export_range(0, 1, 0.05) var n64_dither_strength := 0.9

@export_group("CRT")
@export_range(1, 64, 0.1) var crt_cell_size := 6.0
@export_range(0, 1, 0.01) var crt_scanlines := 0.22
@export_range(0, 1, 0.01) var crt_mask := 0.13
@export_range(0, 1, 0.01) var crt_vignette := 0.08
@export_range(0, 1, 0.01) var crt_glow := 0.38
@export_range(0, 8, 0.1) var crt_glow_radius := 4.0
@export_range(-1, 1, 0.005) var crt_brightness := 0.025
## Curvature is deliberately absent: the imported CRT uses an undistorted image.

@export_group("VHS")
@export_range(0, 10, 0.05) var vhs_chroma_offset := 0.45
@export_range(0, 10, 0.05) var vhs_chroma_bleed := 1.1
@export_range(0, 0.1, 0.00005) var vhs_wobble := 0.0003
@export_range(0, 1, 0.001) var vhs_grain := 0.012
@export_range(0, 1, 0.0001) var vhs_tracking := 0.0005
