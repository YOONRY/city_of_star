extends Node
class_name CityGameState

signal state_changed
signal day_advanced(day: int)
signal tax_due(amount: int)
signal game_over(reason: String)
signal job_training_completed(character_id: StringName)

const STARTING_MONEY := 100
const STARTING_WEEKLY_TAX := 80
const TAX_DUE_WEEKDAY := 7
const STARTING_CARD_TAG := "starter"
const MAX_EQUIPMENT_PER_CHARACTER := 3
const GROWTH_POINTS_PER_STAT := 100
const MAX_JOB_LEVEL := 10
const HIRE_CANDIDATE_COUNT := 3
const PLAYER_GROWTH_BUDGET := 130
const PLAYER_GROWTH_MIN_PER_STAT := 10
const PLAYER_GROWTH_MAX_PER_STAT := 90
const PLAYER_INITIAL_SKILL_COUNT := 2
const DAILY_REQUEST_TAG := "daily_request"
const DAILY_INCOME_TAG := "daily_income"
const RECRUIT_FIRST_NAMES := ["아린", "세라", "레온", "미라", "카인", "루나", "테오", "니아", "로웬", "엘라", "다온", "유리"]
const RECRUIT_LAST_NAMES := ["베일", "노바", "하트", "렌", "크로우", "스톤", "리프", "문", "애쉬", "스타"]
const RECRUIT_PERSONAL_SKILLS := ["침착", "근면", "직감", "협동", "집중", "생존술", "응급 대응", "거리 감각"]

var current_day: int = 1
var office := OfficeState.new()
var tax_manager := TaxManager.new(STARTING_WEEKLY_TAX, TAX_DUE_WEEKDAY)
var is_game_over: bool = false
var game_over_reason: String = ""
var last_tax_payment_day: int = 0
var last_tax_payment_week: int = 0
var last_tax_payment_amount: int = 0
var equipped_card_ids_by_character_id: Dictionary = {}
var character_levels_by_id: Dictionary = {}
var character_bonus_stats_by_id: Dictionary = {}
var character_skill_bonus_stats_by_id: Dictionary = {}
var character_current_job_by_id: Dictionary = {}
var character_job_levels_by_id: Dictionary = {}
var character_job_history_by_id: Dictionary = {}
var job_training_character_id: StringName = &""
var pending_job_change_character_id: StringName = &""
var hire_candidates: Array[CardDefinition] = []
var generated_character_ids: Array[StringName] = []
var recruit_serial: int = 0
var recruit_rng := RandomNumberGenerator.new()
var player_character_id: StringName = &""
var daily_request_assignments: Dictionary = {}
var last_daily_request_results: Array[Dictionary] = []

func _ready() -> void:
	recruit_rng.randomize()
	reset_game()


func reset_game() -> void:
	_clear_generated_characters()
	current_day = 1
	office = OfficeState.new()
	office.reset(STARTING_MONEY)
	_seed_starting_cards()
	tax_manager = TaxManager.new(STARTING_WEEKLY_TAX, TAX_DUE_WEEKDAY)
	is_game_over = false
	game_over_reason = ""
	equipped_card_ids_by_character_id.clear()
	character_levels_by_id.clear()
	character_bonus_stats_by_id.clear()
	character_skill_bonus_stats_by_id.clear()
	character_current_job_by_id.clear()
	character_job_levels_by_id.clear()
	character_job_history_by_id.clear()
	job_training_character_id = &""
	pending_job_change_character_id = &""
	recruit_serial = 0
	player_character_id = &""
	daily_request_assignments.clear()
	last_daily_request_results.clear()
	_refresh_hire_candidates()
	_refresh_daily_requests()
	_clear_last_tax_payment()
	state_changed.emit()


