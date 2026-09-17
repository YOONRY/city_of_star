extends Control

const NO_ACTIVE_DRAWER := -1
const TAX_PAYMENT_EVENT_ID := &"tax_payment"

var day_value: Label
var week_value: Label
var weekday_value: Label
var tax_value: Label
var card_count_value: Label
var request_count_value: Label
var status_label: Label
var event_list: VBoxContainer
var character_detail_popup: PanelContainer
var character_detail_title: Label
var character_detail_content: VBoxContainer
var next_day_button: Button
var character_panel: PanelContainer
var character_card_list: VBoxContainer
var inventory_drawer: PanelContainer
var inventory_drawer_title: Label
var inventory_close_button: Button
var inventory_card_list: VBoxContainer
var personnel_button: Button
var equipment_button: Button
var consumable_button: Button
var active_drawer_type: int = NO_ACTIVE_DRAWER
var selected_event_id: StringName = &""
var selected_character_card_id: StringName = &""
var equipment_target_character_id: StringName = &""
var is_selecting_tax_event_money: bool = false
var tax_event_money_assigned: bool = false

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
	calendar_metrics.columns = 12
	calendar_metrics.add_theme_constant_override("h_separation", 12)
	calendar_metrics.add_theme_constant_override("v_separation", 4)
	calendar_panel.add_child(calendar_metrics)

	day_value = _add_metric(calendar_metrics, "Day")
	week_value = _add_metric(calendar_metrics, "Week")
	weekday_value = _add_metric(calendar_metrics, "Weekday")
	tax_value = _add_metric(calendar_metrics, "Tax")
	card_count_value = _add_metric(calendar_metrics, "Cards")
	request_count_value = _add_metric(calendar_metrics, "Events")

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)

	var event_stage := Control.new()
	event_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(event_stage)

	var event_panel := _make_panel()
	event_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_stage.add_child(event_panel)

	var event_box := VBoxContainer.new()
	event_box.add_theme_constant_override("separation", 14)
	event_panel.add_child(event_box)

	event_box.add_child(_make_section_title("Events"))

	status_label = _make_label("", 13)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_box.add_child(status_label)

	var event_scroll := ScrollContainer.new()
	event_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	event_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_box.add_child(event_scroll)

	event_list = VBoxContainer.new()
	event_list.add_theme_constant_override("separation", 10)
	event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_scroll.add_child(event_list)

	character_detail_popup = _make_panel(Color("#121B24"), Color("#F4C95D"))
	character_detail_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	character_detail_popup.offset_left = 28
	character_detail_popup.offset_top = 28
	character_detail_popup.offset_right = -28
	character_detail_popup.offset_bottom = -28
	character_detail_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	character_detail_popup.visible = false
	event_stage.add_child(character_detail_popup)

	var popup_box := VBoxContainer.new()
	popup_box.add_theme_constant_override("separation", 12)
	character_detail_popup.add_child(popup_box)

	var popup_header := HBoxContainer.new()
	popup_header.add_theme_constant_override("separation", 10)
	popup_box.add_child(popup_header)

	character_detail_title = _make_label("", 20)
	character_detail_title.add_theme_color_override("font_color", Color("#F4C95D"))
	character_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_header.add_child(character_detail_title)

	var character_detail_close_button := _make_close_button()
	character_detail_close_button.pressed.connect(_close_character_detail_popup)
	popup_header.add_child(character_detail_close_button)

	var character_detail_scroll := ScrollContainer.new()
	character_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	character_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_box.add_child(character_detail_scroll)

	character_detail_content = VBoxContainer.new()
	character_detail_content.add_theme_constant_override("separation", 12)
	character_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_detail_scroll.add_child(character_detail_content)

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(340, 0)
	right_column.add_theme_constant_override("separation", 14)
	body.add_child(right_column)

	character_panel = _make_panel()
	character_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(character_panel)

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

	inventory_drawer = _make_panel(Color("#121B24"), Color("#38556A"))
	inventory_drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_drawer.visible = false
	right_column.add_child(inventory_drawer)

	var drawer_box := VBoxContainer.new()
	drawer_box.add_theme_constant_override("separation", 10)
	inventory_drawer.add_child(drawer_box)

	var drawer_header := HBoxContainer.new()
	drawer_header.add_theme_constant_override("separation", 10)
	drawer_box.add_child(drawer_header)

	inventory_drawer_title = _make_label("", 16)
	inventory_drawer_title.add_theme_color_override("font_color", Color("#F4C95D"))
	inventory_drawer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_header.add_child(inventory_drawer_title)

	inventory_close_button = _make_close_button()
	inventory_close_button.pressed.connect(_close_inventory_drawer)
	drawer_header.add_child(inventory_close_button)

	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_box.add_child(inventory_scroll)

	inventory_card_list = VBoxContainer.new()
	inventory_card_list.add_theme_constant_override("separation", 10)
	inventory_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.add_child(inventory_card_list)

	var bottom_icon_row := HBoxContainer.new()
	bottom_icon_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom_icon_row.offset_left = -338
	bottom_icon_row.offset_top = -104
	bottom_icon_row.offset_right = -40
	bottom_icon_row.offset_bottom = -40
	bottom_icon_row.add_theme_constant_override("separation", 10)
	bottom_icon_row.alignment = BoxContainer.ALIGNMENT_END
	add_child(bottom_icon_row)

	personnel_button = _make_icon_button("res://assets/icons/person_icon.svg", "Personnel Office")
	personnel_button.pressed.connect(_on_personnel_pressed)
	bottom_icon_row.add_child(personnel_button)

	equipment_button = _make_icon_button("res://assets/icons/chest_icon.svg", "Equipment Cards")
	equipment_button.pressed.connect(_on_equipment_pressed)
	bottom_icon_row.add_child(equipment_button)

	consumable_button = _make_icon_button("res://assets/icons/potion_icon.svg", "Consumable Cards")
	consumable_button.pressed.connect(_on_consumable_pressed)
	bottom_icon_row.add_child(consumable_button)

	next_day_button = _make_icon_button("res://assets/icons/next_day_icon.svg", "Next Day")
	next_day_button.custom_minimum_size = Vector2(64, 64)
	next_day_button.pressed.connect(_on_next_day_pressed)
	bottom_icon_row.add_child(next_day_button)


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

	if card.is_equipment() and not String(equipment_target_character_id).is_empty():
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = "Click to equip."
		row.gui_input.connect(_on_equipment_card_gui_input.bind(card.id))
		_set_mouse_filter_recursive(box, Control.MOUSE_FILTER_IGNORE)

	return row


