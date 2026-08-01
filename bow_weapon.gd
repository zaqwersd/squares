@tool
class_name BowWeapon
extends Node2D

const FRAME_COLOR := Color.WHITE
const OUTLINE_WIDTH := 2.0
const MUZZLE_OFFSET := 54.0
const STRING_OFFSET := -8.0
const HALF_HEIGHT := 20.0
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
	# The body opens toward the owner. The string sits inside the two white arms.
	draw_rect(Rect2(-14.0, -HALF_HEIGHT, 24.0, BAR_THICKNESS), FRAME_COLOR, true)
	draw_rect(Rect2(5.0, -HALF_HEIGHT, BAR_THICKNESS, HALF_HEIGHT * 2.0), FRAME_COLOR, true)
	draw_rect(Rect2(-14.0, HALF_HEIGHT - BAR_THICKNESS, 24.0, BAR_THICKNESS), FRAME_COLOR, true)

	var inner_edge := HALF_HEIGHT - BAR_THICKNESS
	var contour := PackedVector2Array([
		Vector2(-14.0, -HALF_HEIGHT), Vector2(10.0, -HALF_HEIGHT),
		Vector2(10.0, HALF_HEIGHT), Vector2(-14.0, HALF_HEIGHT),
		Vector2(-14.0, inner_edge), Vector2(5.0, inner_edge),
		Vector2(5.0, -inner_edge), Vector2(-14.0, -inner_edge),
		Vector2(-14.0, -HALF_HEIGHT),
	])
	draw_polyline(contour, border_color, OUTLINE_WIDTH, false)
	draw_line(
		Vector2(STRING_OFFSET, -inner_edge),
		Vector2(STRING_OFFSET, inner_edge),
		border_color,
		OUTLINE_WIDTH,
		false
	)