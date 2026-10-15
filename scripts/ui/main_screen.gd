extends Control

const NO_ACTIVE_DRAWER := -1
const TAX_PAYMENT_EVENT_ID := &"tax_payment"
const JOB_TRAINING_EVENT_ID := &"job_training"
const PIXEL_PANEL_TEXTURE := "res://assets/vendor/kenney_pixel_ui/9slice/space.png"
const PIXEL_PANEL_INLAY_TEXTURE := "res://assets/vendor/kenney_pixel_ui/9slice/space_inlay.png"
const PIXEL_BUTTON_TEXTURE := "res://assets/vendor/kenney_pixel_ui/9slice/blue.png"
const PIXEL_BUTTON_PRESSED_TEXTURE := "res://assets/vendor/kenney_pixel_ui/9slice/blue_pressed.png"
const PIXEL_BUTTON_ACCENT_TEXTURE := "res://assets/vendor/kenney_pixel_ui/9slice/yellow.png"
const PIXEL_BUTTON_ACCENT_PRESSED_TEXTURE := "res://assets/vendor/kenney_pixel_ui/9slice/yellow_pressed.png"
const PIXEL_PANEL_GREY_TEXTURE := "res://assets/vendor/kenney_pixel_ui/9slice/grey.png"
const WINDOW_BACKGROUND_COLOR := Color("#121B24")
const WINDOW_BORDER_COLOR := Color("#2F4659")

var day_value: Label
var status_label: Label
var event_list: VBoxContainer
var character_detail_popup: PanelContainer
var character_detail_title: Label
var character_detail_content: VBoxContainer
var job_change_popup: PanelContainer
var job_change_title: Label
var job_change_content: VBoxContainer
var settlement_popup: PanelContainer
var settlement_content: VBoxContainer
var player_creation_overlay: Control
var player_name_input: LineEdit
var player_species_option: OptionButton
var player_job_option: OptionButton
var player_growth_remaining_label: Label
var player_growth_value_labels: Dictionary = {}
var player_skill_checkboxes: Dictionary = {}
var player_create_button: Button
var player_creation_status_label: Label
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
var is_selecting_job_training_character: bool = false
var job_training_candidate_character_id: StringName = &""
var player_creation_growth := {
	"strength": 10,
	"agility": 10,
	"intelligence": 10,
	"charm": 10,
	"health": 10,
}
var player_creation_skills := PackedStringArray()
var daily_request_character_ids: Dictionary = {}
var request_assignment_target_id: StringName = &""
var settlement_results_dismissed: bool = false

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
	calendar_panel.custom_minimum_size = Vector2(230, 0)
	top_bar.add_child(calendar_panel)

	day_value = _make_label("", 30)
	day_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	day_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	day_value.add_theme_color_override("font_color", Color("#F4C95D"))
	calendar_panel.add_child(day_value)

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

	character_detail_popup = _make_panel(WINDOW_BACKGROUND_COLOR, WINDOW_BORDER_COLOR)
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

	job_change_popup = _make_panel(WINDOW_BACKGROUND_COLOR, WINDOW_BORDER_COLOR)
	job_change_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	job_change_popup.offset_left = 42
	job_change_popup.offset_top = 42
	job_change_popup.offset_right = -42
	job_change_popup.offset_bottom = -42
	job_change_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	job_change_popup.visible = false
	event_stage.add_child(job_change_popup)

	var job_change_box := VBoxContainer.new()
	job_change_box.add_theme_constant_override("separation", 12)
	job_change_popup.add_child(job_change_box)

	job_change_title = _make_label("전직할 직업을 선택하세요", 20)
	job_change_title.add_theme_color_override("font_color", Color("#F4C95D"))
	job_change_box.add_child(job_change_title)

	var job_change_help := _make_label("직업 교육을 마쳤습니다. 조건을 만족한 직업 중 하나를 선택해야 다음 날로 진행할 수 있습니다.", 12)
	job_change_help.add_theme_color_override("font_color", Color("#AAB6C2"))
	job_change_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	job_change_box.add_child(job_change_help)

	var job_change_scroll := ScrollContainer.new()
	job_change_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	job_change_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	job_change_box.add_child(job_change_scroll)

	job_change_content = VBoxContainer.new()
	job_change_content.add_theme_constant_override("separation", 8)
	job_change_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	job_change_scroll.add_child(job_change_content)

	settlement_popup = _make_panel(WINDOW_BACKGROUND_COLOR, WINDOW_BORDER_COLOR)
	settlement_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	settlement_popup.offset_left = 36
	settlement_popup.offset_top = 36
	settlement_popup.offset_right = -36
	settlement_popup.offset_bottom = -36
	settlement_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	settlement_popup.z_index = 30
	settlement_popup.visible = false
	event_stage.add_child(settlement_popup)

	var settlement_box := VBoxContainer.new()
	settlement_box.add_theme_constant_override("separation", 12)
	settlement_popup.add_child(settlement_box)

	var settlement_header := HBoxContainer.new()
	settlement_header.add_theme_constant_override("separation", 10)
	settlement_box.add_child(settlement_header)

	var settlement_title := _make_label("일일 정산", 22)
	settlement_title.add_theme_color_override("font_color", Color("#F4C95D"))
	settlement_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settlement_header.add_child(settlement_title)

	var settlement_close_button := _make_close_button()
	settlement_close_button.pressed.connect(_close_settlement_popup)
	settlement_header.add_child(settlement_close_button)

	var settlement_help := _make_label("전날 실행한 의뢰를 한꺼번에 판정했습니다.", 12)
	settlement_help.add_theme_color_override("font_color", Color("#AAB6C2"))
	settlement_box.add_child(settlement_help)

	var settlement_scroll := ScrollContainer.new()
	settlement_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settlement_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settlement_box.add_child(settlement_scroll)

	settlement_content = VBoxContainer.new()
	settlement_content.add_theme_constant_override("separation", 10)
	settlement_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settlement_scroll.add_child(settlement_content)

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

	var bottom_dock := MarginContainer.new()
	bottom_dock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom_dock.offset_left = -372
	bottom_dock.offset_top = -138
	bottom_dock.offset_right = -32
	bottom_dock.offset_bottom = -32
	bottom_dock.add_theme_constant_override("margin_left", 18)
	bottom_dock.add_theme_constant_override("margin_right", 18)
	bottom_dock.add_theme_constant_override("margin_top", 18)
	bottom_dock.add_theme_constant_override("margin_bottom", 18)
	add_child(bottom_dock)

	var bottom_icon_row := HBoxContainer.new()
	bottom_icon_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_icon_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_icon_row.add_theme_constant_override("separation", 10)
	bottom_icon_row.alignment = BoxContainer.ALIGNMENT_END
	bottom_dock.add_child(bottom_icon_row)

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

	inventory_drawer = _make_panel(Color("#2D3036"), Color("#6F7378"))
	inventory_drawer.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	inventory_drawer.offset_left = -430
	inventory_drawer.offset_top = 112
	inventory_drawer.offset_right = -32
	inventory_drawer.offset_bottom = -32
	inventory_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_drawer.z_index = 40
	inventory_drawer.visible = false
	add_child(inventory_drawer)

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

	_build_player_creation_overlay()


