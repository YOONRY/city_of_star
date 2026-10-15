extends Resource
class_name StatBlock

const GROWTH_STAT_NAMES := ["strength", "agility", "intelligence", "charm", "health"]

@export var strength: int = 0
@export var agility: int = 0
@export var intelligence: int = 0
@export var charm: int = 0
@export var health: int = 0
@export var defense: int = 0
@export var magic_defense: int = 0

func clone() -> StatBlock:
	var block := StatBlock.new()
	block.strength = strength
	block.agility = agility
	block.intelligence = intelligence
	block.charm = charm
	block.health = health
	block.defense = defense
	block.magic_defense = magic_defense
	return block


func growth_only() -> StatBlock:
	var block := clone()
	block.defense = 0
	block.magic_defense = 0
	return block


func add(other: StatBlock) -> StatBlock:
	if other == null:
		return self

	strength += other.strength
	agility += other.agility
	intelligence += other.intelligence
	charm += other.charm
	health += other.health
	defense += other.defense
	magic_defense += other.magic_defense
	return self


func plus(other: StatBlock) -> StatBlock:
	var block := clone()
	return block.add(other)


func floor_divided(divisor: int) -> StatBlock:
	# Only the five growing stats can produce initial stats or level-up gains.
	var safe_divisor := maxi(1, divisor)
	var block := StatBlock.new()
	block.strength = floori(float(strength) / float(safe_divisor))
	block.agility = floori(float(agility) / float(safe_divisor))
	block.intelligence = floori(float(intelligence) / float(safe_divisor))
	block.charm = floori(float(charm) / float(safe_divisor))
	block.health = floori(float(health) / float(safe_divisor))
	return block


func meets(required: StatBlock) -> bool:
	if required == null:
		return true

	return (
		strength >= required.strength
		and agility >= required.agility
		and intelligence >= required.intelligence
		and charm >= required.charm
		and health >= required.health
		and defense >= required.defense
		and magic_defense >= required.magic_defense
	)


func total() -> int:
	return strength + agility + intelligence + charm + health + defense + magic_defense


func as_dictionary() -> Dictionary:
	return {
		"strength": strength,
		"agility": agility,
		"intelligence": intelligence,
		"charm": charm,
		"health": health,
		"defense": defense,
		"magic_defense": magic_defense,
	}
