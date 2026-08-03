class_name SlimeKing
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal defeated

const LANDING_EFFECT := preload("res://slime_landing_effect.gd")
const BLOB_SCENE := preload("res://slime_blob.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://damage_number.tscn")
const MAX_HEALTH := 400
const DEFENSE := 4
const JUMP_DURATION := 1.0
const JUMP_HEIGHT := 56.0
const JUMP_DISTANCE := 128.0
const STOMP_START_DAMAGE := 20
const STOMP_END_DAMAGE := 14
const PHASE_THREE_HEALTH := 100
const PHASE_THREE_BLOB_INTERVAL := 0.2
const PHASE_THREE_WAVE_START_HALF_EXTENT := 64.0
const PHASE_THREE_WAVE_END_HALF_EXTENT := 192.0
const CLOSE_DISTANCE := 230.0
const CARDINAL_ALIGNMENT_TOLERANCE := 36.0
const CARDINAL_ATTACK_RANGE := 640.0
const GEL_COLOR := Color("#00E3A86B")
const CORE_COLOR := Color("#059F84")
const CORE_SIDE_COLOR := Color("#094E33")
const EYE_COLOR := Color("#1C4230")

@onready var visual: Node2D = $Visual
@onready var contact_shadow: Polygon2D = $ContactShadow

var target: IslandPlayer
var max_health := MAX_HEALTH
var health := MAX_HEALTH
var _state := "dormant"
var _state_time := 0.0
var _jump_direction := Vector2.RIGHT
var _jump_start := Vector2.ZERO
var _jump_target := Vector2.ZERO
var _stomps_remaining := 0
var _burst_remaining := 0
var _burst_delay := 0.0
var _rng := RandomNumberGenerator.new()
var _pupil_offset := Vector2.ZERO
var _phase_three_started := false
var _phase_three_landing := false
var _phase_three_shot_delay := 0.0
var _phase_three_shot_angle := 0.0

func configure(new_target: IslandPlayer, seed_value: int) -> void:
	target = new_target
	_rng.seed = seed_value

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	visible = false
	queue_redraw()

func summon() -> void:
	if _state != "dormant":
		return
	_state = "summoning"
	_state_time = 0.0
	visible = true
	modulate.a = 0.0
	_spawn_fragments()
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	if _state == "dormant" or not is_instance_valid(target):
		return
	_state_time += delta
	_update_eyes(delta)
	if not _phase_three_started and health <= PHASE_THREE_HEALTH:
		_begin_phase_three_leap()
		return
	match _state:
		"summoning":
			_update_summoning()
		"jumping":
			_update_jump(delta)
		"resting":
			if _state_time >= (0.5 if _is_enraged() else 1.0):
				_choose_behavior()
		"burst_windup":
			visual.scale = Vector2(1.0 + minf(_state_time / 0.28, 1.0) * 0.25, 1.0 - minf(_state_time / 0.28, 1.0) * 0.20)
			if _state_time >= 0.28:
				_spawn_gel_burst(Vector2(0.0, 38.0), 22)
				_state = "bursting"
				_state_time = 0.0
				_burst_remaining = 3
				_burst_delay = 0.0
		"bursting":
			_update_burst(delta)
		"phase_three_burst":
			_update_phase_three_burst(delta)
		"idle":
			_choose_behavior()

func _update_summoning() -> void:
	var progress := minf(_state_time, 1.0)
	modulate.a = progress
	visual.scale = Vector2(lerpf(0.45, 1.0, progress), lerpf(1.45, 1.0, progress))
	if progress >= 1.0:
		modulate.a = 1.0
		visual.scale = Vector2.ONE
		_state = "idle"
		_state_time = 0.0
		_push_target_out_of_body()

func _choose_behavior() -> void:
	_state_time = 0.0
	# Rage is a fixed jump -> burst -> brief rest loop, never a stationary turret.
	if _is_enraged():
		_stomps_remaining = 1
		_begin_jump()
		return
	# A 24px blob intersects the 48px player box when their centers are within 36px.
	if _has_cardinal_attack_lane():
		_begin_burst_windup()
		return
	_stomps_remaining = 3
	_begin_jump()

