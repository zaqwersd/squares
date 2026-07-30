class_name IslandMap
extends Node2D

const TILE_SIZE := 64
const COASTAL_OCEAN_COLOR := Color("#7DDEFA")
const OCEAN_COLOR := Color("#42CAFD")
const MID_OCEAN_COLOR := Color("#2B9FCB")
const DEEP_OCEAN_COLOR := Color("#247EAE")
const GRASS_COLOR := Color("#7BE0AD")
const SHADOW_COLOR := Color("#61A289")
const COAST_COLOR := Color.WHITE
const BRIDGE_TOP_COLOR := Color("#5A4233")
const BRIDGE_POST_TOP_COLOR := Color("#7B5640")
const BRIDGE_SIDE_COLOR := Color("#43291F")
const BRIDGE_WATER_SHADOW := Color(0.0, 0.0, 0.0, 0.18)
const BRIDGE_WATER_SHADOW_OFFSET := 32.0
const BRIDGE_POST_SIZE := 8.0
const BRIDGE_POST_HEIGHT := 48.0
const BRAZIER_SCENE := preload("res://brazier.tscn")

const BRIDGE_NONE := 0
const BRIDGE_HORIZONTAL := 1
const BRIDGE_VERTICAL := 2

@export_group("Map")
@export_range(5, 512, 1, "or_greater") var map_width := 20
@export_range(5, 512, 1, "or_greater") var map_height := 12
@export var world_seed := 13579

@export_group("Island Shape")
@export_range(0.0, 1.0, 0.01) var island_size := 0.58
@export_range(0.02, 0.3, 0.005) var coast_noise_frequency := 0.115
@export_range(1, 8, 1) var coast_noise_octaves := 4
@export_range(0.0, 0.5, 0.01) var coast_irregularity := 0.28

@export_group("Dock")
@export_range(1, 15, 1) var dock_width := 3
@export_range(2, 30, 1) var dock_length := 6

@export_group("Deep Ocean")
@export_range(5, 20, 1) var deep_ocean_min_land_distance := 5
@export_range(0.0, 4.0, 0.25) var deep_ocean_distance_variation := 1.5
@export_range(2, 8, 1) var shallow_transition_min_width := 2
@export_range(2, 8, 1) var shallow_transition_max_width := 3
@export_range(1, 4, 1) var deep_ocean_min_bridge_distance := 1

@export_group("Bridge Planks")
@export_range(1, 8, 1) var bridge_planks_per_tile := 4
@export_range(0, 8, 1) var bridge_plank_gap := 3
@export_range(0, 8, 1) var bridge_plank_side_height := 4

@export_group("Rendering")
@export_range(1, 12, 1) var coast_width := 5

var _tiles: Array[PackedByteArray] = []
var _bridge_tiles: Array[PackedByteArray] = []
var _deep_ocean_tiles: Array[PackedByteArray] = []
var _ocean_depth: Array[PackedFloat32Array] = []
var _ocean_mesh: ArrayMesh
var _dock_cells := Rect2i()
var _dock_spawn_cell := Vector2i(-1, -1)
var _braziers: Array[Node2D] = []
var _brazier_cells: Array[Vector2i] = []

@onready var terrain_collision: StaticBody2D = $TerrainCollision
@onready var player_shadow: Node2D = $PlayerShadow
@onready var player: IslandPlayer = $Player


func _ready() -> void:
	generate(world_seed)


func generate(seed_value: int) -> void:
	world_seed = seed_value
	_tiles = _create_island(seed_value)
	_build_south_dock()
	_build_deep_ocean(seed_value)
	_rebuild_terrain_collision()
	_place_player()
	player.play_spawn_animation()
	_place_dock_braziers()
	queue_redraw()
	player_shadow.queue_redraw()


func has_generated_map() -> bool:
	return not _tiles.is_empty()