func _build_player_creation_overlay() -> void:
	player_creation_overlay = Control.new()
	player_creation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	player_creation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	player_creation_overlay.z_index = 100
	add_child(player_creation_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.05, 0.08, 0.94)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	player_creation_overlay.add_child(backdrop)

	var panel := _make_panel(WINDOW_BACKGROUND_COLOR, WINDOW_BORDER_COLOR)
	panel.anchor_left = 0.16
	panel.anchor_top = 0.06
	panel.anchor_right = 0.84
	panel.anchor_bottom = 0.94
	player_creation_overlay.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var title := _make_label("플레이어 캐릭터 생성", 22)
	title.add_theme_color_override("font_color", Color("#F4C95D"))
	outer.add_child(title)

	var guide := _make_label("모든 개인 성장치는 10에서 시작합니다. 추가 성장치 80점을 분배하고 초기 개인 스킬 2개를 선택하세요.", 12)
	guide.add_theme_color_override("font_color", Color("#AAB6C2"))
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(guide)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var identity_grid := GridContainer.new()
	identity_grid.columns = 2
	identity_grid.add_theme_constant_override("h_separation", 14)
	identity_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(identity_grid)

	identity_grid.add_child(_make_label("이름", 13))
	player_name_input = LineEdit.new()
	player_name_input.text = "별의 아이"
	player_name_input.max_length = 20
	player_name_input.text_changed.connect(_on_player_creation_changed)
	identity_grid.add_child(player_name_input)

	identity_grid.add_child(_make_label("종족", 13))
	player_species_option = OptionButton.new()
	player_species_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for species_definition in ContentCatalog.species:
		var species_index := player_species_option.item_count
		player_species_option.add_item(species_definition.label())
		player_species_option.set_item_metadata(species_index, species_definition.id)
	identity_grid.add_child(player_species_option)

	identity_grid.add_child(_make_label("기본직업", 13))
	player_job_option = OptionButton.new()
	player_job_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for job in ContentCatalog.jobs:
		if job == null or not job.is_basic_job():
			continue
		var job_index := player_job_option.item_count
		player_job_option.add_item(job.label())
		player_job_option.set_item_metadata(job_index, job.id)
	identity_grid.add_child(player_job_option)

	var growth_header := HBoxContainer.new()
	content.add_child(growth_header)
	var growth_title := _make_label("개인 성장치", 14)
	growth_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	growth_title.add_theme_color_override("font_color", Color("#F4C95D"))
	growth_header.add_child(growth_title)
	player_growth_remaining_label = _make_label("", 13)
	growth_header.add_child(player_growth_remaining_label)

	var growth_grid := GridContainer.new()
	growth_grid.columns = 4
	growth_grid.add_theme_constant_override("h_separation", 10)
	growth_grid.add_theme_constant_override("v_separation", 6)
	content.add_child(growth_grid)
	_add_player_growth_row(growth_grid, "strength", "STR")
	_add_player_growth_row(growth_grid, "agility", "AGI")
	_add_player_growth_row(growth_grid, "intelligence", "INT")
	_add_player_growth_row(growth_grid, "charm", "CHM")
	_add_player_growth_row(growth_grid, "health", "HP")

	var skill_title := _make_label("초기 개인 스킬 · 2개 선택", 14)
	skill_title.add_theme_color_override("font_color", Color("#F4C95D"))
	content.add_child(skill_title)

	var skill_grid := GridContainer.new()
	skill_grid.columns = 2
	skill_grid.add_theme_constant_override("h_separation", 18)
	skill_grid.add_theme_constant_override("v_separation", 5)
	content.add_child(skill_grid)
	for skill_id in GameState.get_player_initial_skill_options():
		var checkbox := CheckBox.new()
		checkbox.text = skill_id
		checkbox.toggled.connect(_on_player_skill_toggled.bind(skill_id))
		player_skill_checkboxes[skill_id] = checkbox
		skill_grid.add_child(checkbox)

	player_creation_status_label = _make_label("", 12)
	player_creation_status_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	content.add_child(player_creation_status_label)

	player_create_button = Button.new()
	player_create_button.text = "캐릭터 생성"
	player_create_button.custom_minimum_size = Vector2(0, 42)
	player_create_button.focus_mode = Control.FOCUS_NONE
	_style_pixel_button(player_create_button, true)
	player_create_button.pressed.connect(_on_player_create_pressed)
	outer.add_child(player_create_button)
	_refresh_player_creation_form()


func _add_player_growth_row(grid: GridContainer, stat_key: String, stat_label: String) -> void:
	grid.add_child(_make_label(stat_label, 13))
	var decrease_button := Button.new()
	decrease_button.text = "-10"
	decrease_button.focus_mode = Control.FOCUS_NONE
	_style_pixel_button(decrease_button, false)
	decrease_button.pressed.connect(_on_player_growth_adjusted.bind(stat_key, -10))
	grid.add_child(decrease_button)

	var value_label := _make_label(str(player_creation_growth[stat_key]), 13)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_growth_value_labels[stat_key] = value_label
	grid.add_child(value_label)

	var increase_button := Button.new()
	increase_button.text = "+10"
	increase_button.focus_mode = Control.FOCUS_NONE
	_style_pixel_button(increase_button, false)
	increase_button.pressed.connect(_on_player_growth_adjusted.bind(stat_key, 10))
	grid.add_child(increase_button)


func _refresh_player_creation_form() -> void:
	if player_creation_overlay == null:
		return

	player_creation_overlay.visible = not GameState.has_player_character()
	var total_growth := 0
	for value in player_creation_growth.values():
		total_growth += int(value)
	var remaining := GameState.PLAYER_GROWTH_BUDGET - total_growth
	player_growth_remaining_label.text = "남은 점수: %s" % remaining
	player_growth_remaining_label.add_theme_color_override("font_color", Color("#B7F6C7") if remaining == 0 else Color("#F4C95D"))

	for stat_key in player_growth_value_labels:
		var value_label := player_growth_value_labels[stat_key] as Label
		value_label.text = str(player_creation_growth[stat_key])

	var valid := (
		not player_name_input.text.strip_edges().is_empty()
		and player_species_option.item_count > 0
		and player_job_option.item_count > 0
		and remaining == 0
		and player_creation_skills.size() == GameState.PLAYER_INITIAL_SKILL_COUNT
	)
	player_create_button.disabled = not valid
	player_creation_status_label.text = "선택한 스킬: %s/%s" % [
		player_creation_skills.size(),
		GameState.PLAYER_INITIAL_SKILL_COUNT,
	]


func _reset_player_creation_form() -> void:
	player_creation_growth = {
		"strength": 10,
		"agility": 10,
		"intelligence": 10,
		"charm": 10,
		"health": 10,
	}
	player_creation_skills.clear()
	if player_name_input != null:
		player_name_input.text = "별의 아이"
	if player_species_option != null and player_species_option.item_count > 0:
		player_species_option.select(0)
	if player_job_option != null and player_job_option.item_count > 0:
		player_job_option.select(0)
	for checkbox in player_skill_checkboxes.values():
		(checkbox as CheckBox).set_pressed_no_signal(false)
	_refresh_player_creation_form()


func _on_player_creation_changed(_new_text: String) -> void:
	_refresh_player_creation_form()


func _on_player_growth_adjusted(stat_key: String, delta: int) -> void:
	var current_value := int(player_creation_growth.get(stat_key, 0))
	var next_value := current_value + delta
	if next_value < GameState.PLAYER_GROWTH_MIN_PER_STAT or next_value > GameState.PLAYER_GROWTH_MAX_PER_STAT:
		return

	var total_growth := 0
	for value in player_creation_growth.values():
		total_growth += int(value)
	if delta > 0 and total_growth + delta > GameState.PLAYER_GROWTH_BUDGET:
		return

	player_creation_growth[stat_key] = next_value
	_refresh_player_creation_form()


