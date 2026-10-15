extends Node

var failures := PackedStringArray()

func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var state := get_tree().root.get_node("GameState") as CityGameState
	var catalog := get_tree().root.get_node("ContentCatalog") as CityContentCatalog
	_test_stat_block()

	var growth := StatBlock.new()
	for stat_name in StatBlock.GROWTH_STAT_NAMES:
		growth.set(stat_name, 10)
	growth.strength = 90
	var options := state.get_player_initial_skill_options()
	var initial_skills := PackedStringArray([options[0], options[1]])
	_check(state.can_create_player_character("Test", &"human", &"Fighter", growth, initial_skills), "Valid player growth is accepted")
	var invalid_growth := growth.clone()
	invalid_growth.strength -= 10
	invalid_growth.defense = 10
	_check(not state.can_create_player_character("Test", &"human", &"Fighter", invalid_growth, initial_skills), "Defense cannot consume the player growth budget")
	invalid_growth.defense = 0
	invalid_growth.magic_defense = 10
	_check(not state.can_create_player_character("Test", &"human", &"Fighter", invalid_growth, initial_skills), "Magic defense cannot consume the player growth budget")

	var character := state.create_player_character("Test", &"human", &"Fighter", growth, initial_skills)
	if character == null:
		_check(false, "Player creation succeeded")
		_finish()
		return
	_check_defenses(state.get_effective_stats(character), 0, 0, "Initial stats")
	for recruit in state.get_hire_candidates():
		_check_defenses(recruit.stats, 0, 0, "Recruit initial stats")

	_test_growth_exclusion(state, catalog, character)
	var armor := _make_equipment(state, catalog, &"test_armor", 4, 1)
	var ward := _make_equipment(state, catalog, &"test_ward", 2, 5)
	_check(state.equip_card(character, armor), "Equip armor")
	_check(state.equip_card(character, ward), "Equip ward")
	_check_defenses(state.get_effective_stats(character), 6, 6, "Equipment stacks")
	_check(state.level_up_character(character), "Level up while equipped")
	_check_defenses(state.get_effective_stats(character), 6, 6, "Equipment defenses do not grow")

	var guard_bonus := StatBlock.new()
	guard_bonus.defense = 3
	guard_bonus.magic_defense = 2
	_check(state.set_character_skill_bonus_stats(character, &"guard", guard_bonus), "Apply first skill")
	guard_bonus.defense = 500
	_check_defenses(state.get_effective_stats(character), 9, 8, "Skill bonus is copied")
	var ward_bonus := StatBlock.new()
	ward_bonus.defense = 1
	ward_bonus.magic_defense = 4
	_check(state.set_character_skill_bonus_stats(character, &"ward", ward_bonus), "Apply second skill")
	_check_defenses(state.get_effective_stats(character), 10, 12, "Distinct skills stack with equipment")
	ward_bonus.defense = 2
	_check(state.set_character_skill_bonus_stats(character, &"ward", ward_bonus), "Refresh existing skill")
	_check_defenses(state.get_effective_stats(character), 11, 12, "Refreshing a skill replaces its old bonus")
	_check(state.level_up_character(character), "Level up with active skills")
	_check_defenses(state.get_effective_stats(character), 11, 12, "Skill defenses do not grow")
	_check(not state.set_character_skill_bonus_stats(character, &"", ward_bonus), "Reject a missing skill ID")
	_check(not state.set_character_skill_bonus_stats(character, &"ward", null), "Reject a missing bonus")
	_check(not state.set_character_skill_bonus_stats(armor, &"guard", ward_bonus), "Reject skill bonuses on equipment")

	_test_ui(character, armor)
	_check(state.remove_character_skill_bonus_stats(character, &"guard"), "Remove first skill")
	_check_defenses(state.get_effective_stats(character), 8, 10, "Other skill remains after removal")
	_check(not state.remove_character_skill_bonus_stats(character, &"guard"), "Removing an absent skill is harmless")
	_check(state.unequip_card(character, armor.id), "Unequip armor")
	_check_defenses(state.get_effective_stats(character), 4, 9, "Unequip preserves active skills")
	_check(state.remove_character_skill_bonus_stats(character, &"ward"), "Remove second skill")
	_check(state.unequip_card(character, ward.id), "Unequip ward")
	_check_defenses(state.get_effective_stats(character), 0, 0, "All sources removed")

	state.set_character_skill_bonus_stats(character, &"guard", ward_bonus)
	state.reset_game()
	_check(state.character_skill_bonus_stats_by_id.is_empty(), "Reset clears skill bonuses")
	catalog.unregister_runtime_card(armor.id)
	catalog.unregister_runtime_card(ward.id)
	_finish()


