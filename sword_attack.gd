class_name SwordAttack
extends RefCounted

var windup_duration: float
var swing_duration: float
var recovery_duration: float
var active := false
var windup_remaining := 0.0
var swing_elapsed := 0.0
var cooldown_remaining := 0.0

func _init(new_windup_duration: float, new_swing_duration: float, new_recovery_duration: float) -> void:
	windup_duration = new_windup_duration
	swing_duration = new_swing_duration
	recovery_duration = new_recovery_duration

func tick(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)

func is_ready() -> bool:
	return not active and cooldown_remaining <= 0.0

func begin() -> bool:
	if not is_ready():
		return false
	active = true
	cooldown_remaining = windup_duration + swing_duration + recovery_duration
	windup_remaining = windup_duration
	swing_elapsed = 0.0
	return true

func cancel() -> void:
	active = false
	windup_remaining = 0.0
	swing_elapsed = 0.0

func interrupt(cooldown: float) -> void:
	cancel()
	cooldown_remaining = cooldown

func advance(delta: float) -> Dictionary:
	var step := {
		"phase": "idle",
		"windup_progress": 0.0,
		"started_swing": false,
		"previous_progress": 0.0,
		"progress": 0.0,
		"finished": false,
	}
	if not active:
		return step
	var remaining_delta := delta
	if windup_remaining > 0.0:
		var used_windup := minf(remaining_delta, windup_remaining)
		windup_remaining -= used_windup
		remaining_delta -= used_windup
		step["phase"] = "windup"
		step["windup_progress"] = smoothstep(0.0, 1.0, 1.0 - windup_remaining / windup_duration)
		if windup_remaining > 0.0:
			return step
		step["started_swing"] = true
	if remaining_delta <= 0.0:
		return step
	var previous_progress := swing_elapsed / swing_duration
	swing_elapsed = minf(swing_duration, swing_elapsed + remaining_delta)
	step["phase"] = "swing"
	step["previous_progress"] = previous_progress
	step["progress"] = swing_elapsed / swing_duration
	if swing_elapsed >= swing_duration:
		active = false
		step["finished"] = true
	return step