func _on_player_skill_toggled(pressed: bool, skill_id: String) -> void:
	if pressed:
		if player_creation_skills.size() >= GameState.PLAYER_INITIAL_SKILL_COUNT:
			var checkbox := player_skill_checkboxes.get(skill_id, null) as CheckBox
			if checkbox != null:
				checkbox.set_pressed_no_signal(false)
			return
		player_creation_skills.append(skill_id)
	else:
		player_creation_skills.erase(skill_id)
	_refresh_player_creation_form()


func _on_player_create_pressed() -> void:
	if player_species_option.item_count <= 0 or player_job_option.item_count <= 0:
		return

	var growth := StatBlock.new()
	growth.strength = int(player_creation_growth["strength"])
	growth.agility = int(player_creation_growth["agility"])
	growth.intelligence = int(player_creation_growth["intelligence"])
	growth.charm = int(player_creation_growth["charm"])
	growth.health = int(player_creation_growth["health"])
	var species_id := StringName(player_species_option.get_item_metadata(player_species_option.selected))
	var job_id := StringName(player_job_option.get_item_metadata(player_job_option.selected))
	var player := GameState.create_player_character(
		player_name_input.text,
		species_id,
		job_id,
		growth,
		player_creation_skills
	)
	if player == null:
		player_creation_status_label.text = "캐릭터 생성 조건을 다시 확인하세요."


func _make_panel(_background_color: Color = Color("#18222C"), border_color: Color = Color("#2F4659")) -> PanelContainer:
	var panel := PanelContainer.new()
	var texture_path := PIXEL_PANEL_TEXTURE
	if border_color == Color("#F4C95D"):
		texture_path = PIXEL_BUTTON_ACCENT_TEXTURE
	elif border_color == Color("#38556A"):
		texture_path = PIXEL_PANEL_INLAY_TEXTURE
	elif border_color == Color("#6F7378"):
		texture_path = PIXEL_PANEL_GREY_TEXTURE
	var style := _make_pixel_style(texture_path, 8, 18)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_pixel_style(texture_path: String, texture_margin: int, content_margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(texture_path)
	style.texture_margin_left = texture_margin
	style.texture_margin_right = texture_margin
	style.texture_margin_top = texture_margin
	style.texture_margin_bottom = texture_margin
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	return style


func _make_empty_style(content_margin: int = 0) -> StyleBoxEmpty:
	var style := StyleBoxEmpty.new()
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	return style


func _make_card_row(card: CardDefinition) -> PanelContainer:
	if card.is_character():
		return _make_character_card_row(card)

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _make_pixel_style(PIXEL_PANEL_INLAY_TEXTURE, 8, 12))
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
	var texture_path := PIXEL_BUTTON_ACCENT_TEXTURE if can_assign_money else PIXEL_PANEL_INLAY_TEXTURE
	row.add_theme_stylebox_override("panel", _make_pixel_style(texture_path, 8, 12))
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
	var assigned_event := _character_event_assignment_label(card)
	var is_event_selection := not String(request_assignment_target_id).is_empty() or is_selecting_job_training_character
	var is_unavailable_for_event := is_event_selection and not assigned_event.is_empty()
	var texture_path := PIXEL_BUTTON_TEXTURE if is_selected else PIXEL_PANEL_TEXTURE
	row.add_theme_stylebox_override("panel", _make_pixel_style(texture_path, 8, 12))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	if not assigned_event.is_empty():
		row.modulate = Color(0.58, 0.62, 0.68, 1.0)
		row.tooltip_text = "%s에 배치 중" % assigned_event
	else:
		row.tooltip_text = "Click to hide details." if is_selected else "Click to show details."
	if not is_unavailable_for_event:
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

	var job_label := _make_label("%s / %s" % [_character_species(card), _character_job(card)], 12)
	job_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	job_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	summary.add_child(job_label)

	if not assigned_event.is_empty():
		var assignment_label := _make_label("배치 중 · %s" % assigned_event, 12)
		assignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		assignment_label.add_theme_color_override("font_color", Color("#8FCBFF"))
		summary.add_child(assignment_label)

	_set_mouse_filter_recursive(box, Control.MOUSE_FILTER_IGNORE)
	_set_button_mouse_filter_recursive(box)
	return row


func _make_profile_frame(card: CardDefinition) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(56, 56)
	frame.add_theme_stylebox_override("panel", _make_pixel_style(PIXEL_PANEL_INLAY_TEXTURE, 8, 8))

	var label := _make_label(_card_initials(card), 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("#F4C95D"))
	frame.add_child(label)
	return frame


func _make_character_detail(card: CardDefinition) -> TabContainer:
	var detail := TabContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_stylebox_override("panel", _make_pixel_style(PIXEL_PANEL_TEXTURE, 8, 12))
	detail.add_theme_stylebox_override("tab_selected", _make_pixel_style(PIXEL_BUTTON_ACCENT_TEXTURE, 8, 8))
	detail.add_theme_stylebox_override("tab_unselected", _make_pixel_style(PIXEL_BUTTON_TEXTURE, 8, 8))
	detail.add_theme_color_override("font_selected_color", Color("#2B2617"))
	detail.add_theme_color_override("font_unselected_color", Color("#F3F4F6"))
	detail.add_child(_make_character_status_tab(card))
	detail.add_child(_make_character_growth_tab(card))
	detail.add_child(_make_character_skills_tab(card))
	detail.add_child(_make_character_job_history_tab(card))
	detail.add_child(_make_character_equipment_tab(card))
	return detail


func _make_character_status_tab(card: CardDefinition) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = "Status"
	tab.add_theme_constant_override("separation", 10)

	var info := GridContainer.new()
	info.columns = 2
	info.add_theme_constant_override("h_separation", 18)
	info.add_theme_constant_override("v_separation", 6)
	tab.add_child(info)

	_add_metric(info, "Species").text = _character_species(card)
	_add_metric(info, "Job").text = _character_job(card)
	_add_metric(info, "Job Level").text = "%s / %s" % [GameState.get_character_job_level(card, GameState.get_character_current_job_id(card)), GameState.MAX_JOB_LEVEL]
	_add_metric(info, "Level").text = str(GameState.get_character_level(card))

	var title := _make_label("Total Stats", 13)
	title.add_theme_color_override("font_color", Color("#F4C95D"))
	tab.add_child(title)

	var effective_stats := GameState.get_effective_stats(card)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 18)
	stats.add_theme_constant_override("v_separation", 6)
	tab.add_child(stats)

	_add_metric(stats, "STR").text = str(effective_stats.strength)
	_add_metric(stats, "AGI").text = str(effective_stats.agility)
	_add_metric(stats, "INT").text = str(effective_stats.intelligence)
	_add_metric(stats, "CHM").text = str(effective_stats.charm)
	_add_metric(stats, "HP").text = str(effective_stats.health)
	_add_metric(stats, "DEF").text = str(effective_stats.defense)
	_add_metric(stats, "MDEF").text = str(effective_stats.magic_defense)

	return tab


func _make_character_growth_tab(card: CardDefinition) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = "Growth"
	tab.add_theme_constant_override("separation", 10)
	tab.add_child(_make_character_growth_section(card))
	tab.add_child(_make_character_level_up_row(card))
	return tab