func _make_money_stack_card() -> PanelContainer:
	var is_tax_target := is_selecting_tax_event_money
	var tax_amount := GameState.tax_manager.weekly_tax
	var is_current_week_paid := GameState.tax_manager.has_paid_current_week(GameState.current_day)
	var can_assign_money := is_tax_target and not is_current_week_paid and GameState.office.money >= tax_amount
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#24313A")
	style.border_color = Color("#F4C95D") if can_assign_money else Color("#D6A64F")
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
	row.tooltip_text = "Click to place funds into the tax event." if can_assign_money else "Current office funds are shown as a stack."
	row.gui_input.connect(_on_money_stack_gui_input)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	row.add_child(box)

	var stack_visual := Control.new()
	stack_visual.custom_minimum_size = Vector2(78, 64)
	box.add_child(stack_visual)

	stack_visual.add_child(_make_money_stack_layer(Vector2(18, 0), Color("#18222C"), Color("#4A6577"), "", 10))
	stack_visual.add_child(_make_money_stack_layer(Vector2(10, 8), Color("#202D36"), Color("#738898"), "", 10))
	stack_visual.add_child(_make_money_stack_layer(Vector2(2, 16), Color("#34414A"), Color("#D6A64F"), "$", 22))

	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation", 4)
	box.add_child(summary)

	var name_label := _make_label("Office Funds", 15)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(name_label)

	var amount_label := _make_label("%s money" % GameState.office.money, 22)
	amount_label.add_theme_color_override("font_color", Color("#F4C95D"))
	summary.add_child(amount_label)

	var meta_text := "Currency stack / current balance"
	if is_tax_target:
		if is_current_week_paid:
			meta_text = "Current week's tax is already paid"
		elif can_assign_money:
			meta_text = "Ready to place %s money into tax event" % tax_amount
		else:
			meta_text = "Need %s more money for tax event" % maxi(0, tax_amount - GameState.office.money)

	var meta_label := _make_label(meta_text, 12)
	meta_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(meta_label)

	_set_mouse_filter_recursive(box, Control.MOUSE_FILTER_IGNORE)
	return row


