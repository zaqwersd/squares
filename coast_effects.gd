class_name CoastEffects
extends Node2D

const TILE_SIZE := 64
const CLIFF_DEPTH := 32
const FOAM_SIZES: Array[int] = [4, 6, 8]
const COAST_COLOR := Color.WHITE
const CLIFF_COLOR := Color("#61A289")
const LAND_COLOR := Color("#7BE0AD")
const FOAM_COLOR := Color(1.0, 1.0, 1.0, 0.82)
const BRIDGE_POST_TOP_COLOR := Color("#9C765E")
const BRIDGE_SIDE_COLOR := Color("#604A3D")
const BRIDGE_TOP_COLOR := Color("#806A58")

@export_range(4.0, 20.0, 1.0) var animation_fps := 10.0
@export_range(0.2, 3.0, 0.1) var coast_pulse_speed := 0.9
@export_range(1, 6, 1) var coast_extra_width := 4
@export_range(0.2, 2.0, 0.1) var sea_level_speed := 0.65
@export_range(1, 6, 1) var sea_level_amplitude := 3
@export_range(1.0, 5.0, 0.1) var foam_cycle_seconds := 2.4
@export_range(2, 16, 1) var foam_travel := 9

var _elapsed := 0.0
var _redraw_elapsed := 0.0
var _map: IslandMap


func _ready() -> void:
	_map = get_parent() as IslandMap
	set_process(_map != null)


func _process(delta: float) -> void:
	_elapsed += delta
	_redraw_elapsed += delta
	var frame_time := 1.0 / maxf(animation_fps, 1.0)
	if _redraw_elapsed >= frame_time:
		_redraw_elapsed = fmod(_redraw_elapsed, frame_time)
		queue_redraw()


func _draw() -> void:
	if _map == null or not _map.has_generated_map():
		return
	var visible_rect := _visible_world_rect().grow(TILE_SIZE)
	var min_cell := Vector2i(
		maxi(0, floori(visible_rect.position.x / TILE_SIZE) - 1),
		maxi(0, floori(visible_rect.position.y / TILE_SIZE) - 1)
	)
	var max_cell := Vector2i(
		mini(_map.map_width - 1, ceili(visible_rect.end.x / TILE_SIZE) + 1),
		mini(_map.map_height - 1, ceili(visible_rect.end.y / TILE_SIZE) + 1)
	)
	var tide_phase := _elapsed * coast_pulse_speed
	var extra_width := int(round(
		(sin(tide_phase) * 0.5 + 0.5) * coast_extra_width
	))
	var sea_offset := int(round(
		sin(_elapsed * sea_level_speed) * sea_level_amplitude
	))
	# Surface cleanup must finish before any outline is drawn.
	for surface_pass in [true, false]:
		for y in range(min_cell.y, max_cell.y + 1):
			for x in range(min_cell.x, max_cell.x + 1):
				var cell := Vector2i(x, y)
				if not _map.is_grass(cell):
					continue
				_draw_cell_coast_effects(
					cell, surface_pass, extra_width, sea_offset
				)
	_draw_bridge_post_waterlines(extra_width, sea_offset)
	_draw_bridge_deck_foreground()
	_draw_bridge_posts_foreground()


func _visible_world_rect() -> Rect2:
	var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
	var first_corner := inverse_canvas * Vector2.ZERO
	var second_corner := inverse_canvas * get_viewport_rect().size
	return Rect2(first_corner, second_corner - first_corner).abs()


func _draw_cell_coast_effects(
	cell: Vector2i,
	surface_pass: bool,
	extra_width: int,
	sea_offset: int
) -> void:
	var origin := Vector2(cell) * TILE_SIZE
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _map.is_grass(cell + direction) or _map.is_bridge(cell + direction):
			continue
		if direction == Vector2i.DOWN:
			_draw_moving_south_waterline(
				cell, origin, extra_width, sea_offset, surface_pass
			)
		elif direction == Vector2i.UP:
			_draw_moving_north_waterline(
				cell, origin, extra_width, sea_offset, surface_pass
			)
		elif not surface_pass:
			var coast_rect := _vertical_coast_rect(
				cell,
				direction,
				origin,
				_map.coast_width + extra_width,
				sea_offset
			)
			if coast_rect.size.y > 0.0:
				draw_rect(coast_rect, COAST_COLOR, true, -1.0, false)
		if not surface_pass:
			_draw_foam_blocks(cell, direction, origin, extra_width, sea_offset)


