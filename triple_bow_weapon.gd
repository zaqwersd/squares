@tool
class_name TripleBowWeapon
extends Node2D

const FRAME_COLOR := Color.WHITE
const OUTLINE_WIDTH := 2.0
const MUZZLE_OFFSET := 54.0
const STRING_OFFSET := -8.0
const HALF_HEIGHT := 25.0
const BAR_THICKNESS := 5.0

@export var border_color := Color("#1A64B5"):
	set(value):
		border_color = value
		queue_redraw()


func set_aim_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		visible = false
		return
	visible = true
	position = direction.normalized() * MUZZLE_OFFSET
	rotation = direction.angle()


func _draw() -> void:
	# The C frame and its three teeth are one continuous filled silhouette.
	draw_rect(Rect2(-14.0, -25.0, 24.0, BAR_THICKNESS), FRAME_COLOR, true)
	draw_rect(Rect2(5.0, -25.0, BAR_THICKNESS, 50.0), FRAME_COLOR, true)
	draw_rect(Rect2(-14.0, 20.0, 24.0, BAR_THICKNESS), FRAME_COLOR, true)

	# Upper and lower teeth extend away from the C frame in matching 11/7/5px steps.
	draw_rect(Rect2(-14.0, -36.0, 5.0, 11.0), FRAME_COLOR, true)
	draw_rect(Rect2(-5.0, -32.0, 5.0, 7.0), FRAME_COLOR, true)
	draw_rect(Rect2(4.0, -30.0, 5.0, 5.0), FRAME_COLOR, true)
	draw_rect(Rect2(-14.0, 25.0, 5.0, 11.0), FRAME_COLOR, true)
	draw_rect(Rect2(-5.0, 25.0, 5.0, 7.0), FRAME_COLOR, true)
	draw_rect(Rect2(4.0, 25.0, 5.0, 5.0), FRAME_COLOR, true)

	# Trace only the union's exterior: attachment seams remain clean and unoutlined.
	var contour := PackedVector2Array([
		Vector2(-14.0, -36.0), Vector2(-9.0, -36.0), Vector2(-9.0, -25.0),
		Vector2(-5.0, -25.0), Vector2(-5.0, -32.0), Vector2(0.0, -32.0), Vector2(0.0, -25.0),
		Vector2(4.0, -25.0), Vector2(4.0, -30.0), Vector2(9.0, -30.0), Vector2(9.0, -25.0),
		Vector2(10.0, -25.0), Vector2(10.0, 25.0),
		Vector2(9.0, 25.0), Vector2(9.0, 30.0), Vector2(4.0, 30.0), Vector2(4.0, 25.0),
		Vector2(0.0, 25.0), Vector2(0.0, 32.0), Vector2(-5.0, 32.0), Vector2(-5.0, 25.0),
		Vector2(-9.0, 25.0), Vector2(-9.0, 36.0), Vector2(-14.0, 36.0),
		Vector2(-14.0, 20.0), Vector2(5.0, 20.0), Vector2(5.0, -20.0),
		Vector2(-14.0, -20.0), Vector2(-14.0, -36.0),
	])
	draw_polyline(contour, border_color, OUTLINE_WIDTH, false)
	draw_line(Vector2(STRING_OFFSET, -20.0), Vector2(STRING_OFFSET, 20.0), border_color, OUTLINE_WIDTH, false)