func advance_day() -> void:
	if is_game_over or has_pending_job_change() or not has_player_character():
		return

	if tax_manager.is_due(current_day) and not tax_manager.has_paid_current_week(current_day):
		_set_game_over("Weekly tax was not paid.")
		return

	_settle_queued_daily_requests()
	current_day += 1
	_refresh_hire_candidates()
	_refresh_daily_requests()

	if not String(job_training_character_id).is_empty():
		pending_job_change_character_id = job_training_character_id
		job_training_character_id = &""
		job_training_completed.emit(pending_job_change_character_id)

	for request in office.advance_requests_one_day():
		office.complete_request(request)

	if tax_manager.is_due(current_day):
		if office.money < tax_manager.weekly_tax:
			_set_game_over("Not enough money to pay the weekly tax.")
			return

		tax_due.emit(tax_manager.weekly_tax)

	day_advanced.emit(current_day)
	state_changed.emit()


func pay_weekly_tax() -> bool:
	if is_game_over:
		return false

	if not tax_manager.is_due(current_day):
		return false

	if tax_manager.has_paid_current_week(current_day):
		return false

	if office.money < tax_manager.weekly_tax:
		_set_game_over("Not enough money to pay the weekly tax.")
		return false

	office.money -= tax_manager.weekly_tax
	tax_manager.mark_paid(current_day)
	_record_tax_payment(tax_manager.weekly_tax)
	state_changed.emit()
	return true


func can_pay_current_week_tax() -> bool:
	if is_game_over:
		return false

	if tax_manager.has_paid_current_week(current_day):
		return false

	return office.money >= tax_manager.weekly_tax


func pay_current_week_tax() -> bool:
	if not can_pay_current_week_tax():
		return false

	office.money -= tax_manager.weekly_tax
	tax_manager.mark_paid(current_day)
	_record_tax_payment(tax_manager.weekly_tax)
	state_changed.emit()
	return true


func can_cancel_current_week_tax_payment() -> bool:
	return (
		not is_game_over
		and last_tax_payment_day == current_day
		and last_tax_payment_week == get_week()
		and last_tax_payment_amount > 0
		and tax_manager.has_paid_current_week(current_day)
	)


func cancel_current_week_tax_payment() -> bool:
	if not can_cancel_current_week_tax_payment():
		return false

	office.money += last_tax_payment_amount
	tax_manager.unmark_paid(current_day)
	_clear_last_tax_payment()
	state_changed.emit()
	return true


func can_hire_card(card: CardDefinition) -> bool:
	if is_game_over or card == null or not card.is_character():
		return false

	if office.owned_cards.has(card):
		return false
	if not hire_candidates.has(card):
		return false

	return office.money >= get_hire_cost(card)


func hire_card(card: CardDefinition) -> bool:
	if not can_hire_card(card):
		return false

	office.money -= get_hire_cost(card)
	office.add_card(card)
	hire_candidates.erase(card)
	state_changed.emit()
	return true


func get_hire_candidates() -> Array[CardDefinition]:
	return hire_candidates.duplicate()


func can_resolve_daily_request(request: RequestDefinition, character: CardDefinition) -> bool:
	return (
		not is_game_over
		and request != null
		and office.available_requests.has(request)
		and character != null
		and character.is_character()
		and office.owned_cards.has(character)
		and not get_daily_request_primary_stats(request).is_empty()
	)


func can_queue_daily_request(request: RequestDefinition, character: CardDefinition) -> bool:
	return (
		can_resolve_daily_request(request, character)
		and not daily_request_assignments.has(request.id)
		and get_character_event_assignment(character).is_empty()
	)


func queue_daily_request(request: RequestDefinition, character: CardDefinition) -> bool:
	if not can_queue_daily_request(request, character):
		return false

	daily_request_assignments[request.id] = character.id
	state_changed.emit()
	return true


func get_daily_request_assigned_character(request: RequestDefinition) -> CardDefinition:
	if request == null or not daily_request_assignments.has(request.id):
		return null
	return ContentCatalog.get_card(StringName(daily_request_assignments[request.id]))


