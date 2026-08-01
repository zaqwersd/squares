class_name HealthPickup
extends Area2D

const HEAL_AMOUNT := 10
const RED_COLOR := Color("#EF4D5B")
const OUTLINE_COLOR := Color.BLACK
const ATTRACTION_CONSTANT := 1050000.0

var _attraction_velocity := Vector2.ZERO


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	var island_map := get_parent() as IslandMap
	var player := island_map.player if island_map != null else null
	if is_instance_valid(player):
		var offset := player.global_position - global_position
		var distance_squared := maxf(offset.length_squared(), 64.0)
		var direction := island_map.get_experience_navigation_direction(global_position)
		if offset.length_squared() < 64.0 * 64.0:
			direction = offset.normalized()
		if not direction.is_zero_approx():
			var attraction := minf(1800.0, ATTRACTION_CONSTANT / distance_squared)
			_attraction_velocity += direction * attraction * delta
			_attraction_velocity = _attraction_velocity.limit_length(300.0)
	position += _attraction_velocity * delta
	_attraction_velocity = _attraction_velocity.move_toward(Vector2.ZERO, 170.0 * delta)


func _draw() -> void:
	const HEART_SCALE := 8.0
	var heart := PackedVector2Array([
		Vector2(0, 0), Vector2(1, 1), Vector2(2, 0), Vector2(0, -2),
		Vector2(-2, 0), Vector2(-1, 1),
	])
	for index in heart.size():
		var point := heart[index] * HEART_SCALE
		point.y = -point.y
		heart[index] = point
	var outline := heart.duplicate()
	outline.append(heart[0])
	# Integer-aligned vector geometry with anti-aliasing explicitly disabled.
	draw_colored_polygon(heart, RED_COLOR)
	draw_polyline(outline, OUTLINE_COLOR, 3.0, false)


func _on_body_entered(body: Node2D) -> void:
	if body is IslandPlayer:
		body.heal(HEAL_AMOUNT)
		set_deferred("monitoring", false)
		queue_free()
