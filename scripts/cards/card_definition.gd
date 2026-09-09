extends Resource
class_name CardDefinition

@export var id: StringName
@export var display_name: String = ""
@export_enum("Character", "Equipment", "Consumable") var card_type: int = GameEnums.CardType.CHARACTER
@export var stats: StatBlock = StatBlock.new()
@export var skill_ids: PackedStringArray = []
@export var weekly_wage: int = 0
@export var job: StringName
@export var tags: PackedStringArray = []

func is_character() -> bool:
	return card_type == GameEnums.CardType.CHARACTER


func is_equipment() -> bool:
	return card_type == GameEnums.CardType.EQUIPMENT


func is_consumable() -> bool:
	return card_type == GameEnums.CardType.CONSUMABLE


func label() -> String:
	if display_name.is_empty():
		return String(id)

	return display_name