func cancel_daily_request_assignment(request: RequestDefinition) -> bool:
	if request == null or not daily_request_assignments.has(request.id):
		return false

	daily_request_assignments.erase(request.id)
	state_changed.emit()
	return true


func get_character_event_assignment(character: CardDefinition) -> String:
	if character == null:
		return ""

	if job_training_character_id == character.id or pending_job_change_character_id == character.id:
		return "직업 교육소"

	for raw_request_id in daily_request_assignments:
		if StringName(daily_request_assignments[raw_request_id]) != character.id:
			continue
		var request := ContentCatalog.get_request(StringName(raw_request_id))
		return request.label() if request != null else String(raw_request_id)
	return ""


func get_daily_request_primary_stats(request: RequestDefinition) -> PackedStringArray:
	var primary_stats := PackedStringArray()
	if request == null or request.required_stats == null:
		return primary_stats

	if request.required_stats.strength > 0:
		primary_stats.append("strength")
	if request.required_stats.agility > 0:
		primary_stats.append("agility")
	if request.required_stats.intelligence > 0:
		primary_stats.append("intelligence")
	if request.required_stats.charm > 0:
		primary_stats.append("charm")
	if request.required_stats.health > 0:
		primary_stats.append("health")
	return primary_stats


func _calculate_daily_request_result(request: RequestDefinition, character: CardDefinition) -> Dictionary:
	var effective_stats := get_effective_stats(character)
	var selected_stat := ""
	var selected_stat_value := -1
	for stat_name in get_daily_request_primary_stats(request):
		var stat_value := int(effective_stats.get(stat_name))
		if stat_value > selected_stat_value:
			selected_stat = stat_name
			selected_stat_value = stat_value

	var die_roll := recruit_rng.randi_range(1, 6)
	var total := die_roll + selected_stat_value
	var outcome := "실패"
	var reward := 0
	if total >= 8:
		outcome = "대성공"
		reward = 40
	elif total >= 6:
		outcome = "성공"
		reward = 20

	return {
		"day": current_day,
		"request": request.label(),
		"character": character.label(),
		"die": die_roll,
		"stat_name": _stat_display_name(selected_stat),
		"stat_value": selected_stat_value,
		"total": total,
		"outcome": outcome,
		"reward": reward,
	}


func _settle_queued_daily_requests() -> void:
	last_daily_request_results.clear()
	for raw_request_id in daily_request_assignments:
		var request := ContentCatalog.get_request(StringName(raw_request_id))
		var character := ContentCatalog.get_card(StringName(daily_request_assignments[raw_request_id]))
		if not can_resolve_daily_request(request, character):
			continue

		var result := _calculate_daily_request_result(request, character)
		office.money += int(result.get("reward", 0))
		office.available_requests.erase(request)
		last_daily_request_results.append(result)
	daily_request_assignments.clear()


func get_player_character() -> CardDefinition:
	return ContentCatalog.get_card(player_character_id)


func has_player_character() -> bool:
	return get_player_character() != null


func get_player_initial_skill_options() -> PackedStringArray:
	return PackedStringArray(RECRUIT_PERSONAL_SKILLS)


func can_create_player_character(
	display_name: String,
	species_id: StringName,
	job_id: StringName,
	growth: StatBlock,
	initial_skill_ids: PackedStringArray
) -> bool:
	if has_player_character() or display_name.strip_edges().is_empty():
		return false
	if ContentCatalog.get_species(species_id) == null:
		return false

	var job := ContentCatalog.get_job(job_id)
	if job == null or not job.is_basic_job():
		return false
	if growth == null or growth.total() != PLAYER_GROWTH_BUDGET:
		return false
	if growth.defense != 0 or growth.magic_defense != 0:
		return false

	for stat_name in StatBlock.GROWTH_STAT_NAMES:
		var value := int(growth.get(stat_name))
		if int(value) < PLAYER_GROWTH_MIN_PER_STAT or int(value) > PLAYER_GROWTH_MAX_PER_STAT:
			return false
		if int(value) % 10 != 0:
			return false
	if initial_skill_ids.size() != PLAYER_INITIAL_SKILL_COUNT:
		return false

	var skill_options := get_player_initial_skill_options()
	for skill_id in initial_skill_ids:
		if not skill_options.has(skill_id):
			return false
	return true


