class_name CrescentWave
extends Area2D

const AFTERIMAGE_SCRIPT := preload("res://crescent_wave_afterimage.gd")
const OUTER_CENTER := Vector2(-112.0, 0.0)
const OUTER_RADIUS := 112.0
const INNER_CENTER := Vector2(-108.0, 0.0)
const INNER_RADIUS := 102.0
const HALF_ARC_ANGLE := 0.46
const TARGET_HIT_COOLDOWN := 0.2
const SPEED := 200.0
const MAX_RANGE := 192.0
const MIN_DAMAGE := 2
const AFTERIMAGE_INTERVAL := 0.055

var direction := Vector2.RIGHT
var damage := 10
var travelled := 0.0
var _hit_cooldowns: Dictionary = {}
var _afterimage_elapsed := 0.0
var target: Node2D
var source_actor: Node2D

func configure(new_direction: Vector2, new_damage: int, new_target: Node2D) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	target = new_target
	rotation = direction.angle()
	queue_redraw()

func configure_player(new_direction: Vector2, new_damage: int, new_source_actor: IslandPlayer) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	source_actor = new_source_actor
	rotation = direction.angle()
	queue_redraw()

func _ready() -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	for target_id in _hit_cooldowns.keys():
		var remaining := float(_hit_cooldowns[target_id]) - delta
		if remaining <= 0.0:
			_hit_cooldowns.erase(target_id)
		else:
			_hit_cooldowns[target_id] = remaining
	var step := minf(SPEED * delta, MAX_RANGE - travelled)
	global_position += direction * step
	travelled += step
	var flight_ratio := clampf(travelled / MAX_RANGE, 0.0, 1.0)
	var growth := smoothstep(0.0, 1.0, flight_ratio)
	scale = Vector2.ONE * lerpf(0.88, 1.18, growth)
	modulate.a = lerpf(1.0, 0.18, flight_ratio)
	_afterimage_elapsed += delta
	if _afterimage_elapsed >= AFTERIMAGE_INTERVAL:
		_afterimage_elapsed = 0.0
		_spawn_afterimage()
	if travelled >= MAX_RANGE:
		queue_free()
		return
	var current_damage := _get_distance_damage()
	if source_actor is IslandPlayer:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and _crescent_touches_body(enemy) and _can_hit_target(enemy):
				enemy.take_damage(current_damage)
				_apply_player_knockback(enemy)
	elif is_instance_valid(target) and _crescent_touches_body(target) and _can_hit_target(target):
		target.take_damage(current_damage)
		var body := target as CharacterBody2D
		if body != null:
			body.move_and_collide(direction * 8.0)

func _get_distance_damage() -> int:
	var falloff := clampf(travelled / MAX_RANGE, 0.0, 1.0)
	return maxi(MIN_DAMAGE, roundi(lerpf(float(damage), float(MIN_DAMAGE), falloff)))

func _spawn_afterimage() -> void:
	var afterimage := AFTERIMAGE_SCRIPT.new() as Node2D
	get_parent().add_child(afterimage)
	afterimage.global_position = global_position
	afterimage.z_index = z_index - 1
	afterimage.configure(direction, _get_faction_color())

func _can_hit_target(hit_target: Node) -> bool:
	var target_id := hit_target.get_instance_id()
	if _hit_cooldowns.has(target_id):
		return false
	_hit_cooldowns[target_id] = TARGET_HIT_COOLDOWN
	return true

func _apply_player_knockback(enemy: Node) -> void:
	var body := enemy as CharacterBody2D
	if body != null and not body.is_in_group("bosses"):
		body.move_and_collide(direction * 8.0)

func _crescent_touches_body(body: Node2D) -> bool:
	var collision_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or not collision_shape.shape is RectangleShape2D:
		return _crescent_touches_point(body.global_position)
	var rectangle := collision_shape.shape as RectangleShape2D
	var half_size := rectangle.size * 0.5
	var body_polygon := PackedVector2Array([
		collision_shape.global_transform * Vector2(-half_size.x, -half_size.y),
		collision_shape.global_transform * Vector2(half_size.x, -half_size.y),
		collision_shape.global_transform * Vector2(half_size.x, half_size.y),
		collision_shape.global_transform * Vector2(-half_size.x, half_size.y),
	])
	return not Geometry2D.intersect_polygons(_get_world_crescent_polygon(), body_polygon).is_empty()

func _crescent_touches_point(world_position: Vector2) -> bool:
	var local_point := to_local(world_position)
	var outer_distance := local_point.distance_to(OUTER_CENTER)
	var inner_distance := local_point.distance_to(INNER_CENTER)
	var outer_angle := (local_point - OUTER_CENTER).angle()
	return (
		outer_distance <= OUTER_RADIUS + 16.0
		and inner_distance >= INNER_RADIUS - 16.0
		and absf(outer_angle) <= HALF_ARC_ANGLE
	)

func _get_world_crescent_polygon() -> PackedVector2Array:
	var polygon := _get_local_crescent_polygon()
	for index in range(polygon.size()):
		polygon[index] = global_transform * polygon[index]
	return polygon

func _get_local_crescent_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for index in range(25):
		var ratio := float(index) / 24.0
		var angle := lerpf(-HALF_ARC_ANGLE, HALF_ARC_ANGLE, ratio)
		polygon.append(OUTER_CENTER + Vector2.from_angle(angle) * OUTER_RADIUS)
	for index in range(24, -1, -1):
		var ratio := float(index) / 24.0
		var angle := lerpf(-HALF_ARC_ANGLE, HALF_ARC_ANGLE, ratio)
		polygon.append(INNER_CENTER + Vector2.from_angle(angle) * INNER_RADIUS)
	return polygon
func _get_faction_color() -> Color:
	return Color("#1A64B5") if source_actor is IslandPlayer else Color("#8B1E2D")

func _draw() -> void:
	var polygon := _get_local_crescent_polygon()
	draw_colored_polygon(polygon, Color.WHITE)
	var faction := _get_faction_color()
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for index in range(25):
		var ratio := float(index) / 24.0
		var angle := lerpf(-HALF_ARC_ANGLE, HALF_ARC_ANGLE, ratio)
		outer.append(OUTER_CENTER + Vector2.from_angle(angle) * OUTER_RADIUS)
		inner.append(INNER_CENTER + Vector2.from_angle(angle) * INNER_RADIUS)
	draw_polyline(outer, faction, 2.0, false)
	draw_polyline(inner, faction, 2.0, false)
	draw_line(outer[0], inner[0], faction, 2.0, false)
	draw_line(outer[outer.size() - 1], inner[inner.size() - 1], faction, 2.0, false)