func is_grass(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_width or cell.y >= map_height:
		return false
	return _tiles[cell.y][cell.x] == 1


func is_bridge(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_width or cell.y >= map_height:
		return false
	return not _bridge_tiles.is_empty() and _bridge_tiles[cell.y][cell.x] != BRIDGE_NONE

func is_brazier(cell: Vector2i) -> bool:
	return cell in _brazier_cells


func is_walkable(cell: Vector2i) -> bool:	return is_grass(cell) or is_bridge(cell)


func is_deep_ocean(cell: Vector2i) -> bool:
	# The finite cache is surrounded by deterministic infinite deep ocean.
	if cell.x < 0 or cell.y < 0 or cell.x >= map_width or cell.y >= map_height:
		return true
	return (
		not _deep_ocean_tiles.is_empty()
		and _deep_ocean_tiles[cell.y][cell.x] == 1
	)


func get_ocean_color(cell: Vector2i) -> Color:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_width or cell.y >= map_height:
		return DEEP_OCEAN_COLOR
	if _ocean_depth.is_empty():
		return OCEAN_COLOR
	return _ocean_color_from_depth(_ocean_depth[cell.y][cell.x])


func _ocean_color_from_depth(depth: float) -> Color:
	if depth < 0.25:
		return COASTAL_OCEAN_COLOR
	if depth < 0.55:
		return OCEAN_COLOR
	if depth < 0.9:
		return MID_OCEAN_COLOR
	return DEEP_OCEAN_COLOR

func _create_island(seed_value: int) -> Array[PackedByteArray]:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = coast_noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = coast_noise_octaves
	noise.fractal_gain = 0.52

	var result := _new_grid()
	for y in map_height:
		for x in map_width:
			var nx := (float(x) + 0.5 - map_width * 0.5) / (map_width * 0.5)
			var ny := (float(y) + 0.5 - map_height * 0.5) / (map_height * 0.5)
			var distance := sqrt(nx * nx + ny * ny)
			var falloff := 1.0 - pow(distance, 1.55)
			var coast_noise := noise.get_noise_2d(x, y) * coast_irregularity
			result[y][x] = 1 if falloff + coast_noise > 1.0 - island_size else 0

	var mainland := _keep_largest_landmass(result)
	mainland = _fill_enclosed_water(mainland)
	var opened := _remove_one_tile_wide_land(mainland)
	if _has_land(opened):
		mainland = _keep_largest_landmass(opened)
	var cleaned := _remove_one_tile_bands(mainland)
	if _has_land(cleaned):
		mainland = _keep_largest_landmass(cleaned)
	mainland = _fill_enclosed_water(mainland)
	mainland = _fill_diagonal_land_corners(mainland, 1)
	return mainland


func _fill_diagonal_land_corners(
	source: Array[PackedByteArray],
	passes: int
) -> Array[PackedByteArray]:
	var current := source.duplicate(true)
	for pass_index in passes:
		var result: Array[PackedByteArray] = current.duplicate(true)
		for y in range(1, map_height - 1):
			for x in range(1, map_width - 1):
				if current[y][x] == 1:
					continue
				var fills_corner: bool = (
					(current[y - 1][x] == 1 and current[y][x + 1] == 1 and current[y - 1][x + 1] == 1)
					or (current[y][x + 1] == 1 and current[y + 1][x] == 1 and current[y + 1][x + 1] == 1)
					or (current[y + 1][x] == 1 and current[y][x - 1] == 1 and current[y + 1][x - 1] == 1)
					or (current[y][x - 1] == 1 and current[y - 1][x] == 1 and current[y - 1][x - 1] == 1)
				)
				if fills_corner:
					result[y][x] = 1
		current = result
	return current


func _build_south_dock() -> void:
	_bridge_tiles = _new_grid()
	_dock_cells = Rect2i()
	_dock_spawn_cell = Vector2i(-1, -1)

	var actual_width := mini(dock_width, map_width)
	var actual_length := mini(dock_length, map_height - 1)
	var max_shore_y := map_height - actual_length - 1
	var start_x := -1
	var shore_y := -1
	var map_center_x := map_width * 0.5
	for y in range(max_shore_y, -1, -1):
		var best_row_x := -1
		var best_distance := INF
		for candidate_x in range(0, map_width - actual_width + 1):
			var connected := true
			for offset in actual_width:
				if (
					not is_grass(Vector2i(candidate_x + offset, y))
					or is_grass(Vector2i(candidate_x + offset, y + 1))
				):
					connected = false
					break
			if not connected:
				continue
			var candidate_center := candidate_x + actual_width * 0.5
			var distance := absf(candidate_center - map_center_x)
			if distance < best_distance:
				best_distance = distance
				best_row_x = candidate_x
		if best_row_x >= 0:
			start_x = best_row_x
			shore_y = y
			break

	if start_x < 0:
		var bottom_y := -1
		var anchor_x := -1
		for y in map_height:
			for x in map_width:
				if not is_grass(Vector2i(x, y)):
					continue
				if y > bottom_y or (
					y == bottom_y
					and absf(x - map_center_x) < absf(anchor_x - map_center_x)
				):
					bottom_y = y
					anchor_x = x
		if bottom_y < 0 or bottom_y + 1 >= map_height:
			return
		start_x = clampi(anchor_x - int(actual_width / 2), 0, map_width - actual_width)
		shore_y = mini(bottom_y, max_shore_y)
		for pad_y in range(maxi(0, shore_y - 1), shore_y + 1):
			for x in range(start_x, start_x + actual_width):
				_tiles[pad_y][x] = 1

	# Reserve one complete grass cell on each side for the dock braziers.
	if map_width >= actual_width + 2:
		start_x = clampi(start_x, 1, map_width - actual_width - 1)
	var platform_width := mini(map_width, maxi(5, actual_width + 2))
	var platform_center_x := start_x + int(actual_width / 2)
	var platform_start_x := clampi(
		platform_center_x - int(platform_width / 2),
		0,
		map_width - platform_width
	)
	for platform_y in range(maxi(0, shore_y - 1), shore_y + 1):
		for platform_x in range(platform_start_x, platform_start_x + platform_width):
			_tiles[platform_y][platform_x] = 1
	_tiles = _fill_diagonal_land_corners(_tiles, 1)

	var water_start_y := shore_y + 1
	if actual_length <= 0:
		return

	# The deck overlays one intact grass row before continuing over the water.
	_dock_cells = Rect2i(start_x, shore_y, actual_width, actual_length + 1)
	for y in range(shore_y, water_start_y + actual_length):
		for x in range(start_x, start_x + actual_width):
			if y >= water_start_y:
				_tiles[y][x] = 0
			_bridge_tiles[y][x] = BRIDGE_VERTICAL
	_dock_spawn_cell = Vector2i(start_x + int(actual_width / 2), _dock_cells.end.y - 2)

func _build_deep_ocean(seed_value: int) -> void:
	_deep_ocean_tiles = _new_grid()
	_ocean_depth = []
	var distances: Array[PackedInt32Array] = []
	var infinity := 1000000000
	for y in map_height:
		var distance_row := PackedInt32Array()
		distance_row.resize(map_width)
		distance_row.fill(infinity)
		distances.append(distance_row)
		var depth_row := PackedFloat32Array()
		depth_row.resize(map_width)
		_ocean_depth.append(depth_row)
		for x in map_width:
			if is_grass(Vector2i(x, y)):
				distances[y][x] = 0

	# Two-pass chamfer distance: cardinal movement costs 10, diagonals cost 14.
	for y in map_height:
		for x in map_width:
			if distances[y][x] == 0:
				continue
			var best := distances[y][x]
			if x > 0:
				best = mini(best, distances[y][x - 1] + 10)
			if y > 0:
				best = mini(best, distances[y - 1][x] + 10)
				if x > 0:
					best = mini(best, distances[y - 1][x - 1] + 14)
				if x + 1 < map_width:
					best = mini(best, distances[y - 1][x + 1] + 14)
			distances[y][x] = best

	for y in range(map_height - 1, -1, -1):
		for x in range(map_width - 1, -1, -1):
			if distances[y][x] == 0:
				continue
			var best := distances[y][x]
			if x + 1 < map_width:
				best = mini(best, distances[y][x + 1] + 10)
			if y + 1 < map_height:
				best = mini(best, distances[y + 1][x] + 10)
				if x > 0:
					best = mini(best, distances[y + 1][x - 1] + 14)
				if x + 1 < map_width:
					best = mini(best, distances[y + 1][x + 1] + 14)
			distances[y][x] = best

	var directions: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1),
	]
	var boundary_noise := FastNoiseLite.new()
	boundary_noise.seed = seed_value ^ 0x5F3759DF
	boundary_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	boundary_noise.frequency = 0.075
	boundary_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	boundary_noise.fractal_octaves = 3

	for y in map_height:
		for x in map_width:
			var cell := Vector2i(x, y)
			if is_grass(cell) or is_bridge(cell):
				continue
			var land_distance := float(distances[y][x]) / 10.0
			if land_distance <= 1.41:
				_ocean_depth[y][x] = 0.0
				continue

			var dock_dx := maxi(
				maxi(_dock_cells.position.x - cell.x, 0),
				cell.x - (_dock_cells.end.x - 1)
			)
			var dock_dy := maxi(
				maxi(_dock_cells.position.y - cell.y, 0),
				cell.y - (_dock_cells.end.y - 1)
			)
			if maxi(dock_dx, dock_dy) <= 1:
				_ocean_depth[y][x] = 0.34
				continue

			var noise_value := boundary_noise.get_noise_2d(x, y)
			var effective_distance := (
				land_distance + noise_value * deep_ocean_distance_variation
			)
			var maximum_width := maxi(
				shallow_transition_min_width,
				shallow_transition_max_width
			)
			var width_noise := noise_value * 0.5 + 0.5
			var shared_band_width := lerpf(
				shallow_transition_min_width,
				maximum_width,
				width_noise
			)
			var shallow_end := 1.41 + shared_band_width
			var transition_end := shallow_end + shared_band_width
			if effective_distance <= shallow_end:
				_ocean_depth[y][x] = 0.34
			elif (
				effective_distance <= transition_end
				or land_distance < deep_ocean_min_land_distance
			):
				_ocean_depth[y][x] = 0.67
			else:
				_ocean_depth[y][x] = 1.0
				_deep_ocean_tiles[y][x] = 1

	_build_ocean_mesh()


