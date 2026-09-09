extends RefCounted
class_name ActiveRequest

var definition: RequestDefinition
var elapsed_days: int = 0
var remaining_days: int = 1

func setup(request_definition: RequestDefinition) -> void:
	definition = request_definition
	elapsed_days = 0

	if definition == null:
		remaining_days = 1
	else:
		remaining_days = maxi(1, definition.duration_days)


func advance_day() -> void:
	elapsed_days += 1
	remaining_days = maxi(0, remaining_days - 1)


func is_complete() -> bool:
	return remaining_days <= 0
