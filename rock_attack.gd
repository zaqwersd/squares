class_name RockAttack
extends RefCounted

var in_flight := false

func can_begin() -> bool:
	return not in_flight

func begin() -> bool:
	if not can_begin():
		return false
	in_flight = true
	return true

func complete() -> void:
	in_flight = false

func cancel() -> void:
	in_flight = false