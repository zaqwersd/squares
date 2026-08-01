class_name DamageNumber
extends Node2D

const FLOAT_DISTANCE := 30.0
const LIFETIME := 0.46

@onready var label: Label = $Label

var _amount := 0
var _text_color := Color.WHITE
var _prefix := ""


func configure(amount: int, text_color: Color, prefix := "") -> void:
	_amount = amount
	_text_color = text_color
	_prefix = prefix
	if is_node_ready():
		_apply_text()


func _ready() -> void:
	_apply_text()
	label.modulate.a = 0.0
	label.scale = Vector2.ONE * 0.68
	# Call deferred so the spawner can assign our world position before tweening.
	call_deferred("_play_animation")


func _play_animation() -> void:
	var start_position := global_position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.06)
	tween.parallel().tween_property(label, "scale", Vector2.ONE * 1.08, 0.1)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.08)
	tween.parallel().tween_property(
		self, "global_position", start_position + Vector2(0.0, -FLOAT_DISTANCE), LIFETIME - 0.08
	)
	tween.parallel().tween_property(label, "modulate:a", 0.0, LIFETIME - 0.16).set_delay(0.16)
	tween.tween_callback(queue_free)


func _apply_text() -> void:
	label.text = _prefix + str(_amount)
	label.add_theme_color_override("font_color", _text_color)
