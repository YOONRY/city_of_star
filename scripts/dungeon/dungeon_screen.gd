extends Control
class_name DungeonScreen

signal finished

const BoardArt := preload("res://scripts/ui/notice_board_art.gd")
const MapView := preload("res://scripts/dungeon/dungeon_map_view.gd")
const LIGHT := Color("#F2EBDD")
const INK := Color("#2E2A24")
const MANA_INK := Color("#255C60")

var run: DungeonRun
var art: BoardArt
var map: MapView
var phase_label: Label
var objective_label: Label
var journal_label: Label
var party_labels: Array[Label] = []
var party_cards: Array[PanelContainer] = []
var action_buttons: Dictionary = {}
var end_turn_button: Button
var retreat_dialog: ConfirmationDialog
var selected_action: int = DungeonRun.Action.STRIKE
var explore_route: Array[Vector2i] = []
var clock := 0.0
var observed_turn := -1
var message := ""


func _ready() -> void:
	if art == null:
		art = BoardArt.new()
	_build()
	_refresh_view()


func _build() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := ColorRect.new()
	backdrop.color = Color("#10191E")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, 26)
	add_child(margins)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margins.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	layout.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	title_box.add_child(_label(GameState.DUNGEON_TITLE, 26, LIGHT))
	objective_label = _label("", 14, Color("#AAC0B8"))
	title_box.add_child(objective_label)
	phase_label = _label("", 17, Color("#E6C28C"))
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(phase_label)
	var retreat_button := _button("철수", false)
	retreat_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	retreat_button.pressed.connect(func() -> void: retreat_dialog.popup_centered())
	header.add_child(retreat_button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var map_frame := _panel(_flat(Color("#253539"), Color("#49605F"), 4))
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(map_frame)
	map = MapView.new()
	map.run = run
	map.cell_pressed.connect(_on_cell_pressed)
	map_frame.add_child(map)

	var sidebar := _panel(art.board)
	sidebar.custom_minimum_size.x = 306
	body.add_child(sidebar)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 10)
	sidebar.add_child(panel)
	panel.add_child(_label("탐사대", 18, LIGHT))
	for member in run.allies:
		var sheet := _panel(art.note)
		panel.add_child(sheet)
		var label := _label("", 14, INK)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sheet.add_child(label)
		party_cards.append(sheet)
		party_labels.append(label)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(space)
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	panel.add_child(actions)
	for action in DungeonRun.ACTIONS:
		var cost: Dictionary = DungeonRun.ACTIONS[action]
		var caption := "%s\n%s AP · %s MP" % [cost.title, cost.ap, cost.mp]
		var button := _button(caption, false)
		button.toggle_mode = true
		button.custom_minimum_size.y = 56
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "사거리 %s칸" % cost.range
		button.pressed.connect(_select_action.bind(action))
		actions.add_child(button)
		action_buttons[action] = button
	end_turn_button = _button("턴 종료", true)
	end_turn_button.pressed.connect(_end_turn)
	actions.add_child(end_turn_button)

	var journal := _panel(_flat(Color("#202D32"), Color("#425655"), 10))
	layout.add_child(journal)
	journal_label = _label("", 13, LIGHT)
	journal_label.custom_minimum_size.y = 38
	journal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal.add_child(journal_label)

	retreat_dialog = ConfirmationDialog.new()
	retreat_dialog.title = "탐사 철수"
	retreat_dialog.dialog_text = "이번 탐사를 끝내고 철수합니다. 사무소로 돌아오는 데 하루가 걸립니다."
	retreat_dialog.ok_button_text = "철수"
	retreat_dialog.cancel_button_text = "계속 탐사"
	retreat_dialog.confirmed.connect(_retreat)
	add_child(retreat_dialog)


func _process(delta: float) -> void:
	if run == null or run.result != DungeonRun.Result.ACTIVE or retreat_dialog.visible:
		return
	clock -= delta
	if clock > 0:
		return
	var actor := run.actor()
	if actor != null and not actor.is_ally():
		run.perform_enemy_turn()
		_after_action()
	elif not run.in_combat() and not explore_route.is_empty():
		var next: Vector2i = explore_route.pop_front()
		if not run.explore_step(next):
			explore_route.clear()
		clock = 0.095
		_after_action()


