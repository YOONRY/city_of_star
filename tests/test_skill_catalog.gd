extends Node

var failures := PackedStringArray()

func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var state := get_tree().root.get_node("GameState") as CityGameState
	var catalog := get_tree().root.get_node("ContentCatalog") as CityContentCatalog
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog.SKILL_DATABASE_PATH))
	_check(catalog.skills.size() == data["skills"].size(), "Every exported skill loads")
	for record: Dictionary in data["skills"]:
		var skill := catalog.get_skill(int(record["id"]))
		_check(skill != null and skill.display_name == record["display_name"], "Skill ID resolves to its DB name")
		_check(skill.effect_text == record["effect_text"] and skill.damage_type == int(record["damage_type"]), "Skill metadata matches the DB")
	_check(catalog.get_job(&"Fighter").get_unlocked_skill_ids(1) == PackedStringArray(["1"]), "Fighter uses DB level-one unlock")
	_test_job_unlocks(catalog, data)
	_check(not catalog.get_job(&"Gladiator").skill_ids.is_empty(), "Jobs outside the DB retain resource skills")

	var character := CardDefinition.new()
	character.id = &"skill_test_character"
	character.job = &"Fighter"
	character.species = &"human"
	catalog.register_runtime_card(character)
	state.office.add_card(character)
	_check(not state.get_character_skill_use_errors(character, 1, 2, 1).is_empty(), "Missing melee weapon blocks use")
	_check(not state.get_character_skill_use_errors(character, 5, 2, 3).is_empty(), "Unlearned skill blocks use")
	var equipment := CardDefinition.new()
	equipment.id = &"skill_test_weapon"
	equipment.card_type = GameEnums.CardType.EQUIPMENT
	equipment.equipment_category = "근접무기"
	catalog.register_runtime_card(equipment)
	state.office.add_card(equipment)
	_check(state.equip_card(character, equipment), "Equip a skill's required weapon")
	_check(state.get_character_skill_use_errors(character, 1, 2, 1).is_empty(), "Learned skill accepts matching AP, column and equipment")
	_check(not state.get_character_skill_use_errors(character, 1, 1, 1).is_empty(), "Front column blocks charge")
	_check(not state.get_character_skill_use_errors(character, 1, 2, 0).is_empty(), "Insufficient AP blocks use")
	_check(not state.get_character_skill_use_errors(character, 999999, 2, 3).is_empty(), "Unknown skill blocks use")
	_check(state.level_up_current_job(character), "Job training succeeds")
	_check(state.get_character_job_skill_ids(character).has("2"), "Level two unlocks the DB passive")
	_check(not state.get_character_skill_use_errors(character, 2, 2, 3).is_empty(), "Passives cannot be cast")
	_test_ui(character)
	await _test_main_ui(state, character)
	while state.can_level_up_current_job(character):
		state.level_up_current_job(character)
	_check(state.get_character_job_skill_ids(character).size() == 10, "Fighter level ten knows ten DB skills")
	_check(state.change_character_job(character, &"Mage"), "Change to a second job")
	_check(state.get_character_job_skill_ids(character).has("1") and state.get_character_job_skill_ids(character).has("21"), "Job changes retain old unlocks and add the new job's skill")
	_check(state.get_character_job_skill_ids(character).size() == 11, "Skills do not duplicate across job history")
	_check(catalog.get_skill(27).get_use_errors(3, 2, PackedStringArray(["마법장비"])).is_empty(), "Equipment spelling ignores spaces")

	var unknown_ap_record: Dictionary = data["skills"][0].duplicate(true)
	unknown_ap_record["ap_cost"] = null
	_check(not SkillDefinition.from_record(unknown_ap_record).get_use_errors(2, 100, PackedStringArray(["근접무기"])).is_empty(), "Unspecified AP never becomes a free cast")
	unknown_ap_record["ap_cost"] = 0
	_check(SkillDefinition.from_record(unknown_ap_record).get_use_errors(2, 0, PackedStringArray(["근접무기"])).is_empty(), "Explicit zero AP remains valid")
	_check(state.unequip_card(character, equipment.id), "Unequip required weapon")
	_check(not state.get_character_skill_use_errors(character, 1, 2, 1).is_empty(), "Unequip invalidates the weapon condition")
	state.reset_game()
	catalog.unregister_runtime_card(character.id)
	catalog.unregister_runtime_card(equipment.id)
	catalog.reload()
	_check(catalog.get_job(&"Fighter").skill_ids.size() == 10, "Reload does not duplicate DB unlocks")
	if failures.is_empty():
		print("Skill catalog checks passed: %s skills." % catalog.skills.size())
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func _test_job_unlocks(catalog: CityContentCatalog, data: Dictionary) -> void:
	for record: Dictionary in data["jobs"]:
		var expected_ids := PackedStringArray()
		var expected_levels := PackedInt32Array()
		for unlock: Dictionary in data["job_skill_unlocks"]:
			if unlock["job_id"] == record["id"]:
				expected_ids.append(str(int(unlock["skill_id"])))
				expected_levels.append(int(unlock["unlock_level"]))
		var job := catalog.get_job(StringName(record["id"]))
		_check(job.skill_ids == expected_ids and job.skill_unlock_levels == expected_levels, "Every DB job reflects its saved unlocks")
	var saved_unlocks: Array[Dictionary] = catalog.job_skill_unlocks
	catalog.job_skill_unlocks = []
	catalog.call("_load_jobs")
	_check(catalog.get_job(&"Trickster").skill_ids.is_empty(), "An empty DB job does not gain sample skills")
	catalog.job_skill_unlocks = saved_unlocks
	catalog.call("_load_jobs")


