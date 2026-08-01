class_name InfiniteTerrainRenderer
extends Node2D

var _last_center := Vector2i(2147483647, 2147483647)


func _process(_delta: float) -> void:
	var island_map := get_parent() as IslandMap
	if island_map == null or not is_instance_valid(island_map.player):
		return
	var center := Vector2i(floori(island_map.player.global_position.x / IslandMap.TILE_SIZE), floori(island_map.player.global_position.y / IslandMap.TILE_SIZE))
	if center == _last_center:
		return
	_last_center = center
	queue_redraw()


func _draw() -> void:
	var island_map := get_parent() as IslandMap
	if island_map == null or not is_instance_valid(island_map.player):
		return
	var distance: int = island_map.infinite_render_distance_tiles
	var center := Vector2i(floori(island_map.player.global_position.x / IslandMap.TILE_SIZE), floori(island_map.player.global_position.y / IslandMap.TILE_SIZE))
	var origin := Vector2(center - Vector2i(distance, distance)) * IslandMap.TILE_SIZE
	var size := Vector2.ONE * float(distance * 2 + 1) * IslandMap.TILE_SIZE
	draw_rect(Rect2(origin, size), IslandMap.DEEP_OCEAN_COLOR, true, -1.0, false)