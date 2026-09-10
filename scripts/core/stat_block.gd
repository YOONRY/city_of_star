extends Resource
class_name StatBlock

@export var strength: int = 0
@export var agility: int = 0
@export var intelligence: int = 0
@export var charm: int = 0
@export var health: int = 0

func clone() -> StatBlock:
	var block := StatBlock.new()
	block.strength = strength
	block.agility = agility
	block.intelligence = intelligence
	block.charm = charm
	block.health = health
	return block


func add(other: StatBlock) -> StatBlock:
	if other == null:
		return self

	strength += other.strength
	agility += other.agility
	intelligence += other.intelligence
	charm += other.charm
	health += other.health
	return self


func plus(other: StatBlock) -> StatBlock:
	var block := clone()
	return block.add(other)


func meets(required: StatBlock) -> bool:
	if required == null:
		return true

	return (
		strength >= required.strength
		and agility >= required.agility
		and intelligence >= required.intelligence
		and charm >= required.charm
		and health >= required.health
	)


func total() -> int:
	return strength + agility + intelligence + charm + health


func as_dictionary() -> Dictionary:
	return {
		"strength": strength,
		"agility": agility,
		"intelligence": intelligence,
		"charm": charm,
		"health": health,
	}