func _build_ocean_mesh() -> void:
	_ocean_mesh = ArrayMesh.new()
	var tile_count := map_width * map_height
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(tile_count * 4)
	colors.resize(tile_count * 4)
	indices.resize(tile_count * 6)

	var tile_index := 0
	for y in map_height:
		for x in map_width:
			var vertex_offset := tile_index * 4
			var index_offset := tile_index * 6
			var left := float(x * TILE_SIZE)
			var top := float(y * TILE_SIZE)
			var right := left + TILE_SIZE
			var bottom := top + TILE_SIZE
			vertices[vertex_offset] = Vector3(left, top, 0.0)
			vertices[vertex_offset + 1] = Vector3(right, top, 0.0)
			vertices[vertex_offset + 2] = Vector3(left, bottom, 0.0)
			vertices[vertex_offset + 3] = Vector3(right, bottom, 0.0)
			var tile_color := _ocean_color_from_depth(_ocean_depth[y][x])
			colors[vertex_offset] = tile_color
			colors[vertex_offset + 1] = tile_color
			colors[vertex_offset + 2] = tile_color
			colors[vertex_offset + 3] = tile_color
			indices[index_offset] = vertex_offset
			indices[index_offset + 1] = vertex_offset + 2
			indices[index_offset + 2] = vertex_offset + 1
			indices[index_offset + 3] = vertex_offset + 1
			indices[index_offset + 4] = vertex_offset + 2
			indices[index_offset + 5] = vertex_offset + 3
			tile_index += 1

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_ocean_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _new_grid() -> Array[PackedByteArray]:
	var grid: Array[PackedByteArray] = []
	for y in map_height:
		var row := PackedByteArray()
		row.resize(map_width)
		grid.append(row)
	return grid


