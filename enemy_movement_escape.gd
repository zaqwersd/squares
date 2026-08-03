class_name EnemyMovementEscape
extends RefCounted

const STALL_SPEED_RATIO := 0.35
const STALL_DURATION := 0.18
const ESCAPE_RETRY_INTERVAL := 0.16
const ESCAPE_SUCCESS_DURATION := 0.22
const PROBE_DISTANCES: Array[float] = [72.0, 48.0, 28.0, 14.0]

var _rng := RandomNumberGenerator.new()
var _escape_remaining := 0.0
var _stall_elapsed := 0.0
var _success_elapsed := 0.0
var _retry_elapsed := 0.0
var _escape_direction := Vector2.ZERO


func configure(seed_value: int) -> void:
	_rng.seed = seed_value


func choose_direction(
	body: CharacterBody2D,
	desired_direction: Vector2,
	speed: float,
	delta: float
) -> Vector2:
	if desired_direction.is_zero_approx() or speed <= 0.0:
		return Vector2.ZERO
	if _escape_remaining <= 0.0:
		return desired_direction.normalized()
	_escape_remaining = maxf(0.0, _escape_remaining - delta)
	_retry_elapsed = maxf(0.0, _retry_elapsed - delta)
	if _escape_direction.is_zero_approx() or _retry_elapsed <= 0.0:
		_escape_direction = _find_wander_direction(body, desired_direction)
		_retry_elapsed = ESCAPE_RETRY_INTERVAL
	return _escape_direction


func report_motion(
	body: CharacterBody2D,
	requested_direction: Vector2,
	speed: float,
	delta: float
) -> void:
	if requested_direction.is_zero_approx() or speed <= 0.0:
		_stall_elapsed = 0.0
		return
	var moving_fast := body.get_real_velocity().length() >= speed * STALL_SPEED_RATIO
	if _escape_remaining > 0.0:
		if moving_fast:
			_success_elapsed += delta
			if _success_elapsed >= ESCAPE_SUCCESS_DURATION:
				_end_escape()
		else:
			_success_elapsed = 0.0
			_retry_elapsed = 0.0
		return
	if moving_fast:
		_stall_elapsed = 0.0
		return
	_stall_elapsed += delta
	if _stall_elapsed >= STALL_DURATION:
		_begin_escape(body, requested_direction)


func is_escaping() -> bool:
	return _escape_remaining > 0.0

func _begin_escape(body: CharacterBody2D, blocked_direction: Vector2) -> void:
	_escape_remaining = 0.9
	_stall_elapsed = 0.0
	_success_elapsed = 0.0
	_retry_elapsed = 0.0
	_escape_direction = _find_wander_direction(body, blocked_direction)


func _end_escape() -> void:
	_escape_remaining = 0.0
	_success_elapsed = 0.0
	_retry_elapsed = 0.0
	_escape_direction = Vector2.ZERO


func _find_wander_direction(body: CharacterBody2D, blocked_direction: Vector2) -> Vector2:
	var base := blocked_direction.normalized()
	if base.is_zero_approx():
		base = Vector2.RIGHT
	var candidates: Array[Vector2] = []
	for index in range(8):
		var angle := TAU * float(index) / 8.0 + _rng.randf_range(-0.18, 0.18)
		candidates.append(Vector2.RIGHT.rotated(angle))
	candidates.shuffle()
	var best := Vector2.ZERO
	var best_clearance := -1.0
	for candidate in candidates:
		var clearance := _probe_clearance(body, candidate)
		if clearance > best_clearance:
			best_clearance = clearance
			best = candidate
		if clearance >= PROBE_DISTANCES[0]:
			return candidate
	return best if not best.is_zero_approx() else -base


func _probe_clearance(body: CharacterBody2D, direction: Vector2) -> float:
	for distance in PROBE_DISTANCES:
		if body.test_move(body.global_transform, direction.normalized() * distance):
			continue
		return distance
	return 0.0