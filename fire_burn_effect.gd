class_name FireBurnEffect
extends Node2D

const DURATION := 3.0
const TICK_INTERVAL := 1.0

var _remaining := DURATION
var _tick_remaining := TICK_INTERVAL
var _damage := 5
var _time := 0.0
var _target_visual: CanvasItem
var _base_modulate := Color.WHITE


func configure(damage: int = 5, duration: float = DURATION) -> void:
	_damage = damage
	_remaining = duration
	_tick_remaining = TICK_INTERVAL


func refresh(damage: int = 5, duration: float = DURATION) -> void:
	_damage = maxi(_damage, damage)
	_remaining = maxf(_remaining, duration)
	_tick_remaining = TICK_INTERVAL


func _ready() -> void:
	z_index = 12
	_target_visual = get_parent().get_node_or_null("Visual") as CanvasItem
	if _target_visual != null:
		_base_modulate = _target_visual.modulate
		_target_visual.modulate = Color(1.0, 0.42, 0.08, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_remaining -= delta
	_tick_remaining -= delta
	_time += delta
	if _target_visual != null:
		_target_visual.modulate = Color(1.0, 0.42, 0.08, 1.0)
	if _tick_remaining <= 0.0:
		_tick_remaining += TICK_INTERVAL
		var target := get_parent()
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.call("take_damage", _damage)
	if _remaining <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# The target sprite itself carries the orange tint; only flames are drawn here.
	for index in range(6):
		var phase := _time * 5.0 + float(index) * 2.19
		var x := sin(phase * 1.31) * 19.0
		var y := 18.0 - fposmod(phase * 8.0 + float(index) * 5.0, 36.0)
		var size := 3.0 + float(index % 3)
		var color := Color("#FF692D") if index % 2 == 0 else Color("#FFC13D")
		draw_rect(Rect2(x - size * 0.5, y - size * 0.5, size, size), color, true, -1.0, false)
func _exit_tree() -> void:
	if _target_visual == null:
		return
	var target := get_parent()
	if is_instance_valid(target) and target.has_method("_update_health_tint"):
		target.call("_update_health_tint")
	else:
		_target_visual.modulate = _base_modulate