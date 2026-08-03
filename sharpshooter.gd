class_name SharpshooterEnemy
extends ArcherEnemy

const MOVE_SPEED := 75.0
const SALVO_COOLDOWN := 1.5
const SALVO_INTERVAL := 0.1
const ARROW_BASE_DAMAGE := 8
const STRENGTH := 1
const ARROW_SPEED := 380.0
const DASH_DISTANCE := 128.0
const DASH_DURATION := 0.2
const DASH_COOLDOWN := 1.5
const COOLDOWN_MOVE_SPEED := 60.0
const DASH_TRAIL_SCRIPT := preload("res://sharpshooter_dash_trail.gd")
const TRIPLE_BOW_ATTACK := preload("res://triple_bow_attack.gd")

@onready var triple_arrow_preview: Node2D = $TripleArrowPreview

var _salvo_remaining := 0
var _salvo_timer := 0.0
var _salvo_direction := Vector2.RIGHT
var _dash_remaining := 0.0
var _dash_cooldown := 0.0
var _dash_direction := Vector2.RIGHT
var _trail_elapsed := 0.0
var _dash_then_salvo := false
var _triple_bow_attack = TRIPLE_BOW_ATTACK.new(3, SALVO_INTERVAL, SALVO_COOLDOWN)


func _ready() -> void:
	super._ready()
	arrow_preview.visible = false
	triple_arrow_preview.visible = false


func configure(new_target: Node2D, spawn_seed: int) -> void:
	super.configure(new_target, spawn_seed)
	max_health = 32
	health = max_health
	_attack_cooldown = 0.6


func _physics_process(delta: float) -> void:
	var island_map := get_parent() as IslandMap
	if island_map != null:
		target = island_map.get_enemy_target(global_position, target)
	if _dead or not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	var to_target := target.global_position - global_position
	if to_target.is_zero_approx():
		velocity = Vector2.ZERO
		return
	var aim_direction := to_target.normalized()
	_update_facing(aim_direction)
	bow_weapon.set_aim_direction(aim_direction)
	var firing_origin := global_position
	var has_clear_line := island_map == null or island_map.has_clear_archer_line_of_fire(firing_origin, target.global_position, self)
	var within_range := to_target.length() <= PREFERRED_MAX_RANGE
	var too_close := to_target.length() < PREFERRED_MIN_RANGE
	var can_fire := has_clear_line
	var navigation_direction := -aim_direction if too_close else _navigation_direction(to_target, not has_clear_line, not has_clear_line)
	_blocked_direction_remaining = maxf(0.0, _blocked_direction_remaining - delta)
	var recovering := _blocked_direction_remaining > 0.0
	if recovering:
		navigation_direction = _blocked_direction
	elif island_map != null and not _movement_escape.is_escaping():
		navigation_direction = island_map.get_obstacle_sliding_direction(global_position, navigation_direction, self)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_triple_bow_attack.tick(delta)
	if _dash_remaining > 0.0:
		_update_dash(delta)
		return
	if _salvo_remaining > 0:
		_move_with_recovery(navigation_direction, island_map, delta, COOLDOWN_MOVE_SPEED)
		_update_salvo(delta)
		return
	# Dashes evade imminent player fire, reach the preferred range, and set up volleys.
	if _dash_cooldown <= 0.0:
		var evade_direction := _get_incoming_projectile_evade_direction()
		if not evade_direction.is_zero_approx():
			_dash_then_salvo = false
			if island_map != null:
				evade_direction = island_map.get_obstacle_sliding_direction(global_position, evade_direction, self)
			_begin_dash(evade_direction)
			return
		_dash_then_salvo = can_fire
		var dash_direction := _get_attack_dash_direction(aim_direction, navigation_direction) if can_fire else navigation_direction
		if not dash_direction.is_zero_approx():
			_begin_dash(dash_direction)
			return
	_move_with_recovery(navigation_direction, island_map, delta, COOLDOWN_MOVE_SPEED)
	_show_ready_arrows(aim_direction)


func _get_incoming_projectile_evade_direction() -> Vector2:
	for node in get_tree().get_nodes_in_group("arrow_projectiles"):
		var arrow := node as ArrowProjectile
		if arrow == null or not arrow.friendly:
			continue
		var evade_direction := _get_projectile_evade_direction(arrow.global_position, arrow.direction, arrow.speed)
		if not evade_direction.is_zero_approx():
			return evade_direction
	for node in get_tree().get_nodes_in_group("rock_projectiles"):
		var rock := node as RockProjectile
		if rock == null or rock.shooter != target:
			continue
		var evade_direction := _get_projectile_evade_direction(rock.global_position, rock.direction, RockProjectile.SPEED)
		if not evade_direction.is_zero_approx():
			return evade_direction
	return Vector2.ZERO

func _get_projectile_evade_direction(projectile_position: Vector2, projectile_direction: Vector2, projectile_speed: float) -> Vector2:
	var to_self := global_position - projectile_position
	var forward_distance := to_self.dot(projectile_direction)
	if forward_distance <= 0.0 or forward_distance > projectile_speed * 0.75:
		return Vector2.ZERO
	var lateral := to_self - projectile_direction * forward_distance
	if lateral.length() > 52.0:
		return Vector2.ZERO
	return lateral.normalized() if lateral.length() > 1.0 else projectile_direction.orthogonal() * _strafe_sign

