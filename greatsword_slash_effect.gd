class_name GreatswordSlashEffect
extends Node2D

const INNER_RADIUS := 0.0
const OUTER_RADIUS := 96.0
const HALF_SWING_ANGLE := PI * 0.5
const TRAIL_ANGLE := PI * 0.22

@export var faction_color := Color("#1A64B5")
var _progress := 0.0
var _reverse := false

func begin_swing(direction: Vector2) -> void:
	position = Vector2.ZERO
	rotation = direction.angle()
	_progress = 0.0
	visible = false
	queue_redraw()

func set_swing_progress(value: float, direction: Vector2, reverse := false) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_reverse = reverse
	if direction.is_zero_approx() or _progress >= 1.0:
		visible = false
		return
	rotation = direction.angle()
	visible = true
	queue_redraw()

func hide_slash() -> void:
	visible = false

func _draw() -> void:
	var current_angle := lerpf(-HALF_SWING_ANGLE, HALF_SWING_ANGLE, _progress)
	var visible_trail := minf(TRAIL_ANGLE, maxf(0.05, _progress * TRAIL_ANGLE * 2.6))
	var start_angle := current_angle + visible_trail if _reverse else current_angle - visible_trail
	var end_angle := current_angle if _reverse else current_angle
	var color := faction_color
	color.a = 0.56 * sin(_progress * PI)
	var points := PackedVector2Array()
	for index in range(10):
		var angle := lerpf(start_angle, end_angle, float(index) / 9.0)
		points.append(Vector2.from_angle(angle) * OUTER_RADIUS)
	for index in range(9, -1, -1):
		var angle := lerpf(start_angle, end_angle, float(index) / 9.0)
		points.append(Vector2.from_angle(angle) * INNER_RADIUS)
	draw_colored_polygon(points, color)
	draw_arc(Vector2.ZERO, OUTER_RADIUS, start_angle, end_angle, 12, color.lightened(0.24), 2.0)