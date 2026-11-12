extends Control

signal cell_pressed(cell: Vector2i)

const ALLY_SPRITE := preload("res://assets/dungeon/expeditioner.svg")
const ENEMY_SPRITE := preload("res://assets/dungeon/sentry.svg")
const FLOOR_COLORS := [Color("#384849"), Color("#3E4E4D"), Color("#41514F"), Color("#3A4A48")]
const PARTY_TINTS := [Color.WHITE, Color("#E4D0A4"), Color("#BEDBEF")]

var run: DungeonRun
var selected_action: int = DungeonRun.Action.STRIKE
var visible_cells: Dictionary[Vector2i, bool] = {}
var discovered_cells: Dictionary[Vector2i, bool] = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _cell_size() -> int:
	return maxi(1, floori(minf((size.x - 20.0) / DungeonLayout.SIZE.x, (size.y - 20.0) / DungeonLayout.SIZE.y)))


func _origin(side: int) -> Vector2:
	return ((size - Vector2(DungeonLayout.SIZE) * side) * 0.5).floor()


func _cell_at(position: Vector2) -> Vector2i:
	var side := _cell_size()
	return Vector2i(((position - _origin(side)) / side).floor())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _cell_at(event.position)
		if Rect2i(Vector2i.ZERO, DungeonLayout.SIZE).has_point(cell):
			cell_pressed.emit(cell)
			accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var cell := _cell_at(at_position)
	if cell == DungeonLayout.EXIT:
		return "동쪽 출구"
	if run == null or not visible_cells.has(cell):
		return ""
	var unit := run.unit_at(cell)
	return "%s · HP %s/%s" % [unit.title, unit.hp, unit.max_hp] if unit != null else ""


func _draw() -> void:
	if run == null:
		return
	var side := _cell_size()
	var origin := _origin(side)
	visible_cells = run.visible_cells()
	discovered_cells.merge(visible_cells, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#172329"))
	for y in DungeonLayout.SIZE.y:
		for x in DungeonLayout.SIZE.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(cell * side), Vector2(side, side))
			if DungeonLayout.is_floor(cell):
				_draw_floor(rect, cell)
				if not visible_cells.has(cell):
					draw_rect(rect, Color("#1221274f") if discovered_cells.has(cell) else Color("#122127a0"))
				if not run.is_open(cell):
					_draw_gate(rect)
			elif _is_wall(cell):
				_draw_wall(rect, cell)
	_draw_exit(Rect2(origin + Vector2(DungeonLayout.EXIT * side), Vector2(side, side)))
	var active := run.actor()
	if active != null and active.is_ally() and active.ap > 0:
		_draw_move_range(origin, side, active)
	for unit in run.allies + run.enemies:
		if unit.is_alive() and (unit.is_ally() or visible_cells.has(unit.cell)):
			var rect := Rect2(origin + Vector2(unit.cell * side), Vector2(side, side))
			_draw_unit(rect, unit, active)


func _is_wall(cell: Vector2i) -> bool:
	for y in range(-1, 2):
		for x in range(-1, 2):
			if DungeonLayout.is_floor(cell + Vector2i(x, y)):
				return true
	return false


func _draw_floor(rect: Rect2, cell: Vector2i) -> void:
	var variant := posmod(cell.x * 19 + cell.y * 23 + cell.x * cell.y, FLOOR_COLORS.size())
	draw_rect(rect, FLOOR_COLORS[variant])
	draw_rect(rect, Color("#2E3A3A"), false, 1.0)
	if variant == 1 or variant == 3:
		draw_rect(Rect2(rect.position + rect.size * Vector2(0.18, 0.28), rect.size * Vector2(0.3, 0.065)), Color("#51615D"))
		draw_rect(Rect2(rect.position + rect.size * Vector2(0.53, 0.70), rect.size * Vector2(0.18, 0.05)), Color("#344240"))


func _draw_wall(rect: Rect2, cell: Vector2i) -> void:
	draw_rect(rect, Color("#263439"))
	var face := rect.grow(-1)
	draw_rect(face, Color("#506060") if posmod(cell.x + cell.y * 2, 4) == 0 else Color("#425252"))
	draw_rect(Rect2(face.position, Vector2(face.size.x, 3)), Color("#62726E"))
	draw_rect(Rect2(face.position + Vector2(0, face.size.y * 0.61), Vector2(face.size.x, 2)), Color("#303E42"))
	draw_rect(Rect2(face.position + Vector2(face.size.x * 0.60, 3), Vector2(2, face.size.y * 0.53)), Color("#344447"))


func _draw_gate(rect: Rect2) -> void:
	draw_rect(rect.grow(-2), Color("#292D2C"))
	for column in range(1, 5):
		draw_rect(Rect2(rect.position + Vector2(rect.size.x * column / 5, 3), Vector2(3, rect.size.y - 6)), Color("#9B805C"))
	draw_rect(Rect2(rect.position + Vector2(2, rect.size.y * 0.53), Vector2(rect.size.x - 4, 3)), Color("#675840"))


func _draw_exit(rect: Rect2) -> void:
	var unlocked := run.encounters_cleared == DungeonLayout.ENCOUNTER_COUNT
	var color := Color("#A2CAAA") if unlocked else Color("#8F846C")
	draw_rect(rect.grow(-3), color, false, 2)
	for index in 3:
		var offset := Vector2(7 + index * 3, 8 + index * 6)
		draw_rect(Rect2(rect.position + offset, Vector2(maxf(4, rect.size.x - 22), 2)), color)


func _draw_move_range(origin: Vector2, side: int, active: DungeonUnit) -> void:
	for y in range(-DungeonRun.MOVE_RANGE, DungeonRun.MOVE_RANGE + 1):
		for x in range(-DungeonRun.MOVE_RANGE, DungeonRun.MOVE_RANGE + 1):
			if absi(x) + absi(y) > DungeonRun.MOVE_RANGE or (x == 0 and y == 0):
				continue
			var cell := active.cell + Vector2i(x, y)
			var route := run.path(active.cell, cell)
			if route.size() > 1 and route.size() <= DungeonRun.MOVE_RANGE + 1:
				var rect := Rect2(origin + Vector2(cell * side), Vector2(side, side)).grow(-2)
				draw_rect(rect, Color("#739B8A38"))
				draw_rect(rect, Color("#759E8A"), false, 1)


func _draw_unit(rect: Rect2, unit: DungeonUnit, active: DungeonUnit) -> void:
	var ally := unit.is_ally()
	if unit == active:
		draw_rect(rect.grow(-1), Color("#EAC583"), false, 2)
	if active != null and active.is_ally() and run.action_error(selected_action, unit).is_empty():
		draw_rect(rect.grow(-4), Color("#B8D8A5") if ally else Color("#E7A181"), false, 2)
	var tint: Color = PARTY_TINTS[run.allies.find(unit)] if ally else (Color("#FFD5A5") if unit.encounter == 1 else Color.WHITE)
	var sprite_rect := rect.grow(-4)
	sprite_rect.position.y -= 2
	draw_texture_rect(ALLY_SPRITE if ally else ENEMY_SPRITE, sprite_rect, false, tint)
	var hp_bar := Rect2(rect.position + Vector2(5, rect.size.y - 6), Vector2(rect.size.x - 10, 3))
	draw_rect(hp_bar, Color("#172329"))
	hp_bar.size.x *= float(unit.hp) / unit.max_hp
	draw_rect(hp_bar, Color("#A9C8A4") if ally else Color("#D68A71"))