func _test_ui(character: CardDefinition) -> void:
	var screen := load("res://scripts/ui/main_screen.gd").new() as Control
	var tab: VBoxContainer = screen.call("_make_character_skills_tab", character)
	var text := ""
	for label in tab.find_children("*", "Label", true, false):
		text += label.text + "\n"
	_check(text.contains("돌진") and text.contains("내구력"), "Skills tab displays learned DB skill names")
	_check(text.contains("AP 1") and text.contains("물리 피해"), "Skills tab displays AP and damage type")
	_check(text.contains("근접무기") and text.contains("힘1.0"), "Skills tab displays equipment and raw stat expression")
	_check(text.contains("강타 · Lv.5"), "Skills tab displays upcoming unlock levels")
	_check(text.contains("받는 피해가 10% 감소한다."), "Skills tab displays DB effect descriptions")
	tab.free()
	screen.free()


func _test_main_ui(state: CityGameState, character: CardDefinition) -> void:
	var previous_player_id := state.player_character_id
	state.player_character_id = character.id
	var screen := load("res://scenes/main/main.tscn").instantiate() as Control
	get_tree().root.add_child(screen)
	screen.set("selected_character_card_id", character.id)
	screen.call("_refresh_character_detail_popup")
	for viewport_size in [Vector2i(1280, 720), Vector2i(1024, 640)]:
		get_tree().root.size = viewport_size
		for frame in 3:
			await get_tree().process_frame
		var popup: Control = screen.get("character_detail_popup")
		var character_panel: Control = screen.get("character_panel")
		_check(popup.get_global_rect().end.x <= character_panel.get_global_rect().position.x, "Skill detail stays inside the left area at %s" % viewport_size)
	var content: VBoxContainer = screen.get("character_detail_content")
	var detail := content.get_child(content.get_child_count() - 1) as TabContainer
	detail.current_tab = 2
	state.level_up_current_job(character)
	for frame in 3:
		await get_tree().process_frame
	detail = content.get_child(content.get_child_count() - 1) as TabContainer
	_check(detail.current_tab == 2, "Skill tab selection survives level-up refresh")
	screen.free()
	state.player_character_id = previous_player_id


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
