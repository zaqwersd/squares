class_name PlayerHealthBar
extends Control

const BORDER_COLOR := Color.BLACK
const BACKGROUND_COLOR := Color("#5A1D28")
const HEALTH_COLOR := Color("#F15F5F")
const TEXT_COLOR := Color.WHITE
var game_font: Font
const BAR_RECT := Rect2(0.0, 0.0, 200.0, 24.0)
const BORDER_WIDTH := 3.0

@export var player_path: NodePath

@onready var player: Node = get_node(player_path)


func _ready() -> void:
	var font_path := "res://fonts/AiDianFengYaHei" + String.chr(0xFF08) + "ShangYongMianFei" + String.chr(0xFF09) + "-2.ttf"
	game_font = ResourceLoader.load(font_path) as Font
	player.health_changed.connect(_on_health_changed)
	queue_redraw()


func _draw() -> void:
	var ratio := float(player.health) / float(player.max_health)
	draw_rect(BAR_RECT, BORDER_COLOR, true, -1.0, false)
	var inner := BAR_RECT.grow(-BORDER_WIDTH)
	draw_rect(inner, BACKGROUND_COLOR, true, -1.0, false)
	draw_rect(
		Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y)),
		HEALTH_COLOR,
		true,
		-1.0,
		false
	)
	var label := "%d / %d" % [player.health, player.max_health]
	var font := game_font if game_font != null else ThemeDB.fallback_font
	var font_size := 14
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		font,
		Vector2((BAR_RECT.size.x - text_size.x) * 0.5, 17.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		TEXT_COLOR
	)


func _on_health_changed(_health: int, _max_health: int) -> void:
	queue_redraw()
