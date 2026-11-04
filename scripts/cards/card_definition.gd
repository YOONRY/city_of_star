extends Resource
class_name CardDefinition

@export var id: StringName
@export var display_name: String = ""
@export_enum("Character", "Equipment", "Consumable") var card_type: int = GameEnums.CardType.CHARACTER
@export var stats: StatBlock = StatBlock.new()
@export var growth: StatBlock = StatBlock.new()
@export var skill_ids: PackedStringArray = []
@export_enum("미지정", "근접무기", "사격무기", "마법장비") var equipment_category: String = "미지정"
@export var weekly_wage: int = 0
@export var species: StringName
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
