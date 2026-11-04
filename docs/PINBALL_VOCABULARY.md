# Pinball vocabulary study

## Directional Slingshot

Gameplay palette: Slingshot. Local up is the launch direction; rotate to aim. Bright rubber and an arrow mark the active face. Width: 24-200 pixels. Strength: fixed outgoing speed, 100-1600 pixels/second (default 650). Only incoming contact on the straight front face powers a launch. Back and rounded ends rebound passively through the authoritative 2D swept-contact system. Collisionless presentation uses the mechanism hardware palette.

Slingshots award no points and use the existing Spring combo extension once per source per chain. Triangle Bumper behavior is unchanged.

Focused check: `Godot.exe --headless --path . --script res://tests/pinball_vocabulary_regression.gd`.