func _draw_moving_north_waterline(
	cell: Vector2i,
	origin: Vector2,
	extra_width: int,
	sea_offset: int,
	surface_pass: bool
) -> void:
	var resting_surface := origin.y
	var surface_y := resting_surface + sea_offset
	var line_width := _map.coast_width + extra_width
	var span := _horizontal_span(cell, origin, line_width, Vector2i.UP)
	if surface_pass:
		var cover_top := (
			resting_surface
			- _map.coast_width
			- coast_extra_width
			- sea_level_amplitude
			- 2
		)
		var water_color := _map.get_ocean_color(cell + Vector2i.UP)
		draw_rect(
			Rect2(
				Vector2(span.position.x, cover_top),
				Vector2(span.size.x, maxf(0.0, surface_y - cover_top))
			),
			water_color,
			true,
			-1.0,
			false
		)
		if surface_y < resting_surface:
			draw_rect(
				Rect2(
					Vector2(origin.x, surface_y),
					Vector2(TILE_SIZE, resting_surface - surface_y)
				),
				LAND_COLOR,
				true,
				-1.0,
				false
			)
		return

	draw_rect(
		Rect2(
			Vector2(span.position.x, surface_y - line_width),
			Vector2(span.size.x, line_width)
		),
		COAST_COLOR,
		true,
		-1.0,
		false
	)


func _draw_moving_south_waterline(
	cell: Vector2i,
	origin: Vector2,
	extra_width: int,
	sea_offset: int,
	surface_pass: bool
) -> void:
	var cliff_top := origin.y + TILE_SIZE
	var resting_surface := cliff_top + CLIFF_DEPTH
	var surface_y := resting_surface + sea_offset
	var line_width := _map.coast_width + extra_width
	var span := _horizontal_span(cell, origin, line_width, Vector2i.DOWN)
	if surface_pass:
		var cover_bottom := (
			resting_surface
			+ _map.coast_width
			+ coast_extra_width
			+ sea_level_amplitude
			+ 2
		)
		var water_color := _map.get_ocean_color(cell + Vector2i.DOWN)
		draw_rect(
			Rect2(
				Vector2(origin.x, cliff_top),
				Vector2(TILE_SIZE, maxf(0.0, surface_y - cliff_top))
			),
			CLIFF_COLOR,
			true,
			-1.0,
			false
		)
		draw_rect(
			Rect2(
				Vector2(span.position.x, surface_y),
				Vector2(span.size.x, maxf(0.0, cover_bottom - surface_y))
			),
			water_color,
			true,
			-1.0,
			false
		)
		return

	draw_rect(
		Rect2(
			Vector2(span.position.x, surface_y),
			Vector2(span.size.x, line_width)
		),
		COAST_COLOR,
		true,
		-1.0,
		false
	)

