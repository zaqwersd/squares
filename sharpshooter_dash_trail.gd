extends Node2D

const LIFETIME := 0.22

var _remaining := LIFETIME
var _length := 128.0
var _half_width := 17.0

func configure(travel_direction: Vector2, length := 128.0, width := 34.0) -> void:
	rotation = travel_direction.angle()
	_length = length
	_half_width = width * 0.5

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	_remaining -= delta
	modulate.a = clampf(_remaining / LIFETIME, 0.0, 1.0)
	if _remaining <= 0.0:
		queue_free()

func _draw() -> void:
	# The near end stays at the dasher's center while the far end retracts toward it.
	var retract_ratio := clampf(_remaining / LIFETIME, 0.0, 1.0)
	var visible_length := _length * retract_ratio
	var points := PackedVector2Array([
		Vector2(-visible_length, -_half_width), Vector2(-visible_length, _half_width),
		Vector2.ZERO + Vector2(0.0, _half_width * 0.30), Vector2.ZERO + Vector2(0.0, -_half_width * 0.30),
	])
	var colors := PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.62), Color(1.0, 1.0, 1.0, 0.62),
	])
	draw_polygon(points, colors)
