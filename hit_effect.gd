class_name ProjectileHitEffect
extends Node2D

var shard_directions := [
	Vector2.RIGHT,
	Vector2(1, 1).normalized(),
	Vector2.DOWN,
	Vector2(-1, 1).normalized(),
	Vector2.LEFT,
	Vector2(-1, -1).normalized(),
	Vector2.UP,
	Vector2(1, -1).normalized(),
]

var color := Color("#1A64B5FF")
var _progress := 0.0


func configure(new_color: Color) -> void:
	color = new_color


func _ready() -> void:
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, 0.22)
	tween.tween_callback(queue_free)
	queue_redraw()


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _progress
	var ring_size := lerpf(12.0, 54.0, _progress)
	var ring_color := color
	ring_color.a *= fade
	draw_rect(
		Rect2(Vector2.ONE * -ring_size * 0.5, Vector2.ONE * ring_size),
		ring_color,
		false,
		3.0,
		false
	)

	var shard_size := lerpf(8.0, 4.0, _progress)
	for direction in shard_directions:
		var distance := lerpf(12.0, 38.0, _progress)
		var shard_center: Vector2 = direction * distance
		draw_rect(
			Rect2(Vector2.ONE * -shard_size * 0.5 + shard_center, Vector2.ONE * shard_size),
			ring_color,
			true,
			-1.0,
			false
		)
