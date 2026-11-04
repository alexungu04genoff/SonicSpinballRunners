class_name CharacterDefinition
extends Resource
## Character identity/profile stay separate from shared type action tuning.
@export var display_name := "Sonic"
@export var profile: PhysicsProfile
@export var type_action: TypeAction
@export var color := Color("5fbaff")
@export var ball_color := Color("075dd2")
@export var meter_capacity := 100.0
@export var meter_cost := 100.0
@export var ring_charge := 5.0
@export var bumper_charge := 2.0
var character_type: String:
 get: return type_action.type_id()
var selection_label: String:
 get: return "%s · %s" % [display_name, type_action.label()]
var description: String:
 get: return "%s: %s Costs %d meter." % [type_action.label(), type_action.description, meter_cost]
