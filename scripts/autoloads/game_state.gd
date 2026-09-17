extends Node
class_name CityGameState

signal state_changed
signal day_advanced(day: int)
signal tax_due(amount: int)
signal game_over(reason: String)

const STARTING_MONEY := 100
const STARTING_WEEKLY_TAX := 80
const TAX_DUE_WEEKDAY := 7
const STARTING_CARD_TAG := "starter"
const MAX_EQUIPMENT_PER_CHARACTER := 3

var current_day: int = 1
var office := OfficeState.new()
var tax_manager := TaxManager.new(STARTING_WEEKLY_TAX, TAX_DUE_WEEKDAY)
var is_game_over: bool = false
var game_over_reason: String = ""
var last_tax_payment_day: int = 0
var last_tax_payment_week: int = 0
var last_tax_payment_amount: int = 0
var equipped_card_ids_by_character_id: Dictionary = {}

func _ready() -> void:
	reset_game()


func reset_game() -> void:
	current_day = 1
	office = OfficeState.new()
	office.reset(STARTING_MONEY)
	_seed_starting_cards()
	tax_manager = TaxManager.new(STARTING_WEEKLY_TAX, TAX_DUE_WEEKDAY)
	is_game_over = false
	game_over_reason = ""
	equipped_card_ids_by_character_id.clear()
	_clear_last_tax_payment()
	state_changed.emit()


func advance_day() -> void:
	if is_game_over:
		return

	if tax_manager.is_due(current_day) and not tax_manager.has_paid_current_week(current_day):
		_set_game_over("Weekly tax was not paid.")
		return

	current_day += 1

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

	return office.money >= get_hire_cost(card)


func hire_card(card: CardDefinition) -> bool:
	if not can_hire_card(card):
		return false

	office.money -= get_hire_cost(card)
	office.add_card(card)
	state_changed.emit()
	return true


func get_hire_cost(card: CardDefinition) -> int:
	if card == null:
		return 0

	return maxi(0, card.weekly_wage)


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

	stats = card.stats.clone()
	if not card.is_character():
		return stats

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


func _record_tax_payment(amount: int) -> void:
	last_tax_payment_day = current_day
	last_tax_payment_week = get_week()
	last_tax_payment_amount = amount


func _clear_last_tax_payment() -> void:
	last_tax_payment_day = 0
	last_tax_payment_week = 0
	last_tax_payment_amount = 0


func _set_game_over(reason: String) -> void:
	is_game_over = true
	game_over_reason = reason
	game_over.emit(reason)
	state_changed.emit()