func create_player_character(
	display_name: String,
	species_id: StringName,
	job_id: StringName,
	growth: StatBlock,
	initial_skill_ids: PackedStringArray
) -> CardDefinition:
	if not can_create_player_character(display_name, species_id, job_id, growth, initial_skill_ids):
		return null

	var player := CardDefinition.new()
	player.id = &"player_character"
	player.display_name = display_name.strip_edges()
	player.card_type = GameEnums.CardType.CHARACTER
	player.growth = growth.clone()
	player.skill_ids = initial_skill_ids.duplicate()
	player.weekly_wage = 0
	player.species = species_id
	player.job = job_id
	player.stats = _calculate_initial_stats(player.growth, player.species, player.job)
	player.tags = PackedStringArray(["player", "character"])

	player_character_id = player.id
	generated_character_ids.append(player.id)
	ContentCatalog.register_runtime_card(player)
	office.add_card(player)
	state_changed.emit()
	return player


func get_hire_cost(card: CardDefinition) -> int:
	if card == null:
		return 0

	return maxi(0, card.weekly_wage)


func get_character_level(character: CardDefinition) -> int:
	if character == null or not character.is_character():
		return 0

	return int(character_levels_by_id.get(character.id, 1))


func get_character_bonus_stats(character: CardDefinition) -> StatBlock:
	var stats := StatBlock.new()
	if character == null or not character.is_character():
		return stats

	var raw_stats := character_bonus_stats_by_id.get(character.id, null) as StatBlock
	if raw_stats == null:
		return stats

	return raw_stats.growth_only()


func get_character_skill_bonus_stats(character: CardDefinition) -> StatBlock:
	var stats := StatBlock.new()
	if character == null or not character.is_character():
		return stats

	var bonuses: Dictionary = character_skill_bonus_stats_by_id.get(character.id, {})
	for bonus in bonuses.values():
		stats.add(bonus as StatBlock)
	return stats


func set_character_skill_bonus_stats(character: CardDefinition, skill_id: StringName, bonus: StatBlock) -> bool:
	if is_game_over or character == null or not character.is_character():
		return false
	if not office.owned_cards.has(character) or String(skill_id).is_empty() or bonus == null:
		return false

	var bonuses: Dictionary = character_skill_bonus_stats_by_id.get(character.id, {})
	bonuses[skill_id] = bonus.clone()
	character_skill_bonus_stats_by_id[character.id] = bonuses
	state_changed.emit()
	return true


func remove_character_skill_bonus_stats(character: CardDefinition, skill_id: StringName) -> bool:
	if character == null or not character.is_character():
		return false

	var bonuses: Dictionary = character_skill_bonus_stats_by_id.get(character.id, {})
	if not bonuses.has(skill_id):
		return false

	bonuses.erase(skill_id)
	if bonuses.is_empty():
		character_skill_bonus_stats_by_id.erase(character.id)
	else:
		character_skill_bonus_stats_by_id[character.id] = bonuses
	state_changed.emit()
	return true


func get_character_current_job_id(character: CardDefinition) -> StringName:
	if character == null or not character.is_character():
		return &""

	return StringName(character_current_job_by_id.get(character.id, character.job))


func get_character_job_level(character: CardDefinition, job_id: StringName) -> int:
	if character == null or not character.is_character() or String(job_id).is_empty():
		return 0

	var levels: Dictionary = character_job_levels_by_id.get(character.id, {})
	if levels.has(job_id):
		return int(levels[job_id])

	if job_id == character.job:
		return 1

	return 0


