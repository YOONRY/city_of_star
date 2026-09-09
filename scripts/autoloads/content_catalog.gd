extends Node
class_name CityContentCatalog

signal catalog_reloaded

const CARD_DIRECTORY := "res://data/cards"
const REQUEST_DIRECTORY := "res://data/requests"

var cards: Array[CardDefinition] = []
var requests: Array[RequestDefinition] = []
var cards_by_id: Dictionary = {}
var requests_by_id: Dictionary = {}

func _ready() -> void:
	reload()


func reload() -> void:
	_load_cards()
	_load_requests()
	catalog_reloaded.emit()


func get_card(id: StringName) -> CardDefinition:
	return cards_by_id.get(id, null) as CardDefinition


func get_request(id: StringName) -> RequestDefinition:
	return requests_by_id.get(id, null) as RequestDefinition


func _load_cards() -> void:
	cards.clear()
	cards_by_id.clear()

	for resource in _load_resource_files(CARD_DIRECTORY):
		if resource is CardDefinition:
			var card := resource as CardDefinition
			cards.append(card)
			if not String(card.id).is_empty():
				cards_by_id[card.id] = card


func _load_requests() -> void:
	requests.clear()
	requests_by_id.clear()

	for resource in _load_resource_files(REQUEST_DIRECTORY):
		if resource is RequestDefinition:
			var request := resource as RequestDefinition
			requests.append(request)
			if not String(request.id).is_empty():
				requests_by_id[request.id] = request


func _load_resource_files(base_path: String) -> Array[Resource]:
	var loaded: Array[Resource] = []
	var directory := DirAccess.open(base_path)

	if directory == null:
		return loaded

	directory.list_dir_begin()
	var file_name := directory.get_next()

	while not file_name.is_empty():
		var full_path := base_path.path_join(file_name)

		if directory.current_is_dir():
			if not file_name.begins_with("."):
				loaded.append_array(_load_resource_files(full_path))
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource := ResourceLoader.load(full_path)
			if resource != null:
				loaded.append(resource)

		file_name = directory.get_next()

	directory.list_dir_end()
	return loaded
