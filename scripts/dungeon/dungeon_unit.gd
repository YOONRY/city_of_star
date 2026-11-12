extends RefCounted
class_name DungeonUnit

var title: String
var cell: Vector2i
var stats: StatBlock
var max_hp: int
var hp: int
var max_mp: int
var mp: int
var ap: int
var encounter: int


func _init(unit_name: String, spawn: Vector2i, attributes: StatBlock, health: int, mana: int, group: int = -1) -> void:
	title = unit_name
	cell = spawn
	stats = attributes
	max_hp = health
	hp = max_hp
	max_mp = mana
	mp = max_mp
	encounter = group


func is_ally() -> bool:
	return encounter < 0


func is_alive() -> bool:
	return hp > 0
