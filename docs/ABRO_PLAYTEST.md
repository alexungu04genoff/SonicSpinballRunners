# Sonic Spinball Runners — ABro playtest

Extract the ZIP into a folder, then open **Sonic Spinball Runners.exe**.
No Godot installation, repository, launcher or administrator access is required.
Use a Windows x64 PC with a Vulkan-capable graphics driver.

The first launch is preset to **Sonic**, **Practice** (unlimited retries),
**Scoring sounds off**, and **3 Zones / 9 Acts**.

The selected theme pool is **Green Hill, Chemical Plant, Casino Night and Rooftop Run**.
Each run shuffles three of those four themes, with three Acts in each Zone.
Start another run to get a different course. Theme and Act selections remain editable.

All five production Acts are included and selected: **First Try Smooth Decor,
RampMania, Reverse C Spring, Secret Entry and SpringUp**. Acts can repeat between
Zones, but each Zone uses three different Acts. Current artwork, scenery settings
and production atmospheres are embedded in the executable.

Earn an Act's score target, touch its gold Goal Ring, then choose a Buddy to advance.
Practice preserves unlimited retries; scoring and goals still work normally.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Flippers | Q / E | LB / RB |
| Steer | Left / right arrows | Left stick |
| Launch | X | X |
| Character special | Space | A |
| Retry checkpoint | R | Back / View |
| Pause / resume | Enter / Escape | Menu / Start |
| Fullscreen | F11 | — |

Allow the first loading screen to finish: graphics drivers may compile shaders.
Later runs can load faster. The package contains offline bakes; it does not need
to generate level geometry during play.

Preferences and local run feedback are stored separately from other builds in
`%APPDATA%\Godot\app_userdata\Sonic Spinball Runners ABro`.
Results provide **Run feel**, **Copy run data** and **Open telemetry folder**.
Nothing is uploaded automatically. You may change settings in the menu; later
launches remember those choices. **Reset run setup** restores the game's standard
two-Zone setup, not this playtest's initial three-Zone preset.
