# Retro shader attribution

Only the files below are vendored. The project-owned adapter, UI and preset tuning live in `scripts/retro/` and `data/retro_settings.tres`. No code is downloaded or translated at runtime.

Trailing whitespace was normalized in the three imported shader files. The adaptations below describe code changes.

## Dither and color precision

- Author: Lucas Rodrigues / Witty Cognomen.
- Repository: https://github.com/WittyCognomen/godot-psx-shaders
- Pinned commit: `5bcd9bbac5470bb1bf01256f863c162d8a265a14`.
- License: MIT, preserved verbatim in [psx/LICENSE.txt](psx/LICENSE.txt).
- Original shader: [`shaders/psx_dither_post.shader`](https://github.com/WittyCognomen/godot-psx-shaders/blob/5bcd9bbac5470bb1bf01256f863c162d8a265a14/shaders/psx_dither_post.shader).
- Original matrix texture: [`shaders/dithers/psxdither.png`](https://github.com/WittyCognomen/godot-psx-shaders/blob/5bcd9bbac5470bb1bf01256f863c162d8a265a14/shaders/dithers/psxdither.png), unchanged.
- Local shader: `psx/dither.gdshader`. Adaptations: Godot 4 extension and sampler hints; the source sampler reads the containing world viewport's screen texture; explicitly unshaded. The original quantization and dither expressions are unchanged.

PIXEL and N64-ish use this same licensed implementation. N64-ish is an aesthetic approximation with different color precision and linear output filtering; it is not an N64 RDP/VI emulator.

## CRT and VHS

- Author: Marcel Jovic (punikonta).
- Repository: https://github.com/punikonta/godot-shader-crt-vhs
- Pinned commit: `6ba87f95c152ec023fc07c4f77e87bdd70783afa`.
- License: MIT, preserved verbatim in [crt_vhs/LICENSE.md](crt_vhs/LICENSE.md).
- Original shaders: [`shaders/crt.gdshader`](https://github.com/punikonta/godot-shader-crt-vhs/blob/6ba87f95c152ec023fc07c4f77e87bdd70783afa/shaders/crt.gdshader) and [`shaders/vhs.gdshader`](https://github.com/punikonta/godot-shader-crt-vhs/blob/6ba87f95c152ec023fc07c4f77e87bdd70783afa/shaders/vhs.gdshader).
- `crt_vhs/vhs.gdshader`: unchanged code with attribution header added. Restrained settings come from our adapter/resource.
- `crt_vhs/crt.gdshader`: attribution header plus the scanline uniforms and scanline block from the same upstream VHS file. This gives CRT its own scanlines without another pass. Other shader code is unchanged.

## Candidates reviewed, not vendored

- [Libretro Shaders for Godot](https://github.com/m0ty/godot-libretro-shaders), version 1.0.0, examined at commit `2be06c78080f51e00748d8f4b558d904a79b36e2`: MIT wrapper, compatible with our engine/Compatibility renderer. Its `set_source_region` API can frame the existing world area, with UI above its CanvasLayer. External shader licenses remain independent. The importer, translator, multipass/history infrastructure and source-region synchronization are unnecessary for this five-preset experiment. Direct materials keep removal and input-to-display latency simpler. This does not rule out a future Libretro preset browser; none is included here.
- [GodotRetro](https://github.com/ahopness/GodotRetro), examined at `3507243e6f99e702773da1da4ff42d4cddfcad7e`: the dither and VHS ports declare CC0 but point to Shadertoy originals whose licenses could not be independently retrieved during this audit. Skipped conservatively. Its CRT Basic points to MIT KinoTube, but the direct Godot 4 CRT/VHS pair above provides both effects with one documented provenance.
- [Leo Peltola / Riley Evans perspective outline/highlight shader](https://godotshaders.com/shader/3d-pixel-art-outline-highlight-shader-perspective-camera/): explicitly MIT. It depends on the normal/roughness texture, unavailable in the project's Compatibility renderer. Optional edge treatment is omitted; no renderer change or substitute outline system was introduced.

Retrieved and reviewed on 2026-10-25. Upstream repository-wide licenses above cover the selected files; no demos, models, audio or other assets are included.
