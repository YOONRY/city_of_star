extends Control

enum Drawer { CLOSED, CHARACTER_PICKER, EQUIPMENT, CONSUMABLE, SHOP, PERSONNEL }

const NO_FACILITY := -1
const TAX_PAYMENT_EVENT_ID := &"tax_payment"
const JOB_TRAINING_EVENT_ID := &"job_training"
const NOTICE_INK := Color("#2E2A24")
const NOTICE_MUTED_INK := Color("#554D40")
const NOTICE_ACTIVE_INK := Color("#245951")
const BOARD_TITLE_INK := Color("#F6EBD6")
const SCREEN_MARGIN := 40
const ROSTER_WIDTH := 360
const NoticeBoardArt := preload("res://scripts/ui/notice_board_art.gd")

var notice_board_art := NoticeBoardArt.new()
var day_value: Label
var status_label: Label
var event_panel: PanelContainer
var event_list: VBoxContainer
var event_detail_popup: PanelContainer
var event_detail_sheet: PanelContainer
var event_detail_title: Label
var event_detail_pin: TextureRect
var event_detail_close_button: Button
var event_detail_scroll: ScrollContainer
var event_detail_content: VBoxContainer
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
var facility_balance_label: Label
var shop_tabs: TabBar
var inventory_scroll: ScrollContainer
var equipment_button: Button
var consumable_button: Button
var active_drawer_type: int = Drawer.CLOSED
var facility_assignment_target: int = NO_FACILITY
var facility_candidate_ids: Dictionary = {}
var facility_open_queue: Array[int] = []
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
	GameState.day_advanced.connect(_on_day_advanced)
	ContentCatalog.catalog_reloaded.connect(_refresh)
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#101820")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", SCREEN_MARGIN)
	root.add_theme_constant_override("margin_right", SCREEN_MARGIN)
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

	var calendar_panel := _make_wood_panel()
	var calendar_frame := notice_board_art.board.duplicate() as StyleBoxTexture
	calendar_frame.content_margin_top = 14
	calendar_frame.content_margin_bottom = 14
	calendar_panel.add_theme_stylebox_override("panel", calendar_frame)
	calendar_panel.custom_minimum_size = Vector2(230, 0)
	top_bar.add_child(calendar_panel)
	var calendar_sheet := _make_paper_panel()
	calendar_panel.add_child(calendar_sheet)

	day_value = _make_ink_label("", 24, NOTICE_ACTIVE_INK)
	day_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	day_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	calendar_sheet.add_child(day_value)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)

	var event_stage := Control.new()
	event_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(event_stage)

	event_panel = _make_wood_panel()
	event_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_stage.add_child(event_panel)

	var event_box := VBoxContainer.new()
	event_box.add_theme_constant_override("separation", 14)
	event_panel.add_child(event_box)

	event_box.add_child(_make_board_title("의뢰 게시판"))

	status_label = _make_label("", 13)
	status_label.add_theme_color_override("font_color", Color("#EDE1D1"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_box.add_child(status_label)

	var event_scroll := ScrollContainer.new()
	event_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	event_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_box.add_child(event_scroll)

	event_list = VBoxContainer.new()
	event_list.add_theme_constant_override("separation", 9)
	event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_scroll.add_child(event_list)
	_build_event_detail_popup(event_stage)

	character_detail_popup = _make_wood_panel()
	character_detail_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_detail_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	character_detail_popup.visible = false
	event_stage.add_child(character_detail_popup)

	var popup_box := VBoxContainer.new()
	popup_box.add_theme_constant_override("separation", 12)
	character_detail_popup.add_child(popup_box)

	var popup_header := HBoxContainer.new()
	popup_header.add_theme_constant_override("separation", 10)
	popup_box.add_child(popup_header)

	character_detail_title = _make_board_title("")
	character_detail_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	character_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_header.add_child(character_detail_title)

	var character_detail_close_button := _make_close_button()
	_style_board_close_button(character_detail_close_button)
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

	job_change_popup = _make_wood_panel()
	job_change_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	job_change_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	job_change_popup.visible = false
	event_stage.add_child(job_change_popup)

	var job_change_box := VBoxContainer.new()
	job_change_box.add_theme_constant_override("separation", 12)
	job_change_popup.add_child(job_change_box)

	job_change_title = _make_board_title("전직할 직업을 선택하세요")
	job_change_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	job_change_box.add_child(job_change_title)

	var job_change_help := _make_ink_label("직업 교육을 마쳤습니다. 조건을 만족한 직업 중 하나를 선택해야 다음 날로 진행할 수 있습니다.", 12, BOARD_TITLE_INK)
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

	settlement_popup = _make_wood_panel()
	settlement_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	var settlement_title := _make_board_title("일일 정산")
	settlement_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settlement_header.add_child(settlement_title)

	var settlement_close_button := _make_close_button()
	_style_board_close_button(settlement_close_button)
	settlement_close_button.pressed.connect(_close_settlement_popup)
	settlement_header.add_child(settlement_close_button)

	var settlement_help := _make_ink_label("전날 실행한 의뢰를 한꺼번에 판정했습니다.", 12, BOARD_TITLE_INK)
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
	right_column.custom_minimum_size = Vector2(ROSTER_WIDTH, 0)
	right_column.add_theme_constant_override("separation", 14)
	body.add_child(right_column)

	character_panel = _make_wood_panel()
	character_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(character_panel)

	var character_box := VBoxContainer.new()
	character_box.add_theme_constant_override("separation", 12)
	character_panel.add_child(character_box)

	character_box.add_child(_make_board_title("인물 목록"))

	var character_scroll := ScrollContainer.new()
	character_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	character_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_box.add_child(character_scroll)

	character_card_list = VBoxContainer.new()
	character_card_list.add_theme_constant_override("separation", 10)
	character_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_scroll.add_child(character_card_list)
	var dock_space := Control.new()
	dock_space.custom_minimum_size.y = 70
	dock_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_box.add_child(dock_space)

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

	inventory_drawer = _make_wood_panel()
	inventory_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_drawer.z_index = 40
	inventory_drawer.visible = false
	add_child(inventory_drawer)
	character_panel.item_rect_changed.connect(_align_inventory_drawer)

	var drawer_box := VBoxContainer.new()
	drawer_box.add_theme_constant_override("separation", 10)
	inventory_drawer.add_child(drawer_box)

	var drawer_header := HBoxContainer.new()
	drawer_header.add_theme_constant_override("separation", 10)
	drawer_box.add_child(drawer_header)

	inventory_drawer_title = _make_board_title("")
	inventory_drawer_title.add_theme_font_size_override("font_size", 21)
	inventory_drawer_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inventory_drawer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_header.add_child(inventory_drawer_title)

	inventory_close_button = _make_close_button()
	_style_board_close_button(inventory_close_button)
	inventory_close_button.pressed.connect(_dismiss_inventory_drawer)
	drawer_header.add_child(inventory_close_button)

	facility_balance_label = _make_ink_label("", 14, BOARD_TITLE_INK)
	facility_balance_label.visible = false
	drawer_box.add_child(facility_balance_label)

	shop_tabs = TabBar.new()
	_style_notice_tabs(shop_tabs)
	shop_tabs.add_tab("구매")
	shop_tabs.add_tab("판매")
	shop_tabs.visible = false
	shop_tabs.tab_changed.connect(_on_shop_tab_changed)
	drawer_box.add_child(shop_tabs)

	inventory_scroll = ScrollContainer.new()
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_box.add_child(inventory_scroll)

	inventory_card_list = VBoxContainer.new()
	inventory_card_list.add_theme_constant_override("separation", 10)
	inventory_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.add_child(inventory_card_list)

	_build_player_creation_overlay()


func _align_inventory_drawer() -> void:
	var bounds := character_panel.get_global_rect()
	inventory_drawer.position = bounds.position - global_position
	inventory_drawer.size = bounds.size


func _build_event_detail_popup(stage: Control) -> void:
	event_detail_popup = _make_wood_panel()
	event_detail_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_detail_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	event_detail_popup.hide()
	stage.add_child(event_detail_popup)

	event_detail_sheet = PanelContainer.new()
	event_detail_popup.add_child(event_detail_sheet)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	event_detail_sheet.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)
	event_detail_pin = TextureRect.new()
	event_detail_pin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	header.add_child(event_detail_pin)
	event_detail_title = _make_ink_label("", 24)
	event_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(event_detail_title)
	event_detail_close_button = _make_close_button()
	event_detail_close_button.tooltip_text = "의뢰 목록으로 돌아가기"
	event_detail_close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_style_notice_button(event_detail_close_button, false)
	event_detail_close_button.pressed.connect(_close_event_detail)
	header.add_child(event_detail_close_button)
	layout.add_child(HSeparator.new())

	event_detail_scroll = ScrollContainer.new()
	event_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	event_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(event_detail_scroll)
	event_detail_content = VBoxContainer.new()
	event_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_detail_scroll.add_child(event_detail_content)


func _build_player_creation_overlay() -> void:
	player_creation_overlay = Control.new()
	player_creation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	player_creation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	player_creation_overlay.z_index = 100
	add_child(player_creation_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color("#131617ed")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	player_creation_overlay.add_child(backdrop)

	var panel := _make_wood_panel()
	panel.anchor_left = 0.16
	panel.anchor_top = 0.06
	panel.anchor_right = 0.84
	panel.anchor_bottom = 0.94
	player_creation_overlay.add_child(panel)

	var sheet := _make_paper_panel(notice_board_art.selected_note)
	panel.add_child(sheet)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	sheet.add_child(outer)

	var title := _make_ink_label("플레이어 캐릭터 생성", 23)
	outer.add_child(title)

	var guide := _make_ink_label("모든 개인 성장치는 10에서 시작합니다. 추가 성장치 80점을 분배하고 초기 개인 스킬 2개를 선택하세요.", 13, NOTICE_MUTED_INK)
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

	identity_grid.add_child(_make_ink_label("이름", 13))
	player_name_input = LineEdit.new()
	_style_paper_input(player_name_input)
	player_name_input.text = "별의 아이"
	player_name_input.max_length = 20
	player_name_input.text_changed.connect(_on_player_creation_changed)
	identity_grid.add_child(player_name_input)

	identity_grid.add_child(_make_ink_label("종족", 13))
	player_species_option = OptionButton.new()
	_style_paper_option(player_species_option)
	player_species_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for species_definition in ContentCatalog.species:
		var species_index := player_species_option.item_count
		player_species_option.add_item(species_definition.label())
		player_species_option.set_item_metadata(species_index, species_definition.id)
	identity_grid.add_child(player_species_option)

	identity_grid.add_child(_make_ink_label("기본직업", 13))
	player_job_option = OptionButton.new()
	_style_paper_option(player_job_option)
	player_job_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for job in ContentCatalog.jobs:
		if job == null or not job.is_basic_job():
			continue
		var job_index := player_job_option.item_count
		player_job_option.add_item(job.label())
		player_job_option.set_item_metadata(job_index, job.id)
	identity_grid.add_child(player_job_option)

	content.add_child(HSeparator.new())
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 24)
	content.add_child(choices)
	var growth_column := VBoxContainer.new()
	growth_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	growth_column.add_theme_constant_override("separation", 8)
	choices.add_child(growth_column)
	var skill_column := VBoxContainer.new()
	skill_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_column.add_theme_constant_override("separation", 8)
	choices.add_child(skill_column)

	var growth_header := HBoxContainer.new()
	growth_column.add_child(growth_header)
	var growth_title := _make_ink_label("개인 성장치", 15, NOTICE_ACTIVE_INK)
	growth_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	growth_header.add_child(growth_title)
	player_growth_remaining_label = _make_ink_label("", 13, NOTICE_MUTED_INK)
	growth_header.add_child(player_growth_remaining_label)

	var growth_grid := GridContainer.new()
	growth_grid.columns = 4
	growth_grid.add_theme_constant_override("h_separation", 10)
	growth_grid.add_theme_constant_override("v_separation", 6)
	growth_column.add_child(growth_grid)
	_add_player_growth_row(growth_grid, "strength", "STR")
	_add_player_growth_row(growth_grid, "agility", "AGI")
	_add_player_growth_row(growth_grid, "intelligence", "INT")
	_add_player_growth_row(growth_grid, "charm", "CHM")
	_add_player_growth_row(growth_grid, "health", "HP")

	var skill_title := _make_ink_label("초기 개인 스킬", 15, NOTICE_ACTIVE_INK)
	skill_column.add_child(skill_title)

	var skill_grid := GridContainer.new()
	skill_grid.columns = 2
	skill_grid.add_theme_constant_override("h_separation", 18)
	skill_grid.add_theme_constant_override("v_separation", 5)
	skill_column.add_child(skill_grid)
	for skill_id in GameState.get_player_initial_skill_options():
		var checkbox := CheckBox.new()
		checkbox.text = skill_id
		_style_paper_checkbox(checkbox)
		checkbox.toggled.connect(_on_player_skill_toggled.bind(skill_id))
		player_skill_checkboxes[skill_id] = checkbox
		skill_grid.add_child(checkbox)

	player_creation_status_label = _make_ink_label("", 13, NOTICE_MUTED_INK)
	player_creation_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_column.add_child(player_creation_status_label)

	player_create_button = Button.new()
	player_create_button.text = "캐릭터 생성"
	player_create_button.custom_minimum_size = Vector2(0, 42)
	player_create_button.focus_mode = Control.FOCUS_NONE
	_style_notice_button(player_create_button, true)
	player_create_button.pressed.connect(_on_player_create_pressed)
	outer.add_child(player_create_button)
	_refresh_player_creation_form()


func _add_player_growth_row(grid: GridContainer, stat_key: String, stat_label: String) -> void:
	grid.add_child(_make_ink_label(stat_label, 13))
	var decrease_button := Button.new()
	decrease_button.text = "-10"
	decrease_button.focus_mode = Control.FOCUS_NONE
	_style_notice_button(decrease_button, false)
	decrease_button.pressed.connect(_on_player_growth_adjusted.bind(stat_key, -10))
	grid.add_child(decrease_button)

	var value_label := _make_ink_label(str(player_creation_growth[stat_key]), 13)
	value_label.custom_minimum_size.x = 32
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_growth_value_labels[stat_key] = value_label
	grid.add_child(value_label)

	var increase_button := Button.new()
	increase_button.text = "+10"
	increase_button.focus_mode = Control.FOCUS_NONE
	_style_notice_button(increase_button, false)
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
	player_growth_remaining_label.add_theme_color_override("font_color", NOTICE_ACTIVE_INK if remaining == 0 else NOTICE_MUTED_INK)

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


func _make_wood_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", notice_board_art.board)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return panel


func _make_paper_panel(style: StyleBoxTexture = null) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style if style != null else notice_board_art.note)
	return panel


