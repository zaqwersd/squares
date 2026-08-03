class_name IslandMap
extends Node2D

const TILE_SIZE := 64
const CHUNK_SIZE_TILES := 16
const COASTAL_OCEAN_COLOR := Color("#7DDEFA")
const OCEAN_COLOR := Color("#42CAFD")
const MID_OCEAN_COLOR := Color("#2B9FCB")
const DEEP_OCEAN_COLOR := Color("#247EAE")
const GRASS_COLOR := Color("#7BE0AD")
const DESERT_COLOR := Color("#FBF2C0")
const DESERT_SIDE_COLOR := Color("#CEC69F")
const SAVANNA_COLOR := Color("#B7D887")
const SAVANNA_SIDE_COLOR := Color("#91AD6D")
const ROCK_TOP_COLOR := Color("#C2C2C2")
const ROCK_SIDE_COLOR := Color("#9F9F9F")
const SHADOW_COLOR := Color("#61A289")
const ARENA_TILE_COLOR := Color("#D7D8D2")
const ARENA_SIDE_COLOR := Color("#9F9F9F")
const ARENA_BRICK_COLOR := Color("#C1C4BB")
const RUNE_STONE_COLOR := Color("#D7D8D2")
const RUNE_LINE_COLOR := Color("#A5AAA0")
const RUNE_INNER_COLOR := Color("#BEC3B8")
const MOSS_COLOR := Color("#6E9D62")
const VINE_COLOR := Color("#568452")
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
const SPEAR_THROWER_SCENE := preload("res://spear_thrower.tscn")
const SHARPSHOOTER_SCENE := preload("res://sharpshooter.tscn")
const SWORDSMAN_SCENE := preload("res://swordsman.tscn")
const SLIME_SCENE := preload("res://slime.tscn")
const SWORDMASTER_SCENE := preload("res://swordmaster.tscn")
const EXPERIENCE_PICKUP_SCENE := preload("res://experience_pickup.tscn")
const HEALTH_PICKUP_SCENE := preload("res://health_pickup.tscn")
const SLIME_KING_SCENE := preload("res://slime_king.tscn")
const ARENA_SEAL_SCRIPT := preload("res://arena_seal.gd")
const WEAPON_PICKUP_SCENE := preload("res://weapon_pickup.tscn")
const TREASURE_CHEST_SCENE := preload("res://treasure_chest.tscn")
const WATER_FALL_EFFECT := preload("res://water_fall_effect.gd")
const WATER_FALL_DURATION := 2.0

const BRIDGE_NONE := 0
const BRIDGE_HORIZONTAL := 1
const BRIDGE_VERTICAL := 2
const CARDINAL_DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const EIGHT_DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i.UP, Vector2i(1, -1),
	Vector2i.LEFT, Vector2i.RIGHT,
	Vector2i(-1, 1), Vector2i.DOWN, Vector2i(1, 1),
]

@export_group("Map")
@export_range(5, 512, 1, "or_greater") var map_width := 20
@export_range(5, 512, 1, "or_greater") var map_height := 12
@export var world_seed := 13579

@export_group("Island Shape")
@export_range(0.0, 1.0, 0.01) var island_size := 0.58
@export_range(0.02, 0.3, 0.005) var coast_noise_frequency := 0.115
@export_range(1, 8, 1) var coast_noise_octaves := 4
@export_range(0.0, 0.5, 0.01) var coast_irregularity := 0.28

@export_group("Desert Biome")
@export_range(2, 80, 1) var desert_transition_width := 48
@export_range(0.0, 16.0, 0.5) var desert_boundary_variation := 4.0
@export_group("Dock")
@export_range(1, 15, 1) var dock_width := 3
@export_range(2, 30, 1) var dock_length := 6

@export_group("External Arena")
@export var external_arena_enabled := true
@export_range(1, 5, 1) var external_bridge_width := 3
@export_range(6, 32, 1) var external_bridge_length := 20
@export_range(7, 15, 2) var external_arena_size := 11

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

@export_group("Chunk Streaming")
@export_range(0, 4, 1) var active_chunk_radius := 1 # Center chunk plus its eight neighbors.

@export_group("Rendering")
@export_range(16, 128, 1) var infinite_render_distance_tiles := 40
@export_range(1, 12, 1) var coast_width := 5

@export_group("Enemies")
@export_range(0, 64, 1) var max_archers := 2
@export_range(0, 8, 1) var max_spear_throwers := 2
@export_range(0.0, 1.0, 0.01) var fire_spear_thrower_spawn_chance := 0.10
@export_range(0, 99, 1) var fire_spear_thrower_unlock_kills := 3
@export_range(0, 64, 1) var max_total_enemies := 10
@export_range(0.1, 5.0, 0.1) var enemy_spawn_min_interval := 0.5
@export_range(0.5, 20.0, 0.1) var enemy_spawn_near_capacity_interval := 3.0
@export_range(0.0, 1.0, 0.01) var health_drop_chance := 0.2
@export_range(2.0, 8.0, 0.5) var archer_shoot_min_distance_tiles := 3.5
@export_range(3.0, 12.0, 0.5) var archer_shoot_max_distance_tiles := 4.5
@export_range(0, 64, 1) var max_swordsmen := 3
@export_range(0, 64, 1) var max_slimes := 5
@export_range(8, 64, 1) var navigation_field_radius_tiles := 20
@export_range(0.05, 1.0, 0.01) var potential_rebuild_interval := 0.25
@export_range(1.0, 30.0, 0.5) var offscreen_enemy_despawn_delay := 7.0
@export_range(0.0, 1.0, 0.01) var sharpshooter_base_spawn_chance := 0.10
@export_range(0.0, 1.0, 0.01) var sharpshooter_miss_bonus := 0.10
@export_range(0, 99, 1) var advanced_enemy_unlock_kills := 6
@export_range(0, 99, 1) var sharpshooter_unlock_archer_kills := 4
@export var spawn_debug_killer_spear := true

var _tiles: Array[PackedByteArray] = []
var _desert_tiles: Array[PackedByteArray] = []
var _savanna_tiles: Array[PackedByteArray] = []
# Sparse global overrides make the world logically unbounded; absent cells are deep ocean.
var _world_tile_overrides: Dictionary = {} # Vector2i -> 0 ocean, 1 grass
var _world_bridge_overrides: Dictionary = {} # Vector2i -> bridge orientation
var _world_rock_overrides: Dictionary = {} # Vector2i -> true
var _arena_tiles: Dictionary = {} # Vector2i -> true
var _arena_center := Vector2i(-1, -1)
var _arena_bounds := Rect2i() # Generated arena footprint; never recompute it from live inspector values.
var _external_island_cells: Dictionary = {} # Vector2i -> true
var _external_bridge_rect := Rect2i()
var _external_ocean_depth: Dictionary = {} # Vector2i -> normalized depth
var _external_land_depth_sources: Array[Vector2i] = []
var _external_mainland_landing := Vector2i(-1, -1)
var _bridge_tiles: Array[PackedByteArray] = []
var _rock_tiles: Array[PackedByteArray] = []
var _deep_ocean_tiles: Array[PackedByteArray] = []
var _ocean_depth: Array[PackedFloat32Array] = []
var _ocean_mesh: ArrayMesh
var _active_chunk := Vector2i(2147483647, 2147483647)
var _active_tile_bounds := Rect2i()
var _terrain_collision_pool: Array[CollisionShape2D] = []
var _terrain_block_rects: Array[Rect2] = []
var _dock_cells := Rect2i()
var _dock_spawn_cell := Vector2i(-1, -1)
var _braziers: Array[Node2D] = []
var _brazier_cells: Array[Vector2i] = []
var _archers: Array[Node2D] = []
var _normal_archer_kills := 0
var _spear_throwers: Array[Node2D] = []
var _normal_spear_thrower_kills := 0
var _swordsmen: Array[Node2D] = []
var _normal_swordsman_kills := 0
var _slimes: Array[Node2D] = []
var _sharpshooters: Array[Node2D] = []
var _swordmasters: Array[Node2D] = []
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
var _swordmaster_miss_count := 0
var _potential_player_cell := Vector2i(-1, -1)
var _game_over := false
var _enemy_spawning_started := false
var _boss_triggered := false
var _slime_king: CharacterBody2D
var _arena_seal: Node2D
var _debug_killer_spear: Node2D
var _boss_chest: Node2D
var _water_falling_actor_ids: Dictionary = {}

@onready var terrain_collision: StaticBody2D = $TerrainCollision
@onready var rock_collision: StaticBody2D = $RockCollision
@onready var player_shadow: Node2D = $PlayerShadow
@onready var player: IslandPlayer = $Player
@onready var game_over_panel: GameOverPanel = $HUD/GameOverPanel
@onready var boss_health_bar: Control = $HUD/BossHealthBar
@onready var chest_reveal_overlay: Control = $HUD/ChestRevealOverlay
@onready var boss_reward_panel: Control = $HUD/BossRewardPanel


func _ready() -> void:
	player.died.connect(_on_player_died)
	boss_reward_panel.connect("reward_selected", _on_boss_reward_selected)
	generate(world_seed)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P):
		return
	if _game_over or boss_reward_panel.visible:
		return
	boss_reward_panel.call("show_choices")
	get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if _game_over or _tiles.is_empty():
		return
	_refresh_active_region()
	var player_cell := _world_to_cell(player.global_position)
	if not _boss_triggered and player_cell == _arena_center:
		_begin_slime_king_encounter()

	_potential_rebuild_elapsed += delta
	if (
		_potential_rebuild_elapsed >= potential_rebuild_interval
		and player_cell.distance_squared_to(_potential_player_cell) >= 4
	):
		_rebuild_archer_potential_field()
		_rebuild_experience_potential_field()
		_potential_rebuild_elapsed = 0.0
	_enemy_visibility_elapsed += delta
	if _enemy_visibility_elapsed >= 0.5:
		_cleanup_offscreen_enemies(_enemy_visibility_elapsed)
		_enemy_visibility_elapsed = 0.0
	_prune_enemy_list(_archers)
	_prune_enemy_list(_spear_throwers)
	_prune_enemy_list(_swordsmen)
	_prune_enemy_list(_slimes)
	_prune_enemy_list(_sharpshooters)
	_prune_enemy_list(_swordmasters)
	_update_water_fall_hazards()
	if is_external_combat_area(player_cell):
		return
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
func get_arena_world_center() -> Vector2:
	return (Vector2(_arena_center) + Vector2.ONE * 0.5) * TILE_SIZE

