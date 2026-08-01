extends Node2D

const START_SCALE := 0.35
const END_SCALE := 2.0
const DURATION := 0.16


func play(direction: Vector2, origin_distance: float) -> void:
	position = direction * origin_distance
	rotation = direction.angle()
	scale = Vector2.ONE * START_SCALE
	modulate = Color.WHITE
	visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * END_SCALE, DURATION)
	tween.parallel().tween_property(self, "modulate:a", 0.0, DURATION)
	tween.tween_callback(func() -> void: visible = false)


func _draw() -> void:
	draw_rect(Rect2(-4.0, -13.0, 8.0, 26.0), Color.WHITE, true)
	draw_rect(Rect2(-13.0, -4.0, 26.0, 8.0), Color.WHITE, true)
