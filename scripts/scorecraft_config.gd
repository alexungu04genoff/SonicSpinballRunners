class_name ScorecraftConfig
extends Resource
## Provisional scoring rhythm, independent of physical movement and meter charge.
@export_range(0.5, 8.0, 0.1) var combo_window := 3.0
@export_range(1, 8, 1) var rings_per_link := 3
@export_range(1, 4, 1) var multiplier_cap := 3
@export var tiered_decay := false
@export_range(0.0, 5.0, 0.1) var rail_protection_budget := 5.0