func _begin_slime_king_encounter() -> void:
	if _boss_triggered or _arena_bounds.size.x <= 0 or _arena_bounds.size.y <= 0:
		return
	_boss_triggered = true
	var arena_bounds := _arena_bounds
	var corner_cells: Array[Vector2i] = [
		arena_bounds.position,
		Vector2i(arena_bounds.end.x - 1, arena_bounds.position.y),
		Vector2i(arena_bounds.position.x, arena_bounds.end.y - 1),
		arena_bounds.end - Vector2i.ONE,
	]
	for brazier in _braziers:
		if is_instance_valid(brazier) and corner_cells.has(_world_to_cell(brazier.global_position)):
			brazier.call("set_sealed", true)
	_arena_seal = ARENA_SEAL_SCRIPT.new() as Node2D
	_arena_seal.call("configure", player, arena_bounds, corner_cells)
	add_child(_arena_seal)
	_slime_king = SLIME_KING_SCENE.instantiate() as CharacterBody2D
	_slime_king.call("configure", player, world_seed ^ 0x5B055)
	_slime_king.global_position = (Vector2(_arena_center) + Vector2.ONE * 0.5) * TILE_SIZE
	_slime_king.defeated.connect(_on_slime_king_defeated)
	add_child(_slime_king)
	_slime_king.call("summon")
	boss_health_bar.watch(_slime_king)

func _on_slime_king_defeated() -> void:
	var drop_position := _slime_king.global_position if is_instance_valid(_slime_king) else (Vector2(_arena_center) + Vector2.ONE * 0.5) * TILE_SIZE
	call_deferred("_spawn_boss_experience", drop_position)
	call_deferred("_spawn_slime_king_chest", drop_position)
	if is_instance_valid(_arena_seal):
		_arena_seal.queue_free()
		_arena_seal = null
	for brazier in _braziers:
		if is_instance_valid(brazier):
			brazier.call("set_sealed", false)
	boss_health_bar.clear_boss()
func _spawn_slime_king_chest(drop_position: Vector2) -> void:
	if is_instance_valid(_boss_chest):
		_boss_chest.queue_free()
	var chest := TREASURE_CHEST_SCENE.instantiate() as TreasureChest
	add_child(chest, true)
	chest.global_position = drop_position
	chest.opening_started.connect(_on_boss_chest_opening.bind(chest))
	chest.opening_finished.connect(_on_boss_chest_opened)
	_boss_chest = chest


func _on_boss_chest_opening(chest: Node2D) -> void:
	if not is_instance_valid(chest):
		return
	var screen_position := get_viewport().get_canvas_transform() * chest.global_position
	chest_reveal_overlay.call("begin_opening", screen_position)


func _on_boss_chest_opened() -> void:
	chest_reveal_overlay.call("begin_panel")
	boss_reward_panel.call("show_choices")

func _on_boss_reward_selected(reward_id: int) -> void:
	player.grant_slime_reward(reward_id)
	chest_reveal_overlay.call("release_panel")

func _active_enemy_count() -> int:
	return _archers.size() + _spear_throwers.size() + _swordsmen.size() + _slimes.size()

func _get_enemy_spawn_interval() -> float:
	if max_total_enemies <= 0:
		return enemy_spawn_near_capacity_interval
	var saturation := clampf(float(_active_enemy_count()) / float(max_total_enemies), 0.0, 1.0)
	return lerpf(enemy_spawn_min_interval, enemy_spawn_near_capacity_interval, saturation * saturation)


func _spawn_weighted_enemy() -> void:
	_spawn_first_enemy()

func _spawn_first_enemy() -> void:
	var player_cell := _world_to_cell(player.global_position)
	if is_desert(player_cell):
		if _spear_throwers.size() < max_spear_throwers:
			_try_spawn_spear_thrower()
		return
	if is_savanna(player_cell) and _spear_throwers.size() < max_spear_throwers and _enemy_rng.randf() < 0.2:
		var spear_count_before: int = _spear_throwers.size()
		_try_spawn_spear_thrower()
		if _spear_throwers.size() > spear_count_before:
			return
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
	for enemy in _archers + _spear_throwers + _swordsmen + _slimes:
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
	_boss_triggered = false
	if is_instance_valid(_slime_king):
		_slime_king.queue_free()
	_slime_king = null
	if is_instance_valid(_arena_seal):
		_arena_seal.queue_free()
	_arena_seal = null
	if is_instance_valid(_boss_chest):
		_boss_chest.queue_free()
	_boss_chest = null
	boss_health_bar.clear_boss()
	_clear_archers()
	_clear_spear_throwers()
	_clear_swordsmen()
	_clear_slimes()
	_sharpshooters.clear()
	_swordmasters.clear()
	_sharpshooter_miss_count = 0
	_swordmaster_miss_count = 0
	if is_instance_valid(_debug_killer_spear):
		_debug_killer_spear.queue_free()
	_debug_killer_spear = null
	_enemy_offscreen_seconds.clear()
	_normal_spear_thrower_kills = 0
	_normal_archer_kills = 0
	_normal_swordsman_kills = 0
	_clear_arrow_projectiles()
	_clear_player_allies()
	world_seed = seed_value
	boss_reward_panel.call("set_reward_seed", seed_value)
	_enemy_rng.seed = seed_value ^ 0x5A17E4
	_experience_rng.seed = seed_value ^ 0x3E9B71
	_loot_rng.seed = seed_value ^ 0x19C4D2
	# Independent seeded offsets make the first encounter type vary with the map seed.
	_enemy_spawn_elapsed = 0.0
	_world_tile_overrides.clear()
	_world_bridge_overrides.clear()
	_world_rock_overrides.clear()
	_arena_tiles.clear()
	_arena_center = Vector2i(-1, -1)
	_arena_bounds = Rect2i()
	_external_island_cells.clear()
	_external_ocean_depth.clear()
	_external_land_depth_sources.clear()
	_external_bridge_rect = Rect2i()
	_external_mainland_landing = Vector2i(-1, -1)
	_tiles = _create_island(seed_value)
	_build_south_dock()
	# The dock pass can fill diagonal mainland corners, so classify biomes afterwards.
	_build_desert_biome(seed_value)
	_build_external_combat_island(seed_value)
	_build_rocks(seed_value)
	_build_deep_ocean(seed_value)
	_ensure_arena_floor()
	_rebuild_rock_collision()
	_place_player()
	_refresh_active_region(true)
	player.play_spawn_animation()
	_place_dock_braziers()
	_spawn_debug_killer_spear()
	_potential_player_cell = Vector2i(-1, -1)
	_rebuild_archer_potential_field()
	_rebuild_experience_potential_field()
	queue_redraw()
	player_shadow.queue_redraw()


func _spawn_debug_killer_spear() -> void:
	if not spawn_debug_killer_spear or not is_instance_valid(player):
		return
	var spear := WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
	spear.configure_weapon(WeaponPickup.WeaponType.KILLER_SPEAR, true)
	add_child(spear, true)
	spear.global_position = player.global_position + Vector2(TILE_SIZE * 1.25, 0.0)
	_debug_killer_spear = spear

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


func is_desert(cell: Vector2i) -> bool:
	return _is_in_map(cell) and not _desert_tiles.is_empty() and _desert_tiles[cell.y][cell.x] == 1


func is_savanna(cell: Vector2i) -> bool:
	return _is_in_map(cell) and not _savanna_tiles.is_empty() and _savanna_tiles[cell.y][cell.x] == 1 and not is_desert(cell)


func get_land_top_color(cell: Vector2i) -> Color:
	if is_desert(cell):
		return DESERT_COLOR
	return SAVANNA_COLOR if is_savanna(cell) else GRASS_COLOR


func get_land_side_color(cell: Vector2i) -> Color:
	if is_desert(cell):
		return DESERT_SIDE_COLOR
	return SAVANNA_SIDE_COLOR if is_savanna(cell) else SHADOW_COLOR

func is_bridge(cell: Vector2i) -> bool:
	if _is_in_map(cell):
		return not _bridge_tiles.is_empty() and _bridge_tiles[cell.y][cell.x] != BRIDGE_NONE
	return int(_world_bridge_overrides.get(cell, BRIDGE_NONE)) != BRIDGE_NONE


func _set_mainland_grass_biome(cell: Vector2i) -> void:
	if not _is_in_map(cell):
		return
	_desert_tiles[cell.y][cell.x] = 0
	_savanna_tiles[cell.y][cell.x] = 0

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


func is_arena_tile(cell: Vector2i) -> bool:
	return _arena_tiles.has(cell)


func is_walkable(cell: Vector2i) -> bool:
	return (is_grass(cell) or is_bridge(cell)) and not is_rock(cell)


func is_water_hazard_cell(cell: Vector2i) -> bool:
	return not is_walkable(cell) and not is_rock(cell) and not is_brazier(cell)