func _make_character_skills_tab(card: CardDefinition) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = "Skills"
	tab.add_theme_constant_override("separation", 8)

	var skill_title := _make_label("Skills", 13)
	skill_title.add_theme_color_override("font_color", Color("#F4C95D"))
	tab.add_child(skill_title)

	var skill_label := _make_label(_format_string_array(card.skill_ids, "None"), 12)
	skill_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(skill_label)

	var species_skill_title := _make_label("Species Skills", 13)
	species_skill_title.add_theme_color_override("font_color", Color("#F4C95D"))
	tab.add_child(species_skill_title)

	var species_skill_label := _make_label(_format_string_array(_species_skills(card), "None"), 12)
	species_skill_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	species_skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(species_skill_label)

	var job_skill_title := _make_label("Learned Job Skills", 13)
	job_skill_title.add_theme_color_override("font_color", Color("#F4C95D"))
	tab.add_child(job_skill_title)

	var job_skill_label := _make_label(_format_string_array(GameState.get_character_job_skill_ids(card), "None"), 12)
	job_skill_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	job_skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(job_skill_label)

	var tag_title := _make_label("Tags", 13)
	tag_title.add_theme_color_override("font_color", Color("#F4C95D"))
	tab.add_child(tag_title)

	var tag_label := _make_label(_format_string_array(card.tags, "None"), 12)
	tag_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(tag_label)
	return tab


func _make_character_job_history_tab(card: CardDefinition) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = "Job History"
	tab.add_theme_constant_override("separation", 10)

	var current_job_id := GameState.get_character_current_job_id(card)
	var current_level := GameState.get_character_job_level(card, current_job_id)
	var current_title := _make_label("Current: %s  Lv.%s/%s" % [_job_label(current_job_id), current_level, GameState.MAX_JOB_LEVEL], 13)
	current_title.add_theme_color_override("font_color", Color("#F4C95D"))
	tab.add_child(current_title)

	var train_button := Button.new()
	train_button.text = "Job Mastered" if current_level >= GameState.MAX_JOB_LEVEL else "Train Current Job"
	train_button.focus_mode = Control.FOCUS_NONE
	train_button.disabled = not GameState.can_level_up_current_job(card)
	_style_pixel_button(train_button, true)
	train_button.pressed.connect(_on_job_level_up_pressed.bind(card.id))
	tab.add_child(train_button)

	var history_title := _make_label("Previous / Acquired Jobs", 13)
	history_title.add_theme_color_override("font_color", Color("#F4C95D"))
	tab.add_child(history_title)

	var levels := GameState.get_character_job_levels(card)
	for job_id in GameState.get_character_job_history_ids(card):
		var job := ContentCatalog.get_job(job_id)
		if job == null:
			continue
		var level := int(levels.get(job.id, 0))
		if level <= 0:
			continue
		tab.add_child(_make_job_history_row(card, job, level, job.id == current_job_id))

	var available_title := _make_label("Available Jobs", 13)
	available_title.add_theme_color_override("font_color", Color("#F4C95D"))
	tab.add_child(available_title)

	for job in ContentCatalog.jobs:
		if levels.has(job.id):
			continue
		tab.add_child(_make_job_candidate_row(card, job))

	return tab


func _make_job_history_row(card: CardDefinition, job: JobDefinition, level: int, is_current: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	var mastered_text := "  MASTER" if level >= GameState.MAX_JOB_LEVEL else ""
	var label := _make_label("%s  Lv.%s%s" % [job.label(), level, mastered_text], 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("#AAB6C2"))
	row.add_child(label)

	var button := Button.new()
	button.text = "Current" if is_current else "교육소"
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = true
	_style_pixel_button(button, false)
	row.add_child(button)
	return row


func _make_job_candidate_row(card: CardDefinition, job: JobDefinition) -> HBoxContainer:
	var row := HBoxContainer.new()
	var can_change := GameState.can_change_character_job(card, job.id)
	var description := job.label()
	if not job.is_basic_job():
		description += "  (%s)" % job.requirement_text()

	var label := _make_label(description, 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("#AAB6C2") if can_change else Color("#697682"))
	row.add_child(label)

	var button := Button.new()
	button.text = "교육소"
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = true
	_style_pixel_button(button, can_change)
	row.add_child(button)
	return row


func _make_character_equipment_tab(card: CardDefinition) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = "Equipment"
	tab.add_theme_constant_override("separation", 10)
	tab.add_child(_make_equipment_slot_section(card))
	return tab


func _make_character_level_up_row(card: CardDefinition) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var gain_label := _make_label("Next %s" % _format_level_up_gain(GameState.get_character_level_up_gain(card)), 12)
	gain_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	gain_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gain_label)

	var level_up_button := Button.new()
	level_up_button.text = "Level Up"
	level_up_button.focus_mode = Control.FOCUS_NONE
	level_up_button.disabled = GameState.is_game_over
	_style_pixel_button(level_up_button, true)
	level_up_button.pressed.connect(_on_level_up_pressed.bind(card.id))
	row.add_child(level_up_button)
	return row


func _make_character_growth_section(card: CardDefinition) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var title := _make_label("Growth", 13)
	title.add_theme_color_override("font_color", Color("#F4C95D"))
	section.add_child(title)

	var character_growth := StatBlock.new()
	if card.growth != null:
		character_growth = card.growth.clone()

	var species_growth := ContentCatalog.get_species_growth(card.species)
	var job_growth := StatBlock.new()
	var current_job_id := GameState.get_character_current_job_id(card)
	job_growth.add(ContentCatalog.get_job_growth(current_job_id))
	for mastered_job_id in GameState.get_character_mastered_job_ids(card):
		if mastered_job_id != current_job_id:
			job_growth.add(ContentCatalog.get_job_growth(mastered_job_id))
	var total_growth := GameState.get_character_growth(card)
	var level_gain := GameState.get_character_level_up_gain(card)

	section.add_child(_make_growth_label("STR", character_growth.strength, species_growth.strength, job_growth.strength, total_growth.strength, level_gain.strength))
	section.add_child(_make_growth_label("AGI", character_growth.agility, species_growth.agility, job_growth.agility, total_growth.agility, level_gain.agility))
	section.add_child(_make_growth_label("INT", character_growth.intelligence, species_growth.intelligence, job_growth.intelligence, total_growth.intelligence, level_gain.intelligence))
	section.add_child(_make_growth_label("CHM", character_growth.charm, species_growth.charm, job_growth.charm, total_growth.charm, level_gain.charm))
	section.add_child(_make_growth_label("HP", character_growth.health, species_growth.health, job_growth.health, total_growth.health, level_gain.health))
	return section


func _make_growth_label(stat_name: String, character_growth: int, species_growth: int, job_growth: int, total_growth: int, level_gain: int) -> Label:
	var label := _make_label("%s Personal %s + Species %s + Job %s = %s  (+%s)" % [
		stat_name,
		character_growth,
		species_growth,
		job_growth,
		total_growth,
		level_gain,
	], 12)
	label.add_theme_color_override("font_color", Color("#AAB6C2"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


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
		_style_pixel_button(button, true)
		button.pressed.connect(_on_equipment_slot_pressed.bind(character.id))
	else:
		button.text = "Slot %s: %s  %s" % [
			slot_index + 1,
			equipment.label(),
			_format_stats(equipment.stats),
		]
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = "%s\n%s\nClick to unequip." % [equipment.label(), _format_stats(equipment.stats)]
		_style_pixel_button(button, false)
		button.pressed.connect(_on_unequip_pressed.bind(character.id, equipment.id))

	return button


func _make_hire_candidate_row(card: CardDefinition) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _make_pixel_style(PIXEL_PANEL_INLAY_TEXTURE, 8, 12))
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

	var job_label := _make_label("%s / %s" % [_character_species(card), _character_job(card)], 12)
	job_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	summary.add_child(job_label)

	var cost_label := _make_label("Hire cost %s" % GameState.get_hire_cost(card), 12)
	cost_label.add_theme_color_override("font_color", Color("#D7DEE8"))
	summary.add_child(cost_label)

	var hire_button := Button.new()
	hire_button.text = "Hire"
	hire_button.disabled = not GameState.can_hire_card(card)
	_style_pixel_button(hire_button, true)
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
	var is_assignment_complete := GameState.get_daily_request_assigned_character(request) != null
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _event_assignment_style(is_assignment_complete, 14))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_event_row_gui_input.bind(event_id))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	row.add_child(box)

	box.add_child(_make_event_title_button(_request_display_title(request), event_id, is_selected))

	if is_selected:
		box.add_child(_make_request_event_detail(request))

	return row


