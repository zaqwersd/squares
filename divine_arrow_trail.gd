extends Node2D

const LIFETIME := 0.18

var _remaining := LIFETIME


func configure(travel_direction: Vector2) -> void:
	rotation = travel_direction.angle()


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_remaining -= delta
	modulate.a = clampf(_remaining / LIFETIME, 0.0, 1.0)
	if _remaining <= 0.0:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-26.0, -3.0, 26.0, 6.0), Color(1.0, 1.0, 1.0, 0.38), true, -1.0, false)
	draw_rect(Rect2(-15.0, -1.0, 15.0, 2.0), Color(1.0, 1.0, 1.0, 0.82), true, -1.0, false)