func _make_board_title(title: String) -> Label:
	var label := _make_label(title, 23)
	label.add_theme_color_override("font_color", BOARD_TITLE_INK)
	return label


func _make_ink_label(value: String, font_size: int, color: Color = NOTICE_INK) -> Label:
	var label := _make_label(value, font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style_board_close_button(button: Button) -> void:
	_style_clear_button(button)
	button.add_theme_color_override("font_color", BOARD_TITLE_INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _style_paper_input(input: LineEdit) -> void:
	input.add_theme_stylebox_override("normal", _notice_control_style(Color("#F5EDDD"), Color("#A39783")))
	input.add_theme_stylebox_override("focus", _notice_control_style(Color.TRANSPARENT, NOTICE_ACTIVE_INK))
	input.add_theme_color_override("font_color", NOTICE_INK)
	input.add_theme_color_override("font_selected_color", NOTICE_INK)
	input.add_theme_color_override("font_placeholder_color", NOTICE_MUTED_INK)
	input.add_theme_color_override("caret_color", NOTICE_ACTIVE_INK)
	input.add_theme_color_override("selection_color", Color("#B5CBC0"))


func _style_paper_option(option: OptionButton) -> void:
	_style_notice_button(option, false)
	option.add_theme_constant_override("modulate_arrow", 1)
	var menu := option.get_popup()
	menu.add_theme_stylebox_override("panel", notice_board_art.note)
	menu.add_theme_stylebox_override("hover", _notice_control_style(Color("#CDD9CC"), Color("#688077")))
	menu.add_theme_color_override("font_color", NOTICE_INK)
	menu.add_theme_color_override("font_hover_color", NOTICE_ACTIVE_INK)
	menu.add_theme_constant_override("v_separation", 8)


func _style_paper_checkbox(checkbox: CheckBox) -> void:
	_style_clear_button(checkbox)
	checkbox.add_theme_stylebox_override("focus", _notice_control_style(Color.TRANSPARENT, NOTICE_ACTIVE_INK))
	checkbox.add_theme_icon_override("unchecked", notice_board_art.check_off)
	checkbox.add_theme_icon_override("checked", notice_board_art.check_on)
	checkbox.add_theme_color_override("font_color", NOTICE_INK)
	checkbox.add_theme_color_override("font_hover_color", NOTICE_ACTIVE_INK)
	checkbox.add_theme_color_override("font_pressed_color", NOTICE_ACTIVE_INK)


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

	var is_equip_target := card.is_equipment() and not equipment_target_character_id.is_empty()
	var row := _make_paper_panel(notice_board_art.selected_note if is_equip_target else notice_board_art.note)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	row.add_child(box)

	var name_label := _make_ink_label(card.label(), 16)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)

	var meta_label := _make_ink_label(_card_meta(card), 12, NOTICE_MUTED_INK)
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(meta_label)

	var stat_label := _make_ink_label(_format_stats(card.stats), 12)
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stat_label)

	if is_equip_target:
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = "장착"
		row.gui_input.connect(_on_equipment_card_gui_input.bind(card.id))
		_set_mouse_filter_recursive(box, Control.MOUSE_FILTER_IGNORE)

	return row


