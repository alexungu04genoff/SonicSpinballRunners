# Current Lava Reef material review

Alex approved the exaggerated normal-only result and completing every material phase. Floor 1C and timber/insets 5B now use normal strength 6.0; all other roles retain 0.85. Geometric relief is no longer generated. Parallax stays off. Albedo pixels, authored contours, authoritative 2D collision, atmosphere and camera are unchanged.

`depth-on.png` captures the canonical defaults in the real disk-loaded Prototype: RampMania, Forward+/Vulkan, production Retro, hidden HUD. `depth-off.png` changes only material detail, with the same frozen game and camera state. `comparison.png` arranges these actual-game frames.

`receipt.json` verifies 26 source textures, 26 bound materials, floor strength 6.0, zero bound geometry-relief materials, unchanged albedo hashes, both control signals, and all five Prototype plus seven Endless bakes. Runtime rebuilding remained zero. The Visual Lab scene loaded successfully. F8 exposes Material detail and Normal strength; multiplier 1.0 restores the approved strength for each material.

Reproduce with graphical Godot: `res://experiments/lava_texture_refined/canonical/review.gd -- --retro=production --final`, after supported Lava Reef Prototype and Endless baking. The script rejects stale recipes, geometric relief, incorrect defaults and a missing production Retro flag.

`approved-prototype-final.log`, `approved-endless.log` and `approved-review.log` describe final verification. Earlier captures and logs document superseded geometry trials. `normal-diagnostic-comparison.png` records the comparison Alex selected. The certificate-store startup error remains nonblocking. No full regression suite or benchmark was run; movement and feel remain the user's play-review task.

Alex explicitly authorized committing and pushing all current project changes, including work from the other theme chats.
