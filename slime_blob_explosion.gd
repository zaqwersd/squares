class_name SlimeBlobExplosion
extends Node2D

const DURATION := 0.20
const GEL_COLOR := Color("#35F3C5A8")

var _source: Node2D
var _friendly := false
var _damage := 0
var _impact_size := 64.0
var _elapsed := 0.0
var _hit_targets: Dictionary = {}


func configure(source: Node2D, is_friendly: bool, damage: int, impact_size: float) -> void:
	_source = source
	_friendly = is_friendly
	_damage = damage
	_impact_size = impact_size


func _ready() -> void:
	z_index = 11
	_apply_damage()
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	_apply_damage()
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _apply_damage() -> void:
	var half_extent := _impact_size * 0.5
	var candidates: Array = get_tree().get_nodes_in_group("enemies") if _friendly else [get_tree().get_first_node_in_group("player")]
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate == _source or _hit_targets.has(candidate):
			continue
		if not candidate.has_method("take_damage"):
			continue
		if _square_overlaps_target(candidate as Node2D, half_extent):
			_hit_targets[candidate] = true
			candidate.call("take_damage", _damage)


func _square_overlaps_target(target: Node2D, half_extent: float) -> bool:
	var target_half_extent := Vector2(24.0, 24.0)
	var collision_shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		var rectangle := collision_shape.shape as RectangleShape2D
		target_half_extent = rectangle.size * 0.5
	var offset := target.global_position - global_position
	return absf(offset.x) <= half_extent + target_half_extent.x and absf(offset.y) <= half_extent + target_half_extent.y


func _draw() -> void:
	var progress := clampf(_elapsed / DURATION, 0.0, 1.0)
	var draw_size := lerpf(_impact_size * 0.42, _impact_size, progress)
	var flash_alpha := clampf(1.0 - progress * 4.5, 0.0, 1.0)
	if flash_alpha > 0.0:
		draw_rect(Rect2(Vector2.ONE * -draw_size * 0.62, Vector2.ONE * draw_size * 1.24), Color(1.0, 1.0, 1.0, flash_alpha), true)
	var color := GEL_COLOR
	color.a = lerpf(0.72, 0.0, progress)
	draw_rect(Rect2(Vector2.ONE * -draw_size * 0.5, Vector2.ONE * draw_size), color, true)
	var outline := Color.WHITE
	outline.a = lerpf(0.85, 0.0, progress)
	draw_rect(Rect2(Vector2.ONE * -draw_size * 0.5, Vector2.ONE * draw_size), outline, false, 2.0)
