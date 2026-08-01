@tool
class_name RockWeapon
extends Node2D

const PROJECTILE_SIZE := 16.0
const BORDER_WIDTH := 2.0
const BORDER_COLOR := Color("#1A64B5FF")
const FILL_COLOR := Color("#B0D1E7")
const MOUNT_OFFSET := 44.0


func set_aim_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		visible = false
		return
	visible = true
	position = direction.normalized() * MOUNT_OFFSET
	rotation = direction.angle()


func _draw() -> void:
	var half := PROJECTILE_SIZE * 0.5
	draw_rect(
		Rect2(Vector2(-half, -half), Vector2.ONE * PROJECTILE_SIZE),
		BORDER_COLOR,
		true
	)
	var inner_size := PROJECTILE_SIZE - BORDER_WIDTH * 2.0
	draw_rect(
		Rect2(Vector2.ONE * -inner_size * 0.5, Vector2.ONE * inner_size),
		FILL_COLOR,
		true
	)
