class_name SpearWeapon
extends Node2D

signal throw_released(direction: Vector2)

const SHAFT_LENGTH := 96.0
const SHAFT_WIDTH := 8.0
const HEAD_LENGTH := 22.0
const MOUNT_OFFSET := 24.0
const TOTAL_LENGTH := SHAFT_LENGTH + HEAD_LENGTH
const RETRACT_DISTANCE := TOTAL_LENGTH * 0.5
const RETRACT_DURATION := 0.2
const SHAFT_COLOR := Color.WHITE
const NORMAL_HEAD_COLOR := Color.WHITE
const FIRE_HEAD_COLOR := Color("#FF9B35")
const KILLER_HEAD_COLOR := Color("#321047")

@export var border_color := Color("#1A64B5")
@export var fire_variant := false:
	set(value):
		fire_variant = value
		queue_redraw()
@export var killer_variant := false:
	set(value):
		killer_variant = value
		queue_redraw()

var _aim_direction := Vector2.RIGHT
var _flame_time := 0.0
var _throwing := false
var _retract_elapsed := 0.0


func _process(delta: float) -> void:
	_flame_time += delta
	if _throwing:
		_retract_elapsed += delta
		var retract_ratio := minf(_retract_elapsed / RETRACT_DURATION, 1.0)
		position = -_aim_direction * (RETRACT_DISTANCE * retract_ratio)
		if retract_ratio >= 1.0:
			_release_throw()
	if fire_variant:
		queue_redraw()


func set_aim_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	_aim_direction = direction.normalized()
	visible = true
	# The spear geometry stays centered on its owner while facing the aim direction.
	rotation = _aim_direction.angle()
	if not _throwing:
		position = Vector2.ZERO


func begin_throw(direction: Vector2) -> bool:
	if _throwing or direction.is_zero_approx():
		return false
	_throwing = true
	_aim_direction = direction.normalized()
	visible = true
	position = Vector2.ZERO
	rotation = _aim_direction.angle()
	_retract_elapsed = 0.0
	return true


func is_retracting() -> bool:
	return _throwing and visible


func restore_to_hand(direction: Vector2) -> void:
	_throwing = false
	_retract_elapsed = 0.0
	set_aim_direction(direction)



func cancel_throw() -> void:
	_throwing = false
	_retract_elapsed = 0.0
	position = Vector2.ZERO
	visible = false
func _release_throw() -> void:
	visible = false
	_throwing = false
	_retract_elapsed = 0.0
	emit_signal("throw_released", _aim_direction)


func _draw() -> void:
	# Draw around the owner node, rather than extending from it.
	draw_set_transform(Vector2(-TOTAL_LENGTH * 0.5, 0.0))
	var shaft_rect := Rect2(0.0, -SHAFT_WIDTH * 0.5, SHAFT_LENGTH, SHAFT_WIDTH)
	draw_rect(shaft_rect, border_color, true, -1.0, false)
	draw_rect(shaft_rect.grow(-2.0), SHAFT_COLOR, true, -1.0, false)
	var head_color := KILLER_HEAD_COLOR if killer_variant else (FIRE_HEAD_COLOR if fire_variant else NORMAL_HEAD_COLOR)
	# The head is a real four-sided trapezoid whose broad base meets the shaft end.
	var head_points := PackedVector2Array([
		Vector2(SHAFT_LENGTH - 2.0, -8.0), Vector2(SHAFT_LENGTH + HEAD_LENGTH, -4.0),
		Vector2(SHAFT_LENGTH + HEAD_LENGTH, 4.0), Vector2(SHAFT_LENGTH - 2.0, 8.0),
	])
	draw_colored_polygon(head_points, border_color)
	var inner_points := PackedVector2Array([
		Vector2(SHAFT_LENGTH + 1.0, -6.0), Vector2(SHAFT_LENGTH + HEAD_LENGTH - 2.0, -2.0),
		Vector2(SHAFT_LENGTH + HEAD_LENGTH - 2.0, 2.0), Vector2(SHAFT_LENGTH + 1.0, 6.0),
	])
	draw_colored_polygon(inner_points, head_color)
	if fire_variant:
		_draw_head_flames()
	draw_set_transform(Vector2.ZERO)


func _draw_head_flames() -> void:
	for index in range(7):
		var phase := _flame_time * 4.0 + float(index) * 1.73
		var x := SHAFT_LENGTH + 4.0 + fposmod(sin(phase * 1.37) * 13.0, 17.0)
		var y := sin(phase * 2.11) * 8.0
		var size := 3.0 + float(index % 2) * 2.0
		var color := Color("#FF5A27") if index % 2 == 0 else Color("#FFCC4D")
		draw_rect(Rect2(x, y - size * 0.5, size, size), color, true, -1.0, false)