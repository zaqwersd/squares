class_name AttackRangePreview
extends Node2D

const LINE_COLOR := Color(0.92, 0.98, 1.0, 0.78)
const LINE_WIDTH := 2.0
const DASH_LENGTH := 8.0
const DASH_GAP := 6.0
const ROCK_RANGE := 64.0 * 3.0 + 34.0
const BOW_RANGE := 640.0 + 46.0
const SPEAR_RANGE := 64.0 * 9.0
const SWORD_RANGE := 88.0
const GREATSWORD_RANGE := 96.0
const GREATSWORD_WAVE_RANGE := 64.0 * 3.0 + 56.0
const SWORD_ARC := PI * 2.0 / 3.0
const GREATSWORD_ARC := PI

var _weapon_type := 0
var _direction := Vector2.RIGHT
var _active := false


func set_range(weapon_type: int, direction: Vector2, active: bool) -> void:
	var normalized_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var changed := _weapon_type != weapon_type or not _direction.is_equal_approx(normalized_direction) or _active != active
	_weapon_type = weapon_type
	_direction = normalized_direction
	_active = active
	visible = active
	if changed:
		queue_redraw()


func _draw() -> void:
	if not _active:
		return
	match _weapon_type:
		WeaponPickup.WeaponType.ROCK:
			_draw_line_range(ROCK_RANGE)
		WeaponPickup.WeaponType.BOW:
			_draw_line_range(BOW_RANGE)
		WeaponPickup.WeaponType.TRIPLE_BOW:
			_draw_sector(BOW_RANGE, deg_to_rad(10.0))
		WeaponPickup.WeaponType.SWORD:
			_draw_sector(SWORD_RANGE, SWORD_ARC)
		WeaponPickup.WeaponType.GREATSWORD:
			_draw_sector(GREATSWORD_RANGE, GREATSWORD_ARC)
			_draw_sector(GREATSWORD_WAVE_RANGE, 0.92)
		WeaponPickup.WeaponType.SPEAR, WeaponPickup.WeaponType.FIRE_SPEAR:
			_draw_line_range(SPEAR_RANGE)


func _draw_line_range(range_length: float) -> void:
	var end := _direction * range_length
	_draw_dashed_segment(Vector2.ZERO, end)
	_draw_dashed_segment(end + _direction.orthogonal() * 7.0, end - _direction.orthogonal() * 7.0)


func _draw_sector(radius: float, arc: float) -> void:
	var start_angle := _direction.angle() - arc * 0.5
	var end_angle := _direction.angle() + arc * 0.5
	_draw_dashed_segment(Vector2.ZERO, Vector2.from_angle(start_angle) * radius)
	_draw_dashed_segment(Vector2.ZERO, Vector2.from_angle(end_angle) * radius)
	var steps := maxi(12, ceili(radius / 18.0))
	var previous := Vector2.from_angle(start_angle) * radius
	for index in range(1, steps + 1):
		var ratio := float(index) / float(steps)
		var current := Vector2.from_angle(lerpf(start_angle, end_angle, ratio)) * radius
		_draw_dashed_segment(previous, current)
		previous = current


func _draw_dashed_segment(from: Vector2, to: Vector2) -> void:
	var delta := to - from
	var length := delta.length()
	if length <= 0.001:
		return
	var direction := delta / length
	var distance := 0.0
	while distance < length:
		var dash_end := minf(distance + DASH_LENGTH, length)
		draw_line(from + direction * distance, from + direction * dash_end, LINE_COLOR, LINE_WIDTH, false)
		distance += DASH_LENGTH + DASH_GAP
