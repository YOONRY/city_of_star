extends RefCounted
class_name OfficeState

var money: int = 100
var reputation: int = 0
var owned_cards: Array[CardDefinition] = []
var available_requests: Array[RequestDefinition] = []
var active_requests: Array[ActiveRequest] = []

func reset(starting_money: int = 100) -> void:
	money = starting_money
	reputation = 0
	owned_cards.clear()
	available_requests.clear()
	active_requests.clear()


func add_card(card: CardDefinition) -> void:
	if card != null and not owned_cards.has(card):
		owned_cards.append(card)


func add_available_request(request: RequestDefinition) -> void:
	if request != null and not available_requests.has(request):
		available_requests.append(request)


func accept_request(request: RequestDefinition) -> ActiveRequest:
	if request == null or not available_requests.has(request):
		return null

	var active := ActiveRequest.new()
	active.setup(request)
	active_requests.append(active)
	available_requests.erase(request)
	return active


func advance_requests_one_day() -> Array[ActiveRequest]:
	var completed: Array[ActiveRequest] = []

	for request in active_requests:
		request.advance_day()
		if request.is_complete():
			completed.append(request)

	return completed


func complete_request(active: ActiveRequest) -> void:
	if active == null or active.definition == null:
		return

	money += active.definition.reward_money
	reputation += active.definition.reward_reputation
	active_requests.erase(active)


func get_roster_stats() -> StatBlock:
	var total_stats := StatBlock.new()

	for card in owned_cards:
		if card != null and card.card_type == GameEnums.CardType.CHARACTER:
			total_stats.add(card.stats)

	return total_stats