func _make_money_stack_card() -> PanelContainer:
	var is_tax_target := is_selecting_tax_event_money
	var tax_amount := GameState.tax_manager.weekly_tax
	var is_current_week_paid := GameState.tax_manager.has_paid_current_week(GameState.current_day)
	var can_assign_money := is_tax_target and not is_current_week_paid and GameState.office.money >= tax_amount
	var row := _make_paper_panel(notice_board_art.completed_note if can_assign_money else notice_board_art.note)
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

	stack_visual.add_child(_make_money_stack_layer(Vector2(18, 0), Color("#93A492")))
	stack_visual.add_child(_make_money_stack_layer(Vector2(10, 8), Color("#ACBDAC")))
	stack_visual.add_child(_make_money_stack_layer(Vector2(2, 16), Color("#CFDACA"), "$"))

	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation", 4)
	box.add_child(summary)

	var name_label := _make_ink_label("보유 자금", 15)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(name_label)

	var amount_label := _make_ink_label("%s money" % GameState.office.money, 22, NOTICE_ACTIVE_INK)
	amount_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(amount_label)

	var meta_text := ""
	if is_tax_target:
		if is_current_week_paid:
			meta_text = "이번 주 납부 완료"
		elif can_assign_money:
			meta_text = "납부할 금액: %s money" % tax_amount
		else:
			meta_text = "부족한 금액: %s money" % maxi(0, tax_amount - GameState.office.money)

	if not meta_text.is_empty():
		var meta_label := _make_ink_label(meta_text, 12, NOTICE_MUTED_INK)
		meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_child(meta_label)

	_set_mouse_filter_recursive(box, Control.MOUSE_FILTER_IGNORE)
	return row


