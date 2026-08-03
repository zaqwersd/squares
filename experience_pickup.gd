class_name ExperiencePickup
extends Area2D

const OUTLINE_COLOR := Color.BLACK
const BLUE_COLOR := Color("#36A8F4")
const GREEN_COLOR := Color("#45D99A")
const PICKUP_SIZE := 9.6
const GOLD_COLOR := Color("#FFD34D")
const ORANGE_COLOR := Color("#FF9F38")

var experience_value := 1
var _velocity := Vector2.ZERO
var _pulse_time := 0.0
var _attraction_velocity := Vector2.ZERO
var _burst_remaining := 0.18
var _redraw_elapsed := 0.0


func configure(value: int, launch_velocity: Vector2) -> void:
	experience_value = maxi(1, value)
	# 1 and 10 share the small size; 5 and 50 share the large size.
	scale = Vector2.ONE * (2.0 if experience_value == 5 or experience_value >= 50 else 1.0)
	_velocity = launch_velocity
	_burst_remaining = 0.18


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	_redraw_elapsed += delta
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
	if _redraw_elapsed >= 1.0 / 12.0:
		_redraw_elapsed = 0.0
		queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + sin(_pulse_time * TAU * 1.5) * 0.5
	var inner_color := (GOLD_COLOR.lerp(ORANGE_COLOR, pulse) if experience_value >= 10 else BLUE_COLOR.lerp(GREEN_COLOR, pulse))
	var outer_rect := Rect2(Vector2.ONE * -PICKUP_SIZE * 0.5, Vector2.ONE * PICKUP_SIZE)
	draw_rect(outer_rect, OUTLINE_COLOR, true)
	draw_rect(outer_rect.grow(-2.0), inner_color, true)


func _on_body_entered(body: Node2D) -> void:
	if body is IslandPlayer:
		body.add_experience(experience_value)
		set_deferred("monitoring", false)
		queue_free()
