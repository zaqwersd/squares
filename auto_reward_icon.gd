class_name AutoRewardIcon
extends RefCounted

const GEL_COLOR := Color("#00E3A86B")
const OUTLINE := Color("#B0FFE2")
const DARK_GEL := Color("#009B7699")
const CORE_TEXTURE := preload("res://art/core.svg")

static func draw_on(canvas: CanvasItem, reward_id: int, center: Vector2, icon_scale: float) -> void:
	match reward_id:
		0:
			var helmet := PackedVector2Array([
				Vector2(-29, -29), Vector2(29, -29), Vector2(29, 7),
				Vector2(19, 7), Vector2(19, -19), Vector2(-19, -19),
				Vector2(-19, 7), Vector2(-29, 7),
			])
			_draw_rectilinear_shape(canvas, helmet, center, icon_scale, GEL_COLOR, OUTLINE)
			canvas.draw_rect(Rect2(center + Vector2(-18, -27) * icon_scale, Vector2(36, 3) * icon_scale), Color("#B0FFE280"), true)
		1:
			var size := Vector2.ONE * 64.0 * icon_scale
			canvas.draw_texture_rect(CORE_TEXTURE, Rect2(center - size * 0.5, size), false)
		2:
			for glove_position in [Vector2(-38, 5), Vector2(12, 5)]:
				var glove := PackedVector2Array([
					glove_position, glove_position + Vector2(28, 0),
					glove_position + Vector2(28, 28), glove_position + Vector2(0, 28),
				])
				_draw_rectilinear_shape(canvas, glove, center, icon_scale, GEL_COLOR, OUTLINE)
				canvas.draw_rect(Rect2(center + (glove_position + Vector2(6, 5)) * icon_scale, Vector2(10, 5) * icon_scale), Color("#B0FFE280"), true)
		3:
			var tissue := PackedVector2Array([
				Vector2(-42, -23), Vector2(-30, -23), Vector2(-30, -38), Vector2(-7, -38),
				Vector2(-7, -30), Vector2(20, -30), Vector2(20, -18), Vector2(41, -18),
				Vector2(41, 9), Vector2(29, 9), Vector2(29, 31), Vector2(5, 31),
				Vector2(5, 41), Vector2(-25, 41), Vector2(-25, 30), Vector2(-42, 30),
			])
			_draw_rectilinear_shape(canvas, tissue, center, icon_scale, GEL_COLOR, OUTLINE)
			canvas.draw_rect(Rect2(center + Vector2(-30, -16) * icon_scale, Vector2(18, 17) * icon_scale), DARK_GEL, true)
			canvas.draw_rect(Rect2(center + Vector2(9, 8) * icon_scale, Vector2(15, 17) * icon_scale), DARK_GEL, true)
		4:
			_draw_gel_bar(canvas, center, icon_scale, Rect2(-40, -26, 80, 12))
			_draw_gel_bar(canvas, center, icon_scale, Rect2(-40, 14, 80, 12))
			_draw_gel_bar(canvas, center, icon_scale, Rect2(-40, -26, 12, 52))
			_draw_gel_bar(canvas, center, icon_scale, Rect2(28, -26, 12, 52))
			canvas.draw_rect(Rect2(center + Vector2(-6, 14) * icon_scale, Vector2(12, 12) * icon_scale), DARK_GEL, true)
			canvas.draw_rect(Rect2(center + Vector2(-6, 14) * icon_scale, Vector2(12, 12) * icon_scale), OUTLINE, false, maxf(1.0, 1.5 * icon_scale))

static func scale_to_fit(reward_id: int, maximum_size: float) -> float:
	var native_size := Vector2(64.0, 64.0)
	match reward_id:
		0:
			native_size = Vector2(58.0, 36.0)
		2:
			native_size = Vector2(78.0, 33.0)
		3:
			native_size = Vector2(83.0, 79.0)
		4:
			native_size = Vector2(80.0, 50.0)
	return minf(maximum_size / native_size.x, maximum_size / native_size.y)
static func _draw_gel_bar(canvas: CanvasItem, center: Vector2, icon_scale: float, rect: Rect2) -> void:
	var scaled_rect := Rect2(center + rect.position * icon_scale, rect.size * icon_scale)
	canvas.draw_rect(scaled_rect, GEL_COLOR, true)
	canvas.draw_rect(scaled_rect, OUTLINE, false, maxf(1.0, 1.2 * icon_scale))
static func _draw_rectilinear_shape(
	canvas: CanvasItem,
	points: PackedVector2Array,
	center: Vector2,
	icon_scale: float,
	fill_color: Color,
	outline_color: Color
) -> void:
	var scaled_points := PackedVector2Array()
	for point in points:
		scaled_points.append(center + point * icon_scale)
	canvas.draw_colored_polygon(scaled_points, fill_color)
	var closed_outline := scaled_points.duplicate()
	closed_outline.append(scaled_points[0])
	# A single closed polyline preserves square corners without seam gaps.
	canvas.draw_polyline(closed_outline, outline_color, maxf(1.0, 2.0 * icon_scale), false)