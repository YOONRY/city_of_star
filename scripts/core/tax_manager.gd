extends RefCounted
class_name TaxManager

var weekly_tax: int = 80
var due_weekday: int = 7
var last_paid_week: int = 0

func _init(initial_weekly_tax: int = 80, due_weekday_value: int = 7) -> void:
	weekly_tax = initial_weekly_tax
	due_weekday = clampi(due_weekday_value, 1, 7)


func weekday(day: int) -> int:
	return ((maxi(day, 1) - 1) % 7) + 1


func current_week(day: int) -> int:
	return floori(float(maxi(day, 1) - 1) / 7.0) + 1


func is_due(day: int) -> bool:
	return weekday(day) == due_weekday


func has_paid_current_week(day: int) -> bool:
	return last_paid_week >= current_week(day)


func mark_paid(day: int) -> void:
	last_paid_week = current_week(day)