func _make_tax_payment_event_row() -> PanelContainer:
	var is_paid := GameState.tax_manager.has_paid_current_week(GameState.current_day)
	var can_resolve := _can_resolve_tax_event()
	var is_selected := selected_event_id == TAX_PAYMENT_EVENT_ID
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _event_assignment_style(is_paid, 14))
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
	_style_pixel_button(resolve_button, true)
	resolve_button.pressed.connect(_on_tax_event_resolve_pressed)
	header.add_child(resolve_button)

	if _can_cancel_tax_event_action():
		var cancel_button := Button.new()
		cancel_button.text = "취소"
		cancel_button.custom_minimum_size = Vector2(72, 34)
		cancel_button.focus_mode = Control.FOCUS_NONE
		_style_pixel_button(cancel_button, false)
		cancel_button.pressed.connect(_on_tax_event_cancel_pressed)
		header.add_child(cancel_button)

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 10)
	box.add_child(slot_row)

	slot_row.add_child(_make_event_slot_button("인물", "필요 없음", true, Callable()))
	slot_row.add_child(_make_assignment_slot_button(
		"소비",
		_tax_consumable_slot_text(),
		tax_event_money_assigned,
		is_paid,
		Callable(self, "_on_tax_consumable_slot_pressed")
	))

	var status_label := _make_label(_tax_event_status_text(), 12)
	status_label.add_theme_color_override("font_color", _tax_event_status_color(is_paid, can_resolve))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	return row