func _vertical_coast_rect(
	cell: Vector2i,
	direction: Vector2i,
	origin: Vector2,
	width: int,
	sea_offset: int
) -> Rect2:
	var starts_at_moving_water := (
		not _map.is_grass(cell + Vector2i.UP)
		and not _map.is_bridge(cell + Vector2i.UP)
	)
	var ends_at_moving_water := (
		not _map.is_grass(cell + Vector2i.DOWN)
		and not _map.is_bridge(cell + Vector2i.DOWN)
	)
	var top := origin.y
	if starts_at_moving_water:
		top += sea_offset - width
	var bottom := origin.y + TILE_SIZE
	if ends_at_moving_water:
		bottom += CLIFF_DEPTH + sea_offset + width

	var side_cell := cell + direction
	var side_cell_above := side_cell + Vector2i.UP
	var side_cell_below := side_cell + Vector2i.DOWN
	if (
		_map.is_grass(side_cell_above)
		and not _map.is_grass(side_cell)
	):
		top = maxf(top, origin.y + CLIFF_DEPTH + sea_offset)
	if _map.is_grass(side_cell_below):
		bottom = minf(bottom, origin.y + TILE_SIZE + sea_offset)
	var x := origin.x - width if direction == Vector2i.LEFT else origin.x + TILE_SIZE
	return Rect2(
		Vector2(round(x), round(top)),
		Vector2(width, round(bottom - top))
	)


func _horizontal_span(
	cell: Vector2i,
	origin: Vector2,
	line_width: int,
	water_direction: Vector2i
) -> Rect2:
	var left_cell := cell + Vector2i.LEFT
	var right_cell := cell + Vector2i.RIGHT
	var diagonal_left := left_cell + water_direction
	var diagonal_right := right_cell + water_direction
	var left_margin := 0
	var right_margin := 0
	if _is_open_water_cell(left_cell) and _is_open_water_cell(diagonal_left):
		left_margin = line_width
	if _is_open_water_cell(right_cell) and _is_open_water_cell(diagonal_right):
		right_margin = line_width
	return Rect2(
		Vector2(origin.x - left_margin, 0.0),
		Vector2(TILE_SIZE + left_margin + right_margin, 0.0)
	)


func _is_open_water_cell(cell: Vector2i) -> bool:
	return not _map.is_grass(cell) and not _map.is_bridge(cell)

func _draw_bridge_post_waterlines(extra_width: int, sea_offset: int) -> void:
	var width := _map.coast_width + extra_width
	for base_rect in _map.get_bridge_water_post_bases():
		var shifted := Rect2(
			base_rect.position + Vector2(0.0, sea_offset),
			base_rect.size
		)
		draw_rect(
			Rect2(
				shifted.position - Vector2(width, width),
				Vector2(shifted.size.x + width * 2, width)
			),
			COAST_COLOR, true, -1.0, false
		)
		draw_rect(
			Rect2(
				Vector2(shifted.position.x - width, shifted.end.y),
				Vector2(shifted.size.x + width * 2, width)
			),
			COAST_COLOR, true, -1.0, false
		)
		draw_rect(
			Rect2(
				Vector2(shifted.position.x - width, shifted.position.y),
				Vector2(width, shifted.size.y)
			),
			COAST_COLOR, true, -1.0, false
		)
		draw_rect(
			Rect2(
				Vector2(shifted.end.x, shifted.position.y),
				Vector2(width, shifted.size.y)
			),
			COAST_COLOR, true, -1.0, false
		)

func _draw_bridge_posts_foreground() -> void:
	for post_rect in _map.get_bridge_post_rects():
		draw_rect(post_rect, BRIDGE_SIDE_COLOR, true, -1.0, false)
		draw_rect(
			Rect2(post_rect.position, Vector2(post_rect.size.x, 8.0)),
			BRIDGE_POST_TOP_COLOR,
			true,
			-1.0,
			false
		)

func _draw_bridge_deck_foreground() -> void:
	var bridge_rect := _map.get_dock_bridge_rect()
	if bridge_rect.size.x <= 0.0 or bridge_rect.size.y <= 0.0:
		return
	var total_length := int(bridge_rect.size.y)
	var tile_count := maxi(1, int(bridge_rect.size.y / TILE_SIZE))
	var plank_count := tile_count * _map.bridge_planks_per_tile
	for plank_index in plank_count:
		var slot_start := int(plank_index * total_length / plank_count)
		var slot_end := int((plank_index + 1) * total_length / plank_count)
		var slot_length := slot_end - slot_start
		var gap := mini(_map.bridge_plank_gap, maxi(0, slot_length - 1))
		var drawable_length := slot_length - gap
		var side_height := mini(
			_map.bridge_plank_side_height,
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
				BRIDGE_SIDE_COLOR, true, -1.0, false
			)
		if top_length > 0:
			draw_rect(
				Rect2(
					plank_position,
					Vector2(bridge_rect.size.x, top_length)
				),
				BRIDGE_TOP_COLOR, true, -1.0, false
			)


