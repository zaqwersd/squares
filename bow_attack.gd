class_name BowAttack
extends RefCounted

var charge_duration: float
var recovery_duration: float
var charging := false
var charge_elapsed := 0.0
var cooldown_remaining := 0.0

func _init(new_charge_duration: float, new_recovery_duration: float) -> void:
	charge_duration = new_charge_duration
	recovery_duration = new_recovery_duration

func tick(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)

func is_ready() -> bool:
	return not charging and cooldown_remaining <= 0.0

func begin_charge() -> bool:
	if not is_ready():
		return false
	charging = true
	charge_elapsed = 0.0
	return true

func advance_charge(delta: float) -> float:
	if not charging:
		return 0.0
	charge_elapsed = minf(charge_duration, charge_elapsed + delta)
	return get_charge_ratio()

func get_charge_ratio() -> float:
	if charge_duration <= 0.0:
		return 1.0
	return clampf(charge_elapsed / charge_duration, 0.0, 1.0)

func release() -> float:
	if not charging:
		return -1.0
	var ratio := get_charge_ratio()
	charging = false
	charge_elapsed = 0.0
	cooldown_remaining = recovery_duration
	return ratio

func cancel() -> void:
	charging = false
	charge_elapsed = 0.0