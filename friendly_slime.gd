class_name FriendlySlime
extends CharacterBody2D

signal removed(respawn_delay: float)

const HIT_EFFECT_SCENE := preload("res://hit_effect.gd")
const DAMAGE_NUMBER_SCENE := preload("res://damage_number.tscn")
const LANDING_EFFECT_SCENE := preload("res://slime_landing_effect.gd")
const MOVEMENT_ESCAPE := preload("res://enemy_movement_escape.gd")
const JUMP_DISTANCE := 64.0 * 1.5
const JUMP_DURATION := 1.0
const JUMP_DIRECTION_VARIANCE := 0.16
const JUMP_HEIGHT := 30.0
const LANDING_DAMAGE := 3
const MAX_HEALTH := 12
const LOW_HEALTH_GEL := Color("#277B68A8")
const FULL_HEALTH_GEL := Color("#00E3A86B")
const OFFSCREEN_DESPAWN_SECONDS := 2.5
const WANDER_DIRECTION_MEMORY := 0.72
const JUMP_PROBE_DISTANCE := 72.0
const TARGET_SLOT_BIAS := 220.0

@onready var visual: Node2D = $Visual
@onready var gel: Polygon2D = $Visual/Gel
@onready var contact_shadow: Polygon2D = $ContactShadow

var target: Node2D
var health := MAX_HEALTH
var defense := 0
var _owner_player: IslandPlayer
var _damage := LANDING_DAMAGE
var _jumping := false
var _jump_elapsed := 0.0
var _jump_direction := Vector2.RIGHT
var _dead := false
var _offscreen_elapsed := 0.0
var _movement_rng := RandomNumberGenerator.new()
var _movement_escape = MOVEMENT_ESCAPE.new()
var _last_wander_direction := Vector2.RIGHT
var _last_jump_direction := Vector2.RIGHT
var _summon_slot := 0


func configure(new_owner: IslandPlayer, summon_strength: int, summon_defense: int, spawn_seed: int, summon_slot := 0) -> void:
	_owner_player = new_owner
	_damage = LANDING_DAMAGE + summon_strength
	defense = summon_defense
	_summon_slot = summon_slot
	_movement_rng.seed = spawn_seed
	_movement_escape.configure(spawn_seed ^ 0x6A11)

func get_summon_slot() -> int:
	return _summon_slot

func _ready() -> void:
	add_to_group("player_allies")
	_update_health_visual()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_update_offscreen_lifetime(delta)
	if _dead:
		return
	target = _find_nearest_enemy()
	if not _jumping:
		_begin_jump()
		return
	_update_jump(delta)


func _update_offscreen_lifetime(delta: float) -> void:
	var visible_rect := _get_owner_visible_rect(48.0)
	if visible_rect.size == Vector2.ZERO:
		return
	if visible_rect.has_point(global_position):
		_offscreen_elapsed = 0.0
		return
	_offscreen_elapsed += delta
	if _offscreen_elapsed >= OFFSCREEN_DESPAWN_SECONDS:
		_expire_offscreen()

func _get_owner_visible_rect(extra_margin := 0.0) -> Rect2:
	if not is_instance_valid(_owner_player):
		return Rect2()
	var camera := _owner_player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return Rect2()
	var visible_size := get_viewport_rect().size / camera.zoom
	return Rect2(_owner_player.global_position - visible_size * 0.5, visible_size).grow(extra_margin)


func _keep_inside_owner_view() -> void:
	var visible_rect := _get_owner_visible_rect(-20.0)
	if visible_rect.size == Vector2.ZERO:
		return
	global_position = Vector2(
		clampf(global_position.x, visible_rect.position.x, visible_rect.end.x),
		clampf(global_position.y, visible_rect.position.y, visible_rect.end.y)
	)

func _find_nearest_enemy() -> Node2D:
	var nearest_visible: Node2D
	var nearest_visible_score := INF
	var nearest_any: Node2D
	var nearest_any_score := INF
	var island_map := get_parent() as IslandMap
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var score := _get_enemy_target_score(enemy_node)
		if score < nearest_any_score:
			nearest_any_score = score
			nearest_any = enemy_node
		var has_clear_line := island_map == null or island_map.has_clear_archer_line_of_fire(global_position, enemy_node.global_position, self)
		if has_clear_line and score < nearest_visible_score:
			nearest_visible_score = score
			nearest_visible = enemy_node
	return nearest_visible if nearest_visible != null else nearest_any


func _get_enemy_target_score(enemy_node: Node2D) -> float:
	var offset := enemy_node.global_position - global_position
	var score := offset.length_squared()
	var side := -1.0 if _summon_slot % 2 == 0 else 1.0
	if is_instance_valid(_owner_player):
		var owner_offset := enemy_node.global_position - _owner_player.global_position
		score -= owner_offset.normalized().dot(Vector2.RIGHT.rotated(float(_summon_slot) * PI * 0.85)) * TARGET_SLOT_BIAS
	score -= signf(offset.x) * side * TARGET_SLOT_BIAS
	return score


func _begin_jump() -> void:
	var island_map := get_parent() as IslandMap
	var desired_direction := _choose_jump_direction(island_map)
	if desired_direction.is_zero_approx():
		desired_direction = _choose_wander_direction()
	_jump_direction = _choose_unblocked_direction(desired_direction, island_map)
	_last_jump_direction = _jump_direction
	_jumping = true
	_jump_elapsed = 0.0
	visual.scale = Vector2(0.78, 1.22)


