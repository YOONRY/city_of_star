extends Resource
class_name JobDefinition

@export var id: StringName
@export var display_name: String = ""
@export_range(1, 10, 1) var tier: int = 1
@export var growth: StatBlock = StatBlock.new()
@export var skill_ids: PackedStringArray = []
@export var skill_unlock_levels: PackedInt32Array = []
@export var prerequisite_job_ids: PackedStringArray = []
@export_range(1, 10, 1) var prerequisite_job_level: int = 10
@export var required_stats: StatBlock = StatBlock.new()

func label() -> String:
	if display_name.is_empty():
		return String(id)

	return display_name


func is_basic_job() -> bool:
	return tier <= 1


func get_unlocked_skill_ids(job_level: int) -> PackedStringArray:
	var unlocked := PackedStringArray()

	for index in skill_ids.size():
		var unlock_level := 1
		if index < skill_unlock_levels.size():
			unlock_level = skill_unlock_levels[index]

		if job_level >= unlock_level:
			unlocked.append(skill_ids[index])

	return unlocked


func requirement_text() -> String:
	var parts := PackedStringArray()
	for prerequisite_id in prerequisite_job_ids:
		parts.append("%s Lv.%s" % [prerequisite_id, prerequisite_job_level])

	if required_stats != null and required_stats.total() > 0:
		parts.append("required stats")

	if parts.is_empty():
		return "No requirements"

	return ", ".join(parts)
