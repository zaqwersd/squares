class_name ArcherEnemy
extends CharacterBody2D

signal defeated

const ARROW_SCENE := preload("res://arrow_projectile.tscn")
const BOW_ATTACK := preload("res://bow_attack.gd")
const MOVEMENT_ESCAPE := preload("res://enemy_movement_escape.gd")
const HIT_EFFECT_SCENE := preload("res://hit_effect.gd")
const DAMAGE_NUMBER_SCENE := preload("res://damage_number.tscn")
const NORMAL_SPEED := 180.0
const CHARGE_SPEED := 20.0
const CHARGE_DURATION := 1.2
const ATTACK_RANGE := 64.0 * 8.0
const PREFERRED_MIN_RANGE := 64.0 * 3.5
const PREFERRED_MAX_RANGE := 64.0 * 4.5
const ATTACK_RECOVERY := 0.2
const LOW_HEALTH_TINT := Color("#7A2730")
const WEAPON_PICKUP_SCENE := preload("res://weapon_pickup.tscn")
const BOW_RECOIL_DISTANCE := 14.0
const BOW_RECOIL_VISUAL_OFFSET := 8.0
const BOW_RECOIL_DURATION := 0.16
const BOW_ARROW_ORIGIN := BowWeapon.MUZZLE_OFFSET + BowWeapon.STRING_OFFSET
const BOW_DRAW_DISTANCE := 16.0

@onready var visual: Sprite2D = $Visual
@onready var bow_weapon: Node2D = $BowWeapon
@onready var bow_fire_flash: Node2D = $BowFireFlash
@onready var bow_charge_effect: BowChargeEffect = $BowChargeEffect
@onready var arrow_preview: Node2D = $ArrowPreview

var target: Node2D
var max_health := 10
var health := 10
var _charging := false
var _charge_time := 0.0
var _recoil_tween: Tween
var _attack_cooldown := 0.8
var _strafe_sign := 1.0
var _blocked_direction := Vector2.ZERO
var _blocked_direction_remaining := 0.0
var _dead := false
var _bow_attack = BOW_ATTACK.new(CHARGE_DURATION, ATTACK_RECOVERY)
var _movement_escape = MOVEMENT_ESCAPE.new()


func configure(new_target: Node2D, spawn_seed: int) -> void:
	target = new_target
	var rng := RandomNumberGenerator.new()
	rng.seed = spawn_seed
	max_health = rng.randi_range(3, 7)
	health = max_health
	_attack_cooldown = rng.randf_range(0.65, 1.25)
	_strafe_sign = -1.0 if rng.randi_range(0, 1) == 0 else 1.0
	_movement_escape.configure(spawn_seed ^ 0x4D2)


func _ready() -> void:
	add_to_group("enemies")
	arrow_preview.visible = false
	bow_charge_effect.clear()
	bow_weapon.visible = false
	_bow_attack = BOW_ATTACK.new(CHARGE_DURATION, ATTACK_RECOVERY)
	_update_health_tint()


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
	bow_weapon.call("set_aim_direction", aim_direction)

	var firing_origin := global_position
	var has_clear_line := (
		island_map == null
		or island_map.has_clear_archer_line_of_fire(firing_origin, target.global_position, self)
	)
	var is_safe_firing_position := (
		island_map != null
		and island_map.is_archer_firing_position(global_position)
	)
	var can_fire := has_clear_line
	var navigation_direction := _navigation_direction(to_target, not is_safe_firing_position, not has_clear_line)
	var movement_speed := CHARGE_SPEED if _charging else NORMAL_SPEED
	if island_map != null and not _movement_escape.is_escaping():
		navigation_direction = island_map.get_obstacle_sliding_direction(global_position, navigation_direction, self)
	navigation_direction = _movement_escape.choose_direction(self, navigation_direction, movement_speed, delta)

	_bow_attack.tick(delta)
	_attack_cooldown = _bow_attack.cooldown_remaining

	if _charging:
		if can_fire:
			_update_charge(delta, aim_direction)
		else:
			_update_preview(aim_direction, _charge_time / CHARGE_DURATION)
		velocity = navigation_direction * CHARGE_SPEED
	else:
		velocity = navigation_direction * NORMAL_SPEED
		if _attack_cooldown <= 0.0:
			_show_ready_arrow(aim_direction)
		if _attack_cooldown <= 0.0 and can_fire:
			_begin_charge(aim_direction)
		elif _attack_cooldown > 0.0:
			arrow_preview.visible = false
	move_and_slide()
	_movement_escape.report_motion(self, navigation_direction, movement_speed, delta)

func _navigation_direction(to_target: Vector2, force_reposition: bool, prefer_tangent: bool) -> Vector2:
	var island_map := get_parent() as IslandMap
	if island_map != null:
		var field_direction := island_map.get_archer_navigation_direction(
			global_position,
			force_reposition
		)
		if not field_direction.is_zero_approx() or (not force_reposition and island_map.is_archer_firing_position(global_position)):
			return _apply_tangent_bias(field_direction, to_target) if prefer_tangent else field_direction
	var fallback := _fallback_movement_direction(to_target)
	return _apply_tangent_bias(fallback, to_target) if prefer_tangent else fallback


