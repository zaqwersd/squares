class_name GreatswordAttack
extends RefCounted

# The sole source of truth for greatsword timing and base damage.
const BASE_SWING_DAMAGE := 6
const BASE_WAVE_DAMAGE := 6
const WINDUP_DURATION := 0.2
const SWING_DURATION := 0.3
const MIDPOINT_PAUSE := 0.1
const RECOVERY_DURATION := 0.5
const TOTAL_COOLDOWN := WINDUP_DURATION + SWING_DURATION + MIDPOINT_PAUSE + RECOVERY_DURATION

var active := false
var windup_remaining := 0.0
var swing_elapsed := 0.0
var midpoint_pause_remaining := 0.0
var return_hit_reset := false

func begin(skip_windup := false) -> void:
	active = true
	windup_remaining = 0.0 if skip_windup else WINDUP_DURATION
	swing_elapsed = 0.0
	midpoint_pause_remaining = 0.0
	return_hit_reset = false

func advance(delta: float) -> Dictionary:
	var step := {
		"phase": "idle",
		"windup_progress": 0.0,
		"started_swing": false,
		"previous_sweep": 0.0,
		"sweep": 0.0,
		"reverse": false,
		"reset_hits": false,
		"finished": false,
	}
	if not active:
		return step
	if windup_remaining > 0.0:
		var spent := minf(delta, windup_remaining)
		windup_remaining -= spent
		delta -= spent
		step["phase"] = "windup"
		step["windup_progress"] = 1.0 - windup_remaining / WINDUP_DURATION
		if windup_remaining > 0.0:
			return step
		step["started_swing"] = true
	if midpoint_pause_remaining > 0.0:
		midpoint_pause_remaining = maxf(0.0, midpoint_pause_remaining - delta)
		step["phase"] = "pause"
		step["previous_sweep"] = 1.0
		step["sweep"] = 1.0
		return step
	if delta <= 0.0:
		step["phase"] = "swing"
		return step
	var previous_time := swing_elapsed / SWING_DURATION
	var midpoint_time := SWING_DURATION * 0.5
	var reaches_midpoint := previous_time < 0.5 and swing_elapsed + delta >= midpoint_time
	swing_elapsed = midpoint_time if reaches_midpoint else minf(SWING_DURATION, swing_elapsed + delta)
	if reaches_midpoint:
		midpoint_pause_remaining = MIDPOINT_PAUSE
	var current_time := swing_elapsed / SWING_DURATION
	step["phase"] = "swing"
	step["previous_sweep"] = _to_and_fro(previous_time)
	step["sweep"] = _to_and_fro(current_time)
	step["reverse"] = current_time > 0.5
	if reaches_midpoint and not return_hit_reset:
		return_hit_reset = true
		step["reset_hits"] = true
	if swing_elapsed >= SWING_DURATION:
		active = false
		step["finished"] = true
	return step

func _to_and_fro(time_progress: float) -> float:
	return time_progress * 2.0 if time_progress <= 0.5 else 2.0 - time_progress * 2.0