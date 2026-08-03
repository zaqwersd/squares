class_name BossHealthBar
extends Control

const BORDER := Color.BLACK
const EMPTY := Color("#3E2030")
const VALUE := Color("#E84E5B")
const BUFFER := Color("#F2CA55")
const WIDTH := 420.0
const HEIGHT := 22.0
const BOSS_NAME := "史莱姆王"

var game_font: Font
var _boss: Node
var _current_health := 200
var _max_health := 200
var _current_ratio := 1.0
var _buffer_ratio := 1.0
var _reveal := 0.0

func _ready() -> void:
	visible = false
	var font_path := "res://fonts/AiDianFengYaHei" + String.chr(0xFF08) + "ShangYongMianFei" + String.chr(0xFF09) + "-2.ttf"
	game_font = ResourceLoader.load(font_path) as Font
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func watch(boss: Node) -> void:
	_boss = boss
	visible = true
	_boss.health_changed.connect(_on_health_changed)
	_current_health = int(_boss.get("health"))
	_max_health = int(_boss.get("max_health"))
	_current_ratio = clampf(float(_current_health) / float(_max_health), 0.0, 1.0)
	_buffer_ratio = _current_ratio
	_reveal = 0.0
	queue_redraw()

func clear_boss() -> void:
	_boss = null
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_reveal = minf(1.0, _reveal + delta * 2.8)
	_buffer_ratio = move_toward(_buffer_ratio, _current_ratio, delta * 0.36)
	queue_redraw()

func _on_health_changed(current: int, maximum: int) -> void:
	_current_health = current
	_max_health = maximum
	_current_ratio = clampf(float(current) / float(maximum), 0.0, 1.0)
	_buffer_ratio = maxf(_buffer_ratio, _current_ratio)

func _draw() -> void:
	var revealed_width := WIDTH * _reveal
	var rect := Rect2(Vector2(-revealed_width * 0.5, 0.0), Vector2(revealed_width, HEIGHT))
	draw_rect(rect, BORDER, true, -1.0, false)
	var inner := rect.grow(-3.0)
	draw_rect(inner, EMPTY, true, -1.0, false)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * _buffer_ratio, inner.size.y)), BUFFER, true, -1.0, false)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * _current_ratio, inner.size.y)), VALUE, true, -1.0, false)
	var font := game_font if game_font != null else ThemeDB.fallback_font
	var label := "%d/%d" % [_current_health, _max_health]
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, Vector2(-label_size.x * 0.5, 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var name_size := font.get_string_size(BOSS_NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var name_position := Vector2(-name_size.x * 0.5, -8.0)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		draw_string(font, name_position + offset, BOSS_NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, BORDER)
	draw_string(font, name_position, BOSS_NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