func get_character_job_levels(character: CardDefinition) -> Dictionary:
	var levels: Dictionary = {}
	if character == null or not character.is_character():
		return levels

	var stored_levels: Dictionary = character_job_levels_by_id.get(character.id, {})
	levels.merge(stored_levels, true)
	if not String(character.job).is_empty() and not levels.has(character.job):
		levels[character.job] = 1
	return levels


func get_character_job_history_ids(character: CardDefinition) -> PackedStringArray:
	var history := PackedStringArray()
	if character == null or not character.is_character():
		return history

	if not String(character.job).is_empty():
		history.append(character.job)

	var stored_history: Array = character_job_history_by_id.get(character.id, [])
	for raw_job_id in stored_history:
		var job_id := StringName(raw_job_id)
		if not history.has(job_id):
			history.append(job_id)
	return history


func get_character_mastered_job_ids(character: CardDefinition) -> PackedStringArray:
	var mastered := PackedStringArray()
	for raw_job_id in get_character_job_levels(character):
		var job_id := StringName(raw_job_id)
		if get_character_job_level(character, job_id) >= MAX_JOB_LEVEL:
			mastered.append(job_id)
	return mastered


func get_character_job_skill_ids(character: CardDefinition) -> PackedStringArray:
	var learned := PackedStringArray()
	for raw_job_id in get_character_job_levels(character):
		var job_id := StringName(raw_job_id)
		var job := ContentCatalog.get_job(job_id)
		if job == null:
			continue

		for skill_id in job.get_unlocked_skill_ids(get_character_job_level(character, job_id)):
			if not learned.has(skill_id):
				learned.append(skill_id)
	return learned


func get_character_growth(character: CardDefinition) -> StatBlock:
	var growth := StatBlock.new()
	if character == null or not character.is_character():
		return growth

	if character.growth != null:
		growth.add(character.growth)

	growth.add(ContentCatalog.get_species_growth(character.species))
	var current_job_id := get_character_current_job_id(character)
	if not String(current_job_id).is_empty():
		growth.add(ContentCatalog.get_job_growth(current_job_id))

	for mastered_job_id in get_character_mastered_job_ids(character):
		if mastered_job_id != current_job_id:
			growth.add(ContentCatalog.get_job_growth(mastered_job_id))
	return growth.growth_only()


func get_character_level_up_gain(character: CardDefinition) -> StatBlock:
	return get_character_growth(character).floor_divided(GROWTH_POINTS_PER_STAT)


func level_up_character(character: CardDefinition) -> bool:
	if is_game_over or character == null or not character.is_character():
		return false

	if not office.owned_cards.has(character):
		return false

	var bonus_stats := _get_mutable_character_bonus_stats(character.id)
	bonus_stats.add(get_character_level_up_gain(character))
	character_levels_by_id[character.id] = get_character_level(character) + 1
	state_changed.emit()
	return true


func can_level_up_current_job(character: CardDefinition) -> bool:
	if is_game_over or character == null or not character.is_character():
		return false
	if not office.owned_cards.has(character):
		return false

	var job_id := get_character_current_job_id(character)
	return not String(job_id).is_empty() and get_character_job_level(character, job_id) < MAX_JOB_LEVEL


func level_up_current_job(character: CardDefinition) -> bool:
	if not can_level_up_current_job(character):
		return false

	var job_id := get_character_current_job_id(character)
	var levels := _get_mutable_character_job_levels(character.id)
	levels[job_id] = get_character_job_level(character, job_id) + 1
	state_changed.emit()
	return true


func can_change_character_job(character: CardDefinition, target_job_id: StringName) -> bool:
	if is_game_over or character == null or not character.is_character():
		return false
	if not office.owned_cards.has(character) or target_job_id == get_character_current_job_id(character):
		return false

	var target_job := ContentCatalog.get_job(target_job_id)
	if target_job == null:
		return false
	if get_character_job_level(character, target_job_id) > 0 or target_job.is_basic_job():
		return true

	for prerequisite_id in target_job.prerequisite_job_ids:
		if get_character_job_level(character, prerequisite_id) < target_job.prerequisite_job_level:
			return false

	return get_effective_stats(character).meets(target_job.required_stats)