func _make_job_training_event_row() -> PanelContainer:
	var is_selected := selected_event_id == JOB_TRAINING_EVENT_ID
	var assigned_character := GameState.get_job_training_character()
	var candidate_character := ContentCatalog.get_card(job_training_candidate_character_id)
	var has_pending_change := GameState.has_pending_job_change()
	var is_assignment_complete := assigned_character != null or has_pending_change
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _event_assignment_style(is_assignment_complete, 14))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_event_row_gui_input.bind(JOB_TRAINING_EVENT_ID))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	row.add_child(box)
	box.add_child(_make_event_title_button("직업 교육소", JOB_TRAINING_EVENT_ID, is_selected))

	if not is_selected:
		return row

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)

	var meta_label := _make_label("Event / 1 day / 캐릭터 카드 1장 필요", 12)
	meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	header.add_child(meta_label)

	var execute_button := Button.new()
	execute_button.text = "완료" if assigned_character != null else "실행"
	execute_button.custom_minimum_size = Vector2(88, 34)
	execute_button.focus_mode = Control.FOCUS_NONE
	execute_button.disabled = candidate_character == null or assigned_character != null or has_pending_change
	_style_pixel_button(execute_button, true)
	execute_button.pressed.connect(_on_job_training_execute_pressed)
	header.add_child(execute_button)

	var slot_text := "미배치"
	if candidate_character != null:
		slot_text = "%s (대기)" % candidate_character.label()
	elif assigned_character != null:
		slot_text = assigned_character.label()
	elif has_pending_change:
		slot_text = "교육 완료"

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 10)
	box.add_child(slot_row)
	slot_row.add_child(_make_assignment_slot_button(
		"인물",
		slot_text,
		candidate_character != null,
		is_assignment_complete,
		Callable(self, "_on_job_training_character_slot_pressed")
	))
	slot_row.add_child(_make_event_slot_button("소비", "필요 없음", true, Callable()))

	if candidate_character != null or assigned_character != null:
		var cancel_button := Button.new()
		cancel_button.text = "배치 취소"
		cancel_button.focus_mode = Control.FOCUS_NONE
		_style_pixel_button(cancel_button, false)
		cancel_button.pressed.connect(_on_job_training_cancel_pressed)
		box.add_child(cancel_button)

	var status_text := "인물 슬롯을 눌러 교육할 캐릭터를 배치하세요."
	if candidate_character != null:
		status_text = "%s 임시 배치. 실행 버튼을 눌러 배치를 확정하세요." % candidate_character.label()
	elif assigned_character != null:
		status_text = "%s 배치 완료. 하루를 넘기면 전직 선택창이 열립니다." % assigned_character.label()
	elif has_pending_change:
		status_text = "교육이 완료되었습니다. 전직할 직업을 선택하세요."
	elif is_selecting_job_training_character:
		status_text = "캐릭터 목록에서 교육할 인물을 선택하세요."

	var status := _make_label(status_text, 12)
	status.add_theme_color_override("font_color", Color("#F4C95D") if candidate_character != null or assigned_character != null or has_pending_change else Color("#AAB6C2"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	return row


func _make_request_event_detail(request: RequestDefinition) -> VBoxContainer:
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	var character_id := StringName(daily_request_character_ids.get(request.id, &""))
	var candidate_character := ContentCatalog.get_card(character_id)
	var queued_character := GameState.get_daily_request_assigned_character(request)
	var is_queued := queued_character != null
	var assigned_character := queued_character if is_queued else candidate_character

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	detail.add_child(header)

	var meta_label := _make_label(_event_meta(request), 12)
	meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(meta_label)

	var execute_button := Button.new()
	execute_button.text = "배치 완료" if is_queued else "실행"
	execute_button.custom_minimum_size = Vector2(88, 34)
	execute_button.focus_mode = Control.FOCUS_NONE
	execute_button.disabled = is_queued or not GameState.can_queue_daily_request(request, assigned_character)
	_style_pixel_button(execute_button, true)
	execute_button.pressed.connect(_on_daily_request_execute_pressed.bind(request.id))
	header.add_child(execute_button)

	var reward_label := _make_label(_event_rewards(request), 12)
	reward_label.add_theme_color_override("font_color", Color("#D7DEE8"))
	detail.add_child(reward_label)

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 10)
	detail.add_child(slot_row)

	var character_text := assigned_character.label() if assigned_character != null else "미배치"
	slot_row.add_child(_make_assignment_slot_button(
		"인물",
		character_text,
		candidate_character != null,
		is_queued,
		Callable(self, "_on_daily_request_character_slot_pressed").bind(request.id)
	))
	slot_row.add_child(_make_event_slot_button("소비", "필요 없음", true, Callable()))
	if assigned_character != null:
		var cancel_button := Button.new()
		cancel_button.text = "배치 해제"
		cancel_button.focus_mode = Control.FOCUS_NONE
		_style_pixel_button(cancel_button, false)
		cancel_button.pressed.connect(_on_daily_request_cancel_pressed.bind(request.id))
		detail.add_child(cancel_button)

	var status_text := "인물을 배치하고 실행하세요. 판정은 다음 날 정산창에서 한꺼번에 진행됩니다."
	if is_queued:
		status_text = "%s 배치 확정. 다음 날 정산을 기다리고 있습니다." % assigned_character.label()
	elif assigned_character != null:
		status_text = "%s 임시 배치. 실행하면 오늘의 의뢰로 확정됩니다." % assigned_character.label()
	var status_label := _make_label(status_text, 12)
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
	_style_clear_button(button)
	if is_selected:
		button.add_theme_color_override("font_color", Color("#F4C95D"))
		button.add_theme_color_override("font_hover_color", Color("#F4C95D"))
		button.add_theme_color_override("font_pressed_color", Color("#D6A64F"))
	button.pressed.connect(_on_event_title_pressed.bind(event_id))
	return button


func _make_event_slot_button(title: String, detail: String, disabled: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [title, detail]
	button.disabled = disabled
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	_style_pixel_button(button, not disabled)

	if not disabled and callback.is_valid():
		button.pressed.connect(callback)

	return button


func _make_assignment_slot_button(title: String, detail: String, has_candidate: bool, is_queued: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [title, detail]
	button.disabled = is_queued
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE

	if is_queued:
		_style_confirmed_request_slot(button)
	elif has_candidate:
		_style_pixel_button(button, false)
		button.add_theme_color_override("font_color", Color("#E9F6FF"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		_style_empty_request_slot(button)

	if not is_queued and callback.is_valid():
		button.pressed.connect(callback)
	return button


func _style_empty_request_slot(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_pixel_style(PIXEL_PANEL_GREY_TEXTURE, 8, 8))
	button.add_theme_stylebox_override("hover", _make_pixel_style(PIXEL_BUTTON_TEXTURE, 8, 8))
	button.add_theme_stylebox_override("pressed", _make_pixel_style(PIXEL_BUTTON_PRESSED_TEXTURE, 8, 8))
	button.add_theme_stylebox_override("disabled", _make_empty_style(8))
	button.add_theme_stylebox_override("focus", _make_empty_style())
	button.add_theme_color_override("font_color", Color("#C1C8CF"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _style_confirmed_request_slot(button: Button) -> void:
	var glow_style := _make_black_glow_style(8)
	button.add_theme_stylebox_override("normal", glow_style)
	button.add_theme_stylebox_override("hover", glow_style)
	button.add_theme_stylebox_override("pressed", glow_style)
	button.add_theme_stylebox_override("disabled", glow_style)
	button.add_theme_stylebox_override("focus", _make_empty_style())
	button.add_theme_color_override("font_color", Color("#E9F6FF"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#E9F6FF"))


func _event_assignment_style(is_complete: bool, content_margin: int) -> StyleBox:
	if is_complete:
		return _make_black_glow_style(content_margin)
	return _make_pixel_style(PIXEL_BUTTON_TEXTURE, 8, content_margin)


func _make_black_glow_style(content_margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#030507")
	style.border_color = Color("#65BFFF")
	style.set_border_width_all(2)
	style.shadow_color = Color(0.18, 0.58, 0.88, 0.9)
	style.shadow_size = 7
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	return style


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
	_style_clear_button(button)
	return button


func _make_close_button() -> Button:
	var button := Button.new()
	button.text = "X"
	button.tooltip_text = "Close"
	button.custom_minimum_size = Vector2(32, 32)
	button.focus_mode = Control.FOCUS_NONE
	_style_clear_button(button)
	return button


func _style_clear_button(button: Button) -> void:
	button.flat = true
	button.add_theme_stylebox_override("normal", _make_empty_style())
	button.add_theme_stylebox_override("hover", _make_empty_style())
	button.add_theme_stylebox_override("pressed", _make_empty_style())
	button.add_theme_stylebox_override("disabled", _make_empty_style())
	button.add_theme_stylebox_override("focus", _make_empty_style())
	button.add_theme_color_override("font_color", Color("#F3F4F6"))
	button.add_theme_color_override("font_hover_color", Color("#F4C95D"))
	button.add_theme_color_override("font_pressed_color", Color("#D6A64F"))
	button.add_theme_color_override("font_disabled_color", Color("#6F7F8D"))


func _style_pixel_button(button: Button, accent: bool) -> void:
	var normal_texture := PIXEL_BUTTON_ACCENT_TEXTURE if accent else PIXEL_BUTTON_TEXTURE
	var pressed_texture := PIXEL_BUTTON_ACCENT_PRESSED_TEXTURE if accent else PIXEL_BUTTON_PRESSED_TEXTURE
	var font_color := Color("#2B2617") if accent else Color("#F3F4F6")
	button.add_theme_stylebox_override("normal", _make_pixel_style(normal_texture, 8, 8))
	button.add_theme_stylebox_override("hover", _make_pixel_style(pressed_texture, 8, 8))
	button.add_theme_stylebox_override("pressed", _make_pixel_style(pressed_texture, 8, 8))
	button.add_theme_stylebox_override("disabled", _make_empty_style(8))
	button.add_theme_stylebox_override("focus", _make_empty_style())
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", Color("#6F7F8D"))


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
	day_value.text = "Day %s" % GameState.current_day

	var tax_can_be_paid := (
		GameState.tax_manager.is_due(GameState.current_day)
		and not GameState.tax_manager.has_paid_current_week(GameState.current_day)
		and not GameState.is_game_over
	)
	var has_open_settlement := not settlement_results_dismissed and not GameState.last_daily_request_results.is_empty()
	next_day_button.disabled = GameState.is_game_over or GameState.has_pending_job_change() or not GameState.has_player_character() or has_open_settlement
	_refresh_player_creation_form()
	_refresh_character_cards()
	_refresh_character_detail_popup()
	_refresh_job_change_popup()
	_refresh_settlement_popup()
	_refresh_event_list()
	_refresh_inventory_drawer()
	_refresh_inventory_buttons()

	if GameState.is_game_over:
		status_label.text = "Game Over: %s" % GameState.game_over_reason
	elif GameState.has_pending_job_change():
		status_label.text = "직업 교육이 완료되었습니다. 전직할 직업을 선택하세요."
	elif not GameState.last_daily_request_results.is_empty():
		status_label.text = "전날 의뢰 %s건 정산 완료 · 총수익 %s money" % [
			GameState.last_daily_request_results.size(),
			_daily_settlement_total_reward(),
		]
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

	var job_label := _make_label("%s / %s" % [_character_species(card), _character_job(card)], 14)
	job_label.add_theme_color_override("font_color", Color("#AAB6C2"))
	summary_text.add_child(job_label)

	character_detail_content.add_child(_make_character_detail(card))


func _refresh_job_change_popup() -> void:
	_clear_children(job_change_content)
	var character := GameState.get_pending_job_change_character()
	if character == null:
		job_change_popup.visible = false
		return

	job_change_popup.visible = true
	job_change_title.text = "%s의 전직" % character.label()

	var current_job_id := GameState.get_character_current_job_id(character)
	var current_label := _make_label("현재 직업: %s  Lv.%s" % [
		_job_label(current_job_id),
		GameState.get_character_job_level(character, current_job_id),
	], 13)
	current_label.add_theme_color_override("font_color", Color("#D7DEE8"))
	job_change_content.add_child(current_label)

	for job in ContentCatalog.jobs:
		job_change_content.add_child(_make_job_change_option(character, job))


func _refresh_settlement_popup() -> void:
	_clear_children(settlement_content)
	if settlement_results_dismissed or GameState.last_daily_request_results.is_empty():
		settlement_popup.visible = false
		return

	settlement_popup.visible = true
	for raw_result in GameState.last_daily_request_results:
		var result: Dictionary = raw_result
		var result_panel := _make_panel(Color("#172633"), WINDOW_BORDER_COLOR)
		settlement_content.add_child(result_panel)

		var result_box := VBoxContainer.new()
		result_box.add_theme_constant_override("separation", 5)
		result_panel.add_child(result_box)

		var result_title := _make_label("%s · %s" % [
			result.get("request", "의뢰"),
			result.get("character", "캐릭터"),
		], 15)
		result_title.add_theme_color_override("font_color", Color("#D7DEE8"))
		result_box.add_child(result_title)

		var formula := _make_label("D6 %s + %s %s = %s" % [
			result.get("die", 0),
			result.get("stat_name", "주요 능력치"),
			result.get("stat_value", 0),
			result.get("total", 0),
		], 13)
		formula.add_theme_color_override("font_color", Color("#AAB6C2"))
		result_box.add_child(formula)

		var outcome := String(result.get("outcome", "실패"))
		var reward := int(result.get("reward", 0))
		var outcome_label := _make_label("%s · +%s money" % [outcome, reward], 16)
		outcome_label.add_theme_color_override("font_color", Color("#F4C95D") if reward > 0 else Color("#8E9AA6"))
		result_box.add_child(outcome_label)

	var total_label := _make_label("총 정산 금액  +%s money" % _daily_settlement_total_reward(), 20)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.add_theme_color_override("font_color", Color("#F4C95D"))
	settlement_content.add_child(total_label)


func _daily_settlement_total_reward() -> int:
	var total := 0
	for result in GameState.last_daily_request_results:
		total += int(result.get("reward", 0))
	return total


func _make_job_change_option(character: CardDefinition, job: JobDefinition) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var can_change := GameState.can_change_character_job(character, job.id)
	var level := GameState.get_character_job_level(character, job.id)
	var detail := job.label()
	if level > 0:
		detail += "  Lv.%s" % level
	if not job.is_basic_job():
		detail += "\n%s" % _job_promotion_requirement_text(character, job)

	var label := _make_label(detail, 13)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("#D7DEE8") if can_change else Color("#697682"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	var button := Button.new()
	button.text = "전직" if level == 0 else "직업 변경"
	button.custom_minimum_size = Vector2(100, 34)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not can_change
	_style_pixel_button(button, can_change)
	button.pressed.connect(_on_training_job_selected.bind(job.id))
	row.add_child(button)
	return row


func _job_promotion_requirement_text(character: CardDefinition, job: JobDefinition) -> String:
	var requirements := PackedStringArray()
	for prerequisite_id in job.prerequisite_job_ids:
		var current_level := GameState.get_character_job_level(character, prerequisite_id)
		var progress := "달성" if current_level >= job.prerequisite_job_level else "현재 Lv.%s" % current_level
		requirements.append("%s Lv.%s 필요 · %s" % [
			_job_label(prerequisite_id),
			job.prerequisite_job_level,
			progress,
		])

	if job.required_stats != null and job.required_stats.total() > 0:
		requirements.append("능력치 %s" % _format_stats(job.required_stats))

	if requirements.is_empty():
		return "전직 조건: 없음"
	return "전직 조건: %s" % " / ".join(requirements)


func _refresh_event_list() -> void:
	var requests := GameState.office.available_requests.duplicate()
	requests.sort_custom(Callable(self, "_sort_requests_by_label"))
	_populate_event_list(requests)


func _refresh_inventory_drawer() -> void:
	character_panel.visible = true

	if active_drawer_type == NO_ACTIVE_DRAWER:
		inventory_drawer.visible = false
		return

	inventory_drawer.visible = true

	if active_drawer_type == GameEnums.CardType.CHARACTER:
		if not String(request_assignment_target_id).is_empty():
			inventory_drawer_title.text = "의뢰 담당 인물 선택"
			_populate_job_training_candidate_list()
		elif is_selecting_job_training_character:
			inventory_drawer_title.text = "직업 교육 대상 선택"
			_populate_job_training_candidate_list()
		else:
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
	event_list.add_child(_make_job_training_event_row())

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


func _populate_job_training_candidate_list() -> void:
	_clear_children(inventory_card_list)
	var characters := _get_cards_by_type(GameEnums.CardType.CHARACTER)
	if characters.is_empty():
		inventory_card_list.add_child(_make_empty_label("배치할 수 있는 캐릭터가 없습니다."))
		return

	for card in characters:
		inventory_card_list.add_child(_make_character_card_row(card))


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
	var candidates := GameState.get_hire_candidates()
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


func _character_event_assignment_label(card: CardDefinition) -> String:
	var confirmed_assignment := GameState.get_character_event_assignment(card)
	if not confirmed_assignment.is_empty():
		return confirmed_assignment

	if card != null and job_training_candidate_character_id == card.id:
		return "직업 교육소 (배치 대기)"

	if card != null:
		for raw_request_id in daily_request_character_ids:
			if StringName(daily_request_character_ids[raw_request_id]) != card.id:
				continue
			var request := ContentCatalog.get_request(StringName(raw_request_id))
			return "%s (배치 대기)" % (_request_display_title(request) if request != null else String(raw_request_id))
	return ""


func _card_meta(card: CardDefinition) -> String:
	var parts: PackedStringArray = []

	if card.is_character():
		if not String(card.species).is_empty():
			parts.append(_character_species(card))
		if not String(card.job).is_empty():
			parts.append(_character_job(card))
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
	return _job_label(GameState.get_character_current_job_id(card))


func _job_label(job_id: StringName) -> String:
	if String(job_id).is_empty():
		return "Unassigned"

	var job := ContentCatalog.get_job(job_id)
	if job == null:
		return String(job_id)
	return job.label()


func _character_species(card: CardDefinition) -> String:
	if String(card.species).is_empty():
		return "Unassigned"

	var species: Variant = ContentCatalog.get_species(card.species)
	if species == null:
		return String(card.species)

	return species.label()


func _species_skills(card: CardDefinition) -> PackedStringArray:
	var species: Variant = ContentCatalog.get_species(card.species)
	if species == null:
		return PackedStringArray()

	return species.skill_ids


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

	var formatted_stats := "STR %s  AGI %s  INT %s  CHM %s  HP %s" % [
		stats.strength,
		stats.agility,
		stats.intelligence,
		stats.charm,
		stats.health,
	]
	if stats.defense != 0:
		formatted_stats += "  DEF %s" % stats.defense
	if stats.magic_defense != 0:
		formatted_stats += "  MDEF %s" % stats.magic_defense
	return formatted_stats


func _format_level_up_gain(stats: StatBlock) -> String:
	if stats == null:
		return "+0"

	var parts: PackedStringArray = []
	if stats.strength != 0:
		parts.append("STR +%s" % stats.strength)
	if stats.agility != 0:
		parts.append("AGI +%s" % stats.agility)
	if stats.intelligence != 0:
		parts.append("INT +%s" % stats.intelligence)
	if stats.charm != 0:
		parts.append("CHM +%s" % stats.charm)
	if stats.health != 0:
		parts.append("HP +%s" % stats.health)

	if parts.is_empty():
		return "+0"

	return ", ".join(parts)


func _event_meta(request: RequestDefinition) -> String:
	var parts: PackedStringArray = [
		GameEnums.request_type_label(request.request_type),
		"%s days" % request.duration_days,
		"valid %s days" % request.valid_days,
	]

	if request.repeatable_after_expiry:
		parts.append("repeatable")

	var visible_tags := PackedStringArray()
	for tag in request.tags:
		if tag != GameState.DAILY_REQUEST_TAG and tag != GameState.DAILY_INCOME_TAG:
			visible_tags.append(tag)
	if not visible_tags.is_empty():
		parts.append("주요 능력: %s" % ", ".join(visible_tags))

	return " / ".join(parts)


func _request_display_title(request: RequestDefinition) -> String:
	if request.tags.has(GameState.DAILY_REQUEST_TAG):
		return "[일일 의뢰] %s" % request.label()
	if request.tags.has(GameState.DAILY_INCOME_TAG):
		return "[일일 소득] %s" % request.label()
	return request.label()


func _event_rewards(request: RequestDefinition) -> String:
	if request.tags.has(GameState.DAILY_REQUEST_TAG) or request.tags.has(GameState.DAILY_INCOME_TAG):
		return "보상: 대성공 40 money / 성공 20 money / 실패 0 money"
	return "Reward %s money / %s reputation" % [
		request.reward_money,
		request.reward_reputation,
	]


func _on_next_day_pressed() -> void:
	var previous_day := GameState.current_day
	GameState.advance_day()
	if GameState.current_day == previous_day:
		return

	daily_request_character_ids.clear()
	request_assignment_target_id = &""
	settlement_results_dismissed = false
	selected_event_id = &""
	_close_inventory_drawer()
	_refresh()


func _on_event_title_pressed(event_id: StringName) -> void:
	_toggle_event_detail(event_id)


func _on_event_row_gui_input(event: InputEvent, event_id: StringName) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_toggle_event_detail(event_id)


func _toggle_event_detail(event_id: StringName) -> void:
	is_selecting_tax_event_money = false
	if event_id != JOB_TRAINING_EVENT_ID:
		is_selecting_job_training_character = false

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
	is_selecting_job_training_character = false
	job_training_candidate_character_id = &""
	daily_request_character_ids.clear()
	request_assignment_target_id = &""
	settlement_results_dismissed = false
	_reset_player_creation_form()
	GameState.reset_game()


func _on_personnel_pressed() -> void:
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	is_selecting_job_training_character = false
	_open_inventory_drawer(GameEnums.CardType.CHARACTER)


func _on_equipment_pressed() -> void:
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	is_selecting_job_training_character = false
	_open_inventory_drawer(GameEnums.CardType.EQUIPMENT)


func _on_consumable_pressed() -> void:
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	is_selecting_job_training_character = false
	_open_inventory_drawer(GameEnums.CardType.CONSUMABLE)


func _on_equipment_slot_pressed(character_id: StringName) -> void:
	equipment_target_character_id = character_id
	selected_character_card_id = character_id
	is_selecting_tax_event_money = false
	_open_inventory_drawer(GameEnums.CardType.EQUIPMENT)


func _on_level_up_pressed(character_id: StringName) -> void:
	var character := ContentCatalog.get_card(character_id)
	if GameState.level_up_character(character):
		selected_character_card_id = character_id
		_refresh()


func _on_job_level_up_pressed(character_id: StringName) -> void:
	var character := ContentCatalog.get_card(character_id)
	if GameState.level_up_current_job(character):
		selected_character_card_id = character_id
		_refresh()


func _on_change_job_pressed(character_id: StringName, job_id: StringName) -> void:
	var character := ContentCatalog.get_card(character_id)
	if GameState.change_character_job(character, job_id):
		selected_character_card_id = character_id
		_refresh()


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


func _on_daily_request_character_slot_pressed(request_id: StringName) -> void:
	var request := ContentCatalog.get_request(request_id)
	if request == null or not GameState.office.available_requests.has(request) or GameState.get_daily_request_assigned_character(request) != null:
		return

	selected_event_id = _request_event_id(request)
	selected_character_card_id = &""
	_refresh_character_detail_popup()
	request_assignment_target_id = request_id
	is_selecting_job_training_character = false
	is_selecting_tax_event_money = false
	equipment_target_character_id = &""
	_open_inventory_drawer(GameEnums.CardType.CHARACTER)


func _on_daily_request_execute_pressed(request_id: StringName) -> void:
	var request := ContentCatalog.get_request(request_id)
	var character_id := StringName(daily_request_character_ids.get(request_id, &""))
	var character := ContentCatalog.get_card(character_id)
	if not GameState.queue_daily_request(request, character):
		return

	daily_request_character_ids.erase(request_id)
	selected_event_id = &""
	_close_inventory_drawer()
	_refresh()


func _on_daily_request_cancel_pressed(request_id: StringName) -> void:
	var request := ContentCatalog.get_request(request_id)
	daily_request_character_ids.erase(request_id)
	if request != null:
		GameState.cancel_daily_request_assignment(request)
	request_assignment_target_id = &""
	_close_inventory_drawer()
	_refresh()


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


func _on_job_training_character_slot_pressed() -> void:
	selected_event_id = JOB_TRAINING_EVENT_ID
	selected_character_card_id = &""
	_refresh_character_detail_popup()
	is_selecting_job_training_character = true
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	_open_inventory_drawer(GameEnums.CardType.CHARACTER)


func _on_job_training_cancel_pressed() -> void:
	if not String(job_training_candidate_character_id).is_empty():
		job_training_candidate_character_id = &""
		is_selecting_job_training_character = false
		_close_inventory_drawer()
		_refresh()
		return

	if GameState.cancel_job_training():
		is_selecting_job_training_character = false
		_close_inventory_drawer()


func _on_job_training_execute_pressed() -> void:
	var character := ContentCatalog.get_card(job_training_candidate_character_id)
	if character == null:
		return

	job_training_candidate_character_id = &""
	selected_event_id = &""
	is_selecting_job_training_character = false
	if GameState.assign_job_training(character):
		_refresh()


func _on_training_job_selected(job_id: StringName) -> void:
	if GameState.complete_job_training(job_id):
		selected_event_id = JOB_TRAINING_EVENT_ID
		_refresh()


func _open_inventory_drawer(card_type: int) -> void:
	active_drawer_type = card_type

	_refresh_inventory_drawer()
	_refresh_inventory_buttons()


func _close_inventory_drawer() -> void:
	active_drawer_type = NO_ACTIVE_DRAWER
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	is_selecting_job_training_character = false
	request_assignment_target_id = &""
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
			if not String(request_assignment_target_id).is_empty():
				var request_id := request_assignment_target_id
				var request := ContentCatalog.get_request(request_id)
				var request_character := ContentCatalog.get_card(card_id)
				if _character_event_assignment_label(request_character).is_empty() and GameState.can_queue_daily_request(request, request_character):
					daily_request_character_ids[request_id] = card_id
					selected_event_id = _request_event_id(request)
					_close_inventory_drawer()
					_refresh()
				return

			if is_selecting_job_training_character:
				var training_character := ContentCatalog.get_card(card_id)
				if _character_event_assignment_label(training_character).is_empty() and GameState.can_assign_job_training(training_character):
					job_training_candidate_character_id = card_id
					selected_event_id = JOB_TRAINING_EVENT_ID
					_close_inventory_drawer()
					_refresh()
				return

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


func _close_settlement_popup() -> void:
	settlement_results_dismissed = true
	_refresh()


func _on_hire_pressed(card_id: StringName) -> void:
	var card := ContentCatalog.get_card(card_id)
	if GameState.hire_card(card):
		_refresh()
