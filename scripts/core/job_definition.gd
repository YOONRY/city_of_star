extends Resource
class_name JobDefinition

@export var id: StringName
@export var display_name: String = ""
@export var growth: StatBlock = StatBlock.new()

func label() -> String:
	if display_name.is_empty():
		return String(id)

	return display_name