func change_character_job(character: CardDefinition, target_job_id: StringName) -> bool:
	if not can_change_character_job(character, target_job_id):
		return false

	var levels := _get_mutable_character_job_levels(character.id)
	if not levels.has(target_job_id):
		levels[target_job_id] = 1
	var history := _get_mutable_character_job_history(character.id)
	if not history.has(target_job_id):
		history.append(target_job_id)
	character_current_job_by_id[character.id] = target_job_id
	state_changed.emit()
	return true


func can_assign_job_training(character: CardDefinition) -> bool:
	return (
		not is_game_over
		and String(pending_job_change_character_id).is_empty()
		and character != null
		and character.is_character()
		and office.owned_cards.has(character)
		and get_character_event_assignment(character).is_empty()
	)


func assign_job_training(character: CardDefinition) -> bool:
	if not can_assign_job_training(character):
		return false

	job_training_character_id = character.id
	state_changed.emit()
	return true


func cancel_job_training() -> bool:
	if String(job_training_character_id).is_empty():
		return false

	job_training_character_id = &""
	state_changed.emit()
	return true


func get_job_training_character() -> CardDefinition:
	return ContentCatalog.get_card(job_training_character_id)


func get_pending_job_change_character() -> CardDefinition:
	return ContentCatalog.get_card(pending_job_change_character_id)


func has_pending_job_change() -> bool:
	return not String(pending_job_change_character_id).is_empty()


func complete_job_training(target_job_id: StringName) -> bool:
	var character := get_pending_job_change_character()
	if character == null or not can_change_character_job(character, target_job_id):
		return false

	pending_job_change_character_id = &""
	return change_character_job(character, target_job_id)


func get_equipped_card_ids(character_id: StringName) -> Array[StringName]:
	var equipped_ids: Array[StringName] = []
	var raw_ids: Array = equipped_card_ids_by_character_id.get(character_id, [])

	for equipment_id in raw_ids:
		equipped_ids.append(equipment_id)

	return equipped_ids


func get_equipped_cards(character: CardDefinition) -> Array[CardDefinition]:
	var equipped_cards: Array[CardDefinition] = []
	if character == null or not character.is_character():
		return equipped_cards

	for equipment_id in get_equipped_card_ids(character.id):
		var equipment := ContentCatalog.get_card(equipment_id)
		if equipment != null and equipment.is_equipment():
			equipped_cards.append(equipment)

	return equipped_cards


func get_equipment_owner_id(equipment_id: StringName) -> StringName:
	for character_id in equipped_card_ids_by_character_id.keys():
		var equipped_ids: Array = equipped_card_ids_by_character_id[character_id]
		if equipped_ids.has(equipment_id):
			return character_id

	return &""


func is_equipment_equipped(equipment: CardDefinition) -> bool:
	return equipment != null and not String(get_equipment_owner_id(equipment.id)).is_empty()


func can_equip_card(character: CardDefinition, equipment: CardDefinition) -> bool:
	if is_game_over:
		return false

	if character == null or equipment == null:
		return false

	if not character.is_character() or not equipment.is_equipment():
		return false

	if not office.owned_cards.has(character) or not office.owned_cards.has(equipment):
		return false

	if is_equipment_equipped(equipment):
		return false

	return get_equipped_card_ids(character.id).size() < MAX_EQUIPMENT_PER_CHARACTER


func equip_card(character: CardDefinition, equipment: CardDefinition) -> bool:
	if not can_equip_card(character, equipment):
		return false

	var equipped_ids := get_equipped_card_ids(character.id)
	equipped_ids.append(equipment.id)
	equipped_card_ids_by_character_id[character.id] = equipped_ids
	state_changed.emit()
	return true