func _make_money_stack_layer(offset: Vector2, background_color: Color, border_color: Color, text: String, font_size: int) -> PanelContainer:
	var layer := PanelContainer.new()
	layer.position = offset
	layer.custom_minimum_size = Vector2(56, 42)
	layer.size = Vector2(56, 42)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	layer.add_theme_stylebox_override("panel", style)

	if not text.is_empty():
		var label := _make_label(text, font_size)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", Color("#F4C95D"))
		layer.add_child(label)

	return layer


func _make_character_card_row(card: CardDefinition) -> PanelContainer:
	var row := PanelContainer.new()
	var is_selected := selected_character_card_id == card.id
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#21303C") if not is_selected else Color("#263B49")
	style.border_color = Color("#3A5365") if not is_selected else Color("#F4C95D")
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
	row.tooltip_text = "Click to hide details." if is_selected else "Click to show details."
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

	_set_mouse_filter_recursive(box, Control.MOUSE_FILTER_IGNORE)
	_set_button_mouse_filter_recursive(box)
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
	var effective_stats := GameState.get_effective_stats(card)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 18)
	stats.add_theme_constant_override("v_separation", 6)
	detail.add_child(stats)

	_add_metric(stats, "STR").text = str(effective_stats.strength)
	_add_metric(stats, "AGI").text = str(effective_stats.agility)
	_add_metric(stats, "INT").text = str(effective_stats.intelligence)
	_add_metric(stats, "CHM").text = str(effective_stats.charm)
	_add_metric(stats, "HP").text = str(effective_stats.health)

	var wage_label := _make_label("Wage %s" % card.weekly_wage, 12)
	wage_label.add_theme_color_override("font_color", Color("#D7DEE8"))
	detail.add_child(wage_label)

	if not GameState.get_equipped_cards(card).is_empty():
		var base_label := _make_label("Base: %s" % _format_stats(card.stats), 12)
		base_label.add_theme_color_override("font_color", Color("#AAB6C2"))
		base_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(base_label)

	detail.add_child(_make_equipment_slot_section(card))

	var skill_label := _make_label("Skills: %s" % _format_string_array(card.skill_ids, "None"), 12)
	skill_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(skill_label)

	var tag_label := _make_label("Tags: %s" % _format_string_array(card.tags, "None"), 12)
	tag_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(tag_label)

	return detail


func _make_equipment_slot_section(card: CardDefinition) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var title := _make_label("Equipment Slots", 13)
	title.add_theme_color_override("font_color", Color("#F4C95D"))
	section.add_child(title)

	var slots := VBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	section.add_child(slots)

	var equipped_cards := GameState.get_equipped_cards(card)
	for slot_index in range(GameState.MAX_EQUIPMENT_PER_CHARACTER):
		var equipment: CardDefinition = null
		if slot_index < equipped_cards.size():
			equipment = equipped_cards[slot_index]

		slots.add_child(_make_equipment_slot_button(card, equipment, slot_index))

	return section


func _make_equipment_slot_button(character: CardDefinition, equipment: CardDefinition, slot_index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE

	if equipment == null:
		button.text = "Slot %s: Add equipment" % (slot_index + 1)
		button.disabled = GameState.is_game_over
		button.pressed.connect(_on_equipment_slot_pressed.bind(character.id))
	else:
		button.text = "Slot %s: %s  %s" % [
			slot_index + 1,
			equipment.label(),
			_format_stats(equipment.stats),
		]
		button.tooltip_text = "Click to unequip."
		button.pressed.connect(_on_unequip_pressed.bind(character.id, equipment.id))

	return button


func _make_hire_candidate_row(card: CardDefinition) -> PanelContainer:
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
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", style)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	header.add_child(_make_profile_frame(card))

	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(summary)

	var name_label := _make_label(card.label(), 15)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(name_label)

	var job_label := _make_label(_character_job(card), 12)
	job_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	summary.add_child(job_label)

	var cost_label := _make_label("Hire cost %s" % GameState.get_hire_cost(card), 12)
	cost_label.add_theme_color_override("font_color", Color("#D7DEE8"))
	summary.add_child(cost_label)

	var hire_button := Button.new()
	hire_button.text = "Hire"
	hire_button.disabled = not GameState.can_hire_card(card)
	hire_button.pressed.connect(_on_hire_pressed.bind(card.id))
	header.add_child(hire_button)

	var stat_label := _make_label(_format_stats(card.stats), 12)
	stat_label.add_theme_color_override("font_color", Color("#D7DEE8"))
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stat_label)

	var skill_label := _make_label("Skills: %s" % _format_string_array(card.skill_ids, "None"), 12)
	skill_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(skill_label)

	return row