func _get_attack_dash_direction(aim_direction: Vector2, navigation_direction: Vector2) -> Vector2:
	var strafe_direction := aim_direction.orthogonal() * _strafe_sign
	if (target.global_position - global_position).length() < PREFERRED_MIN_RANGE:
		return (-aim_direction).slerp(strafe_direction, 0.25).normalized()
	if navigation_direction.is_zero_approx():
		return strafe_direction
	return navigation_direction.slerp(strafe_direction, 0.8).normalized()

func _move_with_recovery(navigation_direction: Vector2, _island_map: IslandMap, delta: float, speed: float = MOVE_SPEED) -> void:
	navigation_direction = _movement_escape.choose_direction(self, navigation_direction, speed, delta)
	velocity = navigation_direction * speed
	move_and_slide()
	_movement_escape.report_motion(self, navigation_direction, speed, delta)


func _show_ready_arrows(aim_direction: Vector2) -> void:
	triple_arrow_preview.visible = true
	triple_arrow_preview.position = Vector2.ZERO
	triple_arrow_preview.rotation = aim_direction.angle()
	for arrow_name in [&"UpperArrow", &"CenterArrow", &"LowerArrow"]:
		var preview_arrow := triple_arrow_preview.get_node_or_null(NodePath(arrow_name)) as CanvasItem
		if preview_arrow != null:
			preview_arrow.visible = true


func _set_triple_arrow_preview_visible(index: int, is_visible: bool) -> void:
	var arrow_names := [&"UpperArrow", &"CenterArrow", &"LowerArrow"]
	if index < 0 or index >= arrow_names.size():
		return
	var preview_arrow := triple_arrow_preview.get_node_or_null(NodePath(arrow_names[index])) as CanvasItem
	if preview_arrow != null:
		preview_arrow.visible = is_visible


func _begin_salvo(aim_direction: Vector2) -> void:
	if not _triple_bow_attack.begin():
		return
	_salvo_direction = aim_direction
	_salvo_remaining = _triple_bow_attack.remaining
	_salvo_timer = _triple_bow_attack.timer
	_show_ready_arrows(aim_direction)


func _update_salvo(delta: float) -> void:
	for fired_index in _triple_bow_attack.advance(delta):
		var angle_offset := deg_to_rad(5.0 - float(fired_index) * 5.0)
		_set_triple_arrow_preview_visible(fired_index, false)
		_fire_divine_arrow(_salvo_direction.rotated(angle_offset))
	_salvo_remaining = _triple_bow_attack.remaining
	_salvo_timer = _triple_bow_attack.timer
	if not _triple_bow_attack.active:
		_attack_cooldown = _triple_bow_attack.cooldown_remaining

func _fire_divine_arrow(direction: Vector2) -> void:
	var visual_origin := global_position + direction * BOW_ARROW_ORIGIN
	var island_map := get_parent() as IslandMap
	if island_map == null or not island_map.segment_touches_body(global_position, visual_origin, target):
		var arrow := ARROW_SCENE.instantiate() as ArrowProjectile
		arrow.configure(direction, self, false, ARROW_BASE_DAMAGE + STRENGTH, ARROW_SPEED, true)
		get_parent().add_child(arrow)
		arrow.global_position = visual_origin
	else:
		target.take_damage(ARROW_BASE_DAMAGE + STRENGTH)
	bow_fire_flash.play(direction, BOW_ARROW_ORIGIN)


func _begin_dash(direction: Vector2) -> void:
	_dash_direction = direction.normalized()
	_dash_remaining = DASH_DURATION
	_dash_cooldown = DASH_COOLDOWN
	triple_arrow_preview.visible = false
	_trail_elapsed = 0.0
	_spawn_dash_trail()


func _update_dash(delta: float) -> void:
	var step := minf(delta, _dash_remaining)
	move_and_collide(_dash_direction * (DASH_DISTANCE / DASH_DURATION) * step)
	_dash_remaining -= step
	if _dash_remaining <= 0.0:
		velocity = Vector2.ZERO
		if _dash_then_salvo:
			_dash_then_salvo = false
			var aim_direction := (target.global_position - global_position).normalized()
			if not aim_direction.is_zero_approx():
				_begin_salvo(aim_direction)


func _spawn_weapon_pickup(drop_position: Vector2) -> void:
	var weapon_pickup := WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
	weapon_pickup.configure_weapon(WeaponPickup.WeaponType.TRIPLE_BOW)
	get_parent().add_child(weapon_pickup)
	weapon_pickup.global_position = drop_position

func _die() -> void:
	triple_arrow_preview.visible = false
	super._die()

func _spawn_dash_trail() -> void:
	var trail := DASH_TRAIL_SCRIPT.new() as Node2D
	get_parent().add_child(trail)
	trail.global_position = global_position + _dash_direction * DASH_DISTANCE
	trail.z_index = z_index - 1
	trail.configure(_dash_direction, DASH_DISTANCE, 38.0)