func unequip_card(character: CardDefinition, equipment_id: StringName) -> bool:
	if character == null or not character.is_character():
		return false

	var equipped_ids := get_equipped_card_ids(character.id)
	if not equipped_ids.has(equipment_id):
		return false

	equipped_ids.erase(equipment_id)
	if equipped_ids.is_empty():
		equipped_card_ids_by_character_id.erase(character.id)
	else:
		equipped_card_ids_by_character_id[character.id] = equipped_ids

	state_changed.emit()
	return true


func get_effective_stats(card: CardDefinition) -> StatBlock:
	var stats := StatBlock.new()
	if card == null or card.stats == null:
		return stats

	if not card.is_character():
		return card.stats.clone()

	stats = card.stats.growth_only()
	stats.add(get_character_bonus_stats(card))
	stats.add(get_character_skill_bonus_stats(card))

	for equipment in get_equipped_cards(card):
		stats.add(equipment.stats)

	return stats


func get_week() -> int:
	return tax_manager.current_week(current_day)


func get_weekday() -> int:
	return tax_manager.weekday(current_day)


func _seed_starting_cards() -> void:
	for card in ContentCatalog.cards:
		if card != null and card.tags.has(STARTING_CARD_TAG):
			office.add_card(card)


func _refresh_hire_candidates() -> void:
	for candidate in hire_candidates:
		if candidate != null:
			ContentCatalog.unregister_runtime_card(candidate.id)
			generated_character_ids.erase(candidate.id)
	hire_candidates.clear()

	var basic_jobs: Array[JobDefinition] = []
	for job in ContentCatalog.jobs:
		if job != null and job.is_basic_job():
			basic_jobs.append(job)

	if basic_jobs.is_empty() or ContentCatalog.species.is_empty():
		return

	for candidate_index in HIRE_CANDIDATE_COUNT:
		var candidate := _generate_hire_candidate(basic_jobs, candidate_index)
		hire_candidates.append(candidate)
		generated_character_ids.append(candidate.id)
		ContentCatalog.register_runtime_card(candidate)


func _refresh_daily_requests() -> void:
	for available_request in office.available_requests.duplicate():
		if available_request.tags.has(DAILY_REQUEST_TAG) or available_request.tags.has(DAILY_INCOME_TAG):
			office.available_requests.erase(available_request)

	var daily_request_pool: Array[RequestDefinition] = []
	var daily_income_pool: Array[RequestDefinition] = []
	for request in ContentCatalog.requests:
		if request == null:
			continue
		if request.tags.has(DAILY_REQUEST_TAG):
			daily_request_pool.append(request)
		elif request.tags.has(DAILY_INCOME_TAG):
			daily_income_pool.append(request)

	if not daily_request_pool.is_empty():
		office.add_available_request(daily_request_pool[recruit_rng.randi_range(0, daily_request_pool.size() - 1)])
	if not daily_income_pool.is_empty():
		office.add_available_request(daily_income_pool[recruit_rng.randi_range(0, daily_income_pool.size() - 1)])


func _generate_hire_candidate(basic_jobs: Array[JobDefinition], candidate_index: int) -> CardDefinition:
	var job := basic_jobs[recruit_rng.randi_range(0, basic_jobs.size() - 1)]
	var species_definition: Variant = ContentCatalog.species[recruit_rng.randi_range(0, ContentCatalog.species.size() - 1)]
	var candidate := CardDefinition.new()
	recruit_serial += 1
	candidate.id = StringName("random_recruit_%s_%s_%s" % [current_day, recruit_serial, candidate_index])
	candidate.display_name = "%s %s" % [
		RECRUIT_LAST_NAMES[recruit_rng.randi_range(0, RECRUIT_LAST_NAMES.size() - 1)],
		RECRUIT_FIRST_NAMES[recruit_rng.randi_range(0, RECRUIT_FIRST_NAMES.size() - 1)],
	]
	candidate.card_type = GameEnums.CardType.CHARACTER
	candidate.growth = _generate_recruit_growth()
	candidate.skill_ids = _generate_recruit_personal_skills()
	candidate.species = species_definition.id
	candidate.job = job.id
	candidate.stats = _calculate_initial_stats(candidate.growth, candidate.species, candidate.job)
	candidate.weekly_wage = maxi(10, candidate.stats.total() + recruit_rng.randi_range(4, 10))
	candidate.tags = PackedStringArray(["hireable", "character", "random_recruit"])
	return candidate


