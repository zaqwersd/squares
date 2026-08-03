class_name GelHatVisual
extends Node2D

func _ready() -> void:
	position = Vector2.ZERO
	z_index = 6
	queue_redraw()

func _draw() -> void:
	# Reuse the reward icon path so the card preview and equipped helmet stay identical.
	AutoRewardIcon.draw_on(self, 0, Vector2.ZERO, 1.0)