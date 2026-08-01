class_name ExperiencePickup
extends Area2D

const OUTLINE_COLOR := Color.BLACK
const BLUE_COLOR := Color("#36A8F4")
const GREEN_COLOR := Color("#45D99A")
const PICKUP_SIZE := 8.0

var experience_value := 1
var _velocity := Vector2.ZERO
var _pulse_time := 0.0
var _attraction_velocity := Vector2.ZERO
var _burst_remaining := 0.18


func configure(value: int, launch_velocity: Vector2) -> void:
	experience_value = maxi(1, value)
	scale = Vector2.ONE * (2.0 if experience_value >= 5 else 1.0)
	_velocity = launch_velocity
	_burst_remaining = 0.18


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	var island_map := get_parent() as IslandMap
	var player := island_map.player if island_map != null else null
	_burst_remaining = maxf(0.0, _burst_remaining - delta)
	if _burst_remaining <= 0.0 and is_instance_valid(player):
		var offset := player.global_position - global_position
		var distance_squared := maxf(offset.length_squared(), 64.0)
		var direction := island_map.get_experience_navigation_direction(global_position)
		if offset.length_squared() < 64.0 * 64.0:
			direction = offset.normalized()
		if not direction.is_zero_approx():
			var attraction := minf(1800.0, 1050000.0 / distance_squared)
			_attraction_velocity += direction * attraction * delta
			_attraction_velocity = _attraction_velocity.limit_length(300.0)
	position += (_velocity + _attraction_velocity) * delta
	_velocity = _velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	_attraction_velocity = _attraction_velocity.move_toward(Vector2.ZERO, 170.0 * delta)
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + sin(_pulse_time * TAU * 1.5) * 0.5
	var inner_color := BLUE_COLOR.lerp(GREEN_COLOR, pulse)
	var outer_rect := Rect2(Vector2.ONE * -PICKUP_SIZE * 0.5, Vector2.ONE * PICKUP_SIZE)
	draw_rect(outer_rect, OUTLINE_COLOR, true)
	draw_rect(outer_rect.grow(-2.0), inner_color, true)


func _on_body_entered(body: Node2D) -> void:
	if body is IslandPlayer:
		body.add_experience(experience_value)
		set_deferred("monitoring", false)
		queue_free()
