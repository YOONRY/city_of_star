extends Resource
class_name SpeciesDefinition

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var growth: StatBlock = StatBlock.new()
@export var skill_ids: PackedStringArray = []

func label() -> String:
	if display_name.is_empty():
		return String(id)

	return display_name
