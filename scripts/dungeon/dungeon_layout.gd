extends RefCounted
class_name DungeonLayout

const SIZE := Vector2i(26, 12)
const ENTRY := Vector2i(4, 6)
const EXIT := Vector2i(24, 6)
const PARTY_SPAWNS := [ENTRY, Vector2i(3, 6), Vector2i(2, 6)]
const GATE := [Vector2i(16, 5), Vector2i(16, 6)]
const ROOMS := [Rect2i(1, 4, 5, 5), Rect2i(8, 2, 7, 8), Rect2i(18, 2, 7, 8)]
const PASSAGES := [Rect2i(6, 5, 2, 2), Rect2i(15, 5, 3, 2)]
const PILLARS := [Vector2i(11, 6), Vector2i(13, 3), Vector2i(20, 7), Vector2i(22, 5)]
const ENCOUNTER_COUNT := 2


static func is_floor(cell: Vector2i) -> bool:
	if PILLARS.has(cell):
		return false
	for room in ROOMS:
		if room.has_point(cell):
			return true
	for passage in PASSAGES:
		if passage.has_point(cell):
			return true
	return false