func actor_jump_direction_blocked(world_position: Vector2, direction: Vector2, distance: float, body: CollisionObject2D) -> bool:
	if direction.is_zero_approx():
		return false
	var steps := maxi(2, ceili(distance / (TILE_SIZE * 0.35)))
	for step in range(1, steps + 1):
		var sample_position := world_position + direction.normalized() * distance * float(step) / float(steps)
		if is_water_hazard_cell(_world_to_cell(sample_position)):
			return true
	var query := PhysicsRayQueryParameters2D.create(world_position, world_position + direction.normalized() * distance, 3)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.hit_from_inside = false
	if is_instance_valid(body):
		query.exclude = [body.get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _update_water_fall_hazards() -> void:
	var actors: Array[Node] = []
	if is_instance_valid(player):
		actors.append(player)
	actors.append_array(get_tree().get_nodes_in_group("player_allies"))
	actors.append_array(get_tree().get_nodes_in_group("enemies"))
	for actor in actors:
		var actor_body := actor as CharacterBody2D
		if not is_instance_valid(actor_body) or actor_body.is_queued_for_deletion():
			continue
		var actor_id := actor_body.get_instance_id()
		if _water_falling_actor_ids.has(actor_id):
			continue
		if _actor_fully_in_water(actor_body):
			_handle_actor_fall_in_water(actor_body)


func _actor_fully_in_water(actor: CharacterBody2D) -> bool:
	var collision_shape := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var half_size := Vector2(14.0, 14.0)
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		half_size = (collision_shape.shape as RectangleShape2D).size * 0.5 - Vector2.ONE * 2.0
		half_size.x = maxf(4.0, half_size.x)
		half_size.y = maxf(4.0, half_size.y)
	for corner in [Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y), Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y)]:
		if not is_water_hazard_cell(_world_to_cell(actor.global_position + corner)):
			return false
	return true


func _handle_actor_fall_in_water(actor: CharacterBody2D) -> void:
	var actor_id := actor.get_instance_id()
	_water_falling_actor_ids[actor_id] = true
	_spawn_water_fall_effect(actor.global_position)
	actor.velocity = Vector2.ZERO
	actor.set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(actor, "modulate:a", 0.0, 0.28)
	tween.tween_interval(maxf(0.0, WATER_FALL_DURATION - 0.28))
	tween.tween_callback(_finish_actor_fall_in_water.bind(actor, actor_id))


func _finish_actor_fall_in_water(actor: CharacterBody2D, actor_id: int) -> void:
	if not is_instance_valid(actor):
		_release_water_fall_actor(actor_id)
		return
	var safe_position := _find_nearest_safe_position(actor.global_position)
	if actor.has_method("take_true_damage"):
		actor.call("take_true_damage", 5)
	elif actor.has_method("take_damage"):
		actor.call("take_damage", 5)
	actor.global_position = safe_position
	actor.velocity = Vector2.ZERO
	actor.modulate.a = 1.0
	actor.set_physics_process(true)
	_release_water_fall_actor(actor_id)


func _release_water_fall_actor(actor_id: int) -> void:
	_water_falling_actor_ids.erase(actor_id)


func _spawn_water_fall_effect(world_position: Vector2) -> void:
	var effect := WATER_FALL_EFFECT.new() as Node2D
	effect.call("configure", world_seed ^ int(world_position.x) ^ int(world_position.y))
	add_child(effect)
	effect.global_position = world_position


