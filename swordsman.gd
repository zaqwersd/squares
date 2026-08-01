class_name SwordsmanEnemy
extends CharacterBody2D

signal defeated

const HIT_EFFECT_SCENE := preload("res://hit_effect.gd")
const DAMAGE_NUMBER_SCENE := preload("res://damage_number.tscn")
const WEAPON_PICKUP_SCENE := preload("res://weapon_pickup.tscn")
const MOVE_SPEED := 160.0
const ATTACK_INNER_RADIUS := SwordWeapon.MOUNT_OFFSET
const ATTACK_OUTER_RADIUS := SwordWeapon.MOUNT_OFFSET + SwordWeapon.BLADE_LENGTH
const ATTACK_DAMAGE := 8
const ATTACK_COOLDOWN := 0.85
const WINDUP_DURATION := 0.25
const SWING_DURATION := 0.2
const DAMAGE_MOMENT := 0.1
const OBSTACLE_COOLDOWN := 0.3
const LOW_HEALTH_TINT := Color("#7A2730")

@onready var visual: Sprite2D = $Visual
@onready var sword_weapon: SwordWeapon = $SwordWeapon
@onready var slash_effect: SwordSlashEffect = $SwordSlashEffect

var target: Node2D
var max_health := 10
var health := 10
var _attack_cooldown := 0.0
var _swinging := false
var _swing_time := 0.0
var _windup_remaining := 0.0
var _damage_applied := false
var _swing_direction := Vector2.RIGHT
var _dead := false
var _sword_rebounding := false
var _sword_rebound_tween: Tween
var _tangent_sign := 1.0
var _blocked_direction := Vector2.ZERO
var _blocked_direction_remaining := 0.0


func configure(new_target: Node2D, spawn_seed: int) -> void:
	target = new_target
	var rng := RandomNumberGenerator.new()
	rng.seed = spawn_seed
	max_health = rng.randi_range(9, 12)
	health = max_health
	_attack_cooldown = rng.randf_range(0.2, 0.8)
	_tangent_sign = -1.0 if rng.randi_range(0, 1) == 0 else 1.0


func _ready() -> void:
	add_to_group("enemies")
	slash_effect.hide_slash()
	_update_health_tint()


func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	var to_target := target.global_position - global_position
	if to_target.is_zero_approx():
		velocity = Vector2.ZERO
		return
	var aim_direction := to_target.normalized()
	visual.flip_h = aim_direction.x > 0.0
	if not _sword_rebounding:
		sword_weapon.set_aim_direction(aim_direction)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	if _sword_rebounding:
		velocity = Vector2.ZERO
		return
	if _swinging:
		velocity = Vector2.ZERO
		_update_swing(delta)
		return
	var island_map := get_parent() as IslandMap
	var has_clear_line := island_map == null or island_map.has_clear_archer_line_of_fire(global_position, target.global_position, self)
	var can_attack := (
		to_target.length() >= ATTACK_INNER_RADIUS
		and to_target.length() <= ATTACK_OUTER_RADIUS
		and has_clear_line
	)
	if not can_attack:
		var navigation_direction := island_map.get_swordsman_navigation_direction(global_position) if island_map != null else Vector2.ZERO
		if navigation_direction.is_zero_approx():
			navigation_direction = aim_direction if to_target.length() > ATTACK_OUTER_RADIUS else -aim_direction
		if not has_clear_line:
			var tangent := aim_direction.orthogonal() * _tangent_sign
			navigation_direction = navigation_direction.slerp(tangent, 0.62).normalized()
		_blocked_direction_remaining = maxf(0.0, _blocked_direction_remaining - delta)
		var recovering := _blocked_direction_remaining > 0.0
		if recovering:
			navigation_direction = _blocked_direction
		elif island_map != null:
			navigation_direction = island_map.get_obstacle_sliding_direction(global_position, navigation_direction, self)
		velocity = navigation_direction * MOVE_SPEED
		move_and_slide()
		if _blocked_direction_remaining <= 0.0 and get_real_velocity().length() < MOVE_SPEED * 0.2:
			_blocked_direction = island_map.get_unblocked_movement_direction(self, navigation_direction, MOVE_SPEED, delta) if island_map != null else navigation_direction.orthogonal()
			_tangent_sign *= -1.0
			_blocked_direction_remaining = 0.75
		else:
			_blocked_direction_remaining = 0.0
		return
	if _attack_cooldown <= 0.0:
		_begin_swing(aim_direction)


func _begin_swing(aim_direction: Vector2) -> void:
	_swinging = true
	_attack_cooldown = ATTACK_COOLDOWN
	_windup_remaining = WINDUP_DURATION
	_swing_time = 0.0
	_damage_applied = false
	_swing_direction = aim_direction
	sword_weapon.set_aim_direction(_swing_direction)
	slash_effect.hide_slash()


