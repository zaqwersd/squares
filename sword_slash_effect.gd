class_name SwordSlashEffect
extends Node2D

const INNER_RADIUS := SwordWeapon.MOUNT_OFFSET
const OUTER_RADIUS := SwordWeapon.MOUNT_OFFSET + SwordWeapon.BLADE_LENGTH
const HALF_SWING_ANGLE := SwordWeapon.SWING_ARC * 0.5
const TRAIL_ANGLE := PI * 0.16

@export var faction_color := Color("#8B1E2D")

var _progress := 0.0


func begin_swing(direction: Vector2) -> void:
	position = Vector2.ZERO
	rotation = direction.angle()
	_progress = 0.0
	visible = false
	queue_redraw()


func set_swing_progress(value: float, direction: Vector2) -> void:
	_progress = clampf(value, 0.0, 1.0)
	if direction.is_zero_approx() or _progress >= 1.0:
		visible = false
		return
	rotation = direction.angle()
	visible = true
	queue_redraw()


func hide_slash() -> void:
	visible = false


func _draw() -> void:
	# This ribbon is driven by the exact same progress as the blade itself.
	var current_angle := lerpf(-HALF_SWING_ANGLE, HALF_SWING_ANGLE, _progress)
	var visible_trail := minf(TRAIL_ANGLE, maxf(0.03, _progress * TRAIL_ANGLE * 2.5))
	var start_angle := current_angle - visible_trail
	var fade := sin(_progress * PI)
	var light_color := faction_color
	light_color.a = 0.64 * fade
	var points := PackedVector2Array()
	for index in range(7):
		var angle := lerpf(start_angle, current_angle, float(index) / 6.0)
		points.append(Vector2(cos(angle), sin(angle)) * OUTER_RADIUS)
	for index in range(6, -1, -1):
		var angle := lerpf(start_angle, current_angle, float(index) / 6.0)
		points.append(Vector2(cos(angle), sin(angle)) * INNER_RADIUS)
	draw_colored_polygon(points, light_color)
	var edge_color := light_color
	edge_color.a = minf(0.9, light_color.a + 0.2)
	draw_arc(Vector2.ZERO, OUTER_RADIUS, start_angle, current_angle, 8, edge_color, 1.5)