func _is_enraged() -> bool:
	return health <= int(max_health / 2)

func _begin_phase_three_leap() -> void:
	_phase_three_started = true
	_phase_three_landing = true
	_jump_start = global_position
	var island_map := get_parent() as IslandMap
	_jump_target = island_map.get_arena_world_center() if island_map != null else target.global_position
	var movement: Vector2 = _jump_target - _jump_start
	_jump_direction = movement.normalized() if not movement.is_zero_approx() else Vector2.RIGHT
	_state = "jumping"
	_state_time = 0.0
	visual.position = Vector2.ZERO
	visual.scale = Vector2(0.8, 1.2)

func _update_phase_three_burst(delta: float) -> void:
	_phase_three_shot_delay -= delta
	var pulse := (sin(_state_time * TAU * 1.6) + 1.0) * 0.5
	var vertical_scale := lerpf(1.0, 0.76, pulse)
	visual.scale = Vector2(lerpf(1.0, 1.18, pulse), vertical_scale)
	# Keep the bottom of the 128px gel silhouette fixed while it compresses.
	visual.position.y = 64.0 * (1.0 - vertical_scale)
	if _phase_three_shot_delay > 0.0:
		return
	var direction := Vector2.from_angle(_phase_three_shot_angle)
	var blob := BLOB_SCENE.instantiate() as Area2D
	blob.call("configure", direction, self, 13, 160.0)
	blob.global_position = global_position + direction * 56.0
	get_parent().add_child(blob)
	_phase_three_shot_angle -= deg_to_rad(23.0)
	_phase_three_shot_delay = PHASE_THREE_BLOB_INTERVAL
func _begin_burst_windup() -> void:
	_state = "burst_windup"
	_state_time = 0.0

func _begin_burst_immediately() -> void:
	_spawn_gel_burst(Vector2(0.0, 38.0), 22)
	visual.scale = Vector2.ONE
	_state = "bursting"
	_state_time = 0.0
	_burst_remaining = 3
	_burst_delay = 0.0

func _has_cardinal_attack_lane() -> bool:
	var offset := target.global_position - global_position
	return (
		(absf(offset.x) <= CARDINAL_ALIGNMENT_TOLERANCE and absf(offset.y) <= CARDINAL_ATTACK_RANGE)
		or (absf(offset.y) <= CARDINAL_ALIGNMENT_TOLERANCE and absf(offset.x) <= CARDINAL_ATTACK_RANGE)
	)

func _begin_alignment_jump() -> void:
	var offset := target.global_position - global_position
	var destination := global_position
	if absf(offset.x) <= absf(offset.y):
		destination.x = target.global_position.x
	else:
		destination.y = target.global_position.y
	_jump_start = global_position
	var movement := destination - _jump_start
	if movement.length() > JUMP_DISTANCE:
		movement = movement.normalized() * JUMP_DISTANCE
	_jump_target = _jump_start + movement
	_jump_direction = movement.normalized() if not movement.is_zero_approx() else Vector2.RIGHT
	_state = "jumping"
	_state_time = 0.0
	visual.scale = Vector2(0.8, 1.2)

func _begin_jump() -> void:
	_jump_start = global_position
	_jump_direction = (target.global_position - global_position).normalized()
	if _jump_direction.is_zero_approx():
		_jump_direction = Vector2.RIGHT
	_jump_target = _jump_start + _jump_direction * minf(JUMP_DISTANCE, _jump_start.distance_to(target.global_position))
	_state = "jumping"
	_state_time = 0.0
	visual.scale = Vector2(0.8, 1.2)

func _update_jump(_delta: float) -> void:
	var progress := minf(_state_time / JUMP_DURATION, 1.0)
	global_position = _jump_start.lerp(_jump_target, progress)
	var arc := sin(progress * PI)
	visual.position.y = -arc * JUMP_HEIGHT
	visual.scale = Vector2(lerpf(0.8, 1.08, arc), lerpf(1.2, 0.92, arc))
	contact_shadow.scale = Vector2.ONE * lerpf(1.0, 0.62, arc)
	if progress >= 1.0:
		_land()

