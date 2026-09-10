extends Control

const NO_ACTIVE_DRAWER := -1

var day_value: Label
var week_value: Label
var weekday_value: Label
var money_value: Label
var tax_value: Label
var card_count_value: Label
var request_count_value: Label
var status_label: Label
var event_list: VBoxContainer
var action_panel: PanelContainer
var next_day_button: Button
var pay_tax_button: Button
var reset_button: Button
var character_card_list: VBoxContainer
var inventory_panel: PanelContainer
var inventory_drawer: PanelContainer
var inventory_drawer_title: Label
var inventory_card_list: VBoxContainer
var equipment_button: Button
var consumable_button: Button
var active_drawer_type: int = NO_ACTIVE_DRAWER
var expanded_character_card_ids: Dictionary = {}

func _ready() -> void:
	_build_ui()
	GameState.state_changed.connect(_refresh)
	ContentCatalog.catalog_reloaded.connect(_refresh)
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#101820")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 40)
	root.add_theme_constant_override("margin_right", 40)
	root.add_theme_constant_override("margin_top", 32)
	root.add_theme_constant_override("margin_bottom", 32)
	add_child(root)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	root.add_child(layout)

	var top_bar := HBoxContainer.new()
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(top_bar)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	var calendar_panel := _make_panel(Color("#14202A"), Color("#2F4659"))
	top_bar.add_child(calendar_panel)

	var calendar_metrics := GridContainer.new()
	calendar_metrics.columns = 6
	calendar_metrics.add_theme_constant_override("h_separation", 12)
	calendar_metrics.add_theme_constant_override("v_separation", 4)
	calendar_panel.add_child(calendar_metrics)

	day_value = _add_metric(calendar_metrics, "Day")
	week_value = _add_metric(calendar_metrics, "Week")
	weekday_value = _add_metric(calendar_metrics, "Weekday")

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)

	var character_panel := _make_panel()
	character_panel.custom_minimum_size = Vector2(320, 0)
	body.add_child(character_panel)

	var character_box := VBoxContainer.new()
	character_box.add_theme_constant_override("separation", 12)
	character_panel.add_child(character_box)

	character_box.add_child(_make_section_title("Character Cards"))

	var character_scroll := ScrollContainer.new()
	character_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	character_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_box.add_child(character_scroll)

	character_card_list = VBoxContainer.new()
	character_card_list.add_theme_constant_override("separation", 10)
	character_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_scroll.add_child(character_card_list)

	var event_panel := _make_panel()
	event_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(event_panel)

	var event_box := VBoxContainer.new()
	event_box.add_theme_constant_override("separation", 14)
	event_panel.add_child(event_box)

	event_box.add_child(_make_section_title("Events"))

	var event_scroll := ScrollContainer.new()
	event_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	event_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_box.add_child(event_scroll)

	event_list = VBoxContainer.new()
	event_list.add_theme_constant_override("separation", 10)
	event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_scroll.add_child(event_list)

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(300, 0)
	right_column.add_theme_constant_override("separation", 14)
	body.add_child(right_column)

	action_panel = _make_panel()
	action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_child(action_panel)

	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 12)
	action_panel.add_child(action_box)

	action_box.add_child(_make_section_title("Actions"))

	next_day_button = Button.new()
	next_day_button.text = "Next Day"
	next_day_button.pressed.connect(_on_next_day_pressed)
	action_box.add_child(next_day_button)

	pay_tax_button = Button.new()
	pay_tax_button.text = "Pay Tax"
	pay_tax_button.pressed.connect(_on_pay_tax_pressed)
	action_box.add_child(pay_tax_button)

	reset_button = Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(_on_reset_pressed)
	action_box.add_child(reset_button)

	var office_metrics := GridContainer.new()
	office_metrics.columns = 2
	office_metrics.add_theme_constant_override("h_separation", 20)
	office_metrics.add_theme_constant_override("v_separation", 8)
	action_box.add_child(office_metrics)

	money_value = _add_metric(office_metrics, "Money")
	tax_value = _add_metric(office_metrics, "Tax")
	card_count_value = _add_metric(office_metrics, "Cards")
	request_count_value = _add_metric(office_metrics, "Events")

	status_label = _make_label("", 13)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_box.add_child(status_label)

	inventory_panel = _make_panel()
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(inventory_panel)

	var inventory_box := VBoxContainer.new()
	inventory_box.add_theme_constant_override("separation", 12)
	inventory_panel.add_child(inventory_box)

	inventory_box.add_child(_make_section_title("Inventory"))

	var inventory_buttons := HBoxContainer.new()
	inventory_buttons.add_theme_constant_override("separation", 10)
	inventory_box.add_child(inventory_buttons)

	equipment_button = _make_icon_button("res://assets/icons/chest_icon.svg", "Equipment Cards")
	equipment_button.pressed.connect(_on_equipment_pressed)
	inventory_buttons.add_child(equipment_button)

	consumable_button = _make_icon_button("res://assets/icons/potion_icon.svg", "Consumable Cards")
	consumable_button.pressed.connect(_on_consumable_pressed)
	inventory_buttons.add_child(consumable_button)

	inventory_drawer = _make_panel(Color("#121B24"), Color("#38556A"))
	inventory_drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_drawer.visible = false
	inventory_box.add_child(inventory_drawer)

	var drawer_box := VBoxContainer.new()
	drawer_box.add_theme_constant_override("separation", 10)
	inventory_drawer.add_child(drawer_box)

	inventory_drawer_title = _make_label("", 16)
	inventory_drawer_title.add_theme_color_override("font_color", Color("#F4C95D"))
	drawer_box.add_child(inventory_drawer_title)

	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_box.add_child(inventory_scroll)

	inventory_card_list = VBoxContainer.new()
	inventory_card_list.add_theme_constant_override("separation", 10)
	inventory_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.add_child(inventory_card_list)


