extends Control

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

	var action_panel := _make_panel()
	action_panel.custom_minimum_size = Vector2(280, 0)
	body.add_child(action_panel)

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


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#18222C")
	style.border_color = Color("#2F4659")
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

	if GameState.is_game_over:
		status_label.text = "Game Over: %s" % GameState.game_over_reason
	elif tax_can_be_paid:
		status_label.text = "Tax is due before the office can move to the next day."
	elif ContentCatalog.cards.is_empty() and ContentCatalog.requests.is_empty():
		status_label.text = "The office is open. No cards or requests have entered the city yet."
	else:
		status_label.text = "The office is ready for daily operations."


func _on_next_day_pressed() -> void:
	GameState.advance_day()


func _on_pay_tax_pressed() -> void:
	GameState.pay_weekly_tax()


func _on_reset_pressed() -> void:
	GameState.reset_game()
