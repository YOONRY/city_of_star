extends RefCounted
class_name GameEnums

enum CardType {
	CHARACTER,
	EQUIPMENT,
	CONSUMABLE,
}

enum RequestType {
	STORY,
	REGULAR,
	EVENT,
}

enum Stat {
	STRENGTH,
	AGILITY,
	INTELLIGENCE,
	CHARM,
	HEALTH,
}

const CARD_TYPE_LABELS := {
	CardType.CHARACTER: "Character",
	CardType.EQUIPMENT: "Equipment",
	CardType.CONSUMABLE: "Consumable",
}

const REQUEST_TYPE_LABELS := {
	RequestType.STORY: "Story",
	RequestType.REGULAR: "Regular",
	RequestType.EVENT: "Event",
}

static func card_type_label(value: int) -> String:
	return CARD_TYPE_LABELS.get(value, "Unknown")


static func request_type_label(value: int) -> String:
	return REQUEST_TYPE_LABELS.get(value, "Unknown")