func _keep_largest_landmass(source: Array[PackedByteArray]) -> Array[PackedByteArray]:
	var visited := _new_grid()
	var largest := PackedInt32Array()
	var directions: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]

	for y in map_height:
		for x in map_width:
			if source[y][x] == 0 or visited[y][x] == 1:
				continue

			var component := PackedInt32Array()
			var pending := PackedInt32Array([y * map_width + x])
			visited[y][x] = 1
			while not pending.is_empty():
				var last_index := pending.size() - 1
				var encoded: int = pending[last_index]
				pending.resize(last_index)
				component.append(encoded)
				var cell := Vector2i(encoded % map_width, int(encoded / map_width))
				for direction in directions:
					var neighbor := cell + direction
					if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_width or neighbor.y >= map_height:
						continue
					if source[neighbor.y][neighbor.x] == 0 or visited[neighbor.y][neighbor.x] == 1:
						continue
					visited[neighbor.y][neighbor.x] = 1
					pending.append(neighbor.y * map_width + neighbor.x)

			if component.size() > largest.size():
				largest = component

	var result := _new_grid()
	for encoded in largest:
		var x := encoded % map_width
		var y := int(encoded / map_width)
		result[y][x] = 1
	return result


func _fill_enclosed_water(source: Array[PackedByteArray]) -> Array[PackedByteArray]:
	var outside_water := _new_grid()
	var pending := PackedInt32Array()

	for x in map_width:
		if source[0][x] == 0:
			outside_water[0][x] = 1
			pending.append(x)
		if source[map_height - 1][x] == 0 and outside_water[map_height - 1][x] == 0:
			outside_water[map_height - 1][x] = 1
			pending.append((map_height - 1) * map_width + x)
	for y in map_height:
		if source[y][0] == 0 and outside_water[y][0] == 0:
			outside_water[y][0] = 1
			pending.append(y * map_width)
		if source[y][map_width - 1] == 0 and outside_water[y][map_width - 1] == 0:
			outside_water[y][map_width - 1] = 1
			pending.append(y * map_width + map_width - 1)

	var directions: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]
	while not pending.is_empty():
		var last_index := pending.size() - 1
		var encoded: int = pending[last_index]
		pending.resize(last_index)
		var cell := Vector2i(encoded % map_width, int(encoded / map_width))
		for direction in directions:
			var neighbor := cell + direction
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_width or neighbor.y >= map_height:
				continue
			if source[neighbor.y][neighbor.x] == 1 or outside_water[neighbor.y][neighbor.x] == 1:
				continue
			outside_water[neighbor.y][neighbor.x] = 1
			pending.append(neighbor.y * map_width + neighbor.x)

	var result: Array[PackedByteArray] = source.duplicate(true)
	for y in map_height:
		for x in map_width:
			if result[y][x] == 0 and outside_water[y][x] == 0:
				result[y][x] = 1
	return result


