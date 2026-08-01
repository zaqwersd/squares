class_name IslandMap
extends Node2D

const TILE_SIZE := 64
const COASTAL_OCEAN_COLOR := Color("#7DDEFA")
const OCEAN_COLOR := Color("#42CAFD")
const MID_OCEAN_COLOR := Color("#2B9FCB")
const DEEP_OCEAN_COLOR := Color("#247EAE")
const GRASS_COLOR := Color("#7BE0AD")
const ROCK_TOP_COLOR := Color("#C2C2C2")
const ROCK_SIDE_COLOR := Color("#9F9F9F")
const SHADOW_COLOR := Color("#61A289")
const COAST_COLOR := Color.WHITE
const BRIDGE_TOP_COLOR := Color("#806A58")
const BRIDGE_POST_TOP_COLOR := Color("#9C765E")
const BRIDGE_SIDE_COLOR := Color("#604A3D")
const BRIDGE_WATER_SHADOW := Color(0.0, 0.0, 0.0, 0.18)
const BRIDGE_WATER_SHADOW_OFFSET := 32.0
const BRIDGE_POST_SIZE := 8.0
const BRIDGE_POST_HEIGHT := 48.0
const BRAZIER_SCENE := preload("res://brazier.tscn")
const ARCHER_SCENE := preload("res://archer.tscn")
const SHARPSHOOTER_SCENE := preload("res://sharpshooter.tscn")
const SWORDSMAN_SCENE := preload("res://swordsman.tscn")
const SLIME_SCENE := preload("res://slime.tscn")
const EXPERIENCE_PICKUP_SCENE := preload("res://experience_pickup.tscn")
const HEALTH_PICKUP_SCENE := preload("res://health_pickup.tscn")

const BRIDGE_NONE := 0
const BRIDGE_HORIZONTAL := 1
const BRIDGE_VERTICAL := 2
const CARDINAL_DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

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

@export_group("Rocks")
@export_range(0, 32, 1) var rock_cluster_count := 7
@export_range(1, 4, 1) var rock_coast_clearance_tiles := 2

@export_group("Rendering")
@export_range(16, 128, 1) var infinite_render_distance_tiles := 40
@export_range(1, 12, 1) var coast_width := 5

@export_group("Enemies")
@export_range(0, 64, 1) var max_archers := 2
@export_range(0, 64, 1) var max_total_enemies := 10
@export_range(0.1, 5.0, 0.1) var enemy_spawn_min_interval := 0.5
@export_range(0.5, 20.0, 0.1) var enemy_spawn_near_capacity_interval := 3.0
@export_range(0.0, 1.0, 0.01) var health_drop_chance := 0.2
@export_range(2, 8, 1) var archer_shoot_min_distance_tiles := 3
@export_range(3, 12, 1) var archer_shoot_max_distance_tiles := 7
@export_range(0, 64, 1) var max_swordsmen := 3
@export_range(0, 64, 1) var max_slimes := 5
@export_range(8, 64, 1) var navigation_field_radius_tiles := 28
@export_range(0.05, 1.0, 0.01) var potential_rebuild_interval := 0.12
@export_range(1.0, 30.0, 0.5) var offscreen_enemy_despawn_delay := 7.0
@export_range(0.0, 1.0, 0.01) var sharpshooter_base_spawn_chance := 0.05
@export_range(0.0, 1.0, 0.01) var sharpshooter_miss_bonus := 0.05

var _tiles: Array[PackedByteArray] = []
# Sparse global overrides make the world logically unbounded; absent cells are deep ocean.
var _world_tile_overrides: Dictionary = {} # Vector2i -> 0 ocean, 1 grass
var _world_bridge_overrides: Dictionary = {} # Vector2i -> bridge orientation
var _world_rock_overrides: Dictionary = {} # Vector2i -> true
var _arena_tiles: Dictionary = {} # Vector2i -> true
var _external_island_cells: Dictionary = {} # Vector2i -> true
var _external_bridge_rect := Rect2i()
var _bridge_tiles: Array[PackedByteArray] = []
var _rock_tiles: Array[PackedByteArray] = []
var _deep_ocean_tiles: Array[PackedByteArray] = []
var _ocean_depth: Array[PackedFloat32Array] = []
var _ocean_mesh: ArrayMesh
var _dock_cells := Rect2i()
var _dock_spawn_cell := Vector2i(-1, -1)
var _braziers: Array[Node2D] = []
var _brazier_cells: Array[Vector2i] = []
var _archers: Array[Node2D] = []
var _swordsmen: Array[Node2D] = []
var _slimes: Array[Node2D] = []
var _sharpshooters: Array[Node2D] = []
var _enemy_rng := RandomNumberGenerator.new()
var _experience_rng := RandomNumberGenerator.new()
var _loot_rng := RandomNumberGenerator.new()
var _enemy_spawn_elapsed := 0.0
var _archer_potential: Dictionary = {}
var _experience_potential: Dictionary = {}
var _potential_rebuild_elapsed := 0.0
var _enemy_visibility_elapsed := 0.0
var _enemy_offscreen_seconds: Dictionary = {}
var _sharpshooter_miss_count := 0
var _sharpshooter_unlock_boost_active := false
var _last_observed_player_level := 1
var _potential_player_cell := Vector2i(-1, -1)
var _game_over := false
var _enemy_spawning_started := false

