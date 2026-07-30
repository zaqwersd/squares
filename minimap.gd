class_name IslandMinimap
extends Control

const MINIMAP_SIZE := 128
const MINIMAP_CENTER := Vector2(64.0, 64.0)
const MINIMAP_TILE_SIZE := 6
const MAP_TILE_SIZE := 64
const PLAYER_MARKER_SIZE := 6
const BORDER_WIDTH := 2

const OCEAN_COLOR := Color("#42CAFD")
const DEEP_OCEAN_COLOR := Color("#247EAE")
const GRASS_COLOR := Color("#7BE0AD")
const PLAYER_COLOR := Color("#154C8BFF")
const BRIDGE_COLOR := Color("#5A4233")
const BRAZIER_COLOR := Color("#FF6B35")
const BRAZIER_MARKER_SIZE := 4
const BORDER_COLOR := Color.BLACK

@export var map_path: NodePath
@export var player_path: NodePath

@onready var island_map: Node = get_node(map_path)
@onready var player: CharacterBody2D = get_node(player_path)


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * MINIMAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2.ONE * MINIMAP_SIZE)
	draw_rect(bounds, DEEP_OCEAN_COLOR, true, -1.0, false)

	var map_height: int = island_map.get("map_height")
	var map_width: int = island_map.get("map_width")
	var player_cell := Vector2i(floori(player.position.x / MAP_TILE_SIZE), floori(player.position.y / MAP_TILE_SIZE))
	var visible_radius := ceili(float(MINIMAP_SIZE) / MINIMAP_TILE_SIZE * 0.5) + 2
	var min_x := maxi(0, player_cell.x - visible_radius)
	var max_x := mini(map_width - 1, player_cell.x + visible_radius)
	var min_y := maxi(0, player_cell.y - visible_radius)
	var max_y := mini(map_height - 1, player_cell.y + visible_radius)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell := Vector2i(x, y)
			var grass: bool = island_map.call("is_grass", cell)
			var bridge: bool = island_map.call("is_bridge", cell)
			var tile_color: Color = island_map.call("get_ocean_color", cell)
			if bridge:
				tile_color = BRIDGE_COLOR
			elif grass:
				tile_color = GRASS_COLOR

			var world_center := (Vector2(cell) + Vector2.ONE * 0.5) * MAP_TILE_SIZE
			var offset_in_tiles := (world_center - player.position) / MAP_TILE_SIZE
			var minimap_center := (
				MINIMAP_CENTER + offset_in_tiles * MINIMAP_TILE_SIZE
			).round()
			draw_rect(
				Rect2(
					minimap_center - Vector2.ONE * MINIMAP_TILE_SIZE * 0.5,
					Vector2.ONE * MINIMAP_TILE_SIZE
				),
				tile_color,
				true,
				-1.0,
				false
			)
			if island_map.call("is_brazier", cell):
				draw_rect(
					Rect2(
						minimap_center - Vector2.ONE * BRAZIER_MARKER_SIZE * 0.5,
						Vector2.ONE * BRAZIER_MARKER_SIZE
					),
					BRAZIER_COLOR,
					true,
					-1.0,
					false
				)

	draw_rect(
		Rect2(
			MINIMAP_CENTER - Vector2.ONE * PLAYER_MARKER_SIZE * 0.5,
			Vector2.ONE * PLAYER_MARKER_SIZE
		),
		PLAYER_COLOR,
		true,
		-1.0,
		false
	)

	draw_rect(Rect2(0, 0, MINIMAP_SIZE, BORDER_WIDTH), BORDER_COLOR)
	draw_rect(
		Rect2(0, MINIMAP_SIZE - BORDER_WIDTH, MINIMAP_SIZE, BORDER_WIDTH),
		BORDER_COLOR
	)
	draw_rect(Rect2(0, 0, BORDER_WIDTH, MINIMAP_SIZE), BORDER_COLOR)
	draw_rect(
		Rect2(MINIMAP_SIZE - BORDER_WIDTH, 0, BORDER_WIDTH, MINIMAP_SIZE),
		BORDER_COLOR
	)

