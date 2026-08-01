class_name SlimeLandingEffect
extends Node2D

const DURATION := 0.26
const GEL_SPLASH_COLOR := Color("#4CB77A")
const START_HALF_EXTENT := 16.0
const END_HALF_EXTENT := 32.0

var _progress := 0.0
var _target: IslandPlayer
var _damage := 0
var _has_damaged := false


func configure(target: IslandPlayer, damage: int) -> void:
	_target = target
	_damage = damage


func _ready() -> void:
	_apply_wave_damage()
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, DURATION)
	tween.tween_callback(queue_free)
	queue_redraw()


func _set_progress(value: float) -> void:
	_progress = value
	_apply_wave_damage()
	queue_redraw()


func _apply_wave_damage() -> void:
	if _has_damaged or _damage <= 0 or not is_instance_valid(_target):
		return
	var half_extent := lerpf(START_HALF_EXTENT, END_HALF_EXTENT, _progress)
	var offset := _target.global_position - global_position
	if absf(offset.x) <= half_extent and absf(offset.y) <= half_extent:
		_has_damaged = true
		_target.take_damage(_damage)


func _draw() -> void:
	var wave_size := lerpf(START_HALF_EXTENT * 2.0, END_HALF_EXTENT * 2.0, _progress)
	var wave_color := Color.WHITE
	wave_color.a = lerpf(1.0, 0.5, _progress)
	draw_rect(Rect2(Vector2.ONE * -wave_size * 0.5, Vector2.ONE * wave_size), wave_color, false, 4.0)

	var splash_color := GEL_SPLASH_COLOR
	splash_color.a = 1.0 - _progress
	for index in range(6):
		var direction := Vector2.from_angle(TAU * float(index) / 6.0 + 0.2)
		var distance := lerpf(8.0, 30.0, _progress)
		var size := lerpf(5.0, 2.0, _progress)
		var center := direction * distance + Vector2(0.0, _progress * _progress * 12.0)
		draw_rect(Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), splash_color, true)