func _on_cell_pressed(cell: Vector2i) -> void:
	if run.result != DungeonRun.Result.ACTIVE:
		return
	message = ""
	if not run.in_combat():
		explore_route = run.path(run.leader().cell, cell)
		if not explore_route.is_empty():
			explore_route.pop_front()
			clock = 0.0
		elif map.visible_cells.has(cell) and run.unit_at(cell) != null and not run.unit_at(cell).is_ally():
			# Clicking a sentry walks toward it until sight starts the encounter.
			var closest: Array[Vector2i] = []
			for direction in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
				var route := run.path(run.leader().cell, cell + direction)
				if not route.is_empty() and (closest.is_empty() or route.size() < closest.size()):
					closest = route
			if not closest.is_empty():
				closest.pop_front()
				explore_route = closest
				clock = 0.0
		return
	if not run.actor().is_ally():
		return
	var unit := run.unit_at(cell)
	if unit == null:
		if not run.move_in_combat(cell):
			message = "이동할 수 없는 칸입니다."
	else:
		message = run.action_error(selected_action, unit)
		if message.is_empty():
			run.use_action(selected_action, unit)
	_after_action()


func _unhandled_key_input(event: InputEvent) -> void:
	if run.result != DungeonRun.Result.ACTIVE or retreat_dialog.visible:
		return
	var direction := Vector2i.ZERO
	if event.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif event.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT
	elif event.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN
	if direction == Vector2i.ZERO:
		return
	explore_route.clear()
	var unit := run.actor() if run.in_combat() else run.leader()
	if unit != null and unit.is_ally():
		_on_cell_pressed(unit.cell + direction)
	get_viewport().set_input_as_handled()


func _select_action(action: int) -> void:
	selected_action = action
	message = ""
	_refresh_view()


func _end_turn() -> void:
	if run.actor() != null and run.actor().is_ally():
		run.end_turn()
		_after_action()


func _retreat() -> void:
	run.retreat()
	_after_action()


func _after_action() -> void:
	if run.result != DungeonRun.Result.ACTIVE:
		finished.emit()
		return
	if run.in_combat():
		explore_route.clear()
	_refresh_view()


func _refresh_view() -> void:
	var unit := run.actor()
	var ally_turn := unit != null and unit.is_ally()
	if run.turn_serial != observed_turn:
		observed_turn = run.turn_serial
		selected_action = DungeonRun.Action.STRIKE
		if unit != null and not unit.is_ally():
			clock = 0.32
		message = ""
	phase_label.text = "탐색" if unit == null else "%s의 턴 · %s라운드" % [unit.title, run.round_number]
	if run.in_combat():
		objective_label.text = "1층 · 전투 %s/%s" % [run.encounters_cleared + 1, DungeonLayout.ENCOUNTER_COUNT]
	else:
		objective_label.text = "1층 · 전투 완료 %s/%s" % [run.encounters_cleared, DungeonLayout.ENCOUNTER_COUNT]
	if run.encounters_cleared == DungeonLayout.ENCOUNTER_COUNT:
		objective_label.text += " · 동쪽 출구 개방"
	for index in run.allies.size():
		var ally := run.allies[index]
		var ap_text := "  AP %s/%s" % [ally.ap, DungeonRun.MAX_AP] if ally == unit else ""
		party_labels[index].text = "%s\nHP %s/%s  MP %s/%s%s" % [ally.title, ally.hp, ally.max_hp, ally.mp, ally.max_mp, ap_text]
		party_cards[index].add_theme_stylebox_override("panel", art.completed_note if ally == unit else art.note)
		party_cards[index].modulate = Color.WHITE if ally.is_alive() else Color("#b3a99f")
	for action in action_buttons:
		var button: Button = action_buttons[action]
		var cost: Dictionary = DungeonRun.ACTIONS[action]
		button.disabled = not ally_turn or unit.ap < int(cost.ap) or unit.mp < int(cost.mp)
		button.set_pressed_no_signal(action == selected_action and ally_turn and not button.disabled)
	end_turn_button.disabled = not ally_turn
	var lines := run.log_lines.slice(maxi(0, run.log_lines.size() - 2))
	if not message.is_empty():
		lines = PackedStringArray([run.log_lines[-1], message])
	journal_label.text = "\n".join(lines)
	map.selected_action = selected_action
	map.queue_redraw()


func _label(value: String, font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	return label


func _panel(style: StyleBox) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _button(caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	var color := Color("#3F675F") if primary else Color("#DED5C2")
	var edge := Color("#79928A") if primary else Color("#9B8F77")
	button.add_theme_stylebox_override("normal", _flat(color, edge, 8))
	button.add_theme_stylebox_override("hover", _flat(color.lightened(0.10), edge, 8))
	button.add_theme_stylebox_override("pressed", _flat(Color("#ACC7B5"), Color("#47756D"), 8))
	button.add_theme_stylebox_override("disabled", _flat(Color("#B0A596"), Color("#80715F"), 8))
	button.add_theme_color_override("font_color", LIGHT if primary else INK)
	button.add_theme_color_override("font_hover_color", LIGHT if primary else INK)
	button.add_theme_color_override("font_pressed_color", MANA_INK)
	button.add_theme_color_override("font_disabled_color", Color("#4A4237"))
	return button


func _flat(background: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style