func _make_event_row(request: RequestDefinition) -> PanelContainer:
	var event_id := _request_event_id(request)
	var is_selected := selected_event_id == event_id
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202C35") if not is_selected else Color("#243542")
	style.border_color = Color("#3A5365") if not is_selected else Color("#F4C95D")
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
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_event_row_gui_input.bind(event_id))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	row.add_child(box)

	box.add_child(_make_event_title_button(request.label(), event_id, is_selected))

	if is_selected:
		box.add_child(_make_request_event_detail(request))

	return row


func _make_tax_payment_event_row() -> PanelContainer:
	var is_paid := GameState.tax_manager.has_paid_current_week(GameState.current_day)
	var can_resolve := _can_resolve_tax_event()
	var is_selected := selected_event_id == TAX_PAYMENT_EVENT_ID
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202C35") if not is_paid else Color("#20352C")
	style.border_color = _tax_event_border_color(is_paid, can_resolve, is_selected)
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
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_event_row_gui_input.bind(TAX_PAYMENT_EVENT_ID))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	row.add_child(box)

	var title_button := _make_event_title_button("세금 납부", TAX_PAYMENT_EVENT_ID, is_selected)
	if is_paid:
		title_button.add_theme_color_override("font_color", Color("#B7F6C7"))
		title_button.add_theme_color_override("font_hover_color", Color("#D8FFE1"))
		title_button.add_theme_color_override("font_pressed_color", Color("#8DDEAA"))
	box.add_child(title_button)

	if not is_selected:
		return row

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var meta_label := _make_label(_tax_event_meta(), 12)
	meta_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(meta_label)

	var resolve_button := Button.new()
	resolve_button.text = _tax_event_action_label(is_paid)
	resolve_button.disabled = not can_resolve
	resolve_button.custom_minimum_size = Vector2(88, 34)
	resolve_button.focus_mode = Control.FOCUS_NONE
	resolve_button.pressed.connect(_on_tax_event_resolve_pressed)
	header.add_child(resolve_button)

	if _can_cancel_tax_event_action():
		var cancel_button := Button.new()
		cancel_button.text = "취소"
		cancel_button.custom_minimum_size = Vector2(72, 34)
		cancel_button.focus_mode = Control.FOCUS_NONE
		cancel_button.pressed.connect(_on_tax_event_cancel_pressed)
		header.add_child(cancel_button)

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 10)
	box.add_child(slot_row)

	slot_row.add_child(_make_event_slot_button("인물", "필요 없음", true, Callable()))
	slot_row.add_child(_make_event_slot_button("소비", _tax_consumable_slot_text(), is_paid, Callable(self, "_on_tax_consumable_slot_pressed")))

	var status_label := _make_label(_tax_event_status_text(), 12)
	status_label.add_theme_color_override("font_color", _tax_event_status_color(is_paid, can_resolve))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	return row


func _make_request_event_detail(request: RequestDefinition) -> VBoxContainer:
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)

	var meta_label := _make_label(_event_meta(request), 12)
	meta_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(meta_label)

	var reward_label := _make_label(_event_rewards(request), 12)
	reward_label.add_theme_color_override("font_color", Color("#D7DEE8"))
	detail.add_child(reward_label)

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 10)
	detail.add_child(slot_row)

	slot_row.add_child(_make_event_slot_button("인물", "미배치", true, Callable()))
	slot_row.add_child(_make_event_slot_button("소비", "미배치", true, Callable()))

	var status_label := _make_label("아직 일반 의뢰의 카드 배치 처리는 연결되지 않았습니다.", 12)
	status_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(status_label)

	return detail


