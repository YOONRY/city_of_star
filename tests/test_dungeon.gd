extends Node

var failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await _test_full_expedition()
	_test_retreat()
	_test_party_initiative()
	if failures.is_empty():
		print("Dungeon checks passed.")
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_full_expedition() -> void:
	GameState.reset_game()
	var runner := ContentCatalog.get_card(&"night_runner")
	var mediator := ContentCatalog.get_card(&"street_mediator")
	var requester := ContentCatalog.get_card(&"clinic_fixer")
	var trainee := ContentCatalog.get_card(&"ledger_savant")
	GameState.player_character_id = runner.id
	GameState.office.add_card(requester)
	GameState.office.add_card(trainee)
	var screen := preload("res://scenes/main/main.tscn").instantiate() as Control
	get_tree().root.add_child(screen)
	var events: VBoxContainer = screen.get("event_list")
	var detail: VBoxContainer = screen.get("event_detail_content")
	var picker: VBoxContainer = screen.get("inventory_card_list")
	await _click(_button(events, GameState.DUNGEON_TITLE))
	await _click(_button(detail, "탐사 인원\n0/3"))
	await _click(_character_row(picker, runner.label()))
	await _click(_button(detail, "배치 확정"))
	_check(GameState.dungeon_status == GameState.DungeonStatus.SCHEDULED and GameState.dungeon_party_ids == [runner.id], "The roster picker confirms a dungeon party")
	_check(GameState.begin_dungeon() == null, "A scheduled party cannot enter the same day")
	_check(not GameState.can_assign_facility(GameEnums.Facility.SHOP, runner), "A scheduled member cannot staff a facility")
	_check(not GameState.can_queue_daily_request(GameState.office.available_requests[0], runner), "A scheduled member cannot accept a daily request")
	_check(GameState.queue_daily_request(GameState.office.available_requests[0], requester), "Queue an ordinary request alongside the dungeon")
	_check(GameState.assign_job_training(trainee), "Queue training alongside the dungeon")
	_check(GameState.assign_facility(GameEnums.Facility.SHOP, mediator), "Queue a staffed facility alongside the dungeon")
	await _click(screen.get("next_day_button") as Button)
	_check(GameState.current_day == 2 and screen.get("dungeon_screen") == null, "Daily settlement comes before the dungeon")
	screen.call("_close_settlement_popup")
	_check(GameState.has_pending_job_change() and screen.get("dungeon_screen") == null, "Training comes before the dungeon")
	screen.call("_on_training_job_selected", &"Fighter")
	var drawer: PanelContainer = screen.get("inventory_drawer")
	_check(drawer.visible and screen.get("dungeon_screen") == null, "The shop opens before the dungeon")
	await _click(screen.get("inventory_close_button") as Button)
	var dungeon: DungeonScreen = screen.get("dungeon_screen")
	_check(dungeon != null and GameState.dungeon_status == GameState.DungeonStatus.EXPLORING, "Closing the last facility automatically enters the dungeon")
	if dungeon == null:
		screen.free()
		return
	GameState.advance_day()
	_check(GameState.current_day == 2, "The calendar cannot advance during exploration")
	var run := dungeon.run
	var map := dungeon.map
	var guide := run.leader()
	_check(not run.in_combat() and not run.is_open(DungeonLayout.GATE[0]), "The party begins at the entrance with the gate closed")
	_check(not run.explore_step(Vector2i.ZERO), "The explorer cannot step through walls")
	_check(run.path(guide.cell, DungeonLayout.EXIT).is_empty(), "The first battle cannot be bypassed")

	for viewport_size in [Vector2i(1280, 720), Vector2i(1024, 640)]:
		get_tree().root.size = viewport_size
		for frame in 3:
			await get_tree().process_frame
		_check(dungeon.get_global_rect().encloses(map.get_global_rect()), "The map fits at %s" % viewport_size)
	var first_room := Vector2i(9, 5)
	var side: int = map.call("_cell_size")
	var origin: Vector2 = map.call("_origin", side)
	_send_click(map.get_global_rect().position + origin + Vector2(first_room * side) + Vector2.ONE * (side * 0.5))
	for tick in 30:
		if run.in_combat():
			break
		dungeon.call("_process", 0.2)
	_check(run.in_combat() and dungeon.map == map and run.actor() == guide, "Clicking the map starts combat on that same map")
	if not run.in_combat():
		screen.free()
		return
	var first_enemy := run.enemies[0]
	_check(guide.ap == DungeonRun.MAX_AP, "A turn starts with full AP")
	_check(run.use_action(DungeonRun.Action.BOLT, first_enemy), "A visible target in range can be hit with a mana skill")
	_check(guide.ap == 1 and guide.mp == DungeonRun.MAX_MP - 2, "A mana skill spends both AP and MP")
	_check(not run.use_action(DungeonRun.Action.BOLT, first_enemy), "An unaffordable action is blocked")
	run.end_turn()
	for step in 4:
		if run.actor() == guide:
			break
		run.perform_enemy_turn()
	_check(guide.ap == DungeonRun.MAX_AP and guide.mp == DungeonRun.MAX_MP - 2, "The next turn restores AP but not MP")
	_finish_battle(run)
	_check(run.encounters_cleared == 1 and not run.in_combat() and run.is_open(DungeonLayout.GATE[0]), "Defeating the first encounter opens the gate and resumes exploration")
	var hp_after_first := guide.hp
	var mp_after_first := guide.mp
	_walk(run, Vector2i(20, 5))
	_check(run.in_combat() and run.actor() == guide and guide.ap == DungeonRun.MAX_AP, "The second battle starts with fresh AP")
	_check(guide.hp == hp_after_first and guide.mp == mp_after_first and mp_after_first < guide.max_mp, "HP and MP are preserved into the second battle")
	_finish_battle(run)
	_check(run.encounters_cleared == DungeonLayout.ENCOUNTER_COUNT and run.result == DungeonRun.Result.ACTIVE, "Two battles are required and victory still needs the exit")
	_walk(run, DungeonLayout.EXIT)
	_check(run.result == DungeonRun.Result.CLEARED, "Reaching the east exit after both battles clears the expedition")
	var money_before_return := GameState.office.money
	dungeon.call("_after_action")
	_check(screen.get("dungeon_screen") == null and GameState.dungeon_status == GameState.DungeonStatus.RETURNING and GameState.dungeon_due_day == 3, "Victory returns to the office with a one-day travel delay")
	_check(GameState.office.money == money_before_return and not GameState.get_character_event_assignment(runner).is_empty(), "Rewards and party release wait for arrival")
	GameState.advance_day()
	_check(GameState.dungeon_status == GameState.DungeonStatus.CLEARED and GameState.get_character_event_assignment(runner).is_empty(), "The party is freed after one day")
	_check(GameState.office.money == money_before_return + GameState.DUNGEON_CLEAR_REWARD, "The clear reward is paid on return")
	screen.free()


