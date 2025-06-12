extends Node

enum EntityType 
{
	NONE = 0,
	organic,
	robot,
}

@export_group("VARIABLES")
@export
var entity_type : EntityType = EntityType.NONE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func is_organic() -> bool:
	return entity_type == EntityType.organic

func is_robot() -> bool:
	return entity_type == EntityType.robot

func set_type(new_type : EntityType) -> void:
	entity_type = new_type
	pass

func get_type() -> EntityType:
	return entity_type

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