func _remove_one_tile_wide_land(source: Array[PackedByteArray]) -> Array[PackedByteArray]:
	# A cross-shaped morphological opening removes width-one land corridors and
	# peninsulas while restoring the boundary of regions at least two tiles wide.
	var eroded := _new_grid()
	for y in range(1, map_height - 1):
		for x in range(1, map_width - 1):
			if (
				source[y][x] == 1
				and source[y][x - 1] == 1
				and source[y][x + 1] == 1
				and source[y - 1][x] == 1
				and source[y + 1][x] == 1
			):
				eroded[y][x] = 1

	var result := _new_grid()
	for y in map_height:
		for x in map_width:
			if eroded[y][x] == 1:
				result[y][x] = 1
				continue
			if x > 0 and eroded[y][x - 1] == 1:
				result[y][x] = 1
			elif x + 1 < map_width and eroded[y][x + 1] == 1:
				result[y][x] = 1
			elif y > 0 and eroded[y - 1][x] == 1:
				result[y][x] = 1
			elif y + 1 < map_height and eroded[y + 1][x] == 1:
				result[y][x] = 1
	return result

func _remove_one_tile_bands(source: Array[PackedByteArray]) -> Array[PackedByteArray]:
	var current: Array[PackedByteArray] = source.duplicate(true)
	for pass_index in 2:
		var result: Array[PackedByteArray] = current.duplicate(true)
		for y in map_height:
			for x in map_width:
				if current[y][x] == 0:
					continue
				var left_water := x == 0 or current[y][x - 1] == 0
				var right_water := x + 1 >= map_width or current[y][x + 1] == 0
				var up_water := y == 0 or current[y - 1][x] == 0
				var down_water := y + 1 >= map_height or current[y + 1][x] == 0
				if (left_water and right_water) or (up_water and down_water):
					result[y][x] = 0
		current = result
	return current

func _has_land(source: Array[PackedByteArray]) -> bool:
	for row in source:
		for value in row:
			if value == 1:
				return true
	return false


func _draw() -> void:
	if _tiles.is_empty():
		return

	if _ocean_mesh != null:
		draw_mesh(_ocean_mesh, null)
	else:
		draw_rect(
			Rect2(Vector2.ZERO, Vector2(map_width, map_height) * TILE_SIZE),
			OCEAN_COLOR,
			true,
			-1.0,
			false
		)
	_draw_coast_backings()
	_draw_cliff_runs()
	_draw_grass_runs()
	_draw_dock_bridge()

