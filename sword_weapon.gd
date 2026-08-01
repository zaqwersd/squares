@tool
class_name SwordWeapon
extends Node2D

@export var outline_color := Color("#8B1E2D")
const HANDLE_COLOR := Color("#73683B")
const BLADE_COLOR := Color.WHITE
const MOUNT_OFFSET := 56.0
const BLADE_LENGTH := 32.0
const BLADE_HALF_WIDTH := 2.0
const SWING_ARC := PI * 2.0 / 3.0


func set_aim_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		visible = false
		return
	visible = true
	position = direction.normalized() * MOUNT_OFFSET
	rotation = direction.angle()


func set_windup_direction(direction: Vector2, progress: float) -> void:
	if direction.is_zero_approx():
		visible = false
		return
	visible = true
	var windup_direction := direction.normalized().rotated(lerpf(0.0, -SWING_ARC * 0.5, progress))
	position = windup_direction * MOUNT_OFFSET
	rotation = windup_direction.angle()


func set_swing_direction(direction: Vector2, progress: float) -> void:
	if direction.is_zero_approx():
		visible = false
		return
	visible = true
	var swing_direction := direction.normalized().rotated(lerpf(-SWING_ARC * 0.5, SWING_ARC * 0.5, progress))
	position = swing_direction * MOUNT_OFFSET
	rotation = swing_direction.angle()


func get_blade_polygon_for_swing(direction: Vector2, progress: float) -> PackedVector2Array:
	var swing_direction := direction.normalized().rotated(lerpf(-SWING_ARC * 0.5, SWING_ARC * 0.5, progress))
	var blade_transform: Transform2D = get_parent().global_transform * Transform2D(swing_direction.angle(), swing_direction * MOUNT_OFFSET)
	return _blade_polygon_from_transform(blade_transform)

func get_swing_sector_polygon(direction: Vector2, from_progress: float, to_progress: float) -> PackedVector2Array:
	var from_angle := direction.angle() + lerpf(-SWING_ARC * 0.5, SWING_ARC * 0.5, from_progress)
	var to_angle := direction.angle() + lerpf(-SWING_ARC * 0.5, SWING_ARC * 0.5, to_progress)
	var sample_count: int = maxi(1, ceili(absf(to_angle - from_angle) / 0.05))
	var sector := PackedVector2Array([get_parent().global_transform * Vector2.ZERO])
	var radius := MOUNT_OFFSET + BLADE_LENGTH
	for sample in range(sample_count + 1):
		var ratio := float(sample) / float(sample_count)
		var local_point := Vector2.from_angle(lerpf(from_angle, to_angle, ratio)) * radius
		sector.append(get_parent().global_transform * local_point)
	return sector

func _draw() -> void:
	_draw_piece(Rect2(-16.0, -2.0, 12.0, 4.0), HANDLE_COLOR)
	_draw_piece(Rect2(-4.0, -8.0, 4.0, 16.0), HANDLE_COLOR)
	_draw_piece(Rect2(0.0, -BLADE_HALF_WIDTH, BLADE_LENGTH, BLADE_HALF_WIDTH * 2.0), BLADE_COLOR)


func _blade_polygon_from_transform(blade_transform: Transform2D) -> PackedVector2Array:
	return PackedVector2Array([
		blade_transform * Vector2(0.0, -BLADE_HALF_WIDTH),
		blade_transform * Vector2(BLADE_LENGTH, -BLADE_HALF_WIDTH),
		blade_transform * Vector2(BLADE_LENGTH, BLADE_HALF_WIDTH),
		blade_transform * Vector2(0.0, BLADE_HALF_WIDTH),
	])


func _draw_piece(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color, true)
	draw_rect(rect, outline_color, false, 2.0)