func _make_panel(background_color: Color = Color("#18222C"), border_color: Color = Color("#2F4659")) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_card_row(card: CardDefinition) -> PanelContainer:
	if card.is_character():
		return _make_character_card_row(card)

	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#21303C")
	style.border_color = Color("#3A5365")
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", style)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	row.add_child(box)

	var name_label := _make_label(card.label(), 14)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)

	var meta_label := _make_label(_card_meta(card), 12)
	meta_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(meta_label)

	var stat_label := _make_label(_format_stats(card.stats), 12)
	stat_label.add_theme_color_override("font_color", Color("#D7DEE8"))
	box.add_child(stat_label)

	return row


func _make_character_card_row(card: CardDefinition) -> PanelContainer:
	var row := PanelContainer.new()
	var is_expanded := expanded_character_card_ids.has(card.id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#21303C") if not is_expanded else Color("#263B49")
	style.border_color = Color("#3A5365") if not is_expanded else Color("#F4C95D")
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", style)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = "Click to toggle details."
	row.gui_input.connect(_on_character_card_gui_input.bind(card.id))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	row.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)

	header.add_child(_make_profile_frame(card))

	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.custom_minimum_size = Vector2(0, 56)
	header.add_child(summary)

	var name_label := _make_label(card.label(), 19)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(name_label)

	var summary_spacer := Control.new()
	summary_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.add_child(summary_spacer)

	var job_label := _make_label(_character_job(card), 12)
	job_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	job_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	summary.add_child(job_label)

	if is_expanded:
		box.add_child(_make_character_detail(card))

	_set_mouse_filter_recursive(box, Control.MOUSE_FILTER_IGNORE)
	return row


func _make_profile_frame(card: CardDefinition) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(56, 56)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111A22")
	style.border_color = Color("#60798C")
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	frame.add_theme_stylebox_override("panel", style)

	var label := _make_label(_card_initials(card), 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("#F4C95D"))
	frame.add_child(label)
	return frame


func _make_character_detail(card: CardDefinition) -> VBoxContainer:
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 18)
	stats.add_theme_constant_override("v_separation", 6)
	detail.add_child(stats)

	_add_metric(stats, "STR").text = str(card.stats.strength)
	_add_metric(stats, "AGI").text = str(card.stats.agility)
	_add_metric(stats, "INT").text = str(card.stats.intelligence)
	_add_metric(stats, "CHM").text = str(card.stats.charm)

	var wage_label := _make_label("Wage %s" % card.weekly_wage, 12)
	wage_label.add_theme_color_override("font_color", Color("#D7DEE8"))
	detail.add_child(wage_label)

	var skill_label := _make_label("Skills: %s" % _format_string_array(card.skill_ids, "None"), 12)
	skill_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(skill_label)

	var tag_label := _make_label("Tags: %s" % _format_string_array(card.tags, "None"), 12)
	tag_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(tag_label)

	return detail


