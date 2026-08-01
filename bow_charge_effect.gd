class_name BowChargeEffect
extends Node2D

const PARTICLE_COUNT := 12
const COMPLETE_FLASH_DURATION := 0.12

var _charge_progress := 0.0
var _complete_flash_remaining := 0.0
var _animation_time := 0.0


func show_charge(direction: Vector2, origin_distance: float, progress: float) -> void:
	position = direction * origin_distance
	rotation = direction.angle()
	_charge_progress = clampf(progress, 0.0, 1.0)
	_complete_flash_remaining = 0.0
	visible = true
	queue_redraw()


func complete_charge(direction: Vector2, origin_distance: float) -> void:
	position = direction * origin_distance
	rotation = direction.angle()
	_charge_progress = 1.0
	_complete_flash_remaining = COMPLETE_FLASH_DURATION
	visible = true
	queue_redraw()


func clear() -> void:
	_charge_progress = 0.0
	_complete_flash_remaining = 0.0
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_animation_time += delta
	if _complete_flash_remaining > 0.0:
		_complete_flash_remaining = maxf(0.0, _complete_flash_remaining - delta)
		if _complete_flash_remaining <= 0.0:
			visible = false
	queue_redraw()


func _draw() -> void:
	if _complete_flash_remaining > 0.0:
		var flash_ratio: float = _complete_flash_remaining / COMPLETE_FLASH_DURATION
		var flash_size: float = lerpf(6.0, 28.0, flash_ratio)
		var flash_color := Color(1.0, 1.0, 1.0, flash_ratio)
		draw_rect(Rect2(-flash_size * 0.5, -3.0, flash_size, 6.0), flash_color, true)
		draw_rect(Rect2(-3.0, -flash_size * 0.5, 6.0, flash_size), flash_color, true)
		return

	var approach: float = smoothstep(0.0, 1.0, _charge_progress)
	for index in range(PARTICLE_COUNT):
		var normalized_index: float = float(index) / float(PARTICLE_COUNT)
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var travel_progress: float = fposmod(_animation_time * 1.45 + normalized_index, 1.0)
		var arrow_contact := Vector2(
			lerpf(2.0, 30.0, fposmod(normalized_index * 2.7, 1.0)),
			side * 4.0
		)
		var outer_position := arrow_contact + Vector2(
			-14.0 - float(index % 4) * 4.0,
			side * (20.0 + float(index % 3) * 6.0)
		)
		var particle_position := outer_position.lerp(arrow_contact, smoothstep(0.0, 1.0, travel_progress))
		var fade_out := 1.0 - smoothstep(0.72, 1.0, travel_progress)
		var particle_size: float = 3.0 + float(index % 3)
		var particle_alpha: float = (0.28 + approach * 0.55) * fade_out
		draw_rect(
			Rect2(particle_position - Vector2.ONE * particle_size * 0.5, Vector2.ONE * particle_size),
			Color(1.0, 1.0, 1.0, particle_alpha),
			true
		)