func _land() -> void:
	visual.position = Vector2.ZERO
	visual.scale = Vector2(1.25, 0.74)
	contact_shadow.scale = Vector2.ONE
	var effect := LANDING_EFFECT.new() as Node2D
	if _phase_three_landing:
		effect.call(
			"configure", target, STOMP_START_DAMAGE,
			PHASE_THREE_WAVE_START_HALF_EXTENT, PHASE_THREE_WAVE_END_HALF_EXTENT,
			STOMP_END_DAMAGE
		)
	else:
		effect.call("configure", target, STOMP_START_DAMAGE, 64.0, 128.0, STOMP_END_DAMAGE)
	effect.global_position = global_position
	get_parent().add_child(effect)
	_spawn_gel_burst(Vector2(0.0, 52.0), 26)
	_state_time = 0.0
	if _phase_three_landing:
		_phase_three_landing = false
		_phase_three_shot_delay = 0.0
		_phase_three_shot_angle = (target.global_position - global_position).angle()
		_push_target_out_of_body()
		_state = "phase_three_burst"
		return
	var squash := create_tween()
	squash.tween_property(visual, "scale", Vector2.ONE, 0.15)
	if _is_enraged():
		_begin_burst_immediately()
		return
	if _has_cardinal_attack_lane():
		_begin_burst_windup()
		return
	_stomps_remaining -= 1
	if _stomps_remaining > 0:
		_begin_jump()
	else:
		_state = "resting"
func _update_burst(delta: float) -> void:
	_burst_delay -= delta
	if _burst_delay > 0.0:
		return
	_fire_cardinal_burst()
	_burst_remaining -= 1
	_burst_delay = 0.2
	if _burst_remaining <= 0:
		visual.scale = Vector2.ONE
		_state_time = 0.0
		_state = "resting"

func _fire_cardinal_burst() -> void:
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		var blob := BLOB_SCENE.instantiate() as Area2D
		blob.call("configure", direction, self, 13, 160.0)
		blob.global_position = global_position + direction * 56.0
		get_parent().add_child(blob)

func _update_eyes(delta: float) -> void:
	var desired := (target.global_position - global_position).normalized() * 3.0
	_pupil_offset = _pupil_offset.lerp(desired, minf(delta * 8.0, 1.0))
	queue_redraw()

func _push_target_out_of_body() -> void:
	var offset := target.global_position - global_position
	if offset.length() < 88.0:
		if offset.is_zero_approx():
			offset = Vector2.DOWN
		target.global_position = global_position + offset.normalized() * 96.0

func _flash_brightness() -> void:
	var current_alpha := modulate.a
	modulate = Color(2.5, 2.5, 2.5, current_alpha)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, current_alpha), 0.075)
func take_damage(amount: int) -> void:
	if _state == "dormant":
		return
	_flash_brightness()
	var hit_direction := (global_position - target.global_position).normalized()
	if hit_direction.is_zero_approx():
		hit_direction = Vector2.DOWN
	_spawn_gel_burst(hit_direction * 44.0, 16)
	visual.scale = Vector2(1.07, 0.94)
	var hit_tween := create_tween()
	hit_tween.tween_property(visual, "scale", Vector2.ONE, 0.10)
	var final_damage := maxi(1, amount - DEFENSE)
	_show_damage_number(final_damage)
	health = maxi(0, health - final_damage)
	health_changed.emit(health, max_health)
	if health <= 0:
		defeated.emit()
		queue_free()

func _show_damage_number(amount: int) -> void:
	var number := DAMAGE_NUMBER_SCENE.instantiate() as Node2D
	number.configure(amount, Color.WHITE)
	get_parent().add_child(number)
	# The king is 128px tall; start the number above its gel shell.
	number.global_position = global_position + Vector2(0.0, -54.0)
func show_projectile_hit(_hit_color: Color) -> void:
	pass

func _spawn_gel_burst(local_offset: Vector2, particle_count: int) -> void:
	var effect := SlimeKingGelBurst.new()
	effect.configure(local_offset, particle_count, _rng.randi())
	effect.global_position = global_position
	get_parent().add_child(effect)
