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

var current_day: int = 1
var office := OfficeState.new()
var tax_manager := TaxManager.new(STARTING_WEEKLY_TAX, TAX_DUE_WEEKDAY)
var is_game_over: bool = false
var game_over_reason: String = ""

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


func get_week() -> int:
	return tax_manager.current_week(current_day)


func get_weekday() -> int:
	return tax_manager.weekday(current_day)


func _seed_starting_cards() -> void:
	for card in ContentCatalog.cards:
		if card != null and card.tags.has(STARTING_CARD_TAG):
			office.add_card(card)


func _set_game_over(reason: String) -> void:
	is_game_over = true
	game_over_reason = reason
	game_over.emit(reason)
	state_changed.emit()