@onready var terrain_collision: StaticBody2D = $TerrainCollision
@onready var rock_collision: StaticBody2D = $RockCollision
@onready var player_shadow: Node2D = $PlayerShadow
@onready var player: IslandPlayer = $Player
@onready var game_over_panel: GameOverPanel = $HUD/GameOverPanel


func _ready() -> void:
	player.died.connect(_on_player_died)
	generate(world_seed)


func _process(delta: float) -> void:
	if _game_over or _tiles.is_empty():
		return
	var player_cell := _world_to_cell(player.global_position)
	if player.level >= 3 and _last_observed_player_level < 3:
		_sharpshooter_unlock_boost_active = true
		_sharpshooter_miss_count = 0
	_last_observed_player_level = player.level
	_potential_rebuild_elapsed += delta
	if player_cell != _potential_player_cell and _potential_rebuild_elapsed >= potential_rebuild_interval:
		_rebuild_archer_potential_field()
		_rebuild_experience_potential_field()
		_potential_rebuild_elapsed = 0.0
	_enemy_visibility_elapsed += delta
	if _enemy_visibility_elapsed >= 0.5:
		_cleanup_offscreen_enemies(_enemy_visibility_elapsed)
		_enemy_visibility_elapsed = 0.0
	_prune_enemy_list(_archers)
	_prune_enemy_list(_swordsmen)
	_prune_enemy_list(_slimes)
	_prune_enemy_list(_sharpshooters)
	if not _enemy_spawning_started:
		if is_bridge(player_cell):
			return
		_enemy_spawning_started = true
		_spawn_first_enemy()
		_enemy_spawn_elapsed = 0.0
	if _active_enemy_count() >= max_total_enemies:
		return
	_enemy_spawn_elapsed += delta
	if _enemy_spawn_elapsed >= _get_enemy_spawn_interval():
		_enemy_spawn_elapsed = 0.0
		_spawn_weighted_enemy()
func _active_enemy_count() -> int:
	return _archers.size() + _swordsmen.size() + _slimes.size()

func _get_enemy_spawn_interval() -> float:
	if max_total_enemies <= 0:
		return enemy_spawn_near_capacity_interval
	var saturation := clampf(float(_active_enemy_count()) / float(max_total_enemies), 0.0, 1.0)
	return lerpf(enemy_spawn_min_interval, enemy_spawn_near_capacity_interval, saturation * saturation)


func _spawn_weighted_enemy() -> void:
	_spawn_first_enemy()

func _spawn_first_enemy() -> void:
	var roll := _enemy_rng.randf()
	if roll < 0.55 and _slimes.size() < max_slimes:
		_try_spawn_slime()
	elif roll < 0.82 and _swordsmen.size() < max_swordsmen:
		_try_spawn_swordsman()
	elif _archers.size() < max_archers:
		_try_spawn_archer()
	elif _slimes.size() < max_slimes:
		_try_spawn_slime()
	elif _swordsmen.size() < max_swordsmen:
		_try_spawn_swordsman()

func _prune_enemy_list(enemies: Array[Node2D]) -> void:
	for index in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[index]) or enemies[index].is_queued_for_deletion():
			enemies.remove_at(index)

func _cleanup_offscreen_enemies(elapsed: float) -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	if camera == null:
		return
	var visible_size := get_viewport_rect().size / camera.zoom
	var retention_view := Rect2(player.global_position - visible_size * 0.5, visible_size).grow(TILE_SIZE)
	for enemy in _archers + _swordsmen + _slimes:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var enemy_id := enemy.get_instance_id()
		if retention_view.has_point(enemy.global_position):
			_enemy_offscreen_seconds.erase(enemy_id)
			continue
		var offscreen_time := float(_enemy_offscreen_seconds.get(enemy_id, 0.0)) + elapsed
		if offscreen_time >= offscreen_enemy_despawn_delay:
			enemy.queue_free()
			_enemy_offscreen_seconds.erase(enemy_id)
		else:
			_enemy_offscreen_seconds[enemy_id] = offscreen_time

