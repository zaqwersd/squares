class_name ArenaSeal
extends Node2D

const OUTER_COLORS := [Color("#00646E99"), Color("#008895B5"), Color("#0AA8AC8C")]
const INNER_COLORS := [Color("#39CDBBA0"), Color("#74F3D0C8"), Color("#B0FFE2A0")]
var target: IslandPlayer
var blocked_cells: Dictionary = {} # Hazard cells, excluding the brazier obstacle itself.
var fire_cells: Dictionary = {} # Visible flame cells, including the brazier cells.
var center := Vector2.ZERO
var _arena_bounds := Rect2i()
var _last_hit_cell := Vector2i(-9999, -9999)

func configure(new_target: IslandPlayer, arena_bounds: Rect2i, brazier_cells: Array[Vector2i]) -> void:
	target = new_target
	_arena_bounds = arena_bounds
	center = Vector2(arena_bounds.get_center()) * 64.0
	for torch_cell in brazier_cells:
		for x in range(arena_bounds.position.x, arena_bounds.end.x):
			var row_cell := Vector2i(x, torch_cell.y)
			if row_cell != torch_cell:
				fire_cells[row_cell] = true
				blocked_cells[row_cell] = true
		for y in range(arena_bounds.position.y, arena_bounds.end.y):
			var column_cell := Vector2i(torch_cell.x, y)
			if column_cell != torch_cell:
				fire_cells[column_cell] = true
				blocked_cells[column_cell] = true
	# Corner lines cross each other; fire never replaces a brazier cell.
	for torch_cell in brazier_cells:
		fire_cells.erase(torch_cell)
		blocked_cells.erase(torch_cell)

func _ready() -> void:
	z_index = 7
	for cell_value in fire_cells:
		_spawn_fire_pair(Vector2(cell_value) * 64.0 + Vector2(32.0, 32.0))

func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	var cell := Vector2i(floori(target.global_position.x / 64.0), floori(target.global_position.y / 64.0))
	if blocked_cells.has(cell) and cell != _last_hit_cell:
		_last_hit_cell = cell
		target.take_damage(3)
		var away := (center - target.global_position).normalized()
		if away.is_zero_approx():
			away = Vector2.DOWN
		target.global_position += away * 44.0
		# A live encounter created before a hot-reload may not have cached bounds.
		# Never clamp against an empty rectangle, because its inverted limits teleport the player.
		if _arena_bounds.size.x > 2 and _arena_bounds.size.y > 2:
			var inner_min := (Vector2(_arena_bounds.position + Vector2i.ONE) + Vector2.ONE * 0.5) * 64.0
			var inner_max := (Vector2(_arena_bounds.end - Vector2i.ONE) + Vector2.ONE * 0.5) * 64.0
			target.global_position = target.global_position.clamp(inner_min, inner_max)
	elif not blocked_cells.has(cell):
		_last_hit_cell = Vector2i(-9999, -9999)

func _spawn_fire_pair(position_in_world: Vector2) -> void:
	var outer := _make_emitter(56, 0.85, Vector3(29, 27, 1), 24.0, 44.0, Vector3(0, -18, 0), 4.0, 7.0, OUTER_COLORS)
	outer.position = position_in_world
	add_child(outer)
	var inner := _make_emitter(38, 0.64, Vector3(24, 23, 1), 20.0, 37.0, Vector3(0, -24, 0), 6.0, 10.0, INNER_COLORS)
	inner.position = position_in_world + Vector2(0.0, 1.0)
	add_child(inner)

func _make_emitter(amount: int, lifetime: float, box_extents: Vector3, velocity_min: float, velocity_max: float, gravity: Vector3, scale_minimum: float, scale_maximum: float, colors: Array) -> GPUParticles2D:
	var emitter := GPUParticles2D.new()
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.randomness = 0.42
	emitter.visibility_rect = Rect2(-40, -80, 80, 100)
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = box_extents
	material.direction = Vector3(0, -1, 0)
	material.spread = 22.0
	material.initial_velocity_min = velocity_min
	material.initial_velocity_max = velocity_max
	material.gravity = gravity
	material.scale_min = scale_minimum
	material.scale_max = scale_maximum
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray(colors)
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	material.color_initial_ramp = ramp
	emitter.process_material = material
	return emitter
