# Bumper and flipper presentation

The shared renderer uses collisionless layered models inspired by Sonic's Spring Yard and Casino Night pinball hardware: star medallions, contrasting rubber rims, inset triangle plates, metallic trim, pivot bearings and bright flipper chevrons. These are original procedural meshes and materials; no external art assets are required.

`scripts/pinball_models.gd` owns the models and `PALETTES`. Each theme row supplies six colours in `SLOTS` order: `rubber`, `face`, `trim`, `mark`, `paddle`, `base`. Add a row keyed by a theme ID to style a new stage. Unknown themes receive the default palette. All instances in a playfield build share the resolved materials.

For a local override, set the presentation's exported `pinball_palette` dictionary with named Color values, such as `{"rubber": Color("d75050"), "paddle": Color("45cbad")}`, before building the playfield. Unspecified slots retain the stage palette. Rebuild the presentation after changing overrides. Existing theme switching rebuilds and resolves the stage palette automatically.

`scripts/pinball_surface.gdshader` supplies neutral, filtered moulded stipple and enamel/metal response. Colour is a shader parameter rather than baked into a texture. Stars and chevrons are raised geometry, retaining readable markings across palettes. The palette gallery can be regenerated with `--script res://tests/pinball_models_capture.gd`; it saves `test-results/pinball-models/gallery.png` with a graphical renderer.

Generated and authored playfields share the builders while retaining their existing dimensions, pivots, collision outlines, bumper flashes and flipper animation. No physics, scoring or gameplay input code changes. The editor's schematic 2D previews remain schematic. Check readability at the normal gameplay camera and with retro filters during manual playtesting.

Reference: [Sonic 2 Casino Night Zone](https://www.soniczone0.com/games/sonic2/casinonight/).
