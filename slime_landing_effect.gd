class_name SlimeLandingEffect
extends Node2D

const DURATION := 0.26
const GEL_SPLASH_COLOR := Color("#4CB77A")
const START_HALF_EXTENT := 16.0
const END_HALF_EXTENT := 32.0

var _progress := 0.0
var _elapsed := 0.0
var _target: Node2D
var _start_damage := 0
var _end_damage := 0
var _has_damaged := false
var _start_half_extent := START_HALF_EXTENT
var _end_half_extent := END_HALF_EXTENT
var _friendly := false
var _hit_targets: Dictionary = {}


func configure(target: Node2D, start_damage: int, start_half_extent: float = START_HALF_EXTENT, end_half_extent: float = END_HALF_EXTENT, end_damage := -1, friendly := false) -> void:
	_target = target
	_start_damage = start_damage
	_end_damage = start_damage if end_damage < 0 else end_damage
	_start_half_extent = start_half_extent
	_end_half_extent = end_half_extent
	_friendly = friendly


func _ready() -> void:
	z_index = 7
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	_progress = clampf(_elapsed / DURATION, 0.0, 1.0)
	_apply_wave_damage()
	if _progress >= 1.0:
		queue_free()
		return
	queue_redraw()


func _apply_wave_damage() -> void:
	if _start_damage <= 0:
		return
	var half_extent := lerpf(_start_half_extent, _end_half_extent, _progress)
	var impact_damage := roundi(lerpf(float(_start_damage), float(_end_damage), _progress))
	if _friendly:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var enemy_node := enemy as Node2D
			if not is_instance_valid(enemy_node) or _hit_targets.has(enemy_node) or not enemy_node.has_method("take_damage"):
				continue
			if _square_overlaps_target(enemy_node, half_extent):
				_hit_targets[enemy_node] = true
				enemy_node.call("take_damage", impact_damage)
		return
	if _has_damaged:
		return
	var candidates: Array[Node] = [get_tree().get_first_node_in_group("player")]
	candidates.append_array(get_tree().get_nodes_in_group("player_allies"))
	for candidate in candidates:
		var target_node := candidate as Node2D
		if not is_instance_valid(target_node) or not target_node.has_method("take_damage"):
			continue
		if _square_overlaps_target(target_node, half_extent):
			_has_damaged = true
			target_node.call("take_damage", impact_damage)
			return


func _square_overlaps_target(target_node: Node2D, half_extent: float) -> bool:
	var target_half_extent := Vector2(24.0, 24.0)
	var collision_shape := target_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		target_half_extent = (collision_shape.shape as RectangleShape2D).size * 0.5
	var offset := target_node.global_position - global_position
	return absf(offset.x) <= half_extent + target_half_extent.x and absf(offset.y) <= half_extent + target_half_extent.y


func _draw() -> void:
	var wave_size := lerpf(_start_half_extent * 2.0, _end_half_extent * 2.0, _progress)
	var wave_color := Color.WHITE
	wave_color.a = lerpf(1.0, 0.5, _progress)
	draw_rect(Rect2(Vector2.ONE * -wave_size * 0.5, Vector2.ONE * wave_size), wave_color, false, 8.0)
	var splash_color := GEL_SPLASH_COLOR
	splash_color.a = 1.0 - _progress
	for index in range(6):
		var direction := Vector2.from_angle(TAU * float(index) / 6.0 + 0.2)
		var distance := lerpf(8.0, 30.0, _progress)
		var particle_size := lerpf(5.0, 2.0, _progress)
		var center := direction * distance + Vector2(0.0, _progress * _progress * 12.0)
		draw_rect(Rect2(center - Vector2.ONE * particle_size * 0.5, Vector2.ONE * particle_size), splash_color, true)