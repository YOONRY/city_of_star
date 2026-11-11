extends Node

const SHOP := GameEnums.Facility.SHOP
const PERSONNEL := GameEnums.Facility.PERSONNEL

var failures := PackedStringArray()

func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	GameState.reset_game()
	var runner := ContentCatalog.get_card(&"night_runner")
	var mediator := ContentCatalog.get_card(&"street_mediator")
	var knife := ContentCatalog.get_card(&"field_knife")
	var tonic := ContentCatalog.get_card(&"quick_tonic")
	var revolver := ContentCatalog.get_card(&"old_revolver")
	GameState.player_character_id = runner.id
	var recruit: CardDefinition = GameState.hire_candidates[0]
	var starting_money := GameState.office.money
	_check(not GameState.buy_shop_card(knife) and not GameState.sell_shop_card(tonic), "Cannot trade without an assigned character")
	_check(GameState.get_shop_cards(false).is_empty(), "Unstaffed shop has no visible stock")
	_check(GameState.get_hire_candidates().is_empty() and not GameState.hire_card(recruit), "Unstaffed personnel office cannot show or hire candidates")
	_check(not GameState.assign_facility(SHOP, tonic), "An item cannot staff a facility")
	_check(not GameState.assign_facility(SHOP, recruit), "An unowned character cannot staff a facility")
	_check(GameState.equip_card(runner, revolver), "Equip a card before testing sales")

	var screen := preload("res://scenes/main/main.tscn").instantiate() as Control
	get_tree().root.add_child(screen)
	var events: VBoxContainer = screen.get("event_list")
	var drawer: PanelContainer = screen.get("inventory_drawer")
	var title: Label = screen.get("inventory_drawer_title")
	var balance: Label = screen.get("facility_balance_label")
	var cards: VBoxContainer = screen.get("inventory_card_list")
	var tabs: TabBar = screen.get("shop_tabs")
	var close_button: Button = screen.get("inventory_close_button")
	var next_day_button: Button = screen.get("next_day_button")
	await _click(_find_button(events, "상점"))
	_check(not drawer.visible and _find_button(events, "상점 열기") == null, "Opening the event alone cannot open the shop")
	await _click(_find_button(events, "내일 담당 인물\n미배치"))
	_check(drawer.visible and title.text == "상점 담당 인물 선택" and not tabs.visible, "Facility slot opens the roster picker")
	await _click(_character_row(cards, runner))
	_check(not drawer.visible and GameState.get_facility_character(SHOP) == null, "Choosing a character stages the assignment without opening the shop")
	await _click(_find_button(events, "배치 확정"))
	_check(GameState.get_facility_character(SHOP) == runner and not drawer.visible, "Confirming reserves the chosen character without opening the shop")
	_check(not GameState.is_facility_open(SHOP) and not GameState.buy_shop_card(knife), "The confirmed shop remains closed until the next day")
	_check(not GameState.can_assign_facility(PERSONNEL, runner), "One character cannot staff both facilities")
	_check(not GameState.can_assign_job_training(runner), "Facility staff cannot be sent to training")
	_check(not GameState.can_queue_daily_request(GameState.office.available_requests[0], runner), "Facility staff cannot be sent on daily requests")

	_press(events, "인력 사무소")
	_press(events, "내일 담당 인물\n미배치")
	_pick_character(cards, runner)
	_check(GameState.get_facility_character(PERSONNEL) == null and title.text.ends_with("담당 인물 선택"), "Busy roster rows cannot be selected")
	_pick_character(cards, mediator)
	_check(not drawer.visible and GameState.get_facility_character(PERSONNEL) == null, "Personnel selection also requires confirmation")
	_press(events, "배치 확정")
	_check(GameState.get_hire_candidates().is_empty() and not GameState.hire_card(recruit), "Confirmed staffing cannot hire on the current day")
	_press(events, "배치 취소")
	_check(GameState.get_character_event_assignment(mediator).is_empty(), "Confirmed staffing can be cancelled before the next day")
	_press(events, "내일 담당 인물\n미배치")
	_pick_character(cards, mediator)
	_press(events, "배치 확정")

	var requester := ContentCatalog.get_card(&"clinic_fixer")
	var trainee := ContentCatalog.get_card(&"ledger_savant")
	GameState.office.add_card(requester)
	GameState.office.add_card(trainee)
	_check(GameState.queue_daily_request(GameState.office.available_requests[0], requester), "Queue a daily request alongside facility assignments")
	_check(GameState.assign_job_training(trainee), "Queue training alongside facility assignments")
	await _click(next_day_button)
	var settlement: PanelContainer = screen.get("settlement_popup")
	_check(GameState.current_day == 2 and settlement.visible and not drawer.visible, "The day advances and settlement has priority over the facilities")
	screen.call("_close_settlement_popup")
	_check(GameState.has_pending_job_change() and not drawer.visible, "The facility queue waits for training too")
	screen.call("_on_training_job_selected", &"Fighter")
	_check(drawer.visible and title.text == "상점" and tabs.visible and tabs.current_tab == 0, "The first confirmed facility automatically opens on the next day")
	_check(GameState.get_character_event_assignment(runner).is_empty() and GameState.get_character_event_assignment(mediator).is_empty(), "Completed staffing does not occupy the characters on the new day")
	_check(GameState.is_facility_open(PERSONNEL) and not GameState.get_hire_candidates().has(recruit), "Hiring uses the refreshed candidate list")

	var trade_budget := GameState.office.money
	GameState.office.money = 0
	GameState.state_changed.emit()
	var buy_text := "구매 %s" % knife.shop_price
	_check(_button_disabled(cards, buy_text) and not GameState.buy_shop_card(knife), "Insufficient funds block purchase in the UI and state")
	GameState.office.money = trade_budget
	GameState.state_changed.emit()
	_press(cards, buy_text)
	_check(GameState.office.owned_cards.has(knife), "Purchase adds the equipment to owned cards")
	_check(GameState.office.money == trade_budget - knife.shop_price and balance.text.ends_with(str(GameState.office.money)), "Purchase deducts and displays the exact price")
	_check(not GameState.buy_shop_card(knife), "Already owned cards cannot be bought twice")

	tabs.current_tab = 1
	var revolver_sale_text := "판매 %s" % GameState.get_shop_sale_price(revolver)
	_check(_button_disabled(cards, revolver_sale_text) and not GameState.sell_shop_card(revolver), "Equipped items cannot be sold")
	_check(not GameState.sell_shop_card(runner), "Characters cannot be sold")
	var sale_price := GameState.get_shop_sale_price(tonic)
	_press(cards, "판매 %s" % sale_price)
	_check(not GameState.office.owned_cards.has(tonic), "Selling removes an owned consumable")
	_check(GameState.office.money == trade_budget - knife.shop_price + sale_price, "Sale adds the resale price")
	_check(tabs.current_tab == 1 and not GameState.sell_shop_card(tonic), "Sale stays on the sell tab and cannot be repeated")
	_check(GameState.unequip_card(runner, revolver.id), "Unequip an item to make it sellable")
	_check(not _button_disabled(cards, revolver_sale_text), "Unequipped equipment becomes sellable")

	for viewport_size in [Vector2i(1280, 720), Vector2i(1024, 640)]:
		get_tree().root.size = viewport_size
		for frame in 3:
			await get_tree().process_frame
		var rect := drawer.get_global_rect()
		_check(screen.get_global_rect().encloses(rect) and rect.encloses(next_day_button.get_global_rect()), "Drawer fits and covers the dock at %s" % viewport_size)
	close_button.pressed.emit()
	_check(drawer.visible and title.text == "인력 사무소" and not tabs.visible, "Closing the shop opens the next confirmed facility")
	var outside := InputEventMouseButton.new()
	outside.position = Vector2(12, 12)
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	screen.call("_input", outside)
	_check(not drawer.visible, "Outside click dismisses the last queued facility")

	_press(events, "인력 사무소")
	_press(events, "고용 목록 열기")
	_check(drawer.visible and title.text == "인력 사무소", "An unlocked facility can reopen for the rest of the day")
	var candidates := GameState.get_hire_candidates()
	var previous_money := GameState.office.money
	var previous_roster := GameState.office.owned_cards.size()
	_press(cards.get_child(0), "고용")
	var hired := GameState.office.owned_cards.back() as CardDefinition
	_check(GameState.office.owned_cards.size() == previous_roster + 1, "Hiring moves a candidate into owned cards")
	_check(candidates.has(hired) and not GameState.get_hire_candidates().has(hired), "Hired characters are removed from the candidate list")
	_check(GameState.office.money == previous_money - GameState.get_hire_cost(hired), "Hiring deducts the candidate's price")
	close_button.pressed.emit()
	_press(events, "상점")
	_press(events, "내일 담당 인물\n미배치")
	_pick_character(cards, runner)
	_check(_find_button(events, "배치 확정") != null, "An available facility can be staffed for tomorrow again")
	next_day_button.pressed.emit()
	_check(GameState.current_day == 3 and not drawer.visible, "Skipping confirmation never schedules the next day's facility")
	_check(not GameState.is_facility_open(SHOP) and not GameState.is_facility_open(PERSONNEL), "Facilities expire without another confirmed assignment")
	_check(GameState.queue_daily_request(GameState.office.available_requests[0], runner), "Released staff can take another day's request")
	_check(not GameState.can_assign_facility(SHOP, runner), "Daily request staff cannot be assigned to a facility")
	GameState.reset_game()
	_check(GameState.get_character_event_assignment(runner).is_empty() and GameState.office.money == starting_money, "Game reset clears assignments and transactions")
	screen.free()
	if failures.is_empty():
		print("Facility checks passed.")
	get_tree().quit(0 if failures.is_empty() else 1)


func _character_row(container: Node, character: CardDefinition) -> Control:
	for row in container.get_children():
		for label in row.find_children("*", "Label", true, false):
			if label.text == character.label():
				return row as Control
	_check(false, "Missing character row: %s" % character.label())
	return null


func _click(control: Control) -> void:
	_check(control != null, "Control exists for viewport click")
	if control == null:
		return
	for frame in 3:
		await get_tree().process_frame
	var position := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		get_tree().root.push_input(click, true)


func _pick_character(container: Node, character: CardDefinition) -> void:
	var row := _character_row(container, character)
	if row != null:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		row.gui_input.emit(click)


func _find_button(root: Node, caption: String) -> Button:
	for button in root.find_children("*", "Button", true, false):
		if button.text == caption:
			return button
	return null


func _button_disabled(root: Node, caption: String) -> bool:
	var button := _find_button(root, caption)
	return button != null and button.disabled


func _press(root: Node, caption: String) -> void:
	var button := _find_button(root, caption)
	_check(button != null and not button.disabled, "Enabled button exists: %s" % caption)
	if button != null and not button.disabled:
		button.pressed.emit()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