func _choose_jump_direction(island_map: IslandMap) -> Vector2:
	if is_instance_valid(target):
		var toward_target := (target.global_position - global_position).normalized()
		if toward_target.is_zero_approx():
			return Vector2.ZERO
		var has_clear_line := island_map == null or island_map.has_clear_archer_line_of_fire(global_position, target.global_position, self)
		if has_clear_line:
			return toward_target
		var navigation_direction := island_map.get_obstacle_sliding_direction(global_position, toward_target, self) if island_map != null else toward_target
		if not navigation_direction.is_zero_approx():
			return navigation_direction
	if is_instance_valid(_owner_player):
		var to_owner := _owner_player.global_position - global_position
		if to_owner.length() > JUMP_DISTANCE * 1.4:
			return to_owner.normalized()
	return Vector2.ZERO


func _choose_wander_direction() -> Vector2:
	var turn := _movement_rng.randfn(0.0, PI * 0.23)
	turn = clampf(turn, -PI * 0.82, PI * 0.82)
	var random_direction := _last_wander_direction.rotated(turn).normalized()
	if random_direction.dot(-_last_jump_direction) > 0.6:
		random_direction = random_direction.slerp(_last_jump_direction.orthogonal(), 0.8).normalized()
	_last_wander_direction = _last_wander_direction.slerp(random_direction, WANDER_DIRECTION_MEMORY).normalized()
	return _last_wander_direction


func _choose_unblocked_direction(desired_direction: Vector2, island_map: IslandMap) -> Vector2:
	var base := desired_direction.normalized()
	var candidates: Array[Vector2] = [base]
	for angle in [PI * 0.18, -PI * 0.18, PI * 0.36, -PI * 0.36, PI * 0.58, -PI * 0.58, PI * 0.82, -PI * 0.82]:
		candidates.append(base.rotated(angle).normalized())
	var best_direction := base
	var best_score := -INF
	for candidate in candidates:
		var direction := candidate
		if island_map != null:
			direction = island_map.get_obstacle_sliding_direction(global_position, direction, self)
		if direction.is_zero_approx():
			continue
		var blocked := _jump_direction_blocked(direction)
		var score := direction.dot(base) * 2.0 + direction.dot(_last_jump_direction) * 0.35
		if direction.dot(-_last_jump_direction) > 0.72:
			score -= 1.6
		if blocked:
			score -= 4.0
		if score > best_score:
			best_score = score
			best_direction = direction
	return best_direction.normalized()


func _jump_direction_blocked(direction: Vector2) -> bool:
	var island_map := get_parent() as IslandMap
	if island_map != null and island_map.actor_jump_direction_blocked(global_position, direction, JUMP_PROBE_DISTANCE, self):
		return true
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + direction.normalized() * JUMP_PROBE_DISTANCE, 3)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.hit_from_inside = false
	query.exclude = [get_rid()]
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	return not result.is_empty()


func _update_jump(delta: float) -> void:
	_jump_elapsed = minf(JUMP_DURATION, _jump_elapsed + delta)
	var progress := _jump_elapsed / JUMP_DURATION
	var movement_speed := JUMP_DISTANCE / JUMP_DURATION
	var movement := _jump_direction * movement_speed * delta
	move_and_collide(movement)
	_keep_inside_owner_view()
	_movement_escape.report_motion(self, _jump_direction, movement_speed, delta)
	var arc := sin(progress * PI)
	visual.position.y = -arc * JUMP_HEIGHT
	visual.scale = Vector2(lerpf(0.78, 1.08, arc), lerpf(1.22, 0.92, arc))
	contact_shadow.scale = Vector2(lerpf(0.85, 0.55, arc), lerpf(0.85, 0.55, arc))
	if progress >= 1.0:
		_land()


func _land() -> void:
	_jumping = false
	visual.position = Vector2.ZERO
	visual.scale = Vector2(1.28, 0.72)
	contact_shadow.scale = Vector2.ONE
	var squash_tween := create_tween()
	squash_tween.tween_property(visual, "scale", Vector2.ONE, 0.12)
	var effect := LANDING_EFFECT_SCENE.new() as Node2D
	effect.call("configure", _owner_player, _damage, 16.0, 32.0, -1, true)
	effect.global_position = global_position
	get_parent().add_child(effect)


func take_damage(amount: int) -> void:
	if _dead:
		return
	var final_damage := maxi(1, amount - defense)
	_show_damage_number(final_damage)
	health = maxi(0, health - final_damage)
	_update_health_visual()
	_flash_brightness()
	if health <= 0:
		_die()


func take_true_damage(amount: int) -> void:
	if _dead:
		return
	_show_damage_number(amount)
	health = maxi(0, health - amount)
	_update_health_visual()
	_flash_brightness()
	if health <= 0:
		_die()
func show_projectile_hit(hit_color: Color) -> void:
	if _dead:
		return
	_flash_brightness()
	var effect := HIT_EFFECT_SCENE.new() as Node2D
	effect.call("configure", hit_color)
	get_parent().add_child(effect)
	effect.global_position = global_position


func _show_damage_number(amount: int) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate() as Node2D
	damage_number.call("configure", amount, Color.WHITE)
	get_parent().add_child(damage_number)
	damage_number.global_position = global_position


func _update_health_visual() -> void:
	var ratio := clampf(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	gel.color = LOW_HEALTH_GEL.lerp(FULL_HEALTH_GEL, ratio)


func _flash_brightness() -> void:
	visual.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.075)


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	set_collision_layer_value(3, false)
	removed.emit(6.0)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 0.15, 0.16)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback(queue_free)


func _expire_offscreen() -> void:
	_dead = true
	removed.emit(0.0)
	queue_free()
