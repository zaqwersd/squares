@tool
class_name GreatswordWeapon
extends Node2D

@export var outline_color := Color("#8B1E2D")
const HANDLE_COLOR := Color("#73683B")
const BLADE_COLOR := Color("#F4FAF8")
const GEM_COLOR := Color("#37FFCB")
const MOUNT_OFFSET := 56.0
const BLADE_LENGTH := 40.0
const BLADE_HALF_WIDTH := 5.0
const SWING_ARC := PI
const HIT_ANGLE_PADDING := atan(BLADE_HALF_WIDTH / (MOUNT_OFFSET + BLADE_LENGTH))

func set_aim_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		visible = false
		return
	visible = true
	position = direction.normalized() * MOUNT_OFFSET
	rotation = direction.angle()

func set_windup_direction(direction: Vector2, progress: float) -> void:
	set_swing_direction(direction, progress * 0.5)

func set_swing_direction(direction: Vector2, progress: float) -> void:
	if direction.is_zero_approx():
		visible = false
		return
	visible = true
	var swing := direction.normalized().rotated(lerpf(-SWING_ARC * 0.5, SWING_ARC * 0.5, progress))
	position = swing * MOUNT_OFFSET
	rotation = swing.angle()

func get_swing_sector_polygon(direction: Vector2, from_progress: float, to_progress: float) -> PackedVector2Array:
	var from_angle := direction.angle() + lerpf(-SWING_ARC * 0.5, SWING_ARC * 0.5, from_progress)
	var to_angle := direction.angle() + lerpf(-SWING_ARC * 0.5, SWING_ARC * 0.5, to_progress)
	# Pad the wedge by the real outer-edge angle of the 10px blade.
	var start_angle := minf(from_angle, to_angle) - HIT_ANGLE_PADDING
	var end_angle := maxf(from_angle, to_angle) + HIT_ANGLE_PADDING
	var samples := maxi(2, ceili(absf(end_angle - start_angle) / 0.045))
	var points := PackedVector2Array([get_parent().global_transform * Vector2.ZERO])
	for index in range(samples + 1):
		var angle := lerpf(start_angle, end_angle, float(index) / float(samples))
		points.append(get_parent().global_transform * Vector2.from_angle(angle) * (MOUNT_OFFSET + BLADE_LENGTH))
	return points

func hits_collision_shape(direction: Vector2, from_progress: float, to_progress: float, collision_shape: CollisionShape2D) -> bool:
	if collision_shape == null or not collision_shape.shape is RectangleShape2D or direction.is_zero_approx():
		return false
	var rectangle := collision_shape.shape as RectangleShape2D
	# A circle enclosing the square hitbox gives a stable, inclusive full-fan test.
	var hit_radius := rectangle.size.length() * 0.5
	var origin: Vector2 = get_parent().global_position
	var to_target: Vector2 = collision_shape.global_position - origin
	var distance: float = to_target.length()
	var outer_radius := MOUNT_OFFSET + BLADE_LENGTH
	if distance - hit_radius > outer_radius:
		return false
	if distance <= hit_radius:
		return true
	var local_angle := direction.angle_to(to_target / distance)
	var from_angle := lerpf(-SWING_ARC * 0.5, SWING_ARC * 0.5, from_progress)
	var to_angle := lerpf(-SWING_ARC * 0.5, SWING_ARC * 0.5, to_progress)
	var angular_radius := asin(clampf(hit_radius / distance, 0.0, 1.0)) + HIT_ANGLE_PADDING
	var start_angle := minf(from_angle, to_angle) - angular_radius
	var end_angle := maxf(from_angle, to_angle) + angular_radius
	return local_angle >= start_angle and local_angle <= end_angle

func _draw() -> void:
	# A broad, symmetric blade with a layered guard; all joins are intentionally flush.
	_draw_piece(Rect2(-18.0, -3.0, 12.0, 6.0), HANDLE_COLOR)
	_draw_piece(Rect2(-7.0, -14.0, 7.0, 28.0), HANDLE_COLOR)
	_draw_piece(Rect2(-2.0, -18.0, 5.0, 36.0), HANDLE_COLOR)
	# The blade is one uninterrupted rectangular bar.
	var blade := Rect2(0.0, -BLADE_HALF_WIDTH, BLADE_LENGTH, BLADE_HALF_WIDTH * 2.0)
	draw_rect(blade, BLADE_COLOR, true)
	draw_rect(blade, outline_color, false, 2.0)
	draw_rect(Rect2(-9.0, -9.0, 18.0, 18.0), outline_color, true)
	draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), GEM_COLOR, true)

func _draw_piece(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color, true)
	draw_rect(rect, outline_color, false, 2.0)