func _apply_tangent_bias(base_direction: Vector2, to_target: Vector2) -> Vector2:
	var tangent := to_target.normalized().orthogonal() * _strafe_sign
	if base_direction.is_zero_approx():
		return tangent
	return base_direction.slerp(tangent, 0.68).normalized()


func _fallback_movement_direction(to_target: Vector2) -> Vector2:
	var distance := to_target.length()
	var toward := to_target.normalized()
	if distance > PREFERRED_MAX_RANGE:
		return toward
	if distance < PREFERRED_MIN_RANGE:
		return -toward
	return toward.orthogonal() * _strafe_sign


func _begin_charge(aim_direction: Vector2) -> void:
	if not _bow_attack.begin_charge():
		return
	_charging = true
	_charge_time = 0.0
	arrow_preview.visible = true
	_update_preview(aim_direction, 0.0)


func _update_charge(delta: float, aim_direction: Vector2) -> void:
	_charge_time = minf(CHARGE_DURATION, _charge_time + delta)
	_update_preview(aim_direction, _charge_time / CHARGE_DURATION)
	if _charge_time >= CHARGE_DURATION:
		_fire_arrow(aim_direction)

func _show_ready_arrow(aim_direction: Vector2) -> void:
	arrow_preview.visible = true
	arrow_preview.position = aim_direction * BOW_ARROW_ORIGIN
	arrow_preview.rotation = aim_direction.angle()
	arrow_preview.scale = Vector2.ONE

func _update_preview(aim_direction: Vector2, ratio: float) -> void:
	var eased := smoothstep(0.0, 1.0, ratio)
	arrow_preview.position = aim_direction * (BOW_ARROW_ORIGIN - eased * BOW_DRAW_DISTANCE)
	arrow_preview.rotation = aim_direction.angle()
	arrow_preview.scale = Vector2.ONE
	bow_charge_effect.show_charge(aim_direction, BOW_ARROW_ORIGIN - eased * BOW_DRAW_DISTANCE, ratio)


func _fire_arrow(aim_direction: Vector2) -> void:
	if _bow_attack.release() < 0.0:
		return
	_charging = false
	arrow_preview.visible = false
	_attack_cooldown = _bow_attack.cooldown_remaining
	var visual_origin := global_position + aim_direction * (BOW_ARROW_ORIGIN - BOW_DRAW_DISTANCE)
	var island_map := get_parent() as IslandMap
	if island_map == null or not island_map.segment_touches_body(global_position, visual_origin, target):
		var arrow := ARROW_SCENE.instantiate() as Area2D
		arrow.call("configure", aim_direction, self, false, 10, 300.0)
		get_parent().add_child(arrow)
		arrow.global_position = visual_origin
	else:
		target.take_damage(10)
	bow_charge_effect.complete_charge(aim_direction, BOW_ARROW_ORIGIN - BOW_DRAW_DISTANCE)
	bow_fire_flash.call("play", aim_direction, BOW_ARROW_ORIGIN)
	_apply_arrow_recoil(aim_direction)

func _apply_arrow_recoil(aim_direction: Vector2) -> void:
	move_and_collide(-aim_direction * BOW_RECOIL_DISTANCE)
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	visual.position = -aim_direction * BOW_RECOIL_VISUAL_OFFSET
	_recoil_tween = create_tween()
	_recoil_tween.set_trans(Tween.TRANS_QUAD)
	_recoil_tween.set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(visual, "position", Vector2.ZERO, BOW_RECOIL_DURATION)



func _update_facing(aim_direction: Vector2) -> void:
	# The source artwork faces left.
	visual.flip_h = aim_direction.x > 0.0


func show_projectile_hit(hit_color: Color) -> void:
	if _dead:
		return
	_flash_brightness()
	var effect := HIT_EFFECT_SCENE.new() as Node2D
	effect.call("configure", hit_color)
	get_parent().add_child(effect)
	effect.global_position = global_position
	var base_scale := visual.scale
	var tween := create_tween()
	tween.tween_property(visual, "scale", base_scale * Vector2(1.16, 0.84), 0.055)
	tween.tween_property(visual, "scale", base_scale, 0.1)

func take_true_damage(amount: int) -> void:
	if _dead:
		return
	_show_damage_number(amount)
	health = maxi(0, health - amount)
	_update_health_tint()
	_flash_brightness()
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


func _flash_brightness() -> void:
	visual.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", LOW_HEALTH_TINT.lerp(Color.WHITE, clampf(float(health) / float(max_health), 0.0, 1.0)), 0.075)
func take_damage(amount: int) -> void:
	if _dead:
		return
	_show_damage_number(amount)
	health = maxi(0, health - amount)
	_update_health_tint()
	_flash_brightness()
	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	bow_weapon.visible = false
	_bow_attack.cancel()
	arrow_preview.visible = false
	bow_charge_effect.clear()
	set_collision_layer_value(4, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	call_deferred("_spawn_weapon_pickup", global_position)
	defeated.emit()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ONE * 0.15, 0.16)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback(queue_free)


func _spawn_weapon_pickup(drop_position: Vector2) -> void:
	var weapon_pickup := WEAPON_PICKUP_SCENE.instantiate() as Area2D
	get_parent().add_child(weapon_pickup)
	weapon_pickup.global_position = drop_position