func _make_event_row(request: RequestDefinition) -> PanelContainer:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202C35")
	style.border_color = Color("#3A5365")
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	row.add_theme_stylebox_override("panel", style)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	var title_label := _make_label(request.label(), 15)
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(title_label)

	var meta_label := _make_label(_event_meta(request), 12)
	meta_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(meta_label)

	var reward_label := _make_label(_event_rewards(request), 12)
	reward_label.add_theme_color_override("font_color", Color("#D7DEE8"))
	box.add_child(reward_label)

	return row


func _make_empty_label(text: String) -> Label:
	var label := _make_label(text, 13)
	label.add_theme_color_override("font_color", Color("#7F8D9B"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_icon_button(icon_path: String, tooltip: String) -> Button:
	var button := Button.new()
	button.icon = load(icon_path)
	button.expand_icon = true
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(58, 58)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.focus_mode = Control.FOCUS_NONE
	return button


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#F3F4F6"))
	return label


func _make_section_title(text: String) -> Label:
	var label := _make_label(text, 20)
	label.add_theme_color_override("font_color", Color("#F4C95D"))
	return label


func _add_metric(grid: GridContainer, name: String) -> Label:
	var name_label := _make_label(name, 14)
	name_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	grid.add_child(name_label)

	var value_label := _make_label("-", 14)
	grid.add_child(value_label)
	return value_label


func _refresh() -> void:
	day_value.text = str(GameState.current_day)
	week_value.text = str(GameState.get_week())
	weekday_value.text = "%s / 7" % GameState.get_weekday()
	money_value.text = str(GameState.office.money)
	card_count_value.text = str(GameState.office.owned_cards.size())
	request_count_value.text = str(ContentCatalog.requests.size())

	var tax_text := str(GameState.tax_manager.weekly_tax)
	if GameState.tax_manager.is_due(GameState.current_day):
		if GameState.tax_manager.has_paid_current_week(GameState.current_day):
			tax_text += " paid"
		else:
			tax_text += " due today"
	tax_value.text = tax_text

	var tax_can_be_paid := (
		GameState.tax_manager.is_due(GameState.current_day)
		and not GameState.tax_manager.has_paid_current_week(GameState.current_day)
		and not GameState.is_game_over
	)
	pay_tax_button.disabled = not tax_can_be_paid
	next_day_button.disabled = GameState.is_game_over
	_refresh_character_cards()
	_refresh_event_list()
	_refresh_inventory_drawer()
	_refresh_inventory_buttons()

	if GameState.is_game_over:
		status_label.text = "Game Over: %s" % GameState.game_over_reason
	elif tax_can_be_paid:
		status_label.text = "Tax is due before the office can move to the next day."
	elif GameState.office.owned_cards.is_empty() and ContentCatalog.requests.is_empty():
		status_label.text = "The office is open. No cards or requests have entered the city yet."
	else:
		status_label.text = "The office is ready for daily operations."


func _refresh_character_cards() -> void:
	var character_cards := _get_cards_by_type(GameEnums.CardType.CHARACTER)
	_populate_card_list(character_card_list, character_cards, "No character cards.")


func _refresh_event_list() -> void:
	var requests := ContentCatalog.requests.duplicate()
	requests.sort_custom(Callable(self, "_sort_requests_by_label"))
	_populate_event_list(requests)


func _refresh_inventory_drawer() -> void:
	if active_drawer_type == NO_ACTIVE_DRAWER:
		action_panel.visible = true
		inventory_drawer.visible = false
		return

	action_panel.visible = false
	inventory_drawer.visible = true

	if active_drawer_type == GameEnums.CardType.EQUIPMENT:
		inventory_drawer_title.text = "Equipment Cards"
		_populate_card_list(
			inventory_card_list,
			_get_cards_by_type(GameEnums.CardType.EQUIPMENT),
			"No equipment cards."
		)
	elif active_drawer_type == GameEnums.CardType.CONSUMABLE:
		inventory_drawer_title.text = "Consumable Cards"
		_populate_card_list(
			inventory_card_list,
			_get_cards_by_type(GameEnums.CardType.CONSUMABLE),
			"No consumable cards."
		)


func _refresh_inventory_buttons() -> void:
	equipment_button.modulate = Color("#F4C95D") if active_drawer_type == GameEnums.CardType.EQUIPMENT else Color.WHITE
	consumable_button.modulate = Color("#F4C95D") if active_drawer_type == GameEnums.CardType.CONSUMABLE else Color.WHITE


func _populate_card_list(container: VBoxContainer, cards: Array[CardDefinition], empty_text: String) -> void:
	_clear_children(container)

	if cards.is_empty():
		container.add_child(_make_empty_label(empty_text))
		return

	for card in cards:
		container.add_child(_make_card_row(card))


func _populate_event_list(requests: Array) -> void:
	_clear_children(event_list)

	if requests.is_empty():
		event_list.add_child(_make_empty_label("No events."))
		return

	for request in requests:
		if request is RequestDefinition:
			event_list.add_child(_make_event_row(request))


func _get_cards_by_type(card_type: int) -> Array[CardDefinition]:
	var filtered: Array[CardDefinition] = []

	for card in GameState.office.owned_cards:
		if card != null and card.card_type == card_type:
			filtered.append(card)

	filtered.sort_custom(Callable(self, "_sort_cards_by_label"))
	return filtered


func _sort_cards_by_label(first: CardDefinition, second: CardDefinition) -> bool:
	return first.label().naturalnocasecmp_to(second.label()) < 0


func _sort_requests_by_label(first: RequestDefinition, second: RequestDefinition) -> bool:
	return first.label().naturalnocasecmp_to(second.label()) < 0


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _set_mouse_filter_recursive(node: Node, mouse_filter: int) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = mouse_filter

	for child in node.get_children():
		_set_mouse_filter_recursive(child, mouse_filter)


func _card_meta(card: CardDefinition) -> String:
	var parts: PackedStringArray = []

	if card.is_character():
		if not String(card.job).is_empty():
			parts.append(String(card.job))
		if card.weekly_wage > 0:
			parts.append("Wage %s" % card.weekly_wage)
	else:
		parts.append(GameEnums.card_type_label(card.card_type))

	if not card.tags.is_empty():
		parts.append(", ".join(card.tags))

	if parts.is_empty():
		return GameEnums.card_type_label(card.card_type)

	return " / ".join(parts)


func _character_job(card: CardDefinition) -> String:
	if String(card.job).is_empty():
		return "Unassigned"

	return String(card.job)


func _card_initials(card: CardDefinition) -> String:
	var words := card.label().split(" ", false)
	var initials := ""

	for word in words:
		if word.length() > 0:
			initials += word.substr(0, 1).to_upper()
		if initials.length() >= 2:
			break

	if initials.is_empty():
		return "?"

	return initials


func _format_string_array(values: PackedStringArray, fallback: String) -> String:
	if values.is_empty():
		return fallback

	return ", ".join(values)


func _format_stats(stats: StatBlock) -> String:
	if stats == null:
		return "STR 0  AGI 0  INT 0  CHM 0"

	return "STR %s  AGI %s  INT %s  CHM %s" % [
		stats.strength,
		stats.agility,
		stats.intelligence,
		stats.charm,
	]


func _event_meta(request: RequestDefinition) -> String:
	var parts: PackedStringArray = [
		GameEnums.request_type_label(request.request_type),
		"%s days" % request.duration_days,
		"valid %s days" % request.valid_days,
	]

	if request.repeatable_after_expiry:
		parts.append("repeatable")

	if not request.tags.is_empty():
		parts.append(", ".join(request.tags))

	return " / ".join(parts)


func _event_rewards(request: RequestDefinition) -> String:
	return "Reward %s money / %s reputation" % [
		request.reward_money,
		request.reward_reputation,
	]


func _on_next_day_pressed() -> void:
	GameState.advance_day()


func _on_pay_tax_pressed() -> void:
	GameState.pay_weekly_tax()


func _on_reset_pressed() -> void:
	expanded_character_card_ids.clear()
	GameState.reset_game()


func _on_equipment_pressed() -> void:
	_toggle_inventory_drawer(GameEnums.CardType.EQUIPMENT)


func _on_consumable_pressed() -> void:
	_toggle_inventory_drawer(GameEnums.CardType.CONSUMABLE)


func _toggle_inventory_drawer(card_type: int) -> void:
	if active_drawer_type == card_type:
		active_drawer_type = NO_ACTIVE_DRAWER
	else:
		active_drawer_type = card_type

	_refresh_inventory_drawer()
	_refresh_inventory_buttons()


func _on_character_card_gui_input(event: InputEvent, card_id: StringName) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if expanded_character_card_ids.has(card_id):
				expanded_character_card_ids.erase(card_id)
			else:
				expanded_character_card_ids[card_id] = true

			_refresh_character_cards()
