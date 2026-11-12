extends RefCounted
class_name DungeonRun

enum Result { ACTIVE, CLEARED, RETREATED, DEFEATED }
enum Action { STRIKE, BOLT, HEAL }

const MAX_AP := 3
const MAX_MP := 6
const MOVE_RANGE := 2
const ACTIONS := {
	Action.STRIKE: {"title": "기본 공격", "ap": 1, "mp": 0, "range": 1},
	Action.BOLT: {"title": "마력탄", "ap": 2, "mp": 2, "range": 4},
	Action.HEAL: {"title": "응급치료", "ap": 2, "mp": 2, "range": 3},
}

var allies: Array[DungeonUnit] = []
var enemies: Array[DungeonUnit] = []
var log_lines := PackedStringArray()
var result: Result = Result.ACTIVE
var encounters_cleared := 0
var round_number := 0
var turn_serial := 0
var _turn_order: Array[DungeonUnit] = []
var _turn_index := 0
var _grid := AStarGrid2D.new()


func _init() -> void:
	_grid.region = Rect2i(Vector2i.ZERO, DungeonLayout.SIZE)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.update()
	_add_enemy("수로 잠복병", Vector2i(10, 4), 5, 1, 1, 0)
	_add_enemy("수로 파수꾼", Vector2i(12, 7), 6, 1, 1, 0)
	_add_enemy("수문 경비병", Vector2i(21, 4), 6, 2, 1, 1)
	_add_enemy("수문 대장", Vector2i(23, 7), 8, 2, 1, 1)
	_log("폐수로 입구에 도착했다.")


func add_ally(title: String, stats: StatBlock) -> void:
	if allies.size() >= DungeonLayout.PARTY_SPAWNS.size():
		return
	var spawn: Vector2i = DungeonLayout.PARTY_SPAWNS[allies.size()]
	allies.append(DungeonUnit.new(title, spawn, stats.clone(), maxi(12, 14 + stats.health * 2), MAX_MP))


func _add_enemy(title: String, cell: Vector2i, hp: int, strength: int, agility: int, group: int) -> void:
	var stats := StatBlock.new()
	stats.strength = strength
	stats.agility = agility
	enemies.append(DungeonUnit.new(title, cell, stats, hp, 0, group))


func in_combat() -> bool:
	return not _turn_order.is_empty()


func actor() -> DungeonUnit:
	return _turn_order[_turn_index] if in_combat() else null


func leader() -> DungeonUnit:
	for ally in allies:
		if ally.is_alive():
			return ally
	return null


func unit_at(cell: Vector2i) -> DungeonUnit:
	for unit in allies + enemies:
		if unit.is_alive() and unit.cell == cell:
			return unit
	return null


func is_open(cell: Vector2i) -> bool:
	return DungeonLayout.is_floor(cell) and (encounters_cleared > 0 or not DungeonLayout.GATE.has(cell))


func visible_cells() -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	const SIGHT_RANGE := 5
	for ally in allies:
		if not ally.is_alive():
			continue
		for y in range(-SIGHT_RANGE, SIGHT_RANGE + 1):
			for x in range(-SIGHT_RANGE, SIGHT_RANGE + 1):
				var cell := ally.cell + Vector2i(x, y)
				if absi(x) + absi(y) <= SIGHT_RANGE and DungeonLayout.is_floor(cell) and _has_sight(ally.cell, cell):
					cells[cell] = true
	return cells


func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_open(from) or not is_open(to) or (to != from and unit_at(to) != null):
		return []
	for y in DungeonLayout.SIZE.y:
		for x in DungeonLayout.SIZE.x:
			var cell := Vector2i(x, y)
			_grid.set_point_solid(cell, not is_open(cell))
	for unit in allies + enemies:
		if unit.is_alive() and unit.cell != from:
			_grid.set_point_solid(unit.cell)
	return _grid.get_id_path(from, to)


func explore_step(to: Vector2i) -> bool:
	var guide := leader()
	if result != Result.ACTIVE or in_combat() or guide == null:
		return false
	if distance(guide.cell, to) != 1 or not is_open(to) or unit_at(to) != null:
		return false
	var trail := guide.cell
	guide.cell = to
	for ally in allies:
		if ally == guide or not ally.is_alive():
			continue
		var route := path(ally.cell, trail)
		trail = ally.cell
		if route.size() > 1:
			ally.cell = route[1]

	for enemy in enemies:
		if not enemy.is_alive() or enemy.encounter != encounters_cleared:
			continue
		for ally in allies:
			if ally.is_alive() and distance(ally.cell, enemy.cell) <= 4 and _has_sight(ally.cell, enemy.cell):
				_start_encounter()
				return true
	if to == DungeonLayout.EXIT and encounters_cleared == DungeonLayout.ENCOUNTER_COUNT:
		result = Result.CLEARED
	return true


func _start_encounter() -> void:
	for unit in allies + enemies:
		if unit.is_alive() and (unit.is_ally() or unit.encounter == encounters_cleared):
			_turn_order.append(unit)
	_turn_order.sort_custom(func(a: DungeonUnit, b: DungeonUnit) -> bool:
		if a.stats.agility != b.stats.agility:
			return a.stats.agility > b.stats.agility
		if a.is_ally() != b.is_ally():
			return a.is_ally()
		return allies.find(a) < allies.find(b) if a.is_ally() else enemies.find(a) < enemies.find(b)
	)
	_turn_index = 0
	round_number = 1
	_begin_turn()
	_log("전투 %s/%s 시작." % [encounters_cleared + 1, DungeonLayout.ENCOUNTER_COUNT])


