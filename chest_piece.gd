class_name ChestPiece
extends Node2D

enum Piece { BACKDROP, BODY, LID }

const WOOD_TOP := Color("#966D34")
const WOOD_BODY := Color("#5E4521")
const METAL := Color("#D8D8D8")
const LOCK_PLATE := Color("#ACACAC")
const LOCK_DARK := Color("#47440A")
const INNER_BLACK := Color.BLACK
const INNER_RAIL := Color("#B9B9B9")
const SVG_CENTER := Vector2(28.0, 25.5)

@export var piece := Piece.BODY:
	set(value):
		piece = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	match piece:
		Piece.BACKDROP:
			_draw_backdrop()
		Piece.BODY:
			_draw_body()
		Piece.LID:
			_draw_lid()


func _rect(x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(x - SVG_CENTER.x, y - SVG_CENTER.y, width, height), color, true, -1.0, false)


func _draw_backdrop() -> void:
	# Black inner layer exactly matches the two brown rectangles combined.
	draw_rect(Rect2(-26.5, -25.5, 53.0, 50.0), INNER_BLACK, true, -1.0, false)
	# Stationary lower copies of both silver side rails remain visible through the opening.
	_rect(1.5, 0, 4, 50, INNER_RAIL)
	_rect(50.5, 0, 4, 50, INNER_RAIL)


func _draw_body() -> void:
	_rect(0, 22, 56, 28, WOOD_BODY)
	_rect(0, 22, 56, 5, METAL)
	_rect(0, 22, 7, 28, METAL)
	_rect(49, 22, 7, 28, METAL)
	_rect(0, 47, 56, 4, METAL)


func _draw_lid() -> void:
	_rect(0, 0, 56, 22, WOOD_TOP)
	_rect(0, 17, 56, 5, METAL)
	_rect(0, 0, 7, 22, METAL)
	_rect(25, 0, 6, 22, METAL)
	_rect(49, 0, 7, 22, METAL)
	# The complete lock stays attached to the lid.
	_rect(21, 15, 14, 15, LOCK_PLATE)
	_rect(25, 19, 6, 8, LOCK_DARK)
	_rect(23, 17, 10, 4, LOCK_DARK)