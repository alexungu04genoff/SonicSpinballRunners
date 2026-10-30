class_name PhysicsModifier
extends Resource
## Effective = clamp((base + sum(additions)) * product(multipliers)).
@export var display_name: String = "Physics Modifier"
@export var additions: Dictionary = {}
@export var multipliers: Dictionary = {}