func _find_nearest_safe_position(world_position: Vector2) -> Vector2:
	var origin := _world_to_cell(world_position)
	if is_walkable(origin):
		return (Vector2(origin) + Vector2.ONE * 0.5) * TILE_SIZE
	for radius in range(1, 18):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				if abs(x - origin.x) != radius and abs(y - origin.y) != radius:
					continue
				var cell := Vector2i(x, y)
				if is_walkable(cell):
					return (Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE
	return get_arena_world_center() if _arena_center.x >= 0 else Vector2.ZERO

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


func get_enemy_target(enemy_position: Vector2, current_target: Variant = null) -> Node2D:
	var best_target: Node2D = player if is_instance_valid(player) else null
	var best_score := INF
	if best_target != null:
		best_score = enemy_position.distance_squared_to(best_target.global_position)
	for ally in get_tree().get_nodes_in_group("player_allies"):
		var ally_node := ally as Node2D
		if not is_instance_valid(ally_node) or not ally_node.has_method("take_damage"):
			continue
		var score := enemy_position.distance_squared_to(ally_node.global_position) * 0.65
		if score < best_score:
			best_score = score
			best_target = ally_node
	if is_instance_valid(current_target) and current_target is Node2D and current_target != best_target:
		var current_node: Node2D = current_target
		var current_score := enemy_position.distance_squared_to(current_node.global_position)
		if current_node.is_in_group("player_allies"):
			current_score *= 0.65
		if current_score <= best_score * 1.2:
			return current_node
	return best_target

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
	if not _is_in_map(cell):
		return float(_external_ocean_depth.get(cell, 1.0)) >= 0.9
	return (
		not _deep_ocean_tiles.is_empty()
		and _deep_ocean_tiles[cell.y][cell.x] == 1
	)


func get_ocean_color(cell: Vector2i) -> Color:
	if not _is_in_map(cell):
		return _ocean_color_from_depth(float(_external_ocean_depth.get(cell, 1.0)))
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
	# Preserve the old rounded grass-island profile in the south, then overlap a
	# matching northern lobe for the desert instead of slicing one tall ellipse in half.
	var lobe_radius_y := map_height * 0.42
	var grass_center_y := map_height * 0.64
	var desert_center_y := map_height * 0.31
	for y in map_height:
		for x in map_width:
			var nx := (float(x) + 0.5 - map_width * 0.5) / (map_width * 0.5)
			var grass_ny := (float(y) + 0.5 - grass_center_y) / lobe_radius_y
			var desert_ny := (float(y) + 0.5 - desert_center_y) / lobe_radius_y
			var grass_distance := sqrt(nx * nx + grass_ny * grass_ny)
			var desert_distance := sqrt(nx * nx + desert_ny * desert_ny)
			var distance := minf(grass_distance, desert_distance)
			var falloff := 1.0 - pow(distance, 1.55)
			var south_smooth := lerpf(1.0, 0.45, smoothstep(map_height * 0.62, map_height * 0.92, float(y)))
			var coast_noise := noise.get_noise_2d(x, y) * coast_irregularity * south_smooth
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
	mainland = _fill_diagonal_land_corners(mainland, 2)
	mainland = _fill_small_water_notches(mainland, 2)
	mainland = _fill_enclosed_water(mainland)
	return mainland



func _build_desert_biome(seed_value: int) -> void:
	_desert_tiles = _new_grid()
	_savanna_tiles = _new_grid()
	var boundary_noise := FastNoiseLite.new()
	boundary_noise.seed = seed_value ^ 0x6D2B79F5
	boundary_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	boundary_noise.frequency = 0.09
	boundary_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	boundary_noise.fractal_octaves = 3
	var patch_noise := FastNoiseLite.new()
	patch_noise.seed = seed_value ^ 0x13579BDF
	patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	patch_noise.frequency = 0.19
	patch_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	patch_noise.fractal_octaves = 2
	for y in map_height:
		for x in map_width:
			if _tiles[y][x] != 1:
				continue
			var boundary_y := map_height * 0.5 + boundary_noise.get_noise_2d(x, 0.0) * desert_boundary_variation
			var local_variation := patch_noise.get_noise_2d(x, y)
			var desert_edge := boundary_y + local_variation * 1.25
			var savanna_edge := boundary_y + float(desert_transition_width) + local_variation * 2.5
			if float(y) <= desert_edge:
				_desert_tiles[y][x] = 1
			elif float(y) <= savanna_edge:
				_savanna_tiles[y][x] = 1

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
	var used_fallback := false
	var platform_width := mini(map_width, maxi(5, actual_width + 2))
	var map_center_x := map_width * 0.5
	for y in range(max_shore_y, -1, -1):
		var best_row_x := -1
		var best_distance := INF
		for candidate_x in range(0, map_width - platform_width + 1):
			var connected := true
			for offset in platform_width:
				if (
					not is_grass(Vector2i(candidate_x + offset, y))
					or is_grass(Vector2i(candidate_x + offset, y + 1))
				):
					connected = false
					break
			if not connected:
				continue
			var candidate_center := candidate_x + platform_width * 0.5
			var distance := absf(candidate_center - map_center_x)
			if distance < best_distance:
				best_distance = distance
				best_row_x = candidate_x
		if best_row_x >= 0:
			start_x = best_row_x + int((platform_width - actual_width) / 2)
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
		used_fallback = true
		start_x = clampi(anchor_x - int(actual_width / 2), 0, map_width - actual_width)
		shore_y = mini(bottom_y, max_shore_y)
		for pad_y in range(maxi(0, shore_y - 1), shore_y + 1):
			for x in range(start_x, start_x + actual_width):
				_tiles[pad_y][x] = 1


	var platform_center_x := start_x + int(actual_width / 2)
	var platform_start_x := clampi(
		platform_center_x - int(platform_width / 2),
		0,
		map_width - platform_width
	)
	# A small taper keeps the wide, walkable shore from reading as a hard-added dock pad.
	if not used_fallback:
		for taper_x in range(
			maxi(0, platform_start_x - 1),
			mini(map_width, platform_start_x + platform_width + 1)
		):
			_tiles[maxi(0, shore_y - 1)][taper_x] = 1
		for taper_x in range(platform_start_x, platform_start_x + platform_width):
			_tiles[maxi(0, shore_y - 2)][taper_x] = 1

	var water_start_y := shore_y + 1
	if used_fallback:
		for platform_y in range(maxi(0, shore_y - 1), shore_y + 1):
			for platform_x in range(platform_start_x, platform_start_x + platform_width):
				_tiles[platform_y][platform_x] = 1
		if water_start_y < map_height:
			for platform_x in range(platform_start_x, platform_start_x + platform_width):
				_tiles[water_start_y][platform_x] = 0
		_tiles = _fill_diagonal_land_corners(_tiles, 1)

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
	if not external_arena_enabled:
		return
	var side: int = 1 if (seed_value & 1) == 0 else -1
	var bridge_width := maxi(1, external_bridge_width)
	if bridge_width % 2 == 0:
		bridge_width -= 1
	var half_width := int(bridge_width / 2)
	var best_shore := Vector2i(-1, -1)
	var best_score := -1000000
	for y in range(half_width + 2, map_height - half_width - 2):
		for x in range(map_width):
			var candidate := Vector2i(x, y)
			if not is_grass(candidate) or is_desert(candidate) or is_savanna(candidate) or is_grass(candidate + Vector2i(side, 0)):
				continue
			var valid_landing := true
			for lane in range(-half_width, half_width + 1):
				var lane_cell := candidate + Vector2i(0, lane)
				if not is_grass(lane_cell) or is_desert(lane_cell) or is_savanna(lane_cell) or is_grass(lane_cell + Vector2i(side, 0)):
					valid_landing = false
					break
			if not valid_landing:
				continue
			var edge_score := candidate.x * side
			var center_score: int = -abs(candidate.y - int(map_height * 0.62))
			var score: int = edge_score * 100 + center_score
			if score > best_score:
				best_score = score
				best_shore = candidate

	if best_shore.x < 0:
		var forced_x := map_width - 1 if side > 0 else 0
		var forced_y := clampi(int(map_height * 0.62), 3, map_height - 4)
		best_shore = Vector2i(forced_x, forced_y)

	# Both bridgeheads are flat 2-by-5 grass platforms. Only the outer cell carries deck boards.
	for lane in range(-2, 3):
		for inset in range(2):
			var landing_cell := best_shore + Vector2i(-side * inset, lane)
			set_world_grass(landing_cell, true)
			_set_mainland_grass_biome(landing_cell)
	_external_mainland_landing = best_shore
	for step in range(external_bridge_length + 1):
		for lane in range(-half_width, half_width + 1):
			var bridge_cell := best_shore + Vector2i(side * step, lane)
			if step > 0:
				set_world_grass(bridge_cell, false)
			set_world_bridge(bridge_cell, BRIDGE_HORIZONTAL)

	var arena_half := int(external_arena_size / 2)
	var outer_radius := arena_half + 3
	# The bridge ends on exactly one grass cell at the island edge; the second platform cell is inland.
	var island_center := best_shore + Vector2i(side * (external_bridge_length + outer_radius), 0)
	_arena_center = island_center
	_arena_bounds = Rect2i(island_center - Vector2i.ONE * arena_half, Vector2i.ONE * external_arena_size)
	var island_noise := FastNoiseLite.new()
	island_noise.seed = seed_value ^ 0x6E624EB7
	island_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	island_noise.frequency = 0.18
	island_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	island_noise.fractal_octaves = 2
	for y_offset in range(-outer_radius, outer_radius + 1):
		for x_offset in range(-outer_radius, outer_radius + 1):
			var contour_radius := float(outer_radius) + island_noise.get_noise_2d(x_offset, y_offset) * 0.85
			var radial_distance := Vector2(x_offset, y_offset).length()
			if radial_distance > contour_radius:
				continue
			var island_cell := island_center + Vector2i(x_offset, y_offset)
			set_world_grass(island_cell, true)
			_external_island_cells[island_cell] = true

	# Guarantee one complete grass ring around the stone floor. The noisy contour
	# may contribute up to two additional rings, so the island stays within +1 to +3 tiles.
	for y_offset in range(-arena_half - 1, arena_half + 2):
		for x_offset in range(-arena_half - 1, arena_half + 2):
			var inner_grass_cell := island_center + Vector2i(x_offset, y_offset)
			set_world_grass(inner_grass_cell, true)
			_external_island_cells[inner_grass_cell] = true

	# The island bridgehead mirrors the mainland: 2 cells long, 5 cells across.
	for lane in range(-2, 3):
		for inset in range(2):
			var landing_cell := island_center + Vector2i(-side * (outer_radius - inset), lane)
			set_world_grass(landing_cell, true)
			_external_island_cells[landing_cell] = true

	for y_offset in range(-arena_half, arena_half + 1):
		for x_offset in range(-arena_half, arena_half + 1):
			var arena_cell := island_center + Vector2i(x_offset, y_offset)
			set_world_grass(arena_cell, true)
			_external_island_cells[arena_cell] = true
			_arena_tiles[arena_cell] = true

	_external_bridge_rect = Rect2i(
		Vector2i(mini(best_shore.x, best_shore.x + side * external_bridge_length), best_shore.y - half_width),
		Vector2i(external_bridge_length + 1, bridge_width)
	)
	_build_external_ocean_depths(seed_value)


func _ensure_arena_floor() -> void:
	if _arena_bounds.size.x <= 0 or _arena_bounds.size.y <= 0:
		return
	for y in range(_arena_bounds.position.y, _arena_bounds.end.y):
		for x in range(_arena_bounds.position.x, _arena_bounds.end.x):
			var arena_cell := Vector2i(x, y)
			set_world_grass(arena_cell, true)
			_external_island_cells[arena_cell] = true
			_arena_tiles[arena_cell] = true

func _build_external_ocean_depths(seed_value: int) -> void:
	_external_ocean_depth.clear()
	if _external_island_cells.is_empty() or _external_bridge_rect.size.x <= 0:
		return
	var bounds := _external_bridge_rect.grow(9)
	for island_cell_value in _external_island_cells:
		var island_cell: Vector2i = island_cell_value
		bounds = bounds.merge(Rect2i(island_cell, Vector2i.ONE).grow(9))
	_external_land_depth_sources.clear()
	for island_cell_value in _external_island_cells:
		var island_cell: Vector2i = island_cell_value
		_external_land_depth_sources.append(island_cell)
	# Include nearby finite mainland cells so the ocean bands continue cleanly across
	# the main-map boundary into the sparse external world.
	var source_min_x := maxi(0, bounds.position.x)
	var source_max_x := mini(map_width - 1, bounds.end.x - 1)
	var source_min_y := maxi(0, bounds.position.y)
	var source_max_y := mini(map_height - 1, bounds.end.y - 1)
	for y in range(source_min_y, source_max_y + 1):
		for x in range(source_min_x, source_max_x + 1):
			var mainland_cell := Vector2i(x, y)
			if is_grass(mainland_cell):
				_external_land_depth_sources.append(mainland_cell)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value ^ 0x22E5A7
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.16
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if is_grass(cell) or is_bridge(cell):
				continue
			var land_distance := _external_structure_distance(cell, false)
			var bridge_distance := _external_structure_distance(cell, true)
			var noisy_distance := land_distance + noise.get_noise_2d(x, y) * 0.45
			var depth := 1.0
			if noisy_distance <= 1.4:
				depth = 0.0
			elif noisy_distance <= 3.8:
				depth = 0.34
			elif noisy_distance <= 6.2:
				depth = 0.67
			# Bridges never create the light coastal band, but their shallow water must
			# flow through a transition band before reaching deep water.
			if bridge_distance <= 1.0:
				depth = minf(depth, 0.34)
			elif bridge_distance <= 4.0:
				depth = minf(depth, 0.67)
			_external_ocean_depth[cell] = depth


func _external_structure_distance(cell: Vector2i, bridge_only: bool) -> float:
	var closest := 1000000.0
	if bridge_only:
		for bridge_cell_value in _world_bridge_overrides:
			var bridge_cell: Vector2i = bridge_cell_value
			closest = minf(closest, float(maxi(abs(cell.x - bridge_cell.x), abs(cell.y - bridge_cell.y))))
		return closest
	for land_cell in _external_land_depth_sources:
		closest = minf(closest, float(maxi(abs(cell.x - land_cell.x), abs(cell.y - land_cell.y))))
	return closest


func is_external_combat_area(cell: Vector2i) -> bool:
	return _external_island_cells.has(cell) or _external_bridge_rect.grow(1).has_point(cell)

func _clear_player_allies() -> void:
	for ally in get_tree().get_nodes_in_group("player_allies"):
		if is_instance_valid(ally):
			ally.queue_free()

func _clear_arrow_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("arrow_projectiles"):
		projectile.queue_free()


func _clear_archers() -> void:
	for archer in _archers:
		if is_instance_valid(archer):
			archer.queue_free()
	_archers.clear()


func _clear_spear_throwers() -> void:
	for thrower in _spear_throwers:
		if is_instance_valid(thrower):
			thrower.queue_free()
	_spear_throwers.clear()

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

func _advanced_enemy_cap_released() -> bool:
	return player.level >= 5


func _get_swordmaster_spawn_chance() -> float:
	if _normal_swordsman_kills < advanced_enemy_unlock_kills or (not _advanced_enemy_cap_released() and _swordmasters.size() >= 1):
		return 0.0
	return minf(1.0, sharpshooter_base_spawn_chance + sharpshooter_miss_bonus * _swordmaster_miss_count)

func _get_sharpshooter_spawn_chance() -> float:
	if _normal_archer_kills < sharpshooter_unlock_archer_kills or (not _advanced_enemy_cap_released() and _sharpshooters.size() >= 1):
		return 0.0
	return minf(1.0, sharpshooter_base_spawn_chance + sharpshooter_miss_bonus * _sharpshooter_miss_count)

func _try_spawn_spear_thrower() -> void:
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
		if not is_grass(cell) or (not is_desert(cell) and not is_savanna(cell)) or is_bridge(cell) or is_brazier(cell) or is_rock(cell):
			continue
		var spawn_position := (Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE
		if excluded_view.has_point(spawn_position) or _is_archer_spawn_occupied(spawn_position):
			continue
		var spawn_fire_thrower := _normal_spear_thrower_kills >= fire_spear_thrower_unlock_kills and _enemy_rng.randf() < fire_spear_thrower_spawn_chance
		var thrower := SPEAR_THROWER_SCENE.instantiate() as CharacterBody2D
		thrower.call("configure", player, _enemy_rng.randi(), spawn_fire_thrower)
		thrower.position = spawn_position
		add_child(thrower, true)
		thrower.connect("defeated", _on_enemy_defeated.bind(thrower))
		_spear_throwers.append(thrower)
		return

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
		if not is_grass(cell) or is_desert(cell) or is_bridge(cell) or is_brazier(cell) or is_rock(cell):
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
		elif sharpshooter_chance > 0.0:
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
		if not is_grass(cell) or is_desert(cell) or is_bridge(cell) or is_brazier(cell) or is_rock(cell):
			continue
		var spawn_position := (Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE
		if excluded_view.has_point(spawn_position) or _is_archer_spawn_occupied(spawn_position):
			continue
		var swordmaster_chance := _get_swordmaster_spawn_chance()
		var spawn_swordmaster := swordmaster_chance > 0.0 and _enemy_rng.randf() < swordmaster_chance
		if spawn_swordmaster:
			_swordmaster_miss_count = 0
		elif swordmaster_chance > 0.0:
			_swordmaster_miss_count += 1
		var swordsman := (SWORDMASTER_SCENE if spawn_swordmaster else SWORDSMAN_SCENE).instantiate() as CharacterBody2D
		swordsman.call("configure", player, _enemy_rng.randi())
		swordsman.position = spawn_position
		add_child(swordsman, true)
		swordsman.connect("defeated", _on_enemy_defeated.bind(swordsman))
		if spawn_swordmaster:
			_swordmasters.append(swordsman)
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
		if not is_grass(cell) or is_desert(cell) or is_bridge(cell) or is_brazier(cell) or is_rock(cell):
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
	if enemy is SpearThrowerEnemy and not bool(enemy.get("_fire_variant")):
		_normal_spear_thrower_kills += 1
	elif enemy is ArcherEnemy and not (enemy is SharpshooterEnemy):
		_normal_archer_kills += 1
	elif enemy.scene_file_path == "res://swordsman.tscn":
		_normal_swordsman_kills += 1
	var experience_amount := 8 if enemy is SharpshooterEnemy or enemy.scene_file_path == "res://swordmaster.tscn" else (11 if enemy.scene_file_path == "res://spear_thrower.tscn" else 2)
	call_deferred("_spawn_enemy_experience", enemy.global_position, experience_amount)
	call_deferred("_try_spawn_health_pickup", enemy.global_position)

func _try_spawn_health_pickup(drop_position: Vector2) -> void:
	if _loot_rng.randf() >= health_drop_chance:
		return
	var pickup := HEALTH_PICKUP_SCENE.instantiate() as HealthPickup
	add_child(pickup, true)
	pickup.global_position = drop_position

func _spawn_boss_experience(drop_position: Vector2) -> void:
	# 50 + 10 + 5 + 1 + 1 = 67. Large gold orbs make the boss reward legible.
	for value in [50, 10, 5, 1, 1]:
		_spawn_experience_pickup(drop_position, value)
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
	for enemy in _archers + _spear_throwers + _swordsmen + _slimes:
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
	var infinity := 1000000000
	var land_distances: Array[PackedInt32Array] = []
	var bridge_distances: Array[PackedInt32Array] = []
	var shallow_distances: Array[PackedInt32Array] = []

	for y in map_height:
		var land_row := PackedInt32Array()
		land_row.resize(map_width)
		land_row.fill(infinity)
		land_distances.append(land_row)
		var bridge_row := PackedInt32Array()
		bridge_row.resize(map_width)
		bridge_row.fill(infinity)
		bridge_distances.append(bridge_row)
		var shallow_row := PackedInt32Array()
		shallow_row.resize(map_width)
		shallow_row.fill(infinity)
		shallow_distances.append(shallow_row)
		var depth_row := PackedFloat32Array()
		depth_row.resize(map_width)
		_ocean_depth.append(depth_row)
		for x in map_width:
			var cell := Vector2i(x, y)
			if is_grass(cell) and not is_bridge(cell):
				land_distances[y][x] = 0
			if is_bridge(cell):
				bridge_distances[y][x] = 0

	_relax_distance_field(land_distances)
	_relax_distance_field(bridge_distances)

	var boundary_noise := FastNoiseLite.new()
	boundary_noise.seed = seed_value ^ 0x5F3759DF
	boundary_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	boundary_noise.frequency = 0.075
	boundary_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	boundary_noise.fractal_octaves = 3

	# Phase 1: land grows a coastal ring then shallow water; bridges independently
	# grow one shallow-water ring. Both results become a shared shallow frontier.
	for y in map_height:
		for x in map_width:
			var cell := Vector2i(x, y)
			if is_grass(cell) or is_bridge(cell):
				continue
			var land_distance := float(land_distances[y][x]) / 10.0
			var bridge_distance := float(bridge_distances[y][x]) / 10.0
			var noise_value := boundary_noise.get_noise_2d(x, y)
			var band_width := lerpf(
				shallow_transition_min_width,
				maxi(shallow_transition_min_width, shallow_transition_max_width),
				noise_value * 0.5 + 0.5
			)
			var land_shallow_end := 1.41 + band_width
			if (land_distance > 1.41 and land_distance <= land_shallow_end) or bridge_distance <= 1.0:
				shallow_distances[y][x] = 0

	_relax_distance_field(shallow_distances)

	# Phase 2: the combined shallow frontier expands transition water. Deep water
	# begins only outside that shared transition band.
	for y in map_height:
		for x in map_width:
			var cell := Vector2i(x, y)
			if is_grass(cell) or is_bridge(cell):
				continue
			var land_distance := float(land_distances[y][x]) / 10.0
			# The mainland's one-tile coastal shelf is an explicit first layer. Bridge
			# shallow water begins outside it, so a bridge cannot erase the shoreline.
			if land_distance <= 1.41:
				_ocean_depth[y][x] = 0.0
				continue
			if shallow_distances[y][x] == 0:
				_ocean_depth[y][x] = 0.34
				continue
			var noise_value := boundary_noise.get_noise_2d(x, y)
			var transition_width := lerpf(
				shallow_transition_min_width,
				maxi(shallow_transition_min_width, shallow_transition_max_width),
				noise_value * 0.5 + 0.5
			)
			var shallow_distance := float(shallow_distances[y][x]) / 10.0
			if shallow_distance <= transition_width:
				_ocean_depth[y][x] = 0.67
			else:
				_ocean_depth[y][x] = 1.0
				_deep_ocean_tiles[y][x] = 1

	_build_ocean_mesh()
	_build_boundary_ocean_depths(seed_value)


func _build_boundary_ocean_depths(seed_value: int) -> void:
	# The finite map's distance field continues past every border before the
	# infinite renderer takes over, preventing deep ocean from hard-cutting a coast.
	const MARGIN := 12
	const INFINITY := 1000000000
	var field_width := map_width + MARGIN * 2
	var field_height := map_height + MARGIN * 2
	var land_field: Array[PackedInt32Array] = []
	var bridge_field: Array[PackedInt32Array] = []
	var shallow_field: Array[PackedInt32Array] = []
	for local_y in range(field_height):
		var land_row := PackedInt32Array()
		land_row.resize(field_width)
		land_row.fill(INFINITY)
		land_field.append(land_row)
		var bridge_row := PackedInt32Array()
		bridge_row.resize(field_width)
		bridge_row.fill(INFINITY)
		bridge_field.append(bridge_row)
		var shallow_row := PackedInt32Array()
		shallow_row.resize(field_width)
		shallow_row.fill(INFINITY)
		shallow_field.append(shallow_row)
		for local_x in range(field_width):
			var world_cell := Vector2i(local_x - MARGIN, local_y - MARGIN)
			if is_grass(world_cell) and not is_bridge(world_cell):
				land_field[local_y][local_x] = 0
			if is_bridge(world_cell):
				bridge_field[local_y][local_x] = 0

	_relax_distance_field_sized(land_field, field_width, field_height)
	_relax_distance_field_sized(bridge_field, field_width, field_height)
	var boundary_noise := FastNoiseLite.new()
	boundary_noise.seed = seed_value ^ 0x5F3759DF
	boundary_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	boundary_noise.frequency = 0.075
	boundary_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	boundary_noise.fractal_octaves = 3

	for local_y in range(field_height):
		for local_x in range(field_width):
			var world_cell := Vector2i(local_x - MARGIN, local_y - MARGIN)
			if is_grass(world_cell) or is_bridge(world_cell):
				continue
			var land_distance := float(land_field[local_y][local_x]) / 10.0
			var bridge_distance := float(bridge_field[local_y][local_x]) / 10.0
			var noise_value := boundary_noise.get_noise_2d(world_cell.x, world_cell.y)
			var band_width := lerpf(
				shallow_transition_min_width,
				maxi(shallow_transition_min_width, shallow_transition_max_width),
				noise_value * 0.5 + 0.5
			)
			if (land_distance > 1.41 and land_distance <= 1.41 + band_width) or bridge_distance <= 1.0:
				shallow_field[local_y][local_x] = 0
	_relax_distance_field_sized(shallow_field, field_width, field_height)

	for local_y in range(field_height):
		for local_x in range(field_width):
			var world_cell := Vector2i(local_x - MARGIN, local_y - MARGIN)
			if _is_in_map(world_cell) or is_grass(world_cell) or is_bridge(world_cell):
				continue
			if _external_ocean_depth.has(world_cell):
				continue
			var land_distance := float(land_field[local_y][local_x]) / 10.0
			if land_distance <= 1.41:
				_external_ocean_depth[world_cell] = 0.0
				continue
			if shallow_field[local_y][local_x] == 0:
				_external_ocean_depth[world_cell] = 0.34
				continue
			var noise_value := boundary_noise.get_noise_2d(world_cell.x, world_cell.y)
			var transition_width := lerpf(
				shallow_transition_min_width,
				maxi(shallow_transition_min_width, shallow_transition_max_width),
				noise_value * 0.5 + 0.5
			)
			var shallow_distance := float(shallow_field[local_y][local_x]) / 10.0
			_external_ocean_depth[world_cell] = 0.67 if shallow_distance <= transition_width else 1.0


func _relax_distance_field_sized(
	field: Array[PackedInt32Array],
	field_width: int,
	field_height: int
) -> void:
	for y in range(field_height):
		for x in range(field_width):
			if field[y][x] == 0:
				continue
			var best := field[y][x]
			if x > 0:
				best = mini(best, field[y][x - 1] + 10)
			if y > 0:
				best = mini(best, field[y - 1][x] + 10)
				if x > 0:
					best = mini(best, field[y - 1][x - 1] + 14)
				if x + 1 < field_width:
					best = mini(best, field[y - 1][x + 1] + 14)
			field[y][x] = best
	for y in range(field_height - 1, -1, -1):
		for x in range(field_width - 1, -1, -1):
			if field[y][x] == 0:
				continue
			var best := field[y][x]
			if x + 1 < field_width:
				best = mini(best, field[y][x + 1] + 10)
			if y + 1 < field_height:
				best = mini(best, field[y + 1][x] + 10)
				if x > 0:
					best = mini(best, field[y + 1][x - 1] + 14)
				if x + 1 < field_width:
					best = mini(best, field[y + 1][x + 1] + 14)
			field[y][x] = best


func _relax_distance_field(field: Array[PackedInt32Array]) -> void:
	for y in map_height:
		for x in map_width:
			if field[y][x] == 0:
				continue
			var best := field[y][x]
			if x > 0:
				best = mini(best, field[y][x - 1] + 10)
			if y > 0:
				best = mini(best, field[y - 1][x] + 10)
				if x > 0:
					best = mini(best, field[y - 1][x - 1] + 14)
				if x + 1 < map_width:
					best = mini(best, field[y - 1][x + 1] + 14)
			field[y][x] = best
	for y in range(map_height - 1, -1, -1):
		for x in range(map_width - 1, -1, -1):
			if field[y][x] == 0:
				continue
			var best := field[y][x]
			if x + 1 < map_width:
				best = mini(best, field[y][x + 1] + 10)
			if y + 1 < map_height:
				best = mini(best, field[y + 1][x] + 10)
				if x > 0:
					best = mini(best, field[y + 1][x - 1] + 14)
				if x + 1 < map_width:
					best = mini(best, field[y + 1][x + 1] + 14)
			field[y][x] = best

func _distance_to_any_bridge(cell: Vector2i) -> int:
	var closest := 1000000
	for y in map_height:
		for x in map_width:
			if not is_bridge(Vector2i(x, y)):
				continue
			closest = mini(closest, maxi(abs(cell.x - x), abs(cell.y - y)))
	for bridge_cell_value in _world_bridge_overrides:
		var bridge_cell: Vector2i = bridge_cell_value
		closest = mini(closest, maxi(abs(cell.x - bridge_cell.x), abs(cell.y - bridge_cell.y)))
	return closest

func _refresh_active_region(force := false) -> void:
	if not is_instance_valid(player):
		return
	var player_cell := _world_to_cell(player.global_position)
	var chunk := Vector2i(
		floori(float(player_cell.x) / CHUNK_SIZE_TILES),
		floori(float(player_cell.y) / CHUNK_SIZE_TILES)
	)
	if not force and chunk == _active_chunk:
		return
	_active_chunk = chunk
	var min_cell := (chunk - Vector2i.ONE * active_chunk_radius) * CHUNK_SIZE_TILES
	var max_cell := (chunk + Vector2i.ONE * (active_chunk_radius + 1)) * CHUNK_SIZE_TILES
	var min_x := clampi(min_cell.x, 0, map_width)
	var min_y := clampi(min_cell.y, 0, map_height)
	var max_x := clampi(max_cell.x, 0, map_width)
	var max_y := clampi(max_cell.y, 0, map_height)
	_active_tile_bounds = Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)
	_build_ocean_mesh()
	_rebuild_terrain_collision()
	queue_redraw()


func _get_active_tile_bounds() -> Rect2i:
	if _active_tile_bounds.size.x <= 0 or _active_tile_bounds.size.y <= 0:
		return Rect2i(Vector2i.ZERO, Vector2i(map_width, map_height))
	return _active_tile_bounds


func _build_ocean_mesh() -> void:
	_ocean_mesh = ArrayMesh.new()
	var bounds := _get_active_tile_bounds()
	var tile_count := bounds.size.x * bounds.size.y
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(tile_count * 4)
	colors.resize(tile_count * 4)
	indices.resize(tile_count * 6)
	var tile_index := 0
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
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
	var directions: Array[Vector2i] = EIGHT_DIRECTIONS

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

	while not pending.is_empty():
		var last_index := pending.size() - 1
		var encoded: int = pending[last_index]
		pending.resize(last_index)
		var cell := Vector2i(encoded % map_width, int(encoded / map_width))
		for direction in EIGHT_DIRECTIONS:
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
	# Strict eight-neighbor opening removes diagonal strings, one-cell necks, and
	# the staircase fragments that otherwise become jagged internal water slots.
	var eroded := _new_grid()
	for y in range(1, map_height - 1):
		for x in range(1, map_width - 1):
			if source[y][x] == 0:
				continue
			var has_full_neighborhood := true
			for direction in EIGHT_DIRECTIONS:
				var neighbor := Vector2i(x, y) + direction
				if source[neighbor.y][neighbor.x] == 0:
					has_full_neighborhood = false
					break
			if has_full_neighborhood:
				eroded[y][x] = 1

	var result := _new_grid()
	for y in map_height:
		for x in map_width:
			if eroded[y][x] == 1:
				result[y][x] = 1
				continue
			for direction in EIGHT_DIRECTIONS:
				var neighbor := Vector2i(x, y) + direction
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < map_width and neighbor.y < map_height and eroded[neighbor.y][neighbor.x] == 1:
					result[y][x] = 1
					break
	return result


func _fill_small_water_notches(source: Array[PackedByteArray], passes: int) -> Array[PackedByteArray]:
	var current: Array[PackedByteArray] = source.duplicate(true)
	for pass_index in passes:
		var result: Array[PackedByteArray] = current.duplicate(true)
		for y in range(1, map_height - 1):
			for x in range(1, map_width - 1):
				if current[y][x] == 1:
					continue
				var land_neighbors := 0
				for direction in EIGHT_DIRECTIONS:
					var neighbor := Vector2i(x, y) + direction
					if current[neighbor.y][neighbor.x] == 1:
						land_neighbors += 1
				if land_neighbors >= 5:
					result[y][x] = 1
		current = result
	return current

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
	_draw_external_ocean()
	_draw_dock_bridge()
	_draw_external_bridge()
	_draw_coast_backings()
	_draw_cliff_runs()
	_draw_grass_runs()
	_draw_external_terrain()
	_draw_rocks()

func _draw_external_ocean() -> void:
	var player_cell := _world_to_cell(player.global_position) if is_instance_valid(player) else Vector2i.ZERO
	var render_bounds := Rect2i(player_cell - Vector2i.ONE * 52, Vector2i.ONE * 105)
	for cell_value in _external_ocean_depth:
		var cell: Vector2i = cell_value
		if not render_bounds.has_point(cell) or _is_in_map(cell) or is_grass(cell) or is_bridge(cell):
			continue
		draw_rect(
			Rect2(Vector2(cell) * TILE_SIZE, Vector2.ONE * TILE_SIZE),
			get_ocean_color(cell), true, -1.0, false
		)


func _draw_external_terrain() -> void:
	for cell_value in _external_island_cells:
		var cell: Vector2i = cell_value
		if _is_in_map(cell):
			continue
		var origin := Vector2(cell) * TILE_SIZE
		var boundary := (
			not is_grass(cell + Vector2i.LEFT)
			or not is_grass(cell + Vector2i.RIGHT)
			or not is_grass(cell + Vector2i.UP)
			or not is_grass(cell + Vector2i.DOWN)
		)
		if boundary:
			_draw_coast_backing(origin, Vector2.ONE * TILE_SIZE)
			if not is_grass(cell + Vector2i.DOWN) and not is_bridge(cell + Vector2i.DOWN):
				_draw_coast_backing(origin + Vector2(0.0, TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE * 0.5))
	for cell_value in _external_island_cells:
		var cell: Vector2i = cell_value
		if _is_in_map(cell) or is_grass(cell + Vector2i.DOWN) or is_bridge(cell + Vector2i.DOWN):
			continue
		draw_rect(
			Rect2(Vector2(cell.x * TILE_SIZE, (cell.y + 1) * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE * 0.5)),
			SHADOW_COLOR, true, -1.0, false
		)
	for cell_value in _external_island_cells:
		var cell: Vector2i = cell_value
		if _is_in_map(cell):
			continue
		draw_rect(Rect2(Vector2(cell) * TILE_SIZE, Vector2.ONE * TILE_SIZE), GRASS_COLOR, true, -1.0, false)
	for cell_value in _arena_tiles:
		var cell: Vector2i = cell_value
		_draw_arena_tile(cell)
	_draw_arena_brickwork()
	_draw_arena_sigil()


func _draw_arena_tile(cell: Vector2i) -> void:
	var origin := Vector2(cell) * TILE_SIZE
	var has_tile_below := _arena_tiles.has(cell + Vector2i.DOWN)
	draw_rect(Rect2(origin, Vector2.ONE * TILE_SIZE), ARENA_TILE_COLOR, true, -1.0, false)
	if not has_tile_below:
		draw_rect(
			Rect2(origin + Vector2(0.0, TILE_SIZE), Vector2(TILE_SIZE, 4.0)),
			ARENA_SIDE_COLOR, true, -1.0, false
		)

func _draw_arena_brickwork() -> void:
	if _arena_bounds.size.x <= 0 or _arena_bounds.size.y <= 0:
		return
	var origin := Vector2(_arena_bounds.position) * TILE_SIZE
	var size := Vector2(_arena_bounds.size) * TILE_SIZE
	const BRICK_WIDTH := 48.0
	const BRICK_HEIGHT := 24.0
	const GROUT_WIDTH := 2.0
	var row_count := int(size.y / BRICK_HEIGHT)
	for row in range(1, row_count):
		var y := origin.y + float(row) * BRICK_HEIGHT
		draw_rect(Rect2(Vector2(origin.x, y), Vector2(size.x, GROUT_WIDTH)), ARENA_BRICK_COLOR, true, -1.0, false)
	for row in range(row_count):
		var seam_x := origin.x + (BRICK_WIDTH * 0.5 if row % 2 == 0 else BRICK_WIDTH)
		var row_y := origin.y + float(row) * BRICK_HEIGHT
		while seam_x < origin.x + size.x:
			draw_rect(Rect2(Vector2(seam_x, row_y), Vector2(GROUT_WIDTH, BRICK_HEIGHT)), ARENA_BRICK_COLOR, true, -1.0, false)
			seam_x += BRICK_WIDTH

func _draw_arena_sigil() -> void:
	if _arena_bounds.size.x < 7 or _arena_bounds.size.y < 7:
		return
	var sigil_origin := Vector2(_arena_center - Vector2i(3, 3)) * TILE_SIZE
	var sigil_size := Vector2.ONE * TILE_SIZE * 7.0
	# The continuous brick floor remains visible through the sigil; only its marks overlay it.
	draw_rect(Rect2(sigil_origin + Vector2(8.0, 8.0), sigil_size - Vector2.ONE * 16.0), RUNE_LINE_COLOR, false, 5.0, false)
	draw_rect(Rect2(sigil_origin + Vector2(64.0, 64.0), sigil_size - Vector2.ONE * 128.0), RUNE_INNER_COLOR, false, 4.0, false)
	# Four inward-facing L glyphs make the whole motif read as a square seal.
	var glyph_inset := 34.0
	var glyph_span := 26.0
	var glyph_right := sigil_origin.x + sigil_size.x - glyph_inset
	var glyph_bottom := sigil_origin.y + sigil_size.y - glyph_inset
	draw_rect(Rect2(Vector2(sigil_origin.x + glyph_inset, sigil_origin.y + glyph_inset), Vector2(glyph_span, 6.0)), RUNE_LINE_COLOR, true, -1.0, false)
	draw_rect(Rect2(Vector2(sigil_origin.x + glyph_inset, sigil_origin.y + glyph_inset), Vector2(6.0, glyph_span)), RUNE_LINE_COLOR, true, -1.0, false)
	draw_rect(Rect2(Vector2(glyph_right - glyph_span, sigil_origin.y + glyph_inset), Vector2(glyph_span, 6.0)), RUNE_LINE_COLOR, true, -1.0, false)
	draw_rect(Rect2(Vector2(glyph_right - 6.0, sigil_origin.y + glyph_inset), Vector2(6.0, glyph_span)), RUNE_LINE_COLOR, true, -1.0, false)
	draw_rect(Rect2(Vector2(sigil_origin.x + glyph_inset, glyph_bottom - 6.0), Vector2(glyph_span, 6.0)), RUNE_LINE_COLOR, true, -1.0, false)
	draw_rect(Rect2(Vector2(sigil_origin.x + glyph_inset, glyph_bottom - glyph_span), Vector2(6.0, glyph_span)), RUNE_LINE_COLOR, true, -1.0, false)
	draw_rect(Rect2(Vector2(glyph_right - glyph_span, glyph_bottom - 6.0), Vector2(glyph_span, 6.0)), RUNE_LINE_COLOR, true, -1.0, false)
	draw_rect(Rect2(Vector2(glyph_right - 6.0, glyph_bottom - glyph_span), Vector2(6.0, glyph_span)), RUNE_LINE_COLOR, true, -1.0, false)
	var center := sigil_origin + sigil_size * 0.5
	draw_rect(Rect2(center - Vector2(40.0, 40.0), Vector2(80.0, 80.0)), RUNE_LINE_COLOR, false, 5.0, false)
	draw_rect(Rect2(center - Vector2(12.0, 12.0), Vector2(24.0, 24.0)), RUNE_INNER_COLOR, true, -1.0, false)


func _draw_external_bridge() -> void:
	if _external_bridge_rect.size.x <= 0 or _external_bridge_rect.size.y <= 0:
		return
	_draw_bridge(
		Rect2(Vector2(_external_bridge_rect.position) * TILE_SIZE, Vector2(_external_bridge_rect.size) * TILE_SIZE),
		BRIDGE_HORIZONTAL
	)

func _draw_coast_backings() -> void:
	var bounds := _get_active_tile_bounds()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
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
	var bounds := _get_active_tile_bounds()
	for y in range(bounds.position.y, bounds.end.y):
		var x := bounds.position.x
		while x < bounds.end.x:
			var cell := Vector2i(x, y)
			if not is_grass(cell) or is_grass(cell + Vector2i.DOWN):
				x += 1
				continue
			var cliff_color := get_land_side_color(cell)
			var run_start := x
			while x < bounds.end.x:
				var run_cell := Vector2i(x, y)
				if not is_grass(run_cell) or is_grass(run_cell + Vector2i.DOWN) or get_land_side_color(run_cell) != cliff_color:
					break
				x += 1
			draw_rect(
				Rect2(
					Vector2(run_start * TILE_SIZE, (y + 1) * TILE_SIZE),
					Vector2((x - run_start) * TILE_SIZE, TILE_SIZE / 2)
				),
				cliff_color,
				true,
				-1.0,
				false
			)

func _draw_grass_runs() -> void:
	var bounds := _get_active_tile_bounds()
	for y in range(bounds.position.y, bounds.end.y):
		var x := bounds.position.x
		while x < bounds.end.x:
			var cell := Vector2i(x, y)
			if not is_grass(cell):
				x += 1
				continue
			var land_color := get_land_top_color(cell)
			var run_start := x
			while x < bounds.end.x and is_grass(Vector2i(x, y)) and get_land_top_color(Vector2i(x, y)) == land_color:
				x += 1
			draw_rect(
				Rect2(
					Vector2(run_start * TILE_SIZE, y * TILE_SIZE),
					Vector2((x - run_start) * TILE_SIZE, TILE_SIZE)
				),
				land_color,
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
	# Bridge cells are omitted from the ocean mesh, so explicitly restore shallow water
	# beneath the deck before drawing its projected shadow. Grass bridgeheads render later.
	draw_rect(bridge_rect, OCEAN_COLOR, true, -1.0, false)
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

func get_bridge_render_data() -> Array[Dictionary]:
	var bridges: Array[Dictionary] = []
	if _dock_cells.size.x > 0 and _dock_cells.size.y > 0:
		bridges.append({
			"rect": Rect2(Vector2(_dock_cells.position) * TILE_SIZE, Vector2(_dock_cells.size) * TILE_SIZE),
			"orientation": BRIDGE_VERTICAL,
		})
	if _external_bridge_rect.size.x > 0 and _external_bridge_rect.size.y > 0:
		bridges.append({
			"rect": Rect2(Vector2(_external_bridge_rect.position) * TILE_SIZE, Vector2(_external_bridge_rect.size) * TILE_SIZE),
			"orientation": BRIDGE_HORIZONTAL,
		})
	return bridges


func get_bridge_water_post_bases() -> Array[Rect2]:
	var bases: Array[Rect2] = []
	for bridge_data in get_bridge_render_data():
		var bridge_rect: Rect2 = bridge_data["rect"]
		var orientation: int = bridge_data["orientation"]
		if orientation == BRIDGE_VERTICAL:
			var row_count := maxi(1, int(bridge_rect.size.y / TILE_SIZE))
			for row in range(2, row_count + 1):
				var post_y := bridge_rect.position.y + row * TILE_SIZE - 16.0
				var base_y := post_y + BRIDGE_POST_HEIGHT - BRIDGE_POST_SIZE
				bases.append(Rect2(Vector2(bridge_rect.position.x, base_y), Vector2.ONE * BRIDGE_POST_SIZE))
				bases.append(Rect2(Vector2(bridge_rect.end.x - BRIDGE_POST_SIZE, base_y), Vector2.ONE * BRIDGE_POST_SIZE))
		else:
			var column_count := maxi(1, int(bridge_rect.size.x / TILE_SIZE))
			for column in range(column_count + 1):
				var post_x := bridge_rect.position.x + column * TILE_SIZE - BRIDGE_POST_SIZE * 0.5
				for side in [Vector2i.UP, Vector2i.DOWN]:
					var bridge_cell := Vector2i(floori((post_x + BRIDGE_POST_SIZE * 0.5) / TILE_SIZE), floori(bridge_rect.position.y / TILE_SIZE))
					var water_cell: Vector2i = bridge_cell + side * (1 if side == Vector2i.UP else int(bridge_rect.size.y / TILE_SIZE))
					if is_grass(water_cell):
						continue
					var anchor_y := bridge_rect.position.y if side == Vector2i.UP else bridge_rect.end.y
					bases.append(Rect2(Vector2(post_x, anchor_y + 24.0), Vector2.ONE * BRIDGE_POST_SIZE))
	return bases

func get_dock_bridge_rect() -> Rect2:
	if _dock_cells.size.x <= 0 or _dock_cells.size.y <= 0:
		return Rect2()
	return Rect2(Vector2(_dock_cells.position) * TILE_SIZE, Vector2(_dock_cells.size) * TILE_SIZE)


func get_bridge_post_rects_behind_deck() -> Array[Rect2]:
	if _external_bridge_rect.size.x <= 0 or _external_bridge_rect.size.y <= 0:
		return []
	var bridge_rect := Rect2(
		Vector2(_external_bridge_rect.position) * TILE_SIZE,
		Vector2(_external_bridge_rect.size) * TILE_SIZE
	)
	return _get_horizontal_bridge_post_rects(bridge_rect, Vector2i.UP)


func get_bridge_post_rects() -> Array[Rect2]:
	var posts: Array[Rect2] = []
	for bridge_data in get_bridge_render_data():
		var bridge_rect: Rect2 = bridge_data["rect"]
		var orientation: int = bridge_data["orientation"]
		if orientation == BRIDGE_VERTICAL:
			var row_count := maxi(1, int(bridge_rect.size.y / TILE_SIZE))
			for row in range(row_count + 1):
				var post_height := BRIDGE_POST_HEIGHT if row >= 2 else 16.0
				var post_y := bridge_rect.position.y + row * TILE_SIZE - 16.0
				posts.append(Rect2(Vector2(bridge_rect.position.x, post_y), Vector2(BRIDGE_POST_SIZE, post_height)))
				posts.append(Rect2(Vector2(bridge_rect.end.x - BRIDGE_POST_SIZE, post_y), Vector2(BRIDGE_POST_SIZE, post_height)))
		else:
			posts.append_array(_get_horizontal_bridge_post_rects(bridge_rect, Vector2i.DOWN))
	return posts


func _get_horizontal_bridge_post_rects(bridge_rect: Rect2, side: Vector2i) -> Array[Rect2]:
	var posts: Array[Rect2] = []
	var column_count := maxi(1, int(bridge_rect.size.x / TILE_SIZE))
	var top_bridge_y := floori(bridge_rect.position.y / TILE_SIZE)
	var bottom_bridge_y := top_bridge_y + int(bridge_rect.size.y / TILE_SIZE) - 1
	for column in range(column_count + 1):
		var post_x := bridge_rect.position.x + column * TILE_SIZE - BRIDGE_POST_SIZE * 0.5
		var bridge_x := floori((post_x + BRIDGE_POST_SIZE * 0.5) / TILE_SIZE)
		var adjacent_cell := Vector2i(bridge_x, top_bridge_y - 1 if side == Vector2i.UP else bottom_bridge_y + 1)
		var anchor_y := bridge_rect.position.y if side == Vector2i.UP else bridge_rect.end.y
		var post_height := 16.0 if is_grass(adjacent_cell) else BRIDGE_POST_HEIGHT
		posts.append(Rect2(Vector2(post_x, anchor_y - 16.0), Vector2(BRIDGE_POST_SIZE, post_height)))
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
				Rect2(plank_position, Vector2(top_width, bridge_rect.size.y - bridge_plank_side_height)),
				BRIDGE_TOP_COLOR,
				true,
				-1.0,
				false
			)

func _rebuild_terrain_collision() -> void:
	_terrain_block_rects.clear()
	var bounds := _get_active_tile_bounds()
	for y in range(bounds.position.y, bounds.end.y):
		var x := bounds.position.x
		while x < bounds.end.x:
			var cell := Vector2i(x, y)
			if not _is_solid_terrain_cell(cell):
				x += 1
				continue
			var run_start := x
			while x < bounds.end.x and _is_solid_terrain_cell(Vector2i(x, y)):
				x += 1
			var run_length := x - run_start
			_add_terrain_block(
				Vector2((run_start + run_length * 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE),
				Vector2(run_length * TILE_SIZE, TILE_SIZE)
			)
	_apply_terrain_collision_blocks()


func _is_solid_terrain_cell(cell: Vector2i) -> bool:
	return is_rock(cell) or is_brazier(cell)
func _get_external_structure_bounds() -> Rect2i:
	var bounds := _external_bridge_rect
	for cell_value in _external_island_cells:
		var cell: Vector2i = cell_value
		bounds = bounds.merge(Rect2i(cell, Vector2i.ONE))
	return bounds

func _add_terrain_block(center: Vector2, size: Vector2) -> void:
	_terrain_block_rects.append(Rect2(center - size * 0.5, size))


func _apply_terrain_collision_blocks() -> void:
	for index in range(_terrain_block_rects.size()):
		var collision: CollisionShape2D
		if index < _terrain_collision_pool.size():
			collision = _terrain_collision_pool[index]
		else:
			collision = CollisionShape2D.new()
			collision.shape = RectangleShape2D.new()
			terrain_collision.add_child(collision)
			_terrain_collision_pool.append(collision)
		var rectangle := collision.shape as RectangleShape2D
		rectangle.size = _terrain_block_rects[index].size
		collision.position = _terrain_block_rects[index].get_center()
		collision.disabled = false
	for index in range(_terrain_block_rects.size(), _terrain_collision_pool.size()):
		_terrain_collision_pool[index].disabled = true

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
		_spawn_brazier_at(cell)
	if _external_mainland_landing.x >= 0:
		for side_cell in [
			_external_mainland_landing + Vector2i(0, -2),
			_external_mainland_landing + Vector2i(0, 2),
		]:
			_spawn_brazier_at(side_cell)
	if not _arena_tiles.is_empty():
		var arena_cells: Array[Vector2i] = []
		for arena_cell_value in _arena_tiles:
			var arena_cell: Vector2i = arena_cell_value
			arena_cells.append(arena_cell)
		var arena_bounds := Rect2i(arena_cells[0], Vector2i.ONE)
		for arena_cell in arena_cells:
			arena_bounds = arena_bounds.merge(Rect2i(arena_cell, Vector2i.ONE))
		for corner in [
			arena_bounds.position,
			Vector2i(arena_bounds.end.x - 1, arena_bounds.position.y),
			Vector2i(arena_bounds.position.x, arena_bounds.end.y - 1),
			arena_bounds.end - Vector2i.ONE,
		]:
			_spawn_brazier_at(corner)


func _spawn_brazier_at(cell: Vector2i) -> void:
	if not is_grass(cell) or is_bridge(cell) or is_brazier(cell):
		return
	var brazier := BRAZIER_SCENE.instantiate() as Node2D
	brazier.position = (Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE
	add_child(brazier, true)
	_braziers.append(brazier)
	_brazier_cells.append(cell)
func _build_rocks(seed_value: int) -> void:
	_rock_tiles = _new_grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x4F6C5A91
	var buckets: Dictionary = {}
	const BUCKET_SIZE := 12
	for y in range(2, map_height - 2):
		for x in range(2, map_width - 2):
			var cell := Vector2i(x, y)
			if not _can_place_rock(cell):
				continue
			var bucket := Vector2i(int(x / BUCKET_SIZE), int(y / BUCKET_SIZE))
			if not buckets.has(bucket):
				buckets[bucket] = [] as Array[Vector2i]
			var cells: Array[Vector2i] = buckets[bucket]
			cells.append(cell)

	var bucket_keys: Array[Vector2i] = []
	for key_value in buckets.keys():
		bucket_keys.append(key_value as Vector2i)
	for index in range(bucket_keys.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: Vector2i = bucket_keys[index]
		bucket_keys[index] = bucket_keys[swap_index]
		bucket_keys[swap_index] = temporary

	var origins: Array[Vector2i] = []
	for bucket in bucket_keys:
		if origins.size() >= _get_scaled_rock_cluster_count():
			break
		var cells: Array[Vector2i] = buckets[bucket]
		var origin: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		if _try_place_rock_cluster(origin, origins, rng):
			origins.append(origin)

	# Some buckets are water-heavy. Fill any remaining quota from all legal cells.
	if origins.size() < _get_scaled_rock_cluster_count():
		var fallback_cells: Array[Vector2i] = []
		for bucket in bucket_keys:
			var cells: Array[Vector2i] = buckets[bucket]
			fallback_cells.append_array(cells)
		for index in range(fallback_cells.size() - 1, 0, -1):
			var swap_index: int = rng.randi_range(0, index)
			var temporary: Vector2i = fallback_cells[index]
			fallback_cells[index] = fallback_cells[swap_index]
			fallback_cells[swap_index] = temporary
		for origin in fallback_cells:
			if origins.size() >= _get_scaled_rock_cluster_count():
				break
			if _try_place_rock_cluster(origin, origins, rng):
				origins.append(origin)


func _try_place_rock_cluster(
	origin: Vector2i,
	origins: Array[Vector2i],
	rng: RandomNumberGenerator
) -> bool:
	for other in origins:
		if origin.distance_squared_to(other) < 100.0:
			return false
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1)]
	var count: int = rng.randi_range(1, 4)
	var cluster: Array[Vector2i] = []
	for index in range(count):
		var cell := origin + offsets[index]
		if _can_place_rock(cell):
			cluster.append(cell)
	if cluster.is_empty():
		return false
	for cell in cluster:
		_rock_tiles[cell.y][cell.x] = 1
	return true

func _get_scaled_rock_cluster_count() -> int:
	# Keep the same visual density as the original 50-by-50 mainland.
	var area_scale := float(map_width * map_height) / 2500.0
	return maxi(rock_cluster_count, roundi(float(rock_cluster_count) * area_scale))

func _can_place_rock(cell: Vector2i) -> bool:
	if not _is_in_map(cell) or not is_grass(cell) or is_desert(cell) or is_bridge(cell) or is_rock(cell):
		return false
	if _dock_cells.size.x > 0 and _dock_cells.grow(2).has_point(cell):
		return false
	# Every one of the eight neighboring cells must stay on land, preserving coast paths.
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue
			var neighbor := cell + Vector2i(x_offset, y_offset)
			if not _is_in_map(neighbor) or not is_grass(neighbor) or is_desert(neighbor):
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
	var bounds := _get_active_tile_bounds()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if not is_rock(cell):
				continue
			var origin := Vector2(cell) * TILE_SIZE
			var has_rock_below := is_rock(cell + Vector2i.DOWN)
			var top_height: float = float(TILE_SIZE) if has_rock_below else float(TILE_SIZE) * 0.5
			draw_rect(Rect2(origin, Vector2(TILE_SIZE, top_height)), ROCK_TOP_COLOR, true, -1.0, false)
			if not has_rock_below:
				draw_rect(Rect2(origin + Vector2(0.0, top_height), Vector2(TILE_SIZE, TILE_SIZE - top_height)), ROCK_SIDE_COLOR, true, -1.0, false)
			_draw_rock_moss(origin, cell, top_height, has_rock_below)
			_draw_rock_fragments(origin, cell)


func _draw_rock_moss(origin: Vector2, cell: Vector2i, top_height: float, has_rock_below: bool) -> void:
	var seed_hash := absi((cell.x * 83492791) ^ (cell.y * 2971215073) ^ world_seed)
	if seed_hash % 5 == 0:
		return
	var patch_x := 7.0 + float(seed_hash % 24)
	var patch_y := 7.0 + float((seed_hash >> 5) % 20)
	draw_rect(Rect2(origin + Vector2(patch_x, patch_y), Vector2(16.0, 6.0)), MOSS_COLOR, true, -1.0, false)
	if seed_hash % 2 == 0:
		draw_rect(Rect2(origin + Vector2(patch_x + 9.0, patch_y + 5.0), Vector2(7.0, 6.0)), MOSS_COLOR, true, -1.0, false)
	if not has_rock_below and seed_hash % 3 != 0:
		var vine_x := 12.0 + float((seed_hash >> 11) % 36)
		var vine_length := 8.0 + float((seed_hash >> 17) % 13)
		draw_rect(Rect2(origin + Vector2(vine_x, top_height - 2.0), Vector2(3.0, vine_length)), VINE_COLOR, true, -1.0, false)

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
