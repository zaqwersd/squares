class_name TripleBowAttack
extends RefCounted

var arrow_count: int
var interval: float
var recovery_duration: float
var active := false
var remaining := 0
var timer := 0.0
var cooldown_remaining := 0.0

func _init(new_arrow_count: int, new_interval: float, new_recovery_duration: float) -> void:
	arrow_count = new_arrow_count
	interval = new_interval
	recovery_duration = new_recovery_duration

func tick(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)

func begin() -> bool:
	if active or cooldown_remaining > 0.0:
		return false
	active = true
	remaining = arrow_count
	timer = 0.0
	return true

func advance(delta: float) -> Array[int]:
	var fired: Array[int] = []
	if not active:
		return fired
	timer -= delta
	while remaining > 0 and timer <= 0.0:
		fired.append(arrow_count - remaining)
		remaining -= 1
		timer += interval
	if remaining == 0:
		active = false
		cooldown_remaining = recovery_duration
	return fired

func cancel() -> void:
	active = false
	remaining = 0
	timer = 0.0