# Pinball vocabulary study

## Directional Slingshot

Gameplay palette: Slingshot. Local up is the launch direction; rotate to aim. Bright rubber and an arrow mark the active face. Width: 24-200 pixels. Strength: fixed outgoing speed, 100-1600 pixels/second (default 650). Only incoming contact on the straight front face powers a launch. Back and rounded ends rebound passively through the authoritative 2D swept-contact system. Collisionless presentation uses the mechanism hardware palette.

Slingshots award no points and use the existing Spring combo extension once per source per chain. Triangle Bumper behavior is unchanged.

Focused check: `Godot.exe --headless --path . --script res://tests/pinball_vocabulary_regression.gd`.

## Drop Target Bank

Choose Gameplay / Drop Target Bank, then drag the first-to-last target span. Release places one bank and one undo action. Rotation and movement affect the whole row. Inspector exposes count (2-12), spacing (16-80 px), target size (10-50 px), color, completion bonus and reset delay (0-60 seconds). Spacing must exceed target size by 2 pixels; very short/long gestures clamp to those bounds.

Each target owns a stable `bank_object_id/target_index` identity, down state, swept capsule collision and independent retraction animation. Down targets are omitted from contact queries immediately. A hit uses existing Switch scoring (25 points); completion uses existing Switch Bank semantics (default fixed 500, including the existing completion Buddy). No labels or custom-layout grouping in V1. Zero reset delay leaves targets down; a positive delay begins after completion and waits for Ball clearance before restoring collision. Soft retries preserve progress; full reset restores the row.

Editor check: `Godot.exe --headless --path . --script res://tests/pinball_vocabulary_editor_regression.gd`.