func _draw_foam_blocks(
	cell: Vector2i,
	direction: Vector2i,
	origin: Vector2,
	extra_width: int,
	sea_offset: int
) -> void:
	for foam_index in 2:
		var hash_value := _hash(cell, direction + Vector2i.ONE * foam_index)
		var offset_time := float(hash_value % 1000) / 1000.0
		var progress := fmod(_elapsed / foam_cycle_seconds + offset_time, 1.0)
		if progress > 0.72:
			continue
		var size := FOAM_SIZES[hash_value % FOAM_SIZES.size()]
		var along := 8 + hash_value % maxi(1, TILE_SIZE - size - 16)
		var outward := _map.coast_width + extra_width + 3 + int(progress * foam_travel)
		var position := _foam_position(
			direction,
			origin,
			along,
			outward,
			size,
			sea_offset
		)
		var foam_rect := Rect2(position.round(), Vector2.ONE * size)
		if _rect_is_open_water(foam_rect):
			draw_rect(foam_rect, FOAM_COLOR, true, -1.0, false)


func _foam_position(
	direction: Vector2i,
	origin: Vector2,
	along: int,
	outward: int,
	size: int,
	sea_offset: int
) -> Vector2:
	if direction == Vector2i.LEFT:
		return origin + Vector2(-outward - size, along)
	if direction == Vector2i.RIGHT:
		return origin + Vector2(TILE_SIZE + outward, along)
	if direction == Vector2i.UP:
		return origin + Vector2(along, sea_offset - outward - size)
	return origin + Vector2(
		along,
		TILE_SIZE + CLIFF_DEPTH + sea_offset + outward
	)

func _rect_is_open_water(rect: Rect2) -> bool:
	var map_size := Vector2(_map.map_width, _map.map_height) * TILE_SIZE
	if (
		rect.position.x < 0.0
		or rect.position.y < 0.0
		or rect.end.x > map_size.x
		or rect.end.y > map_size.y
	):
		return false
	var min_cell := Vector2i(
		floori(rect.position.x / TILE_SIZE),
		floori(rect.position.y / TILE_SIZE)
	)
	var max_cell := Vector2i(
		floori((rect.end.x - 1.0) / TILE_SIZE),
		floori((rect.end.y - 1.0) / TILE_SIZE)
	)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if _map.is_grass(cell) or _map.is_bridge(cell):
				return false
	if _rect_overlaps_visual_cliff(rect):
		return false
	return true


func _rect_overlaps_visual_cliff(rect: Rect2) -> bool:
	var min_x := maxi(0, floori(rect.position.x / TILE_SIZE) - 1)
	var max_x := mini(_map.map_width - 1, floori((rect.end.x - 1.0) / TILE_SIZE) + 1)
	var min_y := maxi(0, floori(rect.position.y / TILE_SIZE) - 1)
	var max_y := mini(_map.map_height - 1, floori((rect.end.y - 1.0) / TILE_SIZE))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var land_cell := Vector2i(x, y)
			if _map.is_grass(land_cell) and not _map.is_grass(land_cell + Vector2i.DOWN):
				var cliff_rect := Rect2(
					Vector2(x * TILE_SIZE, (y + 1) * TILE_SIZE),
					Vector2(TILE_SIZE, CLIFF_DEPTH)
				)
				if rect.intersects(cliff_rect, false):
					return true
	return false


func _hash(cell: Vector2i, direction: Vector2i) -> int:
	return absi(
		(cell.x * 73856093)
		^ (cell.y * 19349663)
		^ (direction.x * 83492791)
		^ (direction.y * 2971215073)
	) % 104729