func _test_stat_block() -> void:
	var stats := StatBlock.new()
	stats.strength = 200
	stats.defense = 400
	stats.magic_defense = 300
	_check_defenses(stats.clone(), 400, 300, "Clone includes defenses")
	_check_defenses(StatBlock.new().plus(stats), 400, 300, "Addition includes defenses")
	_check_defenses(stats.growth_only(), 0, 0, "Growth excludes defenses")
	_check_defenses(stats.floor_divided(100), 0, 0, "Growth conversion excludes defenses")
	_check(stats.floor_divided(100).strength == 2, "Primary stats still grow")
	_check(stats.as_dictionary()["defense"] == 400 and stats.as_dictionary()["magic_defense"] == 300, "Dictionary includes defenses")
	_check(stats.total() == 900, "Total includes all stats")
	var required := StatBlock.new()
	required.magic_defense = 301
	_check(not stats.meets(required), "Requirements check magic defense")
	required.magic_defense = 300
	required.defense = 401
	_check(not stats.meets(required), "Requirements check defense")


func _test_growth_exclusion(state: CityGameState, catalog: CityContentCatalog, character: CardDefinition) -> void:
	var job := catalog.get_job(&"Fighter")
	var species: Resource = catalog.get_species(&"human")
	var saved_job_growth := job.growth
	var saved_species_growth: StatBlock = species.growth
	job.growth = saved_job_growth.clone()
	species.growth = saved_species_growth.clone()
	job.growth.defense = 900
	species.growth.magic_defense = 900
	character.growth.defense = 900
	character.growth.magic_defense = 900
	character.stats.defense = 900
	character.stats.magic_defense = 900
	state.character_bonus_stats_by_id[character.id] = character.growth.clone()
	_check_defenses(state.get_character_growth(character), 0, 0, "All growth sources exclude defenses")
	_check_defenses(state.get_character_level_up_gain(character), 0, 0, "Level-up gain excludes defenses")
	_check_defenses(state.get_effective_stats(character), 0, 0, "Innate and growth bonuses cannot grant defenses")
	_check(state.level_up_character(character), "Character level-up succeeds")
	_check_defenses(state.get_effective_stats(character), 0, 0, "Level-up cannot grant defenses")
	_check(state.level_up_current_job(character), "Job training succeeds")
	_check(state.change_character_job(character, &"Mage"), "Job change succeeds")
	_check_defenses(state.get_effective_stats(character), 0, 0, "Job training and changes cannot grant defenses")
	job.growth = saved_job_growth
	species.growth = saved_species_growth


func _make_equipment(state: CityGameState, catalog: CityContentCatalog, id: StringName, defense: int, magic_defense: int) -> CardDefinition:
	var equipment := CardDefinition.new()
	equipment.id = id
	equipment.card_type = GameEnums.CardType.EQUIPMENT
	equipment.stats.defense = defense
	equipment.stats.magic_defense = magic_defense
	catalog.register_runtime_card(equipment)
	state.office.add_card(equipment)
	return equipment


func _test_ui(character: CardDefinition, equipment: CardDefinition) -> void:
	var screen := load("res://scripts/ui/main_screen.gd").new() as Control
	var status_tab: VBoxContainer = screen.call("_make_character_status_tab", character)
	var stats_grid := status_tab.get_child(status_tab.get_child_count() - 1) as GridContainer
	_check(stats_grid.get_child(10).text == "DEF" and stats_grid.get_child(11).text == "11", "Status displays defense")
	_check(stats_grid.get_child(12).text == "MDEF" and stats_grid.get_child(13).text == "12", "Status displays magic defense")
	var growth_tab: VBoxContainer = screen.call("_make_character_growth_tab", character)
	var growth_section := growth_tab.get_child(0) as VBoxContainer
	_check(growth_section.get_child_count() == 6, "Growth tab still contains only five stats")
	var slot: Button = screen.call("_make_equipment_slot_button", character, equipment, 0)
	_check(slot.text.contains("DEF 4") and slot.text.contains("MDEF 1"), "Equipment displays both defenses")
	_check(slot.clip_text and slot.tooltip_text.contains("DEF 4"), "Equipment text stays contained with full details in its tooltip")
	status_tab.free()
	growth_tab.free()
	slot.free()
	screen.free()


func _check_defenses(stats: StatBlock, defense: int, magic_defense: int, message: String) -> void:
	_check(stats.defense == defense and stats.magic_defense == magic_defense, message)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _finish() -> void:
	if failures.is_empty():
		print("Defense stat checks passed.")
		get_tree().quit(0)
	else:
		print("Defense stat checks failed: %s" % failures.size())
		get_tree().quit(1)
