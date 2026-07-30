class_name PlayerShadowRenderer
extends Node2D

const PLAYER_SIZE := 48.0
const SHADOW_SIZE := Vector2(56.0, 12.0)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.24)

@export var player_path: NodePath

@onready var player: CharacterBody2D = get_node(player_path)

var spawn_scale := 1.0:
	set(value):
		spawn_scale = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(player):
		return

	var bottom_center := player.position + Vector2(0.0, PLAYER_SIZE * 0.5 - 3.0)
	var current_size := SHADOW_SIZE * spawn_scale
	draw_rect(
		Rect2(bottom_center - current_size * 0.5, current_size),
		SHADOW_COLOR,
		true,
		-1.0,
		false
	)