func generate(seed_value: int) -> void:
	_game_over = false
	_enemy_spawning_started = false
	_clear_archers()
	_clear_swordsmen()
	_clear_slimes()
	_sharpshooters.clear()
	_enemy_offscreen_seconds.clear()
	_clear_arrow_projectiles()
	world_seed = seed_value
	_enemy_rng.seed = seed_value ^ 0x5A17E4
	_experience_rng.seed = seed_value ^ 0x3E9B71
	_loot_rng.seed = seed_value ^ 0x19C4D2
	# Independent seeded offsets make the first encounter type vary with the map seed.
	_enemy_spawn_elapsed = 0.0
	_world_tile_overrides.clear()
	_world_bridge_overrides.clear()
	_world_rock_overrides.clear()
	_tiles = _create_island(seed_value)
	_build_south_dock()
	_build_rocks(seed_value)
	_build_deep_ocean(seed_value)
	_rebuild_terrain_collision()
	_rebuild_rock_collision()
	_place_player()
	player.play_spawn_animation()
	_place_dock_braziers()
	_potential_player_cell = Vector2i(-1, -1)
	_rebuild_archer_potential_field()
	_rebuild_experience_potential_field()
	queue_redraw()
	player_shadow.queue_redraw()


func _on_player_died() -> void:
	if _game_over:
		return
	_game_over = true
	player.hide()
	player_shadow.hide()
	game_over_panel.show_game_over()
	get_tree().paused = true


func has_generated_map() -> bool:
	return not _tiles.is_empty()


func is_grass(cell: Vector2i) -> bool:
	if _is_in_map(cell):
		return _tiles[cell.y][cell.x] == 1
	return int(_world_tile_overrides.get(cell, 0)) == 1


func is_bridge(cell: Vector2i) -> bool:
	if _is_in_map(cell):
		return not _bridge_tiles.is_empty() and _bridge_tiles[cell.y][cell.x] != BRIDGE_NONE
	return int(_world_bridge_overrides.get(cell, BRIDGE_NONE)) != BRIDGE_NONE


func set_world_grass(cell: Vector2i, enabled: bool) -> void:
	if _is_in_map(cell):
		_tiles[cell.y][cell.x] = 1 if enabled else 0
	else:
		_world_tile_overrides[cell] = 1 if enabled else 0


func set_world_bridge(cell: Vector2i, orientation: int) -> void:
	if _is_in_map(cell):
		_bridge_tiles[cell.y][cell.x] = orientation
	else:
		_world_bridge_overrides[cell] = orientation


func set_world_rock(cell: Vector2i, enabled: bool) -> void:
	if _is_in_map(cell):
		_rock_tiles[cell.y][cell.x] = 1 if enabled else 0
	else:
		if enabled:
			_world_rock_overrides[cell] = true
		else:
			_world_rock_overrides.erase(cell)

func is_brazier(cell: Vector2i) -> bool:
	return cell in _brazier_cells


func is_rock(cell: Vector2i) -> bool:
	return (not _rock_tiles.is_empty() and _rock_tiles[cell.y][cell.x] == 1) if _is_in_map(cell) else _world_rock_overrides.has(cell)


func is_walkable(cell: Vector2i) -> bool:
	return (is_grass(cell) or is_bridge(cell)) and not is_rock(cell)


func is_archer_traversable(cell: Vector2i) -> bool:
	# A full tile containing sea or a brazier is excluded from field propagation.
	return _is_in_map(cell) and is_walkable(cell) and not is_brazier(cell)


func get_archer_navigation_direction(world_position: Vector2, force_reposition := false) -> Vector2:
	var cell := _world_to_cell(world_position)
	if _archer_potential.is_empty() or not _is_in_map(cell):
		return Vector2.ZERO
	if _is_archer_too_close(cell):
		return _get_archer_retreat_direction(cell)
	var current_value := _get_archer_potential(cell)
	if current_value < 0:
		return Vector2.ZERO
	if current_value == 0:
		return _get_archer_reposition_direction(cell) if force_reposition else Vector2.ZERO
	var best_cell := cell
	var best_value := current_value
	for direction_index in CARDINAL_DIRECTIONS.size():
		var direction: Vector2i = CARDINAL_DIRECTIONS[direction_index]
		var neighbor: Vector2i = cell + direction
		var neighbor_value := _get_archer_potential(neighbor)
		if neighbor_value >= 0 and neighbor_value < best_value:
			best_value = neighbor_value
			best_cell = neighbor
	if best_cell == cell:
		return Vector2.ZERO
	return Vector2(best_cell - cell).normalized()


func get_swordsman_navigation_direction(world_position: Vector2) -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	var to_player := player.global_position - world_position
	if to_player.length() < SwordWeapon.MOUNT_OFFSET:
		return -to_player.normalized()
	return get_experience_navigation_direction(world_position)
func get_experience_navigation_direction(world_position: Vector2) -> Vector2:
	var cell := _world_to_cell(world_position)
	if _experience_potential.is_empty() or not _is_in_map(cell):
		return Vector2.ZERO
	var current_value := _get_experience_potential(cell)
	if current_value <= 0:
		return Vector2.ZERO
	var best_cell := cell
	var best_value := current_value
	for raw_direction in CARDINAL_DIRECTIONS:
		var direction: Vector2i = raw_direction
		var neighbor: Vector2i = cell + direction
		var neighbor_value := _get_experience_potential(neighbor)
		if neighbor_value >= 0 and neighbor_value < best_value:
			best_value = neighbor_value
			best_cell = neighbor
	return Vector2(best_cell - cell).normalized() if best_cell != cell else Vector2.ZERO