func _test_retreat() -> void:
	GameState.reset_game()
	var runner := ContentCatalog.get_card(&"night_runner")
	GameState.player_character_id = runner.id
	var party: Array[StringName] = [runner.id]
	var duplicate: Array[StringName] = [runner.id, runner.id]
	_check(not GameState.schedule_dungeon(duplicate), "Duplicate party members are rejected")
	_check(GameState.schedule_dungeon(party) and GameState.cancel_dungeon_assignment(), "An assignment may be canceled before departure")
	_check(GameState.schedule_dungeon(party), "A canceled member can be scheduled again")
	GameState.advance_day()
	_check(not GameState.cancel_dungeon_assignment(), "A party cannot cancel its assignment after departure day begins")
	var run := GameState.begin_dungeon()
	if run == null:
		_check(false, "The rescheduled expedition starts")
		return
	run.retreat()
	_check(GameState.finish_dungeon() and GameState.dungeon_status == GameState.DungeonStatus.RETURNING, "Retreat has the same travel delay as a clear")
	_check(not GameState.can_assign_job_training(runner), "A retreating member is unavailable")
	GameState.advance_day()
	_check(GameState.dungeon_status == GameState.DungeonStatus.AVAILABLE and GameState.can_schedule_dungeon(party), "After retreat and return the dungeon can be attempted again")
	_check(GameState.office.money == GameState.STARTING_MONEY, "Retreat does not pay a clear reward")


func _test_party_initiative() -> void:
	var run := DungeonRun.new()
	var stats := StatBlock.new()
	stats.agility = 1
	run.add_ally("선두", stats)
	stats.agility = 5
	run.add_ally("지원", stats)
	var support_start := run.allies[1].cell
	_walk(run, Vector2i(9, 5))
	_check(run.allies[1].cell != support_start and run.allies[1].cell != run.leader().cell, "Exploration keeps companions following in separate cells")
	_check(run.actor() == run.allies[1], "The fastest unit acts first, regardless of party order")
	var support := run.allies[1]
	support.cell = Vector2i(10, 6)
	run.enemies[0].cell = Vector2i(12, 6)
	_check(not run.use_action(DungeonRun.Action.BOLT, run.enemies[0]), "A pillar blocks a ranged attack even within range")
	_check(not run.move_in_combat(Vector2i(11, 6)), "A unit cannot move into a pillar")
	_check(run.move_in_combat(Vector2i(10, 5)) and support.ap == DungeonRun.MAX_AP - 1, "A movement action costs 1 AP")
	support.mp = 0
	_check(run.action_error(DungeonRun.Action.BOLT, run.enemies[0]) == "MP가 부족합니다.", "An otherwise affordable skill cannot be used without MP")


func _walk(run: DungeonRun, destination: Vector2i) -> void:
	var guide := run.leader()
	if guide == null:
		return
	var path := run.path(guide.cell, destination)
	for index in range(1, path.size()):
		if run.in_combat() or not run.explore_step(path[index]):
			break


func _finish_battle(run: DungeonRun) -> void:
	for step in 80:
		var actor := run.actor()
		if actor == null:
			return
		if not actor.is_ally():
			run.perform_enemy_turn()
			continue
		var route: Array[Vector2i] = []
		var attacked := false
		for enemy in run.enemies:
			if run.use_action(DungeonRun.Action.STRIKE, enemy):
				attacked = true
				break
			if not enemy.is_alive() or enemy.encounter != run.encounters_cleared:
				continue
			for direction in [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN]:
				var path := run.path(actor.cell, enemy.cell + direction)
				if path.size() > 1 and (route.is_empty() or path.size() < route.size()):
					route = path
		if not attacked and (route.is_empty() or not run.move_in_combat(route[mini(DungeonRun.MOVE_RANGE, route.size() - 1)])):
			run.end_turn()


func _character_row(container: Node, caption: String) -> Control:
	for row in container.get_children():
		for label in row.find_children("*", "Label", true, false):
			if label.text == caption:
				return row as Control
	return null


func _button(container: Node, caption: String) -> Button:
	for button in container.find_children("*", "Button", true, false):
		if button.text == caption:
			return button
	return null


func _click(control: Control) -> void:
	_check(control != null, "Click target is present")
	if control == null:
		return
	for frame in 3:
		await get_tree().process_frame
	_send_click(control.get_global_rect().get_center())


func _send_click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_tree().root.push_input(event, true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
