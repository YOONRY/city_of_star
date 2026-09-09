extends Resource
class_name RequestDefinition

@export var id: StringName
@export var title: String = ""
@export_enum("Story", "Regular", "Event") var request_type: int = GameEnums.RequestType.REGULAR
@export_range(1, 30, 1) var duration_days: int = 1
@export_range(1, 60, 1) var valid_days: int = 1
@export var required_stats: StatBlock = StatBlock.new()
@export var reward_money: int = 0
@export var reward_reputation: int = 0
@export var repeatable_after_expiry: bool = false
@export var next_story_request_id: StringName
@export var tags: PackedStringArray = []

func can_start_with(stats: StatBlock) -> bool:
	return stats != null and stats.meets(required_stats)


func label() -> String:
	if title.is_empty():
		return String(id)

	return title
