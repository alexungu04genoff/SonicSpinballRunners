# Aurora reference benchmark

`miskatonic_reference.gdshader` contains the shader code (only trailing whitespace normalized) from [Aurora Borealis by miskatonicstudio](https://godotshaders.com/shader/aurora-borealis/), retrieved 2026-10-25. The page explicitly dedicates its shader code and code snippets to **CC0**. See [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). The page excludes images, videos and depicted assets from that grant; none are included here.

This file is loaded only by `tests/ice_aurora_benchmark.gd` for the requested quality/cost comparison. Production uses the original `scripts/themes/ice_aurora.gdshader`, a three-mesh curtain effect with no raymarching or sampled noise. No external shader code is copied into the production implementation. Source credit is retained here even though CC0 does not require attribution.

The author's separate GitHub repository identifies an MIT license. This benchmark uses the explicitly CC0 web publication, not an assumption about the repository license. Noise for the test is generated locally with Godot FastNoiseLite; no demo textures are downloaded.
