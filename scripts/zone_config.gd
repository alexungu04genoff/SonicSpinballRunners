class_name ZoneConfig
extends Resource
## Zone difficulty is shared by every Act; score targets are provisional tuning.
@export var title := "Green Hill Zone"
@export var difficulty: int = TableGenerator.Difficulty.EASY
@export var act_targets: Array[int] = [750, 1250, 1750]