func _draw_coast_backings() -> void:
	for y in map_height:
		for x in map_width:
			var cell := Vector2i(x, y)
			if not is_grass(cell):
				continue
			var boundary := (
				not is_grass(cell + Vector2i.LEFT)
				or not is_grass(cell + Vector2i.RIGHT)
				or not is_grass(cell + Vector2i.UP)
				or not is_grass(cell + Vector2i.DOWN)
			)
			if not boundary:
				continue
			var tile_position := Vector2(x, y) * TILE_SIZE
			_draw_coast_backing(tile_position, Vector2.ONE * TILE_SIZE)
			if not is_grass(cell + Vector2i.DOWN):
				_draw_coast_backing(
					tile_position + Vector2(0.0, TILE_SIZE),
					Vector2(TILE_SIZE, TILE_SIZE / 2)
				)


func _draw_coast_backing(position: Vector2, size: Vector2) -> void:
	var margin := Vector2.ONE * coast_width
	draw_rect(
		Rect2(position - margin, size + margin * 2.0),
		COAST_COLOR,
		true,
		-1.0,
		false
	)


func _draw_cliff_runs() -> void:
	for y in map_height:
		var x := 0
		while x < map_width:
			if not is_grass(Vector2i(x, y)) or is_grass(Vector2i(x, y + 1)):
				x += 1
				continue
			var run_start := x
			while x < map_width and is_grass(Vector2i(x, y)) and not is_grass(Vector2i(x, y + 1)):
				x += 1
			draw_rect(
				Rect2(
					Vector2(run_start * TILE_SIZE, (y + 1) * TILE_SIZE),
					Vector2((x - run_start) * TILE_SIZE, TILE_SIZE / 2)
				),
				SHADOW_COLOR,
				true,
				-1.0,
				false
			)


func _draw_grass_runs() -> void:
	for y in map_height:
		var x := 0
		while x < map_width:
			if not is_grass(Vector2i(x, y)):
				x += 1
				continue
			var run_start := x
			while x < map_width and is_grass(Vector2i(x, y)):
				x += 1
			draw_rect(
				Rect2(
					Vector2(run_start * TILE_SIZE, y * TILE_SIZE),
					Vector2((x - run_start) * TILE_SIZE, TILE_SIZE)
				),
				GRASS_COLOR,
				true,
				-1.0,
				false
			)

func _draw_dock_bridge() -> void:
	if _dock_cells.size.x <= 0 or _dock_cells.size.y <= 0:
		return
	var bridge_rect := Rect2(
		Vector2(_dock_cells.position) * TILE_SIZE,
		Vector2(_dock_cells.size) * TILE_SIZE
	)
	_draw_bridge(bridge_rect, BRIDGE_VERTICAL)


func _draw_bridge(bridge_rect: Rect2, orientation: int) -> void:
	# The water receives the bridge shadow 32 pixels below the elevated deck.
	draw_rect(
		Rect2(
			bridge_rect.position + Vector2(0.0, BRIDGE_WATER_SHADOW_OFFSET),
			bridge_rect.size
		),
		BRIDGE_WATER_SHADOW,
		true,
		-1.0,
		false
	)


	# Deck and supports are rendered by CoastEffects after animated waterlines.


func get_bridge_water_post_bases() -> Array[Rect2]:
	var bases: Array[Rect2] = []
	if _dock_cells.size.x <= 0 or _dock_cells.size.y <= 0:
		return bases
	var bridge_rect := Rect2(
		Vector2(_dock_cells.position) * TILE_SIZE,
		Vector2(_dock_cells.size) * TILE_SIZE
	)
	var row_count := maxi(1, int(bridge_rect.size.y / TILE_SIZE))
	for row in range(2, row_count + 1):
		var post_y := bridge_rect.position.y + row * TILE_SIZE - 16.0
		var base_y := post_y + BRIDGE_POST_HEIGHT - BRIDGE_POST_SIZE
		bases.append(Rect2(
			Vector2(bridge_rect.position.x, base_y),
			Vector2.ONE * BRIDGE_POST_SIZE
		))
		bases.append(Rect2(
			Vector2(bridge_rect.end.x - BRIDGE_POST_SIZE, base_y),
			Vector2.ONE * BRIDGE_POST_SIZE
		))
	return bases
