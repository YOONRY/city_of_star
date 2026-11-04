extends Resource
class_name SkillDefinition

enum SkillType { ACTIVE = 1, PASSIVE = 2 }
enum DamageType { NONE = 0, PHYSICAL = 1, MAGIC = 2 }

@export var id: int = 0
@export var display_name: String = ""
@export var skill_type_id: int = SkillType.ACTIVE
@export var ap_cost: int = -1
@export var effect_text: String = ""
@export var usable_columns: PackedInt32Array = [1, 2, 3, 4]
@export var required_equipment: String = ""
@export var target_text: String = ""
@export var main_stat: String = ""
@export var damage_type: int = DamageType.NONE

static func from_record(record: Dictionary) -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.id = int(record["id"])
	skill.display_name = str(record["display_name"])
	skill.skill_type_id = int(record["skill_type_id"])
	skill.ap_cost = -1 if record["ap_cost"] == null else int(record["ap_cost"])
	skill.effect_text = str(record["effect_text"])
	skill.usable_columns = PackedInt32Array(record["usable_columns"])
	skill.required_equipment = str(record["required_equipment"]).strip_edges()
	skill.target_text = str(record["target_text"]).strip_edges()
	skill.main_stat = str(record["main_stat"]).strip_edges()
	skill.damage_type = int(record["damage_type"])
	return skill


func is_active() -> bool:
	return skill_type_id == SkillType.ACTIVE


func type_label() -> String:
	return "액티브" if is_active() else "패시브"


func damage_label() -> String:
	match damage_type:
		DamageType.PHYSICAL:
			return "물리 피해"
		DamageType.MAGIC:
			return "마법 피해"
	return ""


func get_use_errors(column: int, available_ap: int, equipment_categories: PackedStringArray) -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_active():
		errors.append("패시브 스킬입니다.")
		return errors
	if not usable_columns.has(column):
		errors.append("현재 열에서 사용할 수 없습니다.")
	if ap_cost < 0:
		errors.append("소모 AP가 정해지지 않았습니다.")
	elif available_ap < ap_cost:
		errors.append("AP가 부족합니다.")
	if not required_equipment.is_empty():
		var has_equipment := false
		for category in equipment_categories:
			if category.replace(" ", "") == required_equipment.replace(" ", ""):
				has_equipment = true
				break
		if not has_equipment:
			errors.append("필요 장비: %s" % required_equipment)
	return errors