func _spawn_fragments() -> void:
	var effect := SlimeKingArrivalEffect.new()
	effect.global_position = global_position
	get_parent().add_child(effect)

func _draw() -> void:
	# Visual transforms are applied here because this compact boss is drawn by its root node.
	draw_set_transform(visual.position, 0.0, visual.scale)
	# The 64px core sits beneath the translucent 128px gel shell.
	draw_rect(Rect2(-32, -32, 64, 64), CORE_COLOR, true, -1.0, false)
	draw_rect(Rect2(-32, 20, 64, 12), CORE_SIDE_COLOR, true, -1.0, false)
	# Exact 2x coordinates of the SVG: eye wells (#9FE5C8) remain fixed;
	# only the two #009A85 pupils move, clamped inside those wells.
	var pupil_motion := Vector2(clampf(_pupil_offset.x, -3.0, 3.0), clampf(_pupil_offset.y, -3.0, 3.0))
	var left_well := Rect2(-25.76, -14.38, 16.0, 16.0)
	var right_well := Rect2(0.42, -18.44, 24.0, 24.0)
	draw_rect(left_well, Color("#9FE5C8"), true, -1.0, false)
	draw_rect(right_well, Color("#9FE5C8"), true, -1.0, false)
	draw_rect(Rect2(Vector2(-23.12, -4.16) + pupil_motion, Vector2(7.47, 6.23)), Color("#009A85"), true, -1.0, false)
	draw_rect(Rect2(Vector2(5.27, -6.59) + pupil_motion, Vector2(10.59, 8.40)), Color("#009A85"), true, -1.0, false)
	# The two dark eyebrow polygons from slime_king_core.svg, converted from its
	# 8.4667-unit viewBox into this 64px core (2x the exported SVG size).
	draw_colored_polygon(PackedVector2Array([Vector2(-29.04, -20.94), Vector2(-5.36, -15.65), Vector2(-5.36, -5.22), Vector2(-29.04, -10.50)]), EYE_COLOR)
	draw_colored_polygon(PackedVector2Array([Vector2(-1.63, -17.83), Vector2(26.10, -25.15), Vector2(26.10, -13.47), Vector2(-1.63, -6.15)]), EYE_COLOR)
	draw_rect(Rect2(-64, -64, 128, 128), GEL_COLOR, true, -1.0, false)

class SlimeKingArrivalEffect extends Node2D:
	var time := 0.0
	func _process(delta: float) -> void:
		time += delta
		queue_redraw()
		if time >= 1.0:
			queue_free()
	func _draw() -> void:
		var progress := minf(time, 1.0)
		for index in range(24):
			var angle := TAU * float(index) / 24.0 + 0.3
			var distance := lerpf(260.0, 12.0, progress)
			var size := lerpf(10.0, 5.0, progress)
			var center := Vector2.from_angle(angle) * distance + Vector2(0.0, lerpf(-100.0, 0.0, progress))
			draw_rect(Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), Color("#00E3A8"), true, -1.0, false)

class SlimeKingGelBurst extends Node2D:
	var time := 0.0
	var origin_offset := Vector2.ZERO
	var particle_count := 16
	var seed_value := 0
	func configure(new_origin_offset: Vector2, new_particle_count: int, new_seed: int) -> void:
		origin_offset = new_origin_offset
		particle_count = new_particle_count
		seed_value = new_seed
	func _process(delta: float) -> void:
		time += delta
		queue_redraw()
		if time >= 0.36:
			queue_free()
	func _draw() -> void:
		var progress := minf(time / 0.36, 1.0)
		for index in range(particle_count):
			var phase := float((seed_value + index * 37) % 360) * PI / 180.0
			var direction := Vector2.from_angle(phase)
			var distance := lerpf(12.0 + float(index % 4) * 3.0, 62.0 + float(index % 5) * 7.0, progress)
			var size := lerpf(16.0 + float(index % 3) * 4.0, 6.0, progress)
			var center := origin_offset + direction * distance + Vector2(0.0, progress * progress * 24.0)
			var color := Color("#00E3A8")
			color.a = lerpf(0.88, 0.0, progress)
			draw_rect(Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), color, true, -1.0, false)