func get_dock_bridge_rect() -> Rect2:
	if _dock_cells.size.x <= 0 or _dock_cells.size.y <= 0:
		return Rect2()
	return Rect2(
		Vector2(_dock_cells.position) * TILE_SIZE,
		Vector2(_dock_cells.size) * TILE_SIZE
	)


func get_bridge_post_rects() -> Array[Rect2]:
	var posts: Array[Rect2] = []
	if _dock_cells.size.x <= 0 or _dock_cells.size.y <= 0:
		return posts
	var bridge_rect := Rect2(
		Vector2(_dock_cells.position) * TILE_SIZE,
		Vector2(_dock_cells.size) * TILE_SIZE
	)
	var row_count := maxi(1, int(bridge_rect.size.y / TILE_SIZE))
	for row in range(row_count + 1):
		var post_height := BRIDGE_POST_HEIGHT if row >= 2 else 16.0
		var post_y := bridge_rect.position.y + row * TILE_SIZE - 16.0
		posts.append(Rect2(
			Vector2(bridge_rect.position.x, post_y),
			Vector2(BRIDGE_POST_SIZE, post_height)
		))
		posts.append(Rect2(
			Vector2(bridge_rect.end.x - BRIDGE_POST_SIZE, post_y),
			Vector2(BRIDGE_POST_SIZE, post_height)
		))
	return posts


func _draw_bridge_posts(	bridge_rect: Rect2,
	orientation: int,
	coast_only: bool
) -> void:
	if orientation == BRIDGE_HORIZONTAL:
		var column_count := maxi(1, int(bridge_rect.size.x / TILE_SIZE))
		for column in range(column_count + 1):
			var post_x := bridge_rect.position.x + column * TILE_SIZE - BRIDGE_POST_SIZE * 0.5
			_draw_bridge_post(
				Vector2(post_x, bridge_rect.position.y),
				BRIDGE_POST_HEIGHT,
				true,
				coast_only
			)
			_draw_bridge_post(
				Vector2(post_x, bridge_rect.end.y - BRIDGE_POST_HEIGHT),
				BRIDGE_POST_HEIGHT,
				true,
				coast_only
			)
	else:
		var row_count := maxi(1, int(bridge_rect.size.y / TILE_SIZE))
		for row in range(row_count + 1):
			var is_water_post := row >= 2
			var post_height := BRIDGE_POST_HEIGHT if is_water_post else 16.0
			var post_y := bridge_rect.position.y + row * TILE_SIZE - 16.0
			_draw_bridge_post(
				Vector2(bridge_rect.position.x, post_y),
				post_height,
				is_water_post,
				coast_only
			)
			_draw_bridge_post(
				Vector2(bridge_rect.end.x - BRIDGE_POST_SIZE, post_y),
				post_height,
				is_water_post,
				coast_only
			)

func _draw_bridge_post(
	top_left: Vector2,
	post_height: float,
	is_water_post: bool,
	coast_only: bool
) -> void:
	var base_rect := Rect2(
		top_left + Vector2(0.0, post_height - BRIDGE_POST_SIZE),
		Vector2.ONE * BRIDGE_POST_SIZE
	)
	if coast_only:
		if is_water_post:
			_draw_coast_backing(base_rect.position, base_rect.size)
		return
	draw_rect(
		Rect2(top_left, Vector2(BRIDGE_POST_SIZE, post_height)),
		BRIDGE_SIDE_COLOR,
		true,
		-1.0,
		false
	)
	draw_rect(
		Rect2(top_left, Vector2.ONE * BRIDGE_POST_SIZE),
		BRIDGE_POST_TOP_COLOR,
		true,
		-1.0,
		false
	)

