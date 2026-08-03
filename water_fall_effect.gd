class_name WaterFallEffect
extends Node2D

const DURATION := 2.0
const WAVE_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const WATER_COLOR := Color("#7DDEFAAA")

var _elapsed := 0.0
var _seed := 0


func configure(seed_value := 0) -> void:
	_seed = seed_value


func _ready() -> void:
	z_index = 12
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_elapsed / DURATION, 0.0, 1.0)
	var wave_size := lerpf(68.0, 18.0, smoothstep(0.0, 1.0, progress))
	var alpha := smoothstep(1.0, 0.0, progress)
	var wave := WAVE_COLOR
	wave.a *= alpha
	draw_rect(Rect2(Vector2.ONE * -wave_size * 0.5, Vector2.ONE * wave_size), wave, false, 3.0)
	var fill := WATER_COLOR
	fill.a *= alpha * 0.5
	draw_rect(Rect2(Vector2.ONE * -wave_size * 0.38, Vector2.ONE * wave_size * 0.76), fill, true)
	for index in range(10):
		var angle := TAU * float(index) / 10.0 + float((_seed + index * 17) % 11) * 0.04
		var direction := Vector2.from_angle(angle)
		var distance := lerpf(42.0 + float(index % 3) * 4.0, 10.0, progress)
		var size := lerpf(5.0, 1.5, progress)
		var particle_alpha := alpha * (0.65 + float(index % 2) * 0.25)
		draw_rect(Rect2(direction * distance - Vector2.ONE * size * 0.5, Vector2.ONE * size), Color(1.0, 1.0, 1.0, particle_alpha), true)