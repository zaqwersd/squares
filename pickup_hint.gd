class_name PickupHint
extends Node2D

const TEXT_COLOR := Color.WHITE
const KEYBOARD_COLOR := Color.WHITE
const KEYBOARD_FILL := Color(0.06, 0.13, 0.17, 0.94)
const GAMEPAD_COLORS := {
	"A": Color("#59C36A"),
	"B": Color("#DD5C55"),
	"X": Color("#4B8CDB"),
	"Y": Color("#E0B64C"),
}

var _gamepad_active := false
var _pulse_time := 0.0
var _font: Font


func _ready() -> void:
	var font_path := "res://fonts/AiDianFengYaHei" + String.chr(0xFF08) + "ShangYongMianFei" + String.chr(0xFF09) + "-2.ttf"
	_font = ResourceLoader.load(font_path) as Font


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func set_gamepad_active(value: bool) -> void:
	if _gamepad_active == value:
		return
	_gamepad_active = value
	queue_redraw()


func _draw() -> void:
	var key_label := "A" if _gamepad_active else "E"
	var action_label := "拾取"
	var font := _font if _font != null else ThemeDB.fallback_font
	var font_size := 15
	var key_size := font.get_string_size(key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pulse := 1.0 + sin(_pulse_time * 4.0) * 0.035
	var brightness := 1.0 + (sin(_pulse_time * 4.0) * 0.5 + 0.5) * 0.18
	var key_half_width := 12.0
	var key_half_height := 12.0
	if key_label in ["RT", "LT", "RB", "LB"]:
		key_half_width = 17.0
		key_half_height = 10.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * pulse)
	if key_label in GAMEPAD_COLORS:
		var button_color: Color = GAMEPAD_COLORS[key_label]
		draw_circle(Vector2.ZERO, key_half_width, button_color * brightness)
		draw_arc(Vector2.ZERO, key_half_width, 0.0, TAU, 24, Color.WHITE * brightness, 2.0)
	else:
		var key_rect := Rect2(
			Vector2(-key_half_width, -key_half_height),
			Vector2(key_half_width * 2.0, key_half_height * 2.0)
		)
		draw_rect(key_rect, KEYBOARD_FILL, true)
		draw_rect(key_rect, KEYBOARD_COLOR * brightness, false, 2.0)
	draw_string(
		font,
		Vector2(-key_size.x * 0.5, 6.0),
		key_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		TEXT_COLOR * brightness
	)
	draw_string(
		font,
		Vector2(key_half_width + 7.0, 6.0),
		action_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		TEXT_COLOR * brightness
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)