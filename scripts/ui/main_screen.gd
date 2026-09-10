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
var next_day_button: Button
var pay_tax_button: Button
var reset_button: Button
var character_card_list: VBoxContainer
var inventory_drawer: PanelContainer
var inventory_drawer_title: Label
var inventory_card_list: VBoxContainer
var equipment_button: Button
var consumable_button: Button
var active_drawer_type: int = NO_ACTIVE_DRAWER

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

	var title := _make_label("City of Star", 34)
	layout.add_child(title)

	var subtitle := _make_label("Office Management Prototype", 16)
	subtitle.add_theme_color_override("font_color", Color("#D7DEE8"))
	layout.add_child(subtitle)

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

	var status_panel := _make_panel()
	status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(status_panel)

	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 14)
	status_panel.add_child(status_box)

	status_box.add_child(_make_section_title("Office"))

	var metrics := GridContainer.new()
	metrics.columns = 2
	metrics.add_theme_constant_override("h_separation", 28)
	metrics.add_theme_constant_override("v_separation", 10)
	status_box.add_child(metrics)

	day_value = _add_metric(metrics, "Day")
	week_value = _add_metric(metrics, "Week")
	weekday_value = _add_metric(metrics, "Weekday")
	money_value = _add_metric(metrics, "Money")
	tax_value = _add_metric(metrics, "Tax")
	card_count_value = _add_metric(metrics, "Cards")
	request_count_value = _add_metric(metrics, "Requests")

	status_label = _make_label("", 15)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_box.add_child(status_label)

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(300, 0)
	right_column.add_theme_constant_override("separation", 14)
	body.add_child(right_column)

	var action_panel := _make_panel()
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

	var inventory_panel := _make_panel()
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
	card_count_value.text = str(ContentCatalog.cards.size())
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
	_refresh_inventory_drawer()
	_refresh_inventory_buttons()

	if GameState.is_game_over:
		status_label.text = "Game Over: %s" % GameState.game_over_reason
	elif tax_can_be_paid:
		status_label.text = "Tax is due before the office can move to the next day."
	elif ContentCatalog.cards.is_empty() and ContentCatalog.requests.is_empty():
		status_label.text = "The office is open. No cards or requests have entered the city yet."
	else:
		status_label.text = "The office is ready for daily operations."


func _refresh_character_cards() -> void:
	var character_cards := _get_cards_by_type(GameEnums.CardType.CHARACTER)
	_populate_card_list(character_card_list, character_cards, "No character cards.")


func _refresh_inventory_drawer() -> void:
	if active_drawer_type == NO_ACTIVE_DRAWER:
		inventory_drawer.visible = false
		return

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


func _get_cards_by_type(card_type: int) -> Array[CardDefinition]:
	var filtered: Array[CardDefinition] = []

	for card in ContentCatalog.cards:
		if card != null and card.card_type == card_type:
			filtered.append(card)

	filtered.sort_custom(Callable(self, "_sort_cards_by_label"))
	return filtered


func _sort_cards_by_label(first: CardDefinition, second: CardDefinition) -> bool:
	return first.label().naturalnocasecmp_to(second.label()) < 0


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


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


func _format_stats(stats: StatBlock) -> String:
	if stats == null:
		return "STR 0  AGI 0  INT 0  CHM 0"

	return "STR %s  AGI %s  INT %s  CHM %s" % [
		stats.strength,
		stats.agility,
		stats.intelligence,
		stats.charm,
	]


func _on_next_day_pressed() -> void:
	GameState.advance_day()


func _on_pay_tax_pressed() -> void:
	GameState.pay_weekly_tax()


func _on_reset_pressed() -> void:
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