func _begin_turn() -> void:
	actor().ap = MAX_AP
	turn_serial += 1


func end_turn() -> void:
	if not in_combat() or result != Result.ACTIVE:
		return
	for step in _turn_order.size():
		_turn_index += 1
		if _turn_index == _turn_order.size():
			_turn_index = 0
			round_number += 1
		if actor().is_alive():
			_begin_turn()
			return


func move_in_combat(to: Vector2i) -> bool:
	var unit := actor()
	if result != Result.ACTIVE or unit == null or not unit.is_ally() or unit.ap < 1:
		return false
	var route := path(unit.cell, to)
	if route.size() < 2 or route.size() > MOVE_RANGE + 1:
		return false
	unit.cell = to
	unit.ap -= 1
	return true


func action_error(action: int, target: DungeonUnit) -> String:
	var unit := actor()
	if result != Result.ACTIVE or unit == null or not unit.is_ally() or not ACTIONS.has(action):
		return "아군의 행동 차례가 아닙니다."
	var cost: Dictionary = ACTIONS[action]
	if unit.ap < int(cost.ap):
		return "AP가 부족합니다."
	if unit.mp < int(cost.mp):
		return "MP가 부족합니다."
	if target == null or not target.is_alive():
		return "대상이 없습니다."
	if action == Action.HEAL:
		if not allies.has(target) or target.hp == target.max_hp:
			return "회복할 아군을 선택하세요."
	elif not enemies.has(target) or target.encounter != encounters_cleared:
		return "교전 중인 적을 선택하세요."
	if distance(unit.cell, target.cell) > int(cost.range) or not _has_sight(unit.cell, target.cell):
		return "사거리 밖이거나 시야가 막혔습니다."
	return ""


func use_action(action: int, target: DungeonUnit) -> bool:
	if not action_error(action, target).is_empty():
		return false
	var unit := actor()
	var cost: Dictionary = ACTIONS[action]
	unit.ap -= int(cost.ap)
	unit.mp -= int(cost.mp)
	if action == Action.HEAL:
		var amount := mini(target.max_hp - target.hp, 3 + maxi(0, unit.stats.intelligence) * 2)
		target.hp += amount
		_log("%s · %s 체력 +%s" % [cost.title, target.title, amount])
	else:
		var magical := action == Action.BOLT
		var power := unit.stats.intelligence * 4 if magical else maxi(unit.stats.strength, unit.stats.agility) * 2
		_deal_damage(target, power, magical, str(cost.title))
	_check_battle_end()
	return true


func perform_enemy_turn() -> void:
	var enemy := actor()
	if result != Result.ACTIVE or enemy == null or enemy.is_ally():
		return
	var target: DungeonUnit
	var best_route: Array[Vector2i] = []
	for ally in allies:
		if not ally.is_alive():
			continue
		if distance(enemy.cell, ally.cell) == 1:
			target = ally
			break
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var route := path(enemy.cell, ally.cell + direction)
			if not route.is_empty() and (best_route.is_empty() or route.size() < best_route.size()):
				best_route = route
				target = ally
	if target != null and distance(enemy.cell, target.cell) > 1 and best_route.size() > 1:
		enemy.cell = best_route[mini(MOVE_RANGE, best_route.size() - 1)]
	if target != null and distance(enemy.cell, target.cell) == 1:
		_deal_damage(target, enemy.stats.strength, false, enemy.title)
	_check_battle_end()
	end_turn()


func _deal_damage(target: DungeonUnit, power: int, magical: bool, source: String) -> void:
	var defense := target.stats.magic_defense if magical else target.stats.defense
	var damage := maxi(1, roundi(float(power) * 100.0 / (100.0 + maxi(0, defense))))
	target.hp = maxi(0, target.hp - damage)
	_log("%s · %s 피해 %s%s" % [source, target.title, damage, " (쓰러짐)" if target.hp == 0 else ""])


func _check_battle_end() -> void:
	if leader() == null:
		_turn_order.clear()
		result = Result.DEFEATED
		return
	for enemy in enemies:
		if enemy.is_alive() and enemy.encounter == encounters_cleared:
			return
	_turn_order.clear()
	encounters_cleared += 1
	_log("수문이 열렸다." if encounters_cleared == 1 else "전투 종료. 동쪽 출구로 이동.")


func retreat() -> void:
	if result == Result.ACTIVE:
		_turn_order.clear()
		result = Result.RETREATED


func distance(from: Vector2i, to: Vector2i) -> int:
	return absi(from.x - to.x) + absi(from.y - to.y)


func _has_sight(from: Vector2i, to: Vector2i) -> bool:
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.y))
	var previous := from
	for index in range(1, steps + 1):
		var next := Vector2i(Vector2(from).lerp(Vector2(to), float(index) / steps).round())
		if not is_open(next):
			return false
		if next.x != previous.x and next.y != previous.y:
			if not is_open(Vector2i(next.x, previous.y)) and not is_open(Vector2i(previous.x, next.y)):
				return false
		previous = next
	return true


func _log(message: String) -> void:
	if log_lines.size() == 4:
		log_lines.remove_at(0)
	log_lines.append(message)
