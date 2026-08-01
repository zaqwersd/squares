extends Node2D

const LIFETIME := 0.24

var _remaining := LIFETIME


func configure(dash_direction: Vector2) -> void:
	rotation = dash_direction.angle()


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_remaining -= delta
	modulate.a = clampf(_remaining / LIFETIME, 0.0, 1.0) * 0.52
	if _remaining <= 0.0:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-74.0, -17.0, 74.0, 34.0), Color(1.0, 1.0, 1.0, 0.16), true, -1.0, false)
	draw_rect(Rect2(-58.0, -11.0, 58.0, 22.0), Color(1.0, 1.0, 1.0, 0.32), true, -1.0, false)
	draw_rect(Rect2(-42.0, -6.0, 42.0, 12.0), Color(1.0, 1.0, 1.0, 0.65), true, -1.0, false)