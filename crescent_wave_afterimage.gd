extends Node2D

const LIFETIME := 0.18
const OUTER_CENTER := Vector2(-112.0, 0.0)
const OUTER_RADIUS := 112.0
const INNER_CENTER := Vector2(-108.0, 0.0)
const INNER_RADIUS := 102.0
const HALF_ARC_ANGLE := 0.46

var _remaining := LIFETIME

func configure(travel_direction: Vector2, _faction: Color) -> void:
	rotation = travel_direction.angle()

func _process(delta: float) -> void:
	_remaining -= delta
	modulate.a = clampf(_remaining / LIFETIME, 0.0, 1.0) * 0.28
	if _remaining <= 0.0:
		queue_free()

func _draw() -> void:
	var polygon := PackedVector2Array()
	for index in range(19):
		var ratio := float(index) / 18.0
		var angle := lerpf(-HALF_ARC_ANGLE, HALF_ARC_ANGLE, ratio)
		polygon.append(OUTER_CENTER + Vector2.from_angle(angle) * OUTER_RADIUS)
	for index in range(18, -1, -1):
		var ratio := float(index) / 18.0
		var angle := lerpf(-HALF_ARC_ANGLE, HALF_ARC_ANGLE, ratio)
		polygon.append(INNER_CENTER + Vector2.from_angle(angle) * INNER_RADIUS)
	draw_colored_polygon(polygon, Color.WHITE)