func _draw_vertical_bridge_planks(bridge_rect: Rect2) -> void:
	var total_length := int(bridge_rect.size.y)
	var tile_count := maxi(1, int(bridge_rect.size.y / TILE_SIZE))
	var plank_count := tile_count * bridge_planks_per_tile
	for plank_index in plank_count:
		var slot_start := int(plank_index * total_length / plank_count)
		var slot_end := int((plank_index + 1) * total_length / plank_count)
		var slot_length := slot_end - slot_start
		var gap := mini(bridge_plank_gap, maxi(0, slot_length - 1))
		var drawable_length := slot_length - gap
		var side_height := mini(
			bridge_plank_side_height,
			maxi(0, drawable_length - 1)
		)
		var top_length := drawable_length - side_height
		var plank_position := bridge_rect.position + Vector2(0.0, slot_start)

		if side_height > 0:
			draw_rect(
				Rect2(
					plank_position + Vector2(0.0, top_length),
					Vector2(bridge_rect.size.x, side_height)
				),
				BRIDGE_SIDE_COLOR,
				true,
				-1.0,
				false
			)
		if top_length > 0:
			draw_rect(
				Rect2(plank_position, Vector2(bridge_rect.size.x, top_length)),
				BRIDGE_TOP_COLOR,
				true,
				-1.0,
				false
			)


func _draw_horizontal_bridge_planks(bridge_rect: Rect2) -> void:
	var total_length := int(bridge_rect.size.x)
	var tile_count := maxi(1, int(bridge_rect.size.x / TILE_SIZE))
	var plank_count := tile_count * bridge_planks_per_tile
	for plank_index in plank_count:
		var slot_start := int(plank_index * total_length / plank_count)
		var slot_end := int((plank_index + 1) * total_length / plank_count)
		var slot_length := slot_end - slot_start
		var gap := mini(bridge_plank_gap, maxi(0, slot_length - 1))
		var top_width := slot_length - gap
		var plank_position := bridge_rect.position + Vector2(slot_start, 0.0)

		if bridge_plank_side_height > 0:
			draw_rect(
				Rect2(
					plank_position + Vector2(0.0, bridge_plank_side_height),
					Vector2(top_width, bridge_rect.size.y)
				),
				BRIDGE_SIDE_COLOR,
				true,
				-1.0,
				false
			)
		if top_width > 0:
			draw_rect(
				Rect2(plank_position, Vector2(top_width, bridge_rect.size.y)),
				BRIDGE_TOP_COLOR,
				true,
				-1.0,
				false
			)

func _rebuild_terrain_collision() -> void:
	for child in terrain_collision.get_children():
		child.free()

	for y in map_height:
		var x := 0
		while x < map_width:
			if is_walkable(Vector2i(x, y)):
				x += 1
				continue
			var run_start := x
			while x < map_width and not is_walkable(Vector2i(x, y)):
				x += 1
			var run_length := x - run_start
			_add_terrain_block(
				Vector2((run_start + run_length * 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE),
				Vector2(run_length * TILE_SIZE, TILE_SIZE)
			)


func _add_terrain_block(center: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.position = center
	collision.shape = shape
	terrain_collision.add_child(collision)

func _place_dock_braziers() -> void:
	for brazier in _braziers:
		if is_instance_valid(brazier):
			brazier.queue_free()
	_braziers.clear()
	_brazier_cells.clear()
	if _dock_cells.size.x <= 0:
		return

	var shore_y := _dock_cells.position.y
	var cells := [
		Vector2i(_dock_cells.position.x - 1, shore_y),
		Vector2i(_dock_cells.end.x, shore_y),
	]
	for cell in cells:
		if not is_grass(cell) or is_bridge(cell):
			continue
		var brazier := BRAZIER_SCENE.instantiate() as Node2D
		brazier.position = (Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE
		add_child(brazier, true)
		_braziers.append(brazier)
		_brazier_cells.append(cell)


func _place_player() -> void:
	var map_center := Vector2(map_width, map_height) * 0.5
	var best_cell := Vector2i(-1, -1)
	var best_distance := INF

	for y in map_height:
		for x in map_width:
			var cell := Vector2i(x, y)
			if not is_grass(cell):
				continue
			var distance := Vector2(cell).distance_squared_to(map_center)
			if distance < best_distance:
				best_distance = distance
				best_cell = cell

	if _dock_spawn_cell.x >= 0:
		best_cell = _dock_spawn_cell

	if best_cell.x >= 0:
		player.position = (Vector2(best_cell) + Vector2.ONE * 0.5) * TILE_SIZE
		player.velocity = Vector2.ZERO

	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_width * TILE_SIZE
	camera.limit_bottom = map_height * TILE_SIZE
	camera.limit_smoothed = true
	camera.reset_smoothing()
	camera.force_update_scroll()
