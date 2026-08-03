class_name IslandMinimap
extends Control

const MINIMAP_SIZE := 128
const MINIMAP_CENTER := Vector2(64.0, 64.0)
const MINIMAP_TILE_SIZE := 6.0
const FULL_MAP_TILE_SIZE := 6.0
const MAP_TILE_SIZE := 64
const PLAYER_MARKER_SIZE := 6.0
const BORDER_WIDTH := 2.0

const OCEAN_COLOR := Color("#42CAFD")
const DEEP_OCEAN_COLOR := Color("#247EAE")
const GRASS_COLOR := Color("#7BE0AD")
const DESERT_COLOR := Color("#FBF2C0")
const SAVANNA_COLOR := Color("#B7D887")
const ROCK_COLOR := Color("#C2C2C2")
const ARENA_TILE_COLOR := Color("#D7D8D2")
const PLAYER_COLOR := Color("#1a64b5ff")
const BRIDGE_COLOR := Color("#806A58")
const BRAZIER_COLOR := Color("#FF6B35")
const BRAZIER_MARKER_SIZE := 4.0
const BORDER_COLOR := Color.BLACK
const MAP_PAN_SPEED := 640.0

@export var map_path: NodePath
@export var player_path: NodePath

@onready var island_map: Node = get_node(map_path)
@onready var player: CharacterBody2D = get_node(player_path)

var _fullscreen := false
var _map_pan := Vector2.ZERO
var _dragging := false
var _paused_by_map := false
var _last_player_cell := Vector2i(2147483647, 2147483647)
var _map_was_panned := false


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * MINIMAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()


func _process(delta: float) -> void:
	if _fullscreen:
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		if stick.length() > 0.2:
			_map_pan += stick.normalized() * MAP_PAN_SPEED * delta
			_map_was_panned = true
		if _map_was_panned:
			queue_redraw()
			_map_was_panned = false
		return
	var player_cell := Vector2i(floori(player.global_position.x / MAP_TILE_SIZE), floori(player.global_position.y / MAP_TILE_SIZE))
	if player_cell != _last_player_cell:
		_last_player_cell = player_cell
		queue_redraw()


func _input(event: InputEvent) -> void:
	var toggle_requested: bool = (
		event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M
	) or (
		event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_BACK]
	)
	if toggle_requested:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not _fullscreen:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_map_pan -= event.relative / FULL_MAP_TILE_SIZE * MAP_TILE_SIZE
		_map_was_panned = true
		accept_event()
func _toggle_fullscreen() -> void:
	_fullscreen = not _fullscreen
	_dragging = false
	if _fullscreen:
		_map_pan = player.global_position
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_paused_by_map = not get_tree().paused
		get_tree().paused = true
	else:
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -144.0
		offset_top = 16.0
		offset_right = -16.0
		offset_bottom = 144.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _paused_by_map:
			get_tree().paused = false
		_paused_by_map = false
	queue_redraw()


func _draw() -> void:
	var draw_size := size if _fullscreen else Vector2.ONE * MINIMAP_SIZE
	var tile_size := FULL_MAP_TILE_SIZE if _fullscreen else MINIMAP_TILE_SIZE
	var center_world := _map_pan if _fullscreen else player.global_position
	var center := draw_size * 0.5
	draw_rect(Rect2(Vector2.ZERO, draw_size), DEEP_OCEAN_COLOR, true, -1.0, false)
	var visible_radius_x := ceili(draw_size.x / tile_size * 0.5) + 2
	var visible_radius_y := ceili(draw_size.y / tile_size * 0.5) + 2
	var center_cell := Vector2i(floori(center_world.x / MAP_TILE_SIZE), floori(center_world.y / MAP_TILE_SIZE))
	for y in range(center_cell.y - visible_radius_y, center_cell.y + visible_radius_y + 1):
		for x in range(center_cell.x - visible_radius_x, center_cell.x + visible_radius_x + 1):
			var cell := Vector2i(x, y)
			var tile_color: Color = island_map.call("get_ocean_color", cell)
			if island_map.call("is_bridge", cell):
				tile_color = BRIDGE_COLOR
			elif island_map.call("is_rock", cell):
				tile_color = ROCK_COLOR
			elif island_map.call("is_arena_tile", cell):
				tile_color = ARENA_TILE_COLOR
			elif island_map.call("is_grass", cell):
				tile_color = DESERT_COLOR if island_map.call("is_desert", cell) else (SAVANNA_COLOR if island_map.call("is_savanna", cell) else GRASS_COLOR)
			var world_center := (Vector2(cell) + Vector2.ONE * 0.5) * MAP_TILE_SIZE
			var map_position := (center + (world_center - center_world) / MAP_TILE_SIZE * tile_size).round()
			draw_rect(Rect2(map_position - Vector2.ONE * tile_size * 0.5, Vector2.ONE * tile_size), tile_color, true, -1.0, false)
			if island_map.call("is_brazier", cell):
				draw_rect(Rect2(map_position - Vector2.ONE * BRAZIER_MARKER_SIZE * 0.5, Vector2.ONE * BRAZIER_MARKER_SIZE), BRAZIER_COLOR, true, -1.0, false)
	var player_position := center + (player.global_position - center_world) / MAP_TILE_SIZE * tile_size
	draw_rect(Rect2(player_position - Vector2.ONE * PLAYER_MARKER_SIZE * 0.5, Vector2.ONE * PLAYER_MARKER_SIZE), PLAYER_COLOR, true, -1.0, false)
	draw_rect(Rect2(0, 0, draw_size.x, BORDER_WIDTH), BORDER_COLOR, true, -1.0, false)
	draw_rect(Rect2(0, draw_size.y - BORDER_WIDTH, draw_size.x, BORDER_WIDTH), BORDER_COLOR, true, -1.0, false)
	draw_rect(Rect2(0, 0, BORDER_WIDTH, draw_size.y), BORDER_COLOR, true, -1.0, false)
	draw_rect(Rect2(draw_size.x - BORDER_WIDTH, 0, BORDER_WIDTH, draw_size.y), BORDER_COLOR, true, -1.0, false)