func _make_event_title_button(title: String, event_id: StringName, is_selected: bool) -> Button:
	var button := Button.new()
	button.text = title
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Click to hide details." if is_selected else "Click to show details."
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_on_event_title_pressed.bind(event_id))
	return button


func _make_event_slot_button(title: String, detail: String, disabled: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [title, detail]
	button.disabled = disabled
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE

	if not disabled and callback.is_valid():
		button.pressed.connect(callback)

	return button


func _tax_event_border_color(is_paid: bool, can_resolve: bool, is_selected: bool) -> Color:
	if is_paid:
		return Color("#60A878")

	if can_resolve:
		return Color("#F4C95D")

	if is_selecting_tax_event_money:
		return Color("#D6A64F")

	if is_selected:
		return Color("#F4C95D")

	return Color("#3A5365")


func _tax_event_meta() -> String:
	return "Week %s / due day %s / tax %s money" % [
		GameState.get_week(),
		GameState.tax_manager.due_weekday,
		GameState.tax_manager.weekly_tax,
	]


func _tax_consumable_slot_text() -> String:
	if GameState.tax_manager.has_paid_current_week(GameState.current_day):
		return "납부 완료"

	if tax_event_money_assigned:
		return "%s money" % GameState.tax_manager.weekly_tax

	return "자금 미배치"


func _tax_event_action_label(is_paid: bool) -> String:
	if is_paid:
		return "완료"

	if tax_event_money_assigned:
		return "실행"

	return "납부"


func _tax_event_status_text() -> String:
	if GameState.tax_manager.has_paid_current_week(GameState.current_day):
		if GameState.can_cancel_current_week_tax_payment():
			return "세금 납부가 실행되었습니다. 다음 날로 넘기기 전까지 취소할 수 있습니다."

		return "이번 주 세금 납부가 완료되었습니다."

	if tax_event_money_assigned and _can_resolve_tax_event():
		return "자금이 배치되었습니다. 실행을 눌러 이벤트를 넘길 수 있습니다."

	if GameState.office.money < GameState.tax_manager.weekly_tax:
		return "자금이 부족합니다. 필요한 금액: %s money" % GameState.tax_manager.weekly_tax

	if is_selecting_tax_event_money:
		return "소비 카드 목록에서 자금 스택을 선택하세요."

	return "소비 슬롯에 현재 보유 금액을 배치해야 합니다."


func _tax_event_status_color(is_paid: bool, can_resolve: bool) -> Color:
	if is_paid:
		return Color("#60A878")

	if can_resolve:
		return Color("#F4C95D")

	return Color("#AAB6C2")


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


func _make_close_button() -> Button:
	var button := Button.new()
	button.text = "X"
	button.tooltip_text = "Close"
	button.custom_minimum_size = Vector2(32, 32)
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
	_sync_tax_event_state()
	day_value.text = str(GameState.current_day)
	week_value.text = str(GameState.get_week())
	weekday_value.text = "%s / 7" % GameState.get_weekday()
	card_count_value.text = str(GameState.office.owned_cards.size())
	request_count_value.text = str(ContentCatalog.requests.size() + 1)

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
	next_day_button.disabled = GameState.is_game_over
	_refresh_character_cards()
	_refresh_character_detail_popup()
	_refresh_event_list()
	_refresh_inventory_drawer()
	_refresh_inventory_buttons()

	if GameState.is_game_over:
		status_label.text = "Game Over: %s" % GameState.game_over_reason
	elif tax_can_be_paid:
		status_label.text = "Tax is due. Resolve the tax event before advancing."
	elif GameState.office.owned_cards.is_empty() and ContentCatalog.requests.is_empty():
		status_label.text = "The office is open. No cards or requests have entered the city yet."
	else:
		status_label.text = "The office is ready for daily operations."


func _sync_tax_event_state() -> void:
	if GameState.tax_manager.has_paid_current_week(GameState.current_day):
		tax_event_money_assigned = false
		is_selecting_tax_event_money = false
		return

	if GameState.office.money < GameState.tax_manager.weekly_tax:
		tax_event_money_assigned = false


func _can_resolve_tax_event() -> bool:
	return tax_event_money_assigned and GameState.can_pay_current_week_tax()


func _can_cancel_tax_event_action() -> bool:
	return tax_event_money_assigned or GameState.can_cancel_current_week_tax_payment()


func _refresh_character_cards() -> void:
	var character_cards := _get_cards_by_type(GameEnums.CardType.CHARACTER)
	_populate_card_list(character_card_list, character_cards, "No character cards.")


func _refresh_character_detail_popup() -> void:
	_clear_children(character_detail_content)

	if String(selected_character_card_id).is_empty():
		character_detail_title.text = ""
		character_detail_popup.visible = false
		return

	var card := ContentCatalog.get_card(selected_character_card_id)
	if card == null or not card.is_character() or not GameState.office.owned_cards.has(card):
		selected_character_card_id = &""
		character_detail_title.text = ""
		character_detail_popup.visible = false
		return

	character_detail_popup.visible = true
	character_detail_title.text = card.label()

	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 14)
	character_detail_content.add_child(summary)

	summary.add_child(_make_profile_frame(card))

	var summary_text := VBoxContainer.new()
	summary_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_text.add_theme_constant_override("separation", 5)
	summary.add_child(summary_text)

	var name_label := _make_label(card.label(), 24)
	name_label.add_theme_color_override("font_color", Color("#F3F4F6"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_text.add_child(name_label)

	var job_label := _make_label(_character_job(card), 14)
	job_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	summary_text.add_child(job_label)

	character_detail_content.add_child(_make_character_detail(card))


func _refresh_event_list() -> void:
	var requests := ContentCatalog.requests.duplicate()
	requests.sort_custom(Callable(self, "_sort_requests_by_label"))
	_populate_event_list(requests)


func _refresh_inventory_drawer() -> void:
	if active_drawer_type == NO_ACTIVE_DRAWER:
		character_panel.visible = true
		inventory_drawer.visible = false
		return

	character_panel.visible = false
	inventory_drawer.visible = true

	if active_drawer_type == GameEnums.CardType.CHARACTER:
		inventory_drawer_title.text = "Personnel Office"
		_populate_hire_candidate_list()
	elif active_drawer_type == GameEnums.CardType.EQUIPMENT:
		inventory_drawer_title.text = _equipment_drawer_title()
		_populate_equipment_card_list()
	elif active_drawer_type == GameEnums.CardType.CONSUMABLE:
		inventory_drawer_title.text = "Consumable Cards"
		_populate_consumable_card_list()


func _refresh_inventory_buttons() -> void:
	personnel_button.modulate = Color("#F4C95D") if active_drawer_type == GameEnums.CardType.CHARACTER else Color.WHITE
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
	event_list.add_child(_make_tax_payment_event_row())

	if requests.is_empty():
		return

	for request in requests:
		if request is RequestDefinition:
			event_list.add_child(_make_event_row(request))


func _populate_hire_candidate_list() -> void:
	_clear_children(inventory_card_list)
	var candidates := _get_hire_candidates()

	if candidates.is_empty():
		inventory_card_list.add_child(_make_empty_label("No available personnel."))
		return

	for card in candidates:
		inventory_card_list.add_child(_make_hire_candidate_row(card))


func _populate_equipment_card_list() -> void:
	_clear_children(inventory_card_list)
	var equipment_cards := _get_cards_by_type(GameEnums.CardType.EQUIPMENT)

	if not String(equipment_target_character_id).is_empty():
		equipment_cards = _get_available_equipment_cards()

	if equipment_cards.is_empty():
		var empty_text := "No available equipment." if not String(equipment_target_character_id).is_empty() else "No equipment cards."
		inventory_card_list.add_child(_make_empty_label(empty_text))
		return

	for card in equipment_cards:
		inventory_card_list.add_child(_make_card_row(card))


func _populate_consumable_card_list() -> void:
	_clear_children(inventory_card_list)
	inventory_card_list.add_child(_make_money_stack_card())

	var consumable_cards := _get_cards_by_type(GameEnums.CardType.CONSUMABLE)
	if consumable_cards.is_empty():
		inventory_card_list.add_child(_make_empty_label("No consumable cards."))
		return

	for card in consumable_cards:
		inventory_card_list.add_child(_make_card_row(card))


func _equipment_drawer_title() -> String:
	var character := ContentCatalog.get_card(equipment_target_character_id)
	if character != null:
		return "Choose Equipment for %s" % character.label()

	return "Equipment Cards"


func _get_cards_by_type(card_type: int) -> Array[CardDefinition]:
	var filtered: Array[CardDefinition] = []

	for card in GameState.office.owned_cards:
		if card != null and card.card_type == card_type:
			filtered.append(card)

	filtered.sort_custom(Callable(self, "_sort_cards_by_label"))
	return filtered


func _get_available_equipment_cards() -> Array[CardDefinition]:
	var equipment_cards: Array[CardDefinition] = []
	var character := ContentCatalog.get_card(equipment_target_character_id)

	for card in _get_cards_by_type(GameEnums.CardType.EQUIPMENT):
		if GameState.can_equip_card(character, card):
			equipment_cards.append(card)

	equipment_cards.sort_custom(Callable(self, "_sort_cards_by_label"))
	return equipment_cards


func _get_hire_candidates() -> Array[CardDefinition]:
	var candidates: Array[CardDefinition] = []

	for card in ContentCatalog.cards:
		if card != null and card.is_character() and not GameState.office.owned_cards.has(card):
			candidates.append(card)

	candidates.sort_custom(Callable(self, "_sort_cards_by_label"))
	return candidates


func _sort_cards_by_label(first: CardDefinition, second: CardDefinition) -> bool:
	return first.label().naturalnocasecmp_to(second.label()) < 0


func _sort_requests_by_label(first: RequestDefinition, second: RequestDefinition) -> bool:
	return first.label().naturalnocasecmp_to(second.label()) < 0


func _request_event_id(request: RequestDefinition) -> StringName:
	var raw_id := String(request.id)
	if raw_id.is_empty():
		raw_id = request.label()

	return StringName("request:%s" % raw_id)


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


func _set_button_mouse_filter_recursive(node: Node) -> void:
	if node is Button:
		var button := node as Button
		button.mouse_filter = Control.MOUSE_FILTER_STOP

	for child in node.get_children():
		_set_button_mouse_filter_recursive(child)


func _card_meta(card: CardDefinition) -> String:
	var parts: PackedStringArray = []

	if card.is_character():
		if not String(card.job).is_empty():
			parts.append(String(card.job))
		if card.weekly_wage > 0:
			parts.append("Wage %s" % card.weekly_wage)
	else:
		parts.append(GameEnums.card_type_label(card.card_type))
		if card.is_equipment():
			var owner := ContentCatalog.get_card(GameState.get_equipment_owner_id(card.id))
			if owner != null:
				parts.append("Equipped by %s" % owner.label())

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
		return "STR 0  AGI 0  INT 0  CHM 0  HP 0"

	return "STR %s  AGI %s  INT %s  CHM %s  HP %s" % [
		stats.strength,
		stats.agility,
		stats.intelligence,
		stats.charm,
		stats.health,
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


func _on_event_title_pressed(event_id: StringName) -> void:
	_toggle_event_detail(event_id)


func _on_event_row_gui_input(event: InputEvent, event_id: StringName) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_toggle_event_detail(event_id)


func _toggle_event_detail(event_id: StringName) -> void:
	is_selecting_tax_event_money = false

	if selected_event_id == event_id:
		selected_event_id = &""
	else:
		selected_event_id = event_id

	_refresh_event_list()
	_refresh_inventory_drawer()
	_refresh_inventory_buttons()


func _on_reset_pressed() -> void:
	selected_event_id = &""
	selected_character_card_id = &""
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	tax_event_money_assigned = false
	GameState.reset_game()


func _on_personnel_pressed() -> void:
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	_open_inventory_drawer(GameEnums.CardType.CHARACTER)


func _on_equipment_pressed() -> void:
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	_open_inventory_drawer(GameEnums.CardType.EQUIPMENT)


func _on_consumable_pressed() -> void:
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	_open_inventory_drawer(GameEnums.CardType.CONSUMABLE)


func _on_equipment_slot_pressed(character_id: StringName) -> void:
	equipment_target_character_id = character_id
	selected_character_card_id = character_id
	is_selecting_tax_event_money = false
	_open_inventory_drawer(GameEnums.CardType.EQUIPMENT)


func _on_unequip_pressed(character_id: StringName, equipment_id: StringName) -> void:
	var character := ContentCatalog.get_card(character_id)
	if GameState.unequip_card(character, equipment_id):
		equipment_target_character_id = &""
		_refresh()


func _on_equipment_card_gui_input(event: InputEvent, equipment_id: StringName) -> void:
	if String(equipment_target_character_id).is_empty():
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return

		var character := ContentCatalog.get_card(equipment_target_character_id)
		var equipment := ContentCatalog.get_card(equipment_id)
		if GameState.equip_card(character, equipment):
			selected_character_card_id = equipment_target_character_id
			equipment_target_character_id = &""
			_close_inventory_drawer()
			_refresh()


func _on_tax_consumable_slot_pressed() -> void:
	if GameState.tax_manager.has_paid_current_week(GameState.current_day):
		return

	selected_event_id = TAX_PAYMENT_EVENT_ID
	is_selecting_tax_event_money = true
	_open_inventory_drawer(GameEnums.CardType.CONSUMABLE)


func _on_money_stack_gui_input(event: InputEvent) -> void:
	if not is_selecting_tax_event_money:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return

		if GameState.can_pay_current_week_tax():
			selected_event_id = TAX_PAYMENT_EVENT_ID
			tax_event_money_assigned = true
			_close_inventory_drawer()
			_refresh()
		else:
			status_label.text = "Not enough money to place into the tax event."


func _on_tax_event_resolve_pressed() -> void:
	if not _can_resolve_tax_event():
		return

	if GameState.pay_current_week_tax():
		tax_event_money_assigned = false
		selected_event_id = &""
		_close_inventory_drawer()
		_refresh()
	else:
		_refresh()


func _on_tax_event_cancel_pressed() -> void:
	if tax_event_money_assigned:
		tax_event_money_assigned = false
		_close_inventory_drawer()
		_refresh()
		return

	if GameState.cancel_current_week_tax_payment():
		selected_event_id = TAX_PAYMENT_EVENT_ID
		_close_inventory_drawer()
	else:
		_refresh()


func _open_inventory_drawer(card_type: int) -> void:
	active_drawer_type = card_type

	_refresh_inventory_drawer()
	_refresh_inventory_buttons()


func _close_inventory_drawer() -> void:
	active_drawer_type = NO_ACTIVE_DRAWER
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	_refresh_inventory_drawer()
	_refresh_inventory_buttons()


func _input(event: InputEvent) -> void:
	if active_drawer_type == NO_ACTIVE_DRAWER:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return

		if _is_inventory_drawer_click(mouse_event.position):
			return

		_close_inventory_drawer()
		get_viewport().set_input_as_handled()


func _is_inventory_drawer_click(position: Vector2) -> bool:
	return (
		_is_point_in_control(inventory_drawer, position)
		or _is_point_in_control(character_detail_popup, position)
		or _is_point_in_control(personnel_button, position)
		or _is_point_in_control(equipment_button, position)
		or _is_point_in_control(consumable_button, position)
		or _is_point_in_control(next_day_button, position)
	)


func _is_point_in_control(control: Control, position: Vector2) -> bool:
	return control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(position)


func _on_character_card_gui_input(event: InputEvent, card_id: StringName) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if selected_character_card_id == card_id:
				selected_character_card_id = &""
			else:
				selected_character_card_id = card_id

			_refresh_character_cards()
			_refresh_character_detail_popup()


func _close_character_detail_popup() -> void:
	var was_selecting_equipment := not String(equipment_target_character_id).is_empty()
	selected_character_card_id = &""
	equipment_target_character_id = &""

	if was_selecting_equipment:
		_close_inventory_drawer()

	_refresh_character_cards()
	_refresh_character_detail_popup()


func _on_hire_pressed(card_id: StringName) -> void:
	var card := ContentCatalog.get_card(card_id)
	if GameState.hire_card(card):
		_refresh()