func _update_swing(delta: float) -> void:
	var swing_delta := delta
	if _windup_remaining > 0.0:
		var used_windup := minf(swing_delta, _windup_remaining)
		_windup_remaining -= used_windup
		swing_delta -= used_windup
		var windup_progress := smoothstep(0.0, 1.0, 1.0 - _windup_remaining / WINDUP_DURATION)
		sword_weapon.set_windup_direction(_swing_direction, windup_progress)
		if _windup_remaining > 0.0:
			return
		sword_weapon.set_swing_direction(_swing_direction, 0.0)
		slash_effect.begin_swing(_swing_direction)
	if swing_delta <= 0.0:
		return
	var previous_progress := _swing_time / SWING_DURATION
	_swing_time = minf(SWING_DURATION, _swing_time + swing_delta)
	var current_progress := _swing_time / SWING_DURATION
	sword_weapon.set_swing_direction(_swing_direction, current_progress)
	slash_effect.set_swing_progress(current_progress, _swing_direction)
	if not _damage_applied and _blade_touches_target(previous_progress, current_progress):
		_damage_applied = true
		target.take_damage(ATTACK_DAMAGE)
	if _swing_time >= SWING_DURATION:
		_swinging = false


func _interrupt_sword_on_obstacle() -> void:
	if _sword_rebounding:
		return
	_swinging = false
	_windup_remaining = 0.0
	_attack_cooldown = OBSTACLE_COOLDOWN
	slash_effect.hide_slash()
	_sword_rebounding = true
	if _sword_rebound_tween != null and _sword_rebound_tween.is_valid():
		_sword_rebound_tween.kill()
	var start_position := sword_weapon.position
	var start_rotation := sword_weapon.rotation
	var pushback := start_position.normalized() * 12.0
	_sword_rebound_tween = create_tween()
	_sword_rebound_tween.set_trans(Tween.TRANS_QUAD)
	_sword_rebound_tween.set_ease(Tween.EASE_OUT)
	_sword_rebound_tween.tween_property(sword_weapon, "position", start_position - pushback, 0.07)
	_sword_rebound_tween.parallel().tween_property(sword_weapon, "rotation", start_rotation - PI * 0.28, 0.07)
	_sword_rebound_tween.set_ease(Tween.EASE_IN)
	_sword_rebound_tween.tween_property(sword_weapon, "position", start_position, 0.1)
	_sword_rebound_tween.parallel().tween_property(sword_weapon, "rotation", start_rotation, 0.1)
	_sword_rebound_tween.tween_callback(func() -> void: _sword_rebounding = false)

func _blade_touches_target(from_progress: float, to_progress: float) -> bool:
	var collision_shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or not collision_shape.shape is RectangleShape2D:
		return false
	var rectangle := collision_shape.shape as RectangleShape2D
	var half_size := rectangle.size * 0.5
	var target_polygon := PackedVector2Array([
		collision_shape.global_transform * Vector2(-half_size.x, -half_size.y),
		collision_shape.global_transform * Vector2(half_size.x, -half_size.y),
		collision_shape.global_transform * Vector2(half_size.x, half_size.y),
		collision_shape.global_transform * Vector2(-half_size.x, half_size.y),
	])
	var blade_polygon := sword_weapon.get_swing_sector_polygon(_swing_direction, from_progress, to_progress)
	return not Geometry2D.intersect_polygons(blade_polygon, target_polygon).is_empty()


func show_projectile_hit(hit_color: Color) -> void:
	if _dead:
		return
	var effect := HIT_EFFECT_SCENE.new() as Node2D
	effect.call("configure", hit_color)
	get_parent().add_child(effect)
	effect.global_position = global_position


func take_damage(amount: int) -> void:
	if _dead:
		return
	_show_damage_number(amount)
	health = maxi(0, health - amount)
	_update_health_tint()
	if health <= 0:
		_die()


func _show_damage_number(amount: int) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate() as Node2D
	damage_number.call("configure", amount, Color.WHITE)
	get_parent().add_child(damage_number)
	damage_number.global_position = global_position


func _update_health_tint() -> void:
	var remaining_ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	visual.modulate = LOW_HEALTH_TINT.lerp(Color.WHITE, remaining_ratio)


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	sword_weapon.visible = false
	set_collision_layer_value(4, false)
	call_deferred("_spawn_weapon_pickup", global_position)
	defeated.emit()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 0.15, 0.16)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback(queue_free)


func _spawn_weapon_pickup(drop_position: Vector2) -> void:
	var weapon_pickup := WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
	weapon_pickup.configure_weapon(WeaponPickup.WeaponType.SWORD)
	get_parent().add_child(weapon_pickup)
	weapon_pickup.global_position = drop_position