func get_unblocked_movement_direction(
	body: CharacterBody2D,
	desired_direction: Vector2,
	speed: float,
	delta: float
) -> Vector2:
	if desired_direction.is_zero_approx():
		return Vector2.ZERO
	var requested := desired_direction.normalized()
	var probe_distance := maxf(8.0, speed * maxf(delta, 1.0 / 60.0))
	var left := requested.orthogonal()
	var candidates: Array[Vector2] = [
		left, -left, -requested,
		requested.rotated(PI * 0.25), requested.rotated(-PI * 0.25),
		requested.rotated(PI * 0.5), requested.rotated(-PI * 0.5),
		requested.rotated(PI * 0.75), requested.rotated(-PI * 0.75),
	]
	for candidate in candidates:
		if not body.test_move(body.global_transform, candidate * probe_distance):
			return candidate
	return requested

func get_obstacle_sliding_direction(
	world_position: Vector2,
	desired_direction: Vector2,
	body: CollisionObject2D
) -> Vector2:
	if desired_direction.is_zero_approx():
		return Vector2.ZERO
	var probe_distance := 48.0
	var closest_distance := INF
	var closest_normal := Vector2.ZERO
	var probe_angles: Array[float] = [-0.55, 0.0, 0.55]
	for probe_angle in probe_angles:
		var probe_direction := desired_direction.rotated(probe_angle).normalized()
		var query := PhysicsRayQueryParameters2D.create(
			world_position,
			world_position + probe_direction * probe_distance,
			11
		)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [body.get_rid()]
		var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			continue
		var hit_position: Vector2 = result.position
		var distance := world_position.distance_to(hit_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_normal = result.normal
	if closest_normal.is_zero_approx():
		return desired_direction
	var tangent := closest_normal.orthogonal()
	if tangent.dot(desired_direction) < 0.0:
		tangent = -tangent
	var slide_weight := clampf(1.0 - closest_distance / probe_distance, 0.0, 1.0)
	slide_weight = maxf(0.35, slide_weight)
	return desired_direction.slerp(tangent, slide_weight).normalized()

func is_archer_firing_position(world_position: Vector2) -> bool:
	var cell := _world_to_cell(world_position)
	return _get_archer_potential(cell) == 0 and not _is_archer_too_close(cell)


func segment_touches_body(from_position: Vector2, to_position: Vector2, body: Node2D) -> bool:
	var collision_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or not collision_shape.shape is RectangleShape2D:
		return false
	var rectangle := collision_shape.shape as RectangleShape2D
	var half_size := rectangle.size * 0.5
	var body_polygon := PackedVector2Array([
		collision_shape.global_transform * Vector2(-half_size.x, -half_size.y),
		collision_shape.global_transform * Vector2(half_size.x, -half_size.y),
		collision_shape.global_transform * Vector2(half_size.x, half_size.y),
		collision_shape.global_transform * Vector2(-half_size.x, half_size.y),
	])
	var travel := to_position - from_position
	if travel.length_squared() < 0.001:
		return Geometry2D.is_point_in_polygon(from_position, body_polygon)
	var normal := travel.normalized().orthogonal()
	var segment_polygon := PackedVector2Array([
		from_position + normal, to_position + normal,
		to_position - normal, from_position - normal,
	])
	return not Geometry2D.intersect_polygons(segment_polygon, body_polygon).is_empty()

func has_clear_archer_line_of_fire(
	firing_position: Vector2,
	target_position: Vector2,
	archer: CollisionObject2D
) -> bool:
	var query := PhysicsRayQueryParameters2D.create(firing_position, target_position, 2)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.hit_from_inside = true
	if is_instance_valid(archer):
		query.exclude = [archer.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _rebuild_archer_potential_field() -> void:
	_archer_potential.clear()
	if not is_instance_valid(player):
		return
	_potential_player_cell = _world_to_cell(player.global_position)
	if not _is_in_map(_potential_player_cell):
		return
	var frontier: Array[Vector2i] = []
	var bounds := _get_navigation_bounds()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if not _is_archer_shooting_candidate(cell):
				continue
			_set_archer_potential(cell, 0)
			frontier.append(cell)
	var frontier_index := 0
	while frontier_index < frontier.size():
		var cell := frontier[frontier_index]
		frontier_index += 1
		var next_value := _get_archer_potential(cell) + 1
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if not _is_in_navigation_range(neighbor) or _get_archer_potential(neighbor) >= 0:
				continue
			if not is_archer_traversable(neighbor):
				continue
			_set_archer_potential(neighbor, next_value)
			frontier.append(neighbor)


func _rebuild_experience_potential_field() -> void:
	_experience_potential.clear()
	if not is_instance_valid(player) or not _is_in_map(_potential_player_cell):
		return
	_set_experience_potential(_potential_player_cell, 0)
	var frontier: Array[Vector2i] = [_potential_player_cell]
	var frontier_index := 0
	while frontier_index < frontier.size():
		var cell := frontier[frontier_index]
		frontier_index += 1
		var next_value := _get_experience_potential(cell) + 1
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if not _is_in_navigation_range(neighbor) or _get_experience_potential(neighbor) >= 0:
				continue
			if not is_archer_traversable(neighbor):
				continue
			_set_experience_potential(neighbor, next_value)
			frontier.append(neighbor)


func _get_navigation_bounds() -> Rect2i:
	var radius := navigation_field_radius_tiles
	var min_x := maxi(0, _potential_player_cell.x - radius)
	var min_y := maxi(0, _potential_player_cell.y - radius)
	var max_x := mini(map_width - 1, _potential_player_cell.x + radius)
	var max_y := mini(map_height - 1, _potential_player_cell.y + radius)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _is_in_navigation_range(cell: Vector2i) -> bool:
	return (
		_is_in_map(cell)
		and abs(cell.x - _potential_player_cell.x) <= navigation_field_radius_tiles
		and abs(cell.y - _potential_player_cell.y) <= navigation_field_radius_tiles
	)

func _is_archer_shooting_candidate(cell: Vector2i) -> bool:
	if not is_archer_traversable(cell):
		return false
	var tile_distance := Vector2(cell).distance_to(Vector2(_potential_player_cell))
	if (
		tile_distance <= float(archer_shoot_min_distance_tiles)
		or tile_distance > float(archer_shoot_max_distance_tiles)
	):
		return false
	return _has_clear_archer_shot(cell, _potential_player_cell)


func _is_archer_too_close(cell: Vector2i) -> bool:
	return Vector2(cell).distance_to(Vector2(_potential_player_cell)) <= float(archer_shoot_min_distance_tiles)


func _get_archer_retreat_direction(cell: Vector2i) -> Vector2:
	var best_cell := cell
	var best_distance := Vector2(cell).distance_squared_to(Vector2(_potential_player_cell))
	for direction_index in CARDINAL_DIRECTIONS.size():
		var direction: Vector2i = CARDINAL_DIRECTIONS[direction_index]
		var neighbor: Vector2i = cell + direction
		if not is_archer_traversable(neighbor):
			continue
		var distance := Vector2(neighbor).distance_squared_to(Vector2(_potential_player_cell))
		if distance > best_distance:
			best_distance = distance
			best_cell = neighbor
	if best_cell == cell:
		return Vector2.ZERO
	return Vector2(best_cell - cell).normalized()


func _get_archer_reposition_direction(cell: Vector2i) -> Vector2:
	var best_cell := cell
	var best_value := 1 << 30
	for direction in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if not is_archer_traversable(neighbor):
			continue
		var neighbor_value := _get_archer_potential(neighbor)
		if neighbor_value >= 0 and neighbor_value < best_value:
			best_value = neighbor_value
			best_cell = neighbor
	if best_cell == cell:
		return Vector2.ZERO
	return Vector2(best_cell - cell).normalized()


func _has_clear_archer_shot(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var x := from_cell.x
	var y := from_cell.y
	var delta_x: int = absi(to_cell.x - from_cell.x)
	var delta_y: int = -absi(to_cell.y - from_cell.y)
	var step_x: int = 1 if from_cell.x < to_cell.x else -1
	var step_y: int = 1 if from_cell.y < to_cell.y else -1
	var error: int = delta_x + delta_y
	while true:
		var cell := Vector2i(x, y)
		if cell != from_cell and cell != to_cell and (is_brazier(cell) or is_rock(cell)):
			return false
		if cell == to_cell:
			return true
		var doubled_error: int = error * 2
		if doubled_error >= delta_y:
			error += delta_y
			x += step_x
		if doubled_error <= delta_x:
			error += delta_x
			y += step_y
	return false


func _world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))


func _is_in_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_width and cell.y < map_height


func _get_archer_potential(cell: Vector2i) -> int:
	if not _is_in_navigation_range(cell):
		return -1
	return int(_archer_potential.get(cell, -1))


func _set_archer_potential(cell: Vector2i, value: int) -> void:
	_archer_potential[cell] = value


func _get_experience_potential(cell: Vector2i) -> int:
	if not _is_in_navigation_range(cell):
		return -1
	return int(_experience_potential.get(cell, -1))


func _set_experience_potential(cell: Vector2i, value: int) -> void:
	_experience_potential[cell] = value

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
func _build_external_combat_island(seed_value: int) -> void:
	_arena_tiles.clear()
	_external_island_cells.clear()
	var side: int = 1 if (seed_value & 1) == 0 else -1
	var best_shore := Vector2i(-1, -1)
	var best_score := -1
	for y in range(1, map_height - 3):
		var shore_x := -1
		for x in range(map_width):
			var cell := Vector2i(x, y)
			if is_grass(cell) and is_grass(cell + Vector2i.DOWN) and is_grass(cell + Vector2i.DOWN * 2):
				if side > 0 or shore_x < 0:
					shore_x = x
		if shore_x < 0:
			continue
		var score: int = shore_x if side > 0 else map_width - 1 - shore_x
		if score > best_score:
			best_score = score
			best_shore = Vector2i(shore_x, y)
	if best_shore.x < 0:
		best_shore = Vector2i(map_width - 2 if side > 0 else 1, int(map_height / 2) - 1)

	# Flatten a three-tile mainland landing so the first bridge span genuinely starts on shore.
	for lane in range(3):
		for inset in range(3):
			set_world_grass(best_shore + Vector2i(-side * inset, lane), true)
	var shore_x := best_shore.x
	var bridge_y := best_shore.y
	for step in range(0, 13):
		for lane in range(3):
			set_world_bridge(Vector2i(shore_x + side * step, bridge_y + lane), BRIDGE_HORIZONTAL)

	var island_center := Vector2i(shore_x + side * 18, bridge_y + 1)
	for y_offset in range(-6, 7):
		for x_offset in range(-6, 7):
			var distance: int = abs(x_offset) + abs(y_offset)
			var variation: int = absi((x_offset * 92821) ^ (y_offset * 68917) ^ seed_value) % 3
			if distance <= 8 + variation:
				var island_cell := island_center + Vector2i(x_offset, y_offset)
				set_world_grass(island_cell, true)
				_external_island_cells[island_cell] = true
	for y_offset in range(-4, 5):
		for x_offset in range(-4, 5):
			_arena_tiles[island_center + Vector2i(x_offset, y_offset)] = true
	_external_bridge_rect = Rect2i(
		Vector2i(mini(shore_x, shore_x + side * 12), bridge_y),
		Vector2i(13, 3)
	)

func _clear_arrow_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("arrow_projectiles"):
		projectile.queue_free()


func _clear_archers() -> void:
	for archer in _archers:
		if is_instance_valid(archer):
			archer.queue_free()
	_archers.clear()


func _clear_swordsmen() -> void:
	for swordsman in _swordsmen:
		if is_instance_valid(swordsman):
			swordsman.queue_free()
	_swordsmen.clear()

func _clear_slimes() -> void:
	for slime in _slimes:
		if is_instance_valid(slime):
			slime.queue_free()
	_slimes.clear()

func _get_enemy_spawn_bounds() -> Rect2i:
	var camera := player.get_node("Camera2D") as Camera2D
	var visible_size := get_viewport_rect().size / camera.zoom
	var radius_x := ceili(visible_size.x / TILE_SIZE * 0.5) + 6
	var radius_y := ceili(visible_size.y / TILE_SIZE * 0.5) + 6
	var player_cell := _world_to_cell(player.global_position)
	var min_x := maxi(0, player_cell.x - radius_x)
	var min_y := maxi(0, player_cell.y - radius_y)
	var max_x := mini(map_width - 1, player_cell.x + radius_x)
	var max_y := mini(map_height - 1, player_cell.y + radius_y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _get_sharpshooter_spawn_chance() -> float:
	if player.level < 3 or _sharpshooters.size() >= 1:
		return 0.0
	var base_chance := 0.5 if _sharpshooter_unlock_boost_active else sharpshooter_base_spawn_chance
	return minf(1.0, base_chance + sharpshooter_miss_bonus * _sharpshooter_miss_count)

func _try_spawn_archer() -> void:
	var viewport_size := get_viewport_rect().size
	var camera := player.get_node("Camera2D") as Camera2D
	var visible_size := viewport_size / camera.zoom
	var excluded_view := Rect2(
		player.position - visible_size * 0.5,
		visible_size
	).grow(TILE_SIZE * 1.5)

	var spawn_bounds := _get_enemy_spawn_bounds()
	for _attempt in 96:
		var cell := Vector2i(
			_enemy_rng.randi_range(spawn_bounds.position.x, spawn_bounds.end.x - 1),
			_enemy_rng.randi_range(spawn_bounds.position.y, spawn_bounds.end.y - 1)
		)
		if not is_grass(cell) or is_bridge(cell) or is_brazier(cell) or is_rock(cell):
			continue
		var spawn_position := (Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE
		if excluded_view.has_point(spawn_position):
			continue
		if _is_archer_spawn_occupied(spawn_position):
			continue
		var sharpshooter_chance := _get_sharpshooter_spawn_chance()
		var spawn_sharpshooter := sharpshooter_chance > 0.0 and _enemy_rng.randf() < sharpshooter_chance
		var spawn_scene: PackedScene = SHARPSHOOTER_SCENE if spawn_sharpshooter else ARCHER_SCENE
		if spawn_sharpshooter:
			_sharpshooter_miss_count = 0
			_sharpshooter_unlock_boost_active = false
		elif player.level >= 3 and _sharpshooters.is_empty():
			_sharpshooter_miss_count += 1
		var archer := spawn_scene.instantiate() as CharacterBody2D
		archer.call("configure", player, _enemy_rng.randi())
		archer.position = spawn_position
		add_child(archer, true)
		archer.connect("defeated", _on_enemy_defeated.bind(archer))
		_archers.append(archer)
		if archer is SharpshooterEnemy:
			_sharpshooters.append(archer)
		return

func _try_spawn_swordsman() -> void:
	var viewport_size := get_viewport_rect().size
	var camera := player.get_node("Camera2D") as Camera2D
	var visible_size := viewport_size / camera.zoom
	var excluded_view := Rect2(player.position - visible_size * 0.5, visible_size).grow(TILE_SIZE * 1.5)
	var spawn_bounds := _get_enemy_spawn_bounds()
	for _attempt in 96:
		var cell := Vector2i(
			_enemy_rng.randi_range(spawn_bounds.position.x, spawn_bounds.end.x - 1),
			_enemy_rng.randi_range(spawn_bounds.position.y, spawn_bounds.end.y - 1)
		)
		if not is_grass(cell) or is_bridge(cell) or is_brazier(cell) or is_rock(cell):
			continue
		var spawn_position := (Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE
		if excluded_view.has_point(spawn_position) or _is_archer_spawn_occupied(spawn_position):
			continue
		var swordsman := SWORDSMAN_SCENE.instantiate() as CharacterBody2D
		swordsman.call("configure", player, _enemy_rng.randi())
		swordsman.position = spawn_position
		add_child(swordsman, true)
		swordsman.connect("defeated", _on_enemy_defeated.bind(swordsman))
		_swordsmen.append(swordsman)
		return
func _try_spawn_slime() -> void:
	var viewport_size := get_viewport_rect().size
	var camera := player.get_node("Camera2D") as Camera2D
	var visible_size := viewport_size / camera.zoom
	var excluded_view := Rect2(player.position - visible_size * 0.5, visible_size).grow(TILE_SIZE * 1.5)
	var spawn_bounds := _get_enemy_spawn_bounds()
	for _attempt in 96:
		var cell := Vector2i(
			_enemy_rng.randi_range(spawn_bounds.position.x, spawn_bounds.end.x - 1),
			_enemy_rng.randi_range(spawn_bounds.position.y, spawn_bounds.end.y - 1)
		)
		if not is_grass(cell) or is_bridge(cell) or is_brazier(cell) or is_rock(cell):
			continue
		var spawn_position := (Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE
		if excluded_view.has_point(spawn_position) or _is_archer_spawn_occupied(spawn_position):
			continue
		var slime := SLIME_SCENE.instantiate() as CharacterBody2D
		slime.call("configure", player, _enemy_rng.randi())
		slime.position = spawn_position
		add_child(slime, true)
		slime.connect("defeated", _on_slime_defeated.bind(slime))
		_slimes.append(slime)
		return


func _on_slime_defeated(slime: Node2D) -> void:
	call_deferred("_spawn_enemy_experience", slime.global_position, 1)
	call_deferred("_try_spawn_health_pickup", slime.global_position)

func _on_enemy_defeated(enemy: Node2D) -> void:
	var experience_amount := 5 if enemy is SharpshooterEnemy else 2
	call_deferred("_spawn_enemy_experience", enemy.global_position, experience_amount)
	call_deferred("_try_spawn_health_pickup", enemy.global_position)

func _try_spawn_health_pickup(drop_position: Vector2) -> void:
	if _loot_rng.randf() >= health_drop_chance:
		return
	var pickup := HEALTH_PICKUP_SCENE.instantiate() as HealthPickup
	add_child(pickup, true)
	pickup.global_position = drop_position

func _spawn_enemy_experience(drop_position: Vector2, amount: int) -> void:
	var remaining := maxi(0, amount)
	while remaining >= 5:
		_spawn_experience_pickup(drop_position, 5)
		remaining -= 5
	for _index in range(remaining):
		_spawn_experience_pickup(drop_position, 1)


func _spawn_experience_pickup(drop_position: Vector2, value: int) -> void:
	var pickup := EXPERIENCE_PICKUP_SCENE.instantiate() as ExperiencePickup
	var angle: float = _experience_rng.randf_range(0.0, TAU)
	var speed: float = _experience_rng.randf_range(210.0, 370.0)
	pickup.configure(value, Vector2.from_angle(angle) * speed)
	add_child(pickup, true)
	pickup.global_position = drop_position

func _is_archer_spawn_occupied(spawn_position: Vector2) -> bool:
	for enemy in _archers + _swordsmen + _slimes:
		if not is_instance_valid(enemy):
			continue
		var offset := enemy.global_position - spawn_position
		if absf(offset.x) < 52.0 and absf(offset.y) < 52.0:
			return true
	return false


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
	camera.limit_left = -1000000
	camera.limit_top = -1000000
	camera.limit_right = 1000000
	camera.limit_bottom = 1000000
	camera.limit_smoothed = true
	camera.reset_smoothing()
	camera.force_update_scroll()

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
	_draw_rocks()

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
func _build_rocks(seed_value: int) -> void:
	_rock_tiles = _new_grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x4F6C5A91
	var candidates: Array[Vector2i] = []
	for y in range(2, map_height - 2):
		for x in range(2, map_width - 2):
			var cell := Vector2i(x, y)
			if _can_place_rock(cell):
				candidates.append(cell)
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: Vector2i = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary
	var origins: Array[Vector2i] = []
	for origin in candidates:
		if origins.size() >= rock_cluster_count:
			break
		var spacing_ok := true
		for other in origins:
			if origin.distance_squared_to(other) < 36.0:
				spacing_ok = false
				break
		if not spacing_ok:
			continue
		var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1)]
		var count: int = rng.randi_range(1, 4)
		var cluster: Array[Vector2i] = []
		for index in range(count):
			var cell := origin + offsets[index]
			if _can_place_rock(cell):
				cluster.append(cell)
		if cluster.is_empty():
			continue
		for cell in cluster:
			_rock_tiles[cell.y][cell.x] = 1
		origins.append(origin)

func _can_place_rock(cell: Vector2i) -> bool:
	if not _is_in_map(cell) or not is_grass(cell) or is_bridge(cell) or is_rock(cell):
		return false
	if _dock_cells.size.x > 0 and _dock_cells.grow(2).has_point(cell):
		return false
	for direction in CARDINAL_DIRECTIONS:
		if not is_grass(cell + direction):
			return false
	return true


func _rebuild_rock_collision() -> void:
	for child in rock_collision.get_children():
		child.free()
	for y in map_height:
		for x in map_width:
			if not is_rock(Vector2i(x, y)):
				continue
			var shape := RectangleShape2D.new()
			shape.size = Vector2.ONE * TILE_SIZE
			var collision := CollisionShape2D.new()
			collision.position = (Vector2(x, y) + Vector2.ONE * 0.5) * TILE_SIZE
			collision.shape = shape
			rock_collision.add_child(collision)


func _draw_rocks() -> void:
	for y in map_height:
		for x in map_width:
			var cell := Vector2i(x, y)
			if not is_rock(cell):
				continue
			var origin := Vector2(cell) * TILE_SIZE
			var has_rock_below := is_rock(cell + Vector2i.DOWN)
			var top_height: float = float(TILE_SIZE) if has_rock_below else float(TILE_SIZE) * 0.5
			draw_rect(Rect2(origin, Vector2(TILE_SIZE, top_height)), ROCK_TOP_COLOR, true, -1.0, false)
			if not has_rock_below:
				draw_rect(Rect2(origin + Vector2(0.0, top_height), Vector2(TILE_SIZE, TILE_SIZE - top_height)), ROCK_SIDE_COLOR, true, -1.0, false)
			_draw_rock_fragments(origin, cell)


func _draw_rock_fragments(origin: Vector2, cell: Vector2i) -> void:
	if not is_rock(cell + Vector2i.DOWN):
		_draw_rock_edge_fragments(origin, cell, Vector2i.DOWN, 5)
	if not is_rock(cell + Vector2i.LEFT):
		_draw_rock_edge_fragments(origin, cell, Vector2i.LEFT, 3)
	if not is_rock(cell + Vector2i.RIGHT):
		_draw_rock_edge_fragments(origin, cell, Vector2i.RIGHT, 3)
	if not is_rock(cell + Vector2i.UP):
		_draw_rock_edge_fragments(origin, cell, Vector2i.UP, 1)


func _draw_rock_edge_fragments(origin: Vector2, cell: Vector2i, edge: Vector2i, count: int) -> void:
	var hash: int = absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (edge.x * 83492791) ^ (edge.y * 265443576) ^ world_seed)
	for index in range(count):
		var distance_from_edge: float = 2.0 + float((hash >> (index * 3)) & 3) + float(index) * 2.0
		var size: float = maxf(3.0, 8.0 - float(index) * 0.85)
		var along: float = (float(index + 1) / float(count + 1)) * TILE_SIZE + float((hash >> (index * 4 + 8)) % 9) - 4.0
		var position := origin
		if edge == Vector2i.DOWN:
			position += Vector2(along, TILE_SIZE + distance_from_edge)
		elif edge == Vector2i.UP:
			position += Vector2(along, -distance_from_edge - size)
		elif edge == Vector2i.LEFT:
			position += Vector2(-distance_from_edge - size, along)
		else:
			position += Vector2(TILE_SIZE + distance_from_edge, along)
		draw_rect(Rect2(position, Vector2(size, size * 0.7)), ROCK_TOP_COLOR, true, -1.0, false)
		draw_rect(Rect2(position + Vector2(0.0, size * 0.7), Vector2(size, maxf(2.0, size * 0.3))), ROCK_SIDE_COLOR, true, -1.0, false)