func _generate_recruit_growth() -> StatBlock:
	var growth := StatBlock.new()
	growth.strength = 10
	growth.agility = 10
	growth.intelligence = 10
	growth.charm = 10
	growth.health = 10
	var target_total := recruit_rng.randi_range(10, 12) * 10
	var points_to_distribute := target_total - growth.total()
	var stat_names := StatBlock.GROWTH_STAT_NAMES
	while points_to_distribute > 0:
		var stat_name: String = stat_names[recruit_rng.randi_range(0, stat_names.size() - 1)]
		growth.set(stat_name, int(growth.get(stat_name)) + 10)
		points_to_distribute -= 10
	return growth


func _calculate_initial_stats(personal_growth: StatBlock, species_id: StringName, job_id: StringName) -> StatBlock:
	var total_growth := StatBlock.new()
	if personal_growth != null:
		total_growth.add(personal_growth)
	total_growth.add(ContentCatalog.get_species_growth(species_id))
	total_growth.add(ContentCatalog.get_job_growth(job_id))
	return total_growth.floor_divided(GROWTH_POINTS_PER_STAT)


func _generate_recruit_personal_skills() -> PackedStringArray:
	var skills := PackedStringArray()
	var first_index := recruit_rng.randi_range(0, RECRUIT_PERSONAL_SKILLS.size() - 1)
	skills.append(RECRUIT_PERSONAL_SKILLS[first_index])
	if recruit_rng.randf() < 0.3:
		var second_index := recruit_rng.randi_range(0, RECRUIT_PERSONAL_SKILLS.size() - 1)
		while second_index == first_index:
			second_index = recruit_rng.randi_range(0, RECRUIT_PERSONAL_SKILLS.size() - 1)
		skills.append(RECRUIT_PERSONAL_SKILLS[second_index])
	return skills


func _clear_generated_characters() -> void:
	for character_id in generated_character_ids:
		ContentCatalog.unregister_runtime_card(character_id)
	generated_character_ids.clear()
	hire_candidates.clear()


func _stat_display_name(stat_name: String) -> String:
	match stat_name:
		"strength":
			return "힘"
		"agility":
			return "민첩"
		"intelligence":
			return "지능"
		"charm":
			return "매력"
		"health":
			return "체력"
	return stat_name


func _record_tax_payment(amount: int) -> void:
	last_tax_payment_day = current_day
	last_tax_payment_week = get_week()
	last_tax_payment_amount = amount


func _clear_last_tax_payment() -> void:
	last_tax_payment_day = 0
	last_tax_payment_week = 0
	last_tax_payment_amount = 0


func _get_mutable_character_bonus_stats(character_id: StringName) -> StatBlock:
	var stats := character_bonus_stats_by_id.get(character_id, null) as StatBlock
	if stats == null:
		stats = StatBlock.new()
		character_bonus_stats_by_id[character_id] = stats

	return stats


func _get_mutable_character_job_levels(character_id: StringName) -> Dictionary:
	var levels: Dictionary = character_job_levels_by_id.get(character_id, {})
	if not character_job_levels_by_id.has(character_id):
		character_job_levels_by_id[character_id] = levels
	return levels


func _get_mutable_character_job_history(character_id: StringName) -> Array:
	var history: Array = character_job_history_by_id.get(character_id, [])
	if not character_job_history_by_id.has(character_id):
		character_job_history_by_id[character_id] = history
	return history


func _set_game_over(reason: String) -> void:
	is_game_over = true
	game_over_reason = reason
	game_over.emit(reason)
	state_changed.emit()