func _make_money_stack_layer(offset: Vector2, background_color: Color, text: String = "") -> PanelContainer:
	var layer := PanelContainer.new()
	layer.position = offset
	layer.custom_minimum_size = Vector2(56, 42)
	layer.size = Vector2(56, 42)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	layer.add_theme_stylebox_override("panel", _notice_control_style(background_color, Color("#607866")))

	if not text.is_empty():
		var label := _make_ink_label(text, 20, NOTICE_ACTIVE_INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		layer.add_child(label)

	return layer


func _make_character_card_row(card: CardDefinition) -> PanelContainer:
	var row := PanelContainer.new()
	var is_selected := selected_character_card_id == card.id
	var assigned_event := _character_event_assignment_label(card)
	var is_event_selection := active_drawer_type == Drawer.CHARACTER_PICKER
	var is_unavailable_for_event := is_event_selection and not assigned_event.is_empty()
	var style := notice_board_art.note
	if not assigned_event.is_empty():
		style = notice_board_art.completed_note
	if is_selected:
		style = notice_board_art.selected_note
	row.add_theme_stylebox_override("panel", style)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	if not assigned_event.is_empty():
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

	var name_label := _make_ink_label(card.label(), 19)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(name_label)

	var summary_spacer := Control.new()
	summary_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.add_child(summary_spacer)

	var job_label := _make_ink_label("%s / %s" % [_character_species(card), _character_job(card)], 12, NOTICE_MUTED_INK)
	job_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	job_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(job_label)

	if not assigned_event.is_empty():
		var assignment_label := _make_ink_label("배치 중 · %s" % assigned_event, 12, NOTICE_ACTIVE_INK)
		assignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		assignment_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		summary.add_child(assignment_label)

	_set_mouse_filter_recursive(box, Control.MOUSE_FILTER_IGNORE)
	_set_button_mouse_filter_recursive(box)
	return row


func _make_profile_frame(card: CardDefinition) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(56, 56)
	frame.add_theme_stylebox_override("panel", _notice_control_style(Color("#C0CFC4"), Color("#6F887B")))

	var label := _make_ink_label(_card_initials(card), 20, NOTICE_ACTIVE_INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(label)
	return frame


func _make_character_detail(card: CardDefinition) -> TabContainer:
	var detail := TabContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_stylebox_override("panel", notice_board_art.selected_note)
	_style_notice_tabs(detail)
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

	var title := _make_ink_label("Total Stats", 13, NOTICE_ACTIVE_INK)
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

	var skill_title := _make_ink_label("Skills", 13, NOTICE_ACTIVE_INK)
	tab.add_child(skill_title)

	var skill_label := _make_ink_label(_format_string_array(card.skill_ids, "None"), 12, NOTICE_MUTED_INK)
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(skill_label)

	var species_skill_title := _make_ink_label("Species Skills", 13, NOTICE_ACTIVE_INK)
	tab.add_child(species_skill_title)

	var species_skill_label := _make_ink_label(_format_string_array(_species_skills(card), "None"), 12, NOTICE_MUTED_INK)
	species_skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(species_skill_label)

	var job_skill_title := _make_ink_label("Learned Job Skills", 13, NOTICE_ACTIVE_INK)
	tab.add_child(job_skill_title)

	var learned_skill_ids := GameState.get_character_job_skill_ids(card)
	if learned_skill_ids.is_empty():
		tab.add_child(_make_ink_label("None", 12, NOTICE_MUTED_INK))
	for skill_id in learned_skill_ids:
		tab.add_child(_make_job_skill_entry(skill_id))

	var current_job_id := GameState.get_character_current_job_id(card)
	var current_job := ContentCatalog.get_job(current_job_id)
	var job_level := GameState.get_character_job_level(card, current_job_id)
	if current_job != null:
		var upcoming := VBoxContainer.new()
		upcoming.add_theme_constant_override("separation", 8)
		for index in current_job.skill_ids.size():
			var unlock_level := 1
			if index < current_job.skill_unlock_levels.size():
				unlock_level = current_job.skill_unlock_levels[index]
			if unlock_level > job_level and not learned_skill_ids.has(current_job.skill_ids[index]):
				upcoming.add_child(_make_job_skill_entry(current_job.skill_ids[index], unlock_level))
		if upcoming.get_child_count() > 0:
			var upcoming_title := _make_ink_label("미습득 직업 스킬", 13, NOTICE_ACTIVE_INK)
			tab.add_child(upcoming_title)
			tab.add_child(upcoming)
		else:
			upcoming.free()

	var tag_title := _make_ink_label("Tags", 13, NOTICE_ACTIVE_INK)
	tab.add_child(tag_title)

	var tag_label := _make_ink_label(_format_string_array(card.tags, "None"), 12, NOTICE_MUTED_INK)
	tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(tag_label)
	return tab


func _make_job_skill_entry(skill_id: String, unlock_level: int = 0) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 4)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skill := ContentCatalog.get_skill(int(skill_id)) if skill_id.is_valid_int() else null
	if skill == null:
		var legacy_label := _make_ink_label(skill_id, 12)
		legacy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(legacy_label)
		return entry

	var title_text := skill.display_name
	if unlock_level > 0:
		title_text += " · Lv.%s" % unlock_level
	var title := _make_ink_label(title_text, 14, NOTICE_MUTED_INK if unlock_level > 0 else NOTICE_ACTIVE_INK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(title)
	var metadata := PackedStringArray([skill.type_label()])
	if skill.is_active():
		metadata.append("AP %s" % skill.ap_cost if skill.ap_cost >= 0 else "AP 미정")
	if not skill.damage_label().is_empty():
		metadata.append(skill.damage_label())
	var metadata_label := _make_ink_label(" · ".join(metadata), 12)
	metadata_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(metadata_label)
	var description := _make_ink_label(skill.effect_text, 12)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(description)

	var columns := PackedStringArray()
	for column in skill.usable_columns:
		columns.append(str(column))
	var conditions := PackedStringArray(["사용 열: %s" % ", ".join(columns)])
	if not skill.required_equipment.is_empty():
		conditions.append("장비: %s" % skill.required_equipment)
	if not skill.main_stat.is_empty():
		conditions.append("주 스탯: %s" % skill.main_stat)
	if not skill.target_text.is_empty():
		conditions.append("대상: %s" % skill.target_text)
	var conditions_label := _make_ink_label(" · ".join(conditions), 12, NOTICE_MUTED_INK)
	conditions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(conditions_label)
	entry.add_child(HSeparator.new())
	return entry


func _make_character_job_history_tab(card: CardDefinition) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = "Job History"
	tab.add_theme_constant_override("separation", 10)

	var current_job_id := GameState.get_character_current_job_id(card)
	var current_level := GameState.get_character_job_level(card, current_job_id)
	var current_title := _make_ink_label("Current: %s  Lv.%s/%s" % [_job_label(current_job_id), current_level, GameState.MAX_JOB_LEVEL], 13, NOTICE_ACTIVE_INK)
	tab.add_child(current_title)

	var train_button := Button.new()
	train_button.text = "Job Mastered" if current_level >= GameState.MAX_JOB_LEVEL else "Train Current Job"
	train_button.focus_mode = Control.FOCUS_NONE
	train_button.disabled = not GameState.can_level_up_current_job(card)
	_style_notice_button(train_button, true)
	train_button.pressed.connect(_on_job_level_up_pressed.bind(card.id))
	tab.add_child(train_button)

	var history_title := _make_ink_label("Previous / Acquired Jobs", 13, NOTICE_ACTIVE_INK)
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

	var available_title := _make_ink_label("Available Jobs", 13, NOTICE_ACTIVE_INK)
	tab.add_child(available_title)

	for job in ContentCatalog.jobs:
		if levels.has(job.id):
			continue
		tab.add_child(_make_job_candidate_row(card, job))

	return tab


func _make_job_history_row(card: CardDefinition, job: JobDefinition, level: int, is_current: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	var mastered_text := "  MASTER" if level >= GameState.MAX_JOB_LEVEL else ""
	var label := _make_ink_label("%s  Lv.%s%s" % [job.label(), level, mastered_text], 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var button := Button.new()
	button.text = "Current" if is_current else "교육소"
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = true
	_style_notice_button(button, false)
	row.add_child(button)
	return row


func _make_job_candidate_row(card: CardDefinition, job: JobDefinition) -> HBoxContainer:
	var row := HBoxContainer.new()
	var can_change := GameState.can_change_character_job(card, job.id)
	var description := job.label()
	if not job.is_basic_job():
		description += "  (%s)" % job.requirement_text()

	var label := _make_ink_label(description, 12, NOTICE_INK if can_change else NOTICE_MUTED_INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	var button := Button.new()
	button.text = "교육소"
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = true
	_style_notice_button(button, can_change)
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

	var gain_label := _make_ink_label("Next %s" % _format_level_up_gain(GameState.get_character_level_up_gain(card)), 12, NOTICE_MUTED_INK)
	gain_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(gain_label)

	var level_up_button := Button.new()
	level_up_button.text = "Level Up"
	level_up_button.focus_mode = Control.FOCUS_NONE
	level_up_button.disabled = GameState.is_game_over
	_style_notice_button(level_up_button, true)
	level_up_button.pressed.connect(_on_level_up_pressed.bind(card.id))
	row.add_child(level_up_button)
	return row


func _make_character_growth_section(card: CardDefinition) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var title := _make_ink_label("Growth", 13, NOTICE_ACTIVE_INK)
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
	var label := _make_ink_label("%s Personal %s + Species %s + Job %s = %s  (+%s)" % [
		stat_name,
		character_growth,
		species_growth,
		job_growth,
		total_growth,
		level_gain,
	], 12, NOTICE_MUTED_INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_equipment_slot_section(card: CardDefinition) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var title := _make_ink_label("Equipment Slots", 13, NOTICE_ACTIVE_INK)
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
		_style_notice_button(button, true)
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
		_style_notice_button(button, false)
		button.pressed.connect(_on_unequip_pressed.bind(character.id, equipment.id))

	return button


func _make_hire_candidate_row(card: CardDefinition) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", notice_board_art.note)
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

	var name_label := _make_ink_label(card.label(), 16)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(name_label)

	var job_label := _make_ink_label("%s / %s" % [_character_species(card), _character_job(card)], 12, NOTICE_MUTED_INK)
	job_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(job_label)

	var cost_label := _make_ink_label("고용 비용 %s" % GameState.get_hire_cost(card), 12, NOTICE_ACTIVE_INK)
	summary.add_child(cost_label)

	var hire_button := Button.new()
	hire_button.text = "고용"
	hire_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hire_button.disabled = not GameState.can_hire_card(card)
	_style_notice_button(hire_button, true)
	hire_button.pressed.connect(_on_hire_pressed.bind(card.id))
	header.add_child(hire_button)

	var stat_label := _make_ink_label(_format_stats(card.stats), 12)
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stat_label)

	var skill_label := _make_ink_label("스킬: %s" % _format_string_array(card.skill_ids, "없음"), 12, NOTICE_MUTED_INK)
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(skill_label)

	return row


func _make_shop_card_row(card: CardDefinition, selling: bool) -> PanelContainer:
	var row := _make_paper_panel()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	row.add_child(header)

	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(summary)
	var name_label := _make_ink_label(card.label(), 16)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(name_label)
	var kind := card.equipment_category if card.is_equipment() else "소비 카드"
	if card.is_equipment() and kind == "미지정":
		kind = "장비 카드"
	var equipped := card.is_equipment() and not GameState.get_equipment_owner_id(card.id).is_empty()
	var detail := "장착 중 · %s" % kind if equipped else kind
	var detail_label := _make_ink_label("%s · %s" % [detail, _format_stats(card.stats)], 12, NOTICE_MUTED_INK)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(detail_label)

	var price := GameState.get_shop_sale_price(card) if selling else card.shop_price
	var button := Button.new()
	button.text = "%s %s" % ["판매" if selling else "구매", price]
	button.custom_minimum_size = Vector2(96, 36)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = not (GameState.can_sell_shop_card(card) if selling else GameState.can_buy_shop_card(card))
	if equipped:
		button.tooltip_text = "장착을 해제한 뒤 판매할 수 있습니다."
	elif not selling and button.disabled:
		button.tooltip_text = "자금이 부족합니다."
	_style_notice_button(button, true)
	button.pressed.connect(_on_shop_trade_pressed.bind(card, selling))
	header.add_child(button)
	return row


func _make_facility_event_detail(facility: int) -> VBoxContainer:
	var character := GameState.get_facility_character(facility)
	var candidate := ContentCatalog.get_card(facility_candidate_ids.get(facility, &""))
	var can_open := GameState.is_facility_open(facility)
	var box := _make_event_detail_body()

	var slot := _make_assignment_slot_button(
		"내일 담당 인물",
		character.label() if character != null else (candidate.label() if candidate != null else "미배치"),
		candidate != null,
		character != null,
		_on_facility_character_slot_pressed.bind(facility)
	)
	slot.disabled = slot.disabled or GameState.is_game_over or GameState.has_pending_job_change()
	slot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(slot)

	if character != null:
		var scheduled := _make_label("내일 이용 예정", 12)
		scheduled.add_theme_color_override("font_color", NOTICE_ACTIVE_INK)
		box.add_child(scheduled)

	if can_open or candidate != null or GameState.can_cancel_facility_assignment(facility):
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 10)
		box.add_child(actions)
		if can_open:
			var open_button := Button.new()
			open_button.text = "상점 열기" if facility == GameEnums.Facility.SHOP else "고용 목록 열기"
			_style_notice_button(open_button, true)
			open_button.pressed.connect(_on_facility_open_pressed.bind(facility))
			actions.add_child(open_button)

		if candidate != null and character == null:
			var confirm_button := Button.new()
			confirm_button.text = "배치 확정"
			confirm_button.disabled = not GameState.can_assign_facility(facility, candidate)
			_style_notice_button(confirm_button, true)
			confirm_button.pressed.connect(_on_facility_confirm_pressed.bind(facility))
			actions.add_child(confirm_button)

		if candidate != null or GameState.can_cancel_facility_assignment(facility):
			var cancel_button := Button.new()
			cancel_button.text = "배치 취소"
			_style_notice_button(cancel_button, false)
			cancel_button.pressed.connect(_on_facility_cancel_pressed.bind(facility))
			actions.add_child(cancel_button)
	return box


func _make_tax_payment_event_detail() -> VBoxContainer:
	var is_paid := GameState.tax_manager.has_paid_current_week(GameState.current_day)
	var can_resolve := _can_resolve_tax_event()
	var box := _make_event_detail_body()

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var meta_label := _make_label(_tax_event_meta(), 12)
	meta_label.add_theme_color_override("font_color", NOTICE_MUTED_INK)
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(meta_label)

	var resolve_button := Button.new()
	resolve_button.text = _tax_event_action_label(is_paid)
	resolve_button.disabled = not can_resolve
	resolve_button.custom_minimum_size = Vector2(88, 34)
	resolve_button.focus_mode = Control.FOCUS_NONE
	_style_notice_button(resolve_button, true)
	resolve_button.pressed.connect(_on_tax_event_resolve_pressed)
	header.add_child(resolve_button)

	if _can_cancel_tax_event_action():
		var cancel_button := Button.new()
		cancel_button.text = "취소"
		cancel_button.custom_minimum_size = Vector2(72, 34)
		cancel_button.focus_mode = Control.FOCUS_NONE
		_style_notice_button(cancel_button, false)
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

	return box


func _make_job_training_event_detail() -> VBoxContainer:
	var assigned_character := GameState.get_job_training_character()
	var candidate_character := ContentCatalog.get_card(job_training_candidate_character_id)
	var has_pending_change := GameState.has_pending_job_change()
	var is_assignment_complete := assigned_character != null or has_pending_change
	var box := _make_event_detail_body()

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)

	var meta_label := _make_label("Event / 1 day / 캐릭터 카드 1장 필요", 12)
	meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_label.add_theme_color_override("font_color", NOTICE_MUTED_INK)
	header.add_child(meta_label)

	var execute_button := Button.new()
	execute_button.text = "완료" if assigned_character != null else "실행"
	execute_button.custom_minimum_size = Vector2(88, 34)
	execute_button.focus_mode = Control.FOCUS_NONE
	execute_button.disabled = candidate_character == null or assigned_character != null or has_pending_change
	_style_notice_button(execute_button, true)
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
		_style_notice_button(cancel_button, false)
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
	status.add_theme_color_override("font_color", NOTICE_ACTIVE_INK if candidate_character != null or is_assignment_complete else NOTICE_MUTED_INK)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	return box


func _make_request_event_detail(request: RequestDefinition) -> VBoxContainer:
	var detail := _make_event_detail_body()
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
	meta_label.add_theme_color_override("font_color", NOTICE_MUTED_INK)
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(meta_label)

	var execute_button := Button.new()
	execute_button.text = "배치 완료" if is_queued else "실행"
	execute_button.custom_minimum_size = Vector2(88, 34)
	execute_button.focus_mode = Control.FOCUS_NONE
	execute_button.disabled = is_queued or not GameState.can_queue_daily_request(request, assigned_character)
	_style_notice_button(execute_button, true)
	execute_button.pressed.connect(_on_daily_request_execute_pressed.bind(request.id))
	header.add_child(execute_button)

	var reward_label := _make_label(_event_rewards(request), 12)
	reward_label.add_theme_color_override("font_color", NOTICE_INK)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		_style_notice_button(cancel_button, false)
		cancel_button.pressed.connect(_on_daily_request_cancel_pressed.bind(request.id))
		detail.add_child(cancel_button)

	var status_text := "인물을 배치하고 실행하세요. 판정은 다음 날 정산창에서 한꺼번에 진행됩니다."
	if is_queued:
		status_text = "%s 배치 확정. 다음 날 정산을 기다리고 있습니다." % assigned_character.label()
	elif assigned_character != null:
		status_text = "%s 임시 배치. 실행하면 오늘의 의뢰로 확정됩니다." % assigned_character.label()
	var status_label := _make_label(status_text, 12)
	status_label.add_theme_color_override("font_color", NOTICE_ACTIVE_INK if assigned_character != null else NOTICE_MUTED_INK)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(status_label)

	return detail


func _make_event_detail_body() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	return box


func _make_event_row(title: String, event_id: StringName, is_complete: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := notice_board_art.completed_note if is_complete else notice_board_art.note
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_event_row_gui_input.bind(event_id))
	panel.add_child(_make_event_title_button(title, event_id, is_complete))
	return panel


func _make_event_title_button(title: String, event_id: StringName, is_complete: bool) -> Button:
	var button := Button.new()
	button.text = title
	button.icon = notice_board_art.completed_pin if is_complete else notice_board_art.pin
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = title
	button.add_theme_constant_override("h_separation", 10)
	button.add_theme_font_size_override("font_size", 16)
	_style_clear_button(button)
	button.add_theme_color_override("font_color", NOTICE_ACTIVE_INK if is_complete else NOTICE_INK)
	button.add_theme_color_override("font_hover_color", NOTICE_ACTIVE_INK)
	button.add_theme_color_override("font_pressed_color", NOTICE_ACTIVE_INK)
	button.pressed.connect(_on_event_title_pressed.bind(event_id))
	return button


func _make_event_slot_button(title: String, detail: String, disabled: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [title, detail]
	button.disabled = disabled
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	_style_notice_button(button, not disabled)

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
		_style_notice_slot(button, Color("#B6C8B1"), Color("#637E63"), NOTICE_ACTIVE_INK)
	elif has_candidate:
		_style_notice_slot(button, Color("#CBD6CD"), Color("#688077"), NOTICE_ACTIVE_INK)
	else:
		_style_notice_slot(button, Color("#E6DDCB"), Color("#A39783"), NOTICE_MUTED_INK)

	if not is_queued and callback.is_valid():
		button.pressed.connect(callback)
	return button


func _style_notice_button(button: Button, primary: bool) -> void:
	var background := Color("#39645D") if primary else Color("#EFE7D5")
	var edge := Color("#274E48") if primary else Color("#8F7F69")
	var ink := Color("#FFF8EB") if primary else NOTICE_INK
	button.add_theme_stylebox_override("normal", _notice_control_style(background, edge))
	button.add_theme_stylebox_override("hover", _notice_control_style(background.lightened(0.08), edge))
	button.add_theme_stylebox_override("pressed", _notice_control_style(background.darkened(0.10), edge))
	button.add_theme_stylebox_override("disabled", _notice_control_style(Color("#D6CEBE"), Color("#ADA18E")))
	button.add_theme_stylebox_override("focus", _notice_control_style(Color.TRANSPARENT, NOTICE_ACTIVE_INK))
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_disabled_color", NOTICE_MUTED_INK)


func _style_notice_tabs(tabs: Control) -> void:
	tabs.add_theme_stylebox_override("tab_selected", _notice_control_style(Color("#CDD9CC"), Color("#688077")))
	tabs.add_theme_stylebox_override("tab_unselected", _notice_control_style(Color("#DED5C2"), Color("#A39783")))
	tabs.add_theme_stylebox_override("tab_hovered", _notice_control_style(Color("#E9E1D0"), Color("#688077")))
	tabs.add_theme_color_override("font_selected_color", NOTICE_ACTIVE_INK)
	tabs.add_theme_color_override("font_unselected_color", NOTICE_MUTED_INK)
	tabs.add_theme_color_override("font_hovered_color", NOTICE_ACTIVE_INK)


func _style_notice_slot(button: Button, background: Color, edge: Color, ink: Color) -> void:
	_style_notice_button(button, false)
	button.add_theme_stylebox_override("normal", _notice_control_style(background, edge))
	button.add_theme_stylebox_override("hover", _notice_control_style(background.lightened(0.12), NOTICE_ACTIVE_INK))
	button.add_theme_stylebox_override("pressed", _notice_control_style(background.darkened(0.06), NOTICE_ACTIVE_INK))
	button.add_theme_stylebox_override("disabled", _notice_control_style(background, edge))
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_disabled_color", ink)


func _notice_control_style(background: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = edge
	style.set_border_width_all(1)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 8)
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
	return NOTICE_ACTIVE_INK if is_paid or can_resolve else NOTICE_MUTED_INK


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


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#F3F4F6"))
	return label


func _add_metric(grid: GridContainer, name: String) -> Label:
	var name_label := _make_ink_label(name, 14, NOTICE_MUTED_INK)
	grid.add_child(name_label)

	var value_label := _make_ink_label("-", 14)
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
	_show_next_facility()

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
	_clear_children(character_card_list)
	if character_cards.is_empty():
		character_card_list.add_child(_make_ink_label("보유한 인물이 없습니다.", 13, BOARD_TITLE_INK))
		return
	for card in character_cards:
		character_card_list.add_child(_make_character_card_row(card))


func _refresh_character_detail_popup() -> void:
	var selected_tab := 0
	for child in character_detail_content.get_children():
		if child is TabContainer:
			selected_tab = child.current_tab
	_clear_children(character_detail_content)

	if String(selected_character_card_id).is_empty():
		character_detail_title.text = ""
		character_detail_popup.visible = false
		_update_event_board_visibility()
		return

	var card := ContentCatalog.get_card(selected_character_card_id)
	if card == null or not card.is_character() or not GameState.office.owned_cards.has(card):
		selected_character_card_id = &""
		character_detail_title.text = ""
		character_detail_popup.visible = false
		_update_event_board_visibility()
		return

	character_detail_popup.visible = true
	_update_event_board_visibility()
	character_detail_title.text = card.label()

	var summary_sheet := PanelContainer.new()
	summary_sheet.add_theme_stylebox_override("panel", notice_board_art.note)
	character_detail_content.add_child(summary_sheet)
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 14)
	summary_sheet.add_child(summary)

	summary.add_child(_make_profile_frame(card))

	var summary_text := VBoxContainer.new()
	summary_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_text.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_text.add_theme_constant_override("separation", 5)
	summary.add_child(summary_text)

	var job_label := _make_ink_label("%s / %s" % [_character_species(card), _character_job(card)], 16)
	job_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_text.add_child(job_label)

	var detail := _make_character_detail(card)
	character_detail_content.add_child(detail)
	detail.current_tab = mini(selected_tab, detail.get_tab_count() - 1)


func _refresh_job_change_popup() -> void:
	_clear_children(job_change_content)
	var character := GameState.get_pending_job_change_character()
	if character == null:
		job_change_popup.visible = false
		return

	job_change_popup.visible = true
	job_change_title.text = "%s의 전직" % character.label()

	var current_job_id := GameState.get_character_current_job_id(character)
	var current_label := _make_ink_label("현재 직업: %s  Lv.%s" % [
		_job_label(current_job_id),
		GameState.get_character_job_level(character, current_job_id),
	], 13, BOARD_TITLE_INK)
	current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		var reward := int(result.get("reward", 0))
		var result_panel := _make_paper_panel(notice_board_art.completed_note if reward > 0 else notice_board_art.note)
		settlement_content.add_child(result_panel)

		var result_box := VBoxContainer.new()
		result_box.add_theme_constant_override("separation", 5)
		result_panel.add_child(result_box)

		var result_title := _make_ink_label("%s · %s" % [
			result.get("request", "의뢰"),
			result.get("character", "캐릭터"),
		], 15)
		result_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result_box.add_child(result_title)

		var formula := _make_ink_label("D6 %s + %s %s = %s" % [
			result.get("die", 0),
			result.get("stat_name", "주요 능력치"),
			result.get("stat_value", 0),
			result.get("total", 0),
		], 13, NOTICE_MUTED_INK)
		result_box.add_child(formula)

		var outcome := String(result.get("outcome", "실패"))
		var outcome_label := _make_ink_label("%s · +%s money" % [outcome, reward], 16, NOTICE_ACTIVE_INK if reward > 0 else NOTICE_MUTED_INK)
		result_box.add_child(outcome_label)

	var total_sheet := _make_paper_panel()
	settlement_content.add_child(total_sheet)
	var total_label := _make_ink_label("총 정산 금액  +%s money" % _daily_settlement_total_reward(), 20, NOTICE_ACTIVE_INK)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_sheet.add_child(total_label)


func _daily_settlement_total_reward() -> int:
	var total := 0
	for result in GameState.last_daily_request_results:
		total += int(result.get("reward", 0))
	return total


func _make_job_change_option(character: CardDefinition, job: JobDefinition) -> PanelContainer:
	var sheet := _make_paper_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	sheet.add_child(row)
	var can_change := GameState.can_change_character_job(character, job.id)
	var level := GameState.get_character_job_level(character, job.id)
	var detail := job.label()
	if level > 0:
		detail += "  Lv.%s" % level
	if not job.is_basic_job():
		detail += "\n%s" % _job_promotion_requirement_text(character, job)

	var label := _make_ink_label(detail, 14, NOTICE_INK if can_change else NOTICE_MUTED_INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	var button := Button.new()
	button.text = "전직" if level == 0 else "직업 변경"
	button.custom_minimum_size = Vector2(100, 34)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not can_change
	_style_notice_button(button, can_change)
	button.pressed.connect(_on_training_job_selected.bind(job.id))
	row.add_child(button)
	return sheet


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
	_refresh_event_detail_popup(requests)


func _refresh_event_detail_popup(requests: Array[RequestDefinition]) -> void:
	_clear_children(event_detail_content)
	var detail: VBoxContainer
	var title := ""
	var is_complete := false
	if selected_event_id == TAX_PAYMENT_EVENT_ID:
		title = "세금 납부"
		is_complete = GameState.tax_manager.has_paid_current_week(GameState.current_day)
		detail = _make_tax_payment_event_detail()
	elif selected_event_id == JOB_TRAINING_EVENT_ID:
		title = "직업 교육소"
		is_complete = _is_job_training_confirmed()
		detail = _make_job_training_event_detail()
	elif not selected_event_id.is_empty():
		for facility in GameEnums.Facility.values():
			if selected_event_id == _facility_event_id(facility):
				title = GameEnums.facility_label(facility)
				is_complete = GameState.get_facility_character(facility) != null
				detail = _make_facility_event_detail(facility)
				break
		if detail == null:
			for request in requests:
				if selected_event_id == _request_event_id(request):
					title = _request_display_title(request)
					is_complete = GameState.get_daily_request_assigned_character(request) != null
					detail = _make_request_event_detail(request)
					break

	event_detail_popup.visible = detail != null
	_update_event_board_visibility()
	if detail == null:
		selected_event_id = &""
		return
	event_detail_title.text = title
	event_detail_pin.texture = notice_board_art.completed_pin if is_complete else notice_board_art.selected_pin
	var sheet := notice_board_art.completed_note if is_complete else notice_board_art.selected_note
	event_detail_sheet.add_theme_stylebox_override("panel", sheet)
	event_detail_content.add_child(detail)


func _update_event_board_visibility() -> void:
	event_panel.visible = not (
		event_detail_popup.visible or character_detail_popup.visible
		or settlement_popup.visible or job_change_popup.visible
	)


func _refresh_inventory_drawer() -> void:
	character_panel.visible = true
	if (
		(active_drawer_type == Drawer.SHOP and not GameState.is_facility_open(GameEnums.Facility.SHOP))
		or (active_drawer_type == Drawer.PERSONNEL and not GameState.is_facility_open(GameEnums.Facility.PERSONNEL))
	):
		active_drawer_type = Drawer.CLOSED

	inventory_drawer.visible = active_drawer_type != Drawer.CLOSED
	shop_tabs.visible = active_drawer_type == Drawer.SHOP
	facility_balance_label.visible = active_drawer_type in [Drawer.SHOP, Drawer.PERSONNEL]
	if facility_balance_label.visible:
		facility_balance_label.text = "보유 자금: %s" % GameState.office.money

	if active_drawer_type == Drawer.CHARACTER_PICKER:
		if facility_assignment_target != NO_FACILITY:
			inventory_drawer_title.text = "%s 담당 인물 선택" % GameEnums.facility_label(facility_assignment_target)
		elif not String(request_assignment_target_id).is_empty():
			inventory_drawer_title.text = "의뢰 담당 인물 선택"
		else:
			inventory_drawer_title.text = "직업 교육 대상 선택"
		_populate_assignment_candidate_list()
	elif active_drawer_type == Drawer.PERSONNEL:
		inventory_drawer_title.text = GameEnums.facility_label(GameEnums.Facility.PERSONNEL)
		_populate_hire_candidate_list()
	elif active_drawer_type == Drawer.SHOP:
		inventory_drawer_title.text = GameEnums.facility_label(GameEnums.Facility.SHOP)
		_populate_shop_card_list()
	elif active_drawer_type == Drawer.EQUIPMENT:
		inventory_drawer_title.text = _equipment_drawer_title()
		_populate_equipment_card_list()
	elif active_drawer_type == Drawer.CONSUMABLE:
		inventory_drawer_title.text = "소비 카드"
		_populate_consumable_card_list()


func _refresh_inventory_buttons() -> void:
	equipment_button.modulate = Color("#F4C95D") if active_drawer_type == Drawer.EQUIPMENT else Color.WHITE
	consumable_button.modulate = Color("#F4C95D") if active_drawer_type == Drawer.CONSUMABLE else Color.WHITE


func _populate_event_list(requests: Array[RequestDefinition]) -> void:
	_clear_children(event_list)
	event_list.add_child(_make_event_row("세금 납부", TAX_PAYMENT_EVENT_ID, GameState.tax_manager.has_paid_current_week(GameState.current_day)))
	event_list.add_child(_make_event_row("직업 교육소", JOB_TRAINING_EVENT_ID, _is_job_training_confirmed()))

	for request in requests:
		var is_complete := GameState.get_daily_request_assigned_character(request) != null
		event_list.add_child(_make_event_row(_request_display_title(request), _request_event_id(request), is_complete))

	for facility in GameEnums.Facility.values():
		var is_complete := GameState.get_facility_character(facility) != null
		event_list.add_child(_make_event_row(GameEnums.facility_label(facility), _facility_event_id(facility), is_complete))


func _is_job_training_confirmed() -> bool:
	return GameState.get_job_training_character() != null or GameState.has_pending_job_change()


func _populate_hire_candidate_list() -> void:
	_clear_children(inventory_card_list)
	var candidates := _get_hire_candidates()

	if candidates.is_empty():
		inventory_card_list.add_child(_make_ink_label("오늘은 고용할 수 있는 인물이 없습니다.", 13, BOARD_TITLE_INK))
		return

	for card in candidates:
		inventory_card_list.add_child(_make_hire_candidate_row(card))


func _populate_shop_card_list() -> void:
	_clear_children(inventory_card_list)
	var selling := shop_tabs.current_tab == 1
	var cards := GameState.get_shop_cards(selling)
	cards.sort_custom(Callable(self, "_sort_cards_by_label"))
	if cards.is_empty():
		inventory_card_list.add_child(_make_ink_label("판매할 카드가 없습니다." if selling else "구매할 카드가 없습니다.", 13, BOARD_TITLE_INK))
		return
	for card in cards:
		inventory_card_list.add_child(_make_shop_card_row(card, selling))


func _populate_assignment_candidate_list() -> void:
	_clear_children(inventory_card_list)
	var characters := _get_cards_by_type(GameEnums.CardType.CHARACTER)
	if characters.is_empty():
		inventory_card_list.add_child(_make_ink_label("배치할 수 있는 인물이 없습니다.", 13, BOARD_TITLE_INK))
		return

	for card in characters:
		inventory_card_list.add_child(_make_character_card_row(card))


func _populate_equipment_card_list() -> void:
	_clear_children(inventory_card_list)
	var equipment_cards := _get_cards_by_type(GameEnums.CardType.EQUIPMENT)

	if not String(equipment_target_character_id).is_empty():
		equipment_cards = _get_available_equipment_cards()

	if equipment_cards.is_empty():
		var empty_text := "장착할 수 있는 장비가 없습니다." if not equipment_target_character_id.is_empty() else "보유 장비가 없습니다."
		inventory_card_list.add_child(_make_ink_label(empty_text, 13, BOARD_TITLE_INK))
		return

	for card in equipment_cards:
		inventory_card_list.add_child(_make_card_row(card))


func _populate_consumable_card_list() -> void:
	_clear_children(inventory_card_list)
	inventory_card_list.add_child(_make_money_stack_card())

	var consumable_cards := _get_cards_by_type(GameEnums.CardType.CONSUMABLE)
	if consumable_cards.is_empty():
		inventory_card_list.add_child(_make_ink_label("보유 소비 카드가 없습니다.", 13, BOARD_TITLE_INK))
		return

	for card in consumable_cards:
		inventory_card_list.add_child(_make_card_row(card))


func _equipment_drawer_title() -> String:
	var character := ContentCatalog.get_card(equipment_target_character_id)
	if character != null:
		return "%s · 장비 선택" % character.label()

	return "장비 카드"


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


func _facility_event_id(facility: int) -> StringName:
	return StringName("facility:%s" % facility)


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
		for facility in facility_candidate_ids:
			if facility_candidate_ids[facility] == card.id:
				return "%s (배치 대기)" % GameEnums.facility_label(facility)
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
	if not next_day_button.disabled:
		GameState.advance_day()


func _on_day_advanced(_day: int) -> void:
	daily_request_character_ids.clear()
	facility_candidate_ids.clear()
	facility_open_queue = GameState.available_facilities.duplicate()
	settlement_results_dismissed = false
	selected_event_id = &""
	_close_inventory_drawer()


func _on_event_title_pressed(event_id: StringName) -> void:
	_toggle_event_detail(event_id)


func _on_event_row_gui_input(event: InputEvent, event_id: StringName) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_toggle_event_detail(event_id)


func _toggle_event_detail(event_id: StringName) -> void:
	if selected_event_id == event_id:
		_close_event_detail()
		return

	selected_event_id = event_id
	selected_character_card_id = &""
	_refresh_character_cards()
	_refresh_character_detail_popup()
	_refresh_event_list()
	event_detail_scroll.scroll_vertical = 0


func _close_event_detail() -> void:
	selected_event_id = &""
	if active_drawer_type == Drawer.CHARACTER_PICKER or is_selecting_tax_event_money:
		_close_inventory_drawer()
	_refresh_event_list()


func _on_reset_pressed() -> void:
	selected_event_id = &""
	selected_character_card_id = &""
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	tax_event_money_assigned = false
	is_selecting_job_training_character = false
	job_training_candidate_character_id = &""
	daily_request_character_ids.clear()
	facility_candidate_ids.clear()
	facility_open_queue.clear()
	request_assignment_target_id = &""
	settlement_results_dismissed = false
	_reset_player_creation_form()
	_close_inventory_drawer()
	GameState.reset_game()


func _on_equipment_pressed() -> void:
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	is_selecting_job_training_character = false
	_open_inventory_drawer(Drawer.EQUIPMENT)


func _on_consumable_pressed() -> void:
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	is_selecting_job_training_character = false
	_open_inventory_drawer(Drawer.CONSUMABLE)


func _on_equipment_slot_pressed(character_id: StringName) -> void:
	equipment_target_character_id = character_id
	selected_character_card_id = character_id
	is_selecting_tax_event_money = false
	_open_inventory_drawer(Drawer.EQUIPMENT)


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
	_open_inventory_drawer(Drawer.CONSUMABLE)


func _on_facility_character_slot_pressed(facility: int) -> void:
	if GameState.is_game_over or GameState.has_pending_job_change() or GameState.get_facility_character(facility) != null:
		return

	_close_inventory_drawer()
	selected_event_id = _facility_event_id(facility)
	selected_character_card_id = &""
	_refresh_character_detail_popup()
	facility_assignment_target = facility
	_open_inventory_drawer(Drawer.CHARACTER_PICKER)


func _on_facility_confirm_pressed(facility: int) -> void:
	var character := ContentCatalog.get_card(facility_candidate_ids.get(facility, &""))
	if not GameState.can_assign_facility(facility, character):
		return

	facility_candidate_ids.erase(facility)
	GameState.assign_facility(facility, character)


func _on_facility_cancel_pressed(facility: int) -> void:
	if facility_candidate_ids.erase(facility):
		_refresh()
	else:
		GameState.cancel_facility_assignment(facility)


func _show_next_facility() -> void:
	if active_drawer_type != Drawer.CLOSED or GameState.has_pending_job_change() or settlement_popup.visible:
		return

	while not facility_open_queue.is_empty():
		var facility: int = facility_open_queue.pop_front()
		if GameState.is_facility_open(facility):
			_on_facility_open_pressed(facility)
			return


func _on_facility_open_pressed(facility: int) -> void:
	if not GameState.is_facility_open(facility):
		return

	_close_inventory_drawer()
	if facility == GameEnums.Facility.SHOP:
		shop_tabs.current_tab = 0
		_open_inventory_drawer(Drawer.SHOP)
	else:
		_open_inventory_drawer(Drawer.PERSONNEL)
	inventory_scroll.scroll_vertical = 0


func _on_shop_tab_changed(_tab: int) -> void:
	if active_drawer_type == Drawer.SHOP:
		_populate_shop_card_list()
		inventory_scroll.scroll_vertical = 0


func _on_shop_trade_pressed(card: CardDefinition, selling: bool) -> void:
	if selling:
		GameState.sell_shop_card(card)
	else:
		GameState.buy_shop_card(card)


func _on_daily_request_character_slot_pressed(request_id: StringName) -> void:
	var request := ContentCatalog.get_request(request_id)
	if request == null or not GameState.office.available_requests.has(request) or GameState.get_daily_request_assigned_character(request) != null:
		return

	_close_inventory_drawer()
	selected_event_id = _request_event_id(request)
	selected_character_card_id = &""
	_refresh_character_detail_popup()
	request_assignment_target_id = request_id
	is_selecting_job_training_character = false
	is_selecting_tax_event_money = false
	equipment_target_character_id = &""
	_open_inventory_drawer(Drawer.CHARACTER_PICKER)


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
	_close_inventory_drawer()
	selected_event_id = JOB_TRAINING_EVENT_ID
	selected_character_card_id = &""
	_refresh_character_detail_popup()
	is_selecting_job_training_character = true
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	_open_inventory_drawer(Drawer.CHARACTER_PICKER)


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
	GameState.complete_job_training(job_id)


func _open_inventory_drawer(drawer_type: int) -> void:
	active_drawer_type = drawer_type
	if drawer_type != Drawer.CHARACTER_PICKER:
		facility_assignment_target = NO_FACILITY
		request_assignment_target_id = &""
		is_selecting_job_training_character = false

	_refresh_inventory_drawer()
	_refresh_inventory_buttons()


func _close_inventory_drawer() -> void:
	active_drawer_type = Drawer.CLOSED
	facility_assignment_target = NO_FACILITY
	equipment_target_character_id = &""
	is_selecting_tax_event_money = false
	is_selecting_job_training_character = false
	request_assignment_target_id = &""
	_refresh_inventory_drawer()
	_refresh_inventory_buttons()


func _dismiss_inventory_drawer() -> void:
	_close_inventory_drawer()
	_show_next_facility()


func _input(event: InputEvent) -> void:
	if active_drawer_type == Drawer.CLOSED:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return

		if _is_inventory_drawer_click(mouse_event.position):
			return

		_dismiss_inventory_drawer()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or player_creation_overlay.visible:
		return
	if active_drawer_type != Drawer.CLOSED:
		_dismiss_inventory_drawer()
	elif event_detail_popup.visible and not settlement_popup.visible and not job_change_popup.visible:
		_close_event_detail()
	else:
		return
	get_viewport().set_input_as_handled()


func _is_inventory_drawer_click(position: Vector2) -> bool:
	return (
		_is_point_in_control(inventory_drawer, position)
		or _is_point_in_control(character_detail_popup, position)
		or _is_point_in_control(event_detail_close_button, position)
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
			if facility_assignment_target != NO_FACILITY:
				var facility := facility_assignment_target
				var character := ContentCatalog.get_card(card_id)
				if _character_event_assignment_label(character).is_empty() and GameState.can_assign_facility(facility, character):
					facility_candidate_ids[facility] = card_id
					_close_inventory_drawer()
					_refresh()
				return

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
				if not selected_event_id.is_empty():
					_close_event_detail()

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
