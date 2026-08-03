class_name PlayerExperienceBar
extends Control

const BORDER_COLOR := Color.BLACK
const BACKGROUND_COLOR := Color("#18364A")
const EXPERIENCE_COLOR := Color("#62D8FF")
const TEXT_COLOR := Color.WHITE
const BAR_RECT := Rect2(40.0, 2.0, 160.0, 14.0)
const BORDER_WIDTH := 2.0

@export var player_path: NodePath

@onready var player: IslandPlayer = get_node(player_path) as IslandPlayer

var game_font: Font


func _ready() -> void:
	var font_path := "res://fonts/AiDianFengYaHei" + String.chr(0xFF08) + "ShangYongMianFei" + String.chr(0xFF09) + "-2.ttf"
	game_font = ResourceLoader.load(font_path) as Font
	player.experience_changed.connect(_on_experience_changed)
	queue_redraw()


func _draw() -> void:
	var ratio := float(player.experience) / float(player.get_experience_required())
	draw_rect(BAR_RECT, BORDER_COLOR, true)
	var inner := BAR_RECT.grow(-BORDER_WIDTH)
	draw_rect(inner, BACKGROUND_COLOR, true)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y)), EXPERIENCE_COLOR, true)
	var label := "LV.%d" % player.level
	var font := game_font if game_font != null else ThemeDB.fallback_font
	var label_position := Vector2(0.0, 14.0)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		draw_string(font, label_position + offset, label, HORIZONTAL_ALIGNMENT_LEFT, 50.0, 13, BORDER_COLOR)
	draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, 50.0, 13, TEXT_COLOR)


func _on_experience_changed(_level: int, _experience: int, _required: int) -> void:
	queue_redraw()
