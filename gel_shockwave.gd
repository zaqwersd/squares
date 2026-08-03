class_name GelShockwave
extends Node2D

const DURATION := 0.42
const GEL_COLOR := Color("#35F3C5A8")

var _source: Node2D
var _damage := 13
var _start_size := 64.0
var _end_size := 192.0
var _elapsed := 0.0
var _hit_targets: Dictionary = {}


func configure(source: Node2D, damage: int, start_size := 64.0, end_size := 192.0) -> void:
	_source = source
	_damage = damage
	_start_size = start_size
	_end_size = end_size


func _ready() -> void:
	z_index = 11
	queue_redraw()


func _process(delta: float) -> void:
	if not is_instance_valid(_source):
		queue_free()
		return
	global_position = _source.global_position
	_elapsed += delta
	_apply_damage()
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _apply_damage() -> void:
	var progress := clampf(_elapsed / DURATION, 0.0, 1.0)
	var half_extent := lerpf(_start_size, _end_size, progress) * 0.5
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or candidate == _source or _hit_targets.has(candidate):
			continue
		if not candidate.has_method("take_damage"):
			continue
		var offset: Vector2 = candidate.global_position - global_position
		if absf(offset.x) <= half_extent and absf(offset.y) <= half_extent:
			_hit_targets[candidate] = true
			candidate.call("take_damage", _damage)


func _draw() -> void:
	var progress := clampf(_elapsed / DURATION, 0.0, 1.0)
	var wave_size := lerpf(_start_size, _end_size, progress)
	var wave_color := Color.WHITE
	wave_color.a = lerpf(1.0, 0.45, progress)
	draw_rect(Rect2(Vector2.ONE * -wave_size * 0.5, Vector2.ONE * wave_size), wave_color, false, 8.0)
	var gel := GEL_COLOR
	gel.a = lerpf(0.32, 0.0, progress)
	draw_rect(Rect2(Vector2.ONE * -wave_size * 0.5 + Vector2(4.0, 4.0), Vector2.ONE * (wave_size - 8.0)), gel, false, 3.0)
