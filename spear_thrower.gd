class_name SpearThrowerEnemy
extends CharacterBody2D

signal defeated

const SPEAR_PROJECTILE_SCENE := preload("res://spear_projectile.gd")
const WEAPON_PICKUP_SCENE := preload("res://weapon_pickup.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://damage_number.tscn")
const MAX_HEALTH := 97
const DEFENSE := 3
const STRENGTH := 3
const MOVE_SPEED := 100.0
const MIN_RANGE := 256.0
const MAX_RANGE := 384.0
const THROW_COOLDOWN := 1.35
const LOW_HEALTH_TINT := Color("#7A2730")

@onready var visual: Sprite2D = $Visual
@onready var spear_weapon: Node2D = $SpearWeapon

var target: Node2D
var health := MAX_HEALTH
var _fire_variant := false
var _cooldown := 0.8
var _spear_in_flight := false
var _dead := false
var _movement_rng := RandomNumberGenerator.new()

func configure(new_target: Node2D, spawn_seed: int, fire_variant := false) -> void:
	target = new_target
	_movement_rng.seed = spawn_seed
	_fire_variant = fire_variant

func _ready() -> void:
	add_to_group("enemies")
	spear_weapon.set("fire_variant", _fire_variant)
	spear_weapon.connect("throw_released", _on_spear_throw_released)

func _physics_process(delta: float) -> void:
	var island_map := get_parent() as IslandMap
	if island_map != null:
		target = island_map.get_enemy_target(global_position, target)
	if _dead or not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	var to_target := target.global_position - global_position
	if to_target.is_zero_approx():
		return
	var direction := to_target.normalized()
	visual.flip_h = direction.x > 0.0
	if not _spear_in_flight:
		spear_weapon.call("set_aim_direction", direction)
	_cooldown = maxf(0.0, _cooldown - delta)
	var distance := to_target.length()
	var movement_direction := Vector2.ZERO
	if distance > MAX_RANGE:
		movement_direction = direction
	elif distance < MIN_RANGE:
		movement_direction = -direction
	else:
		movement_direction = direction.orthogonal() * (1.0 if _movement_rng.randi_range(0, 1) == 0 else -1.0)
	if island_map != null:
		movement_direction = island_map.get_obstacle_sliding_direction(global_position, movement_direction, self)
	velocity = movement_direction * MOVE_SPEED
	var has_clear_line := island_map == null or island_map.has_clear_archer_line_of_fire(global_position, target.global_position, self)
	if not _spear_in_flight and _cooldown <= 0.0 and distance <= 576.0 and has_clear_line:
		if bool(spear_weapon.call("begin_throw", direction)):
			_spear_in_flight = true
			velocity = Vector2.ZERO
	move_and_slide()

func _on_spear_throw_released(direction: Vector2) -> void:
	if _dead or not _spear_in_flight:
		return
	var spear := SPEAR_PROJECTILE_SCENE.new() as Area2D
	spear.call("configure", direction, self, false, 18 + STRENGTH, _fire_variant)
	spear.connect("returned", _on_spear_returned)
	get_parent().add_child(spear)
	spear.global_position = global_position

func _on_spear_returned() -> void:
	_spear_in_flight = false
	_cooldown = THROW_COOLDOWN
	if not _dead and is_instance_valid(target):
		spear_weapon.call("restore_to_hand", (target.global_position - global_position).normalized())

func take_damage(amount: int) -> void:
	if _dead:
		return
	var final_damage := maxi(1, amount - DEFENSE)
	_show_damage_number(final_damage)
	health = maxi(0, health - final_damage)
	_update_health_tint()
	_flash_brightness()
	if health <= 0:
		_die()

func show_projectile_hit(_hit_color: Color) -> void:
	_flash_brightness()

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
	var number := DAMAGE_NUMBER_SCENE.instantiate() as Node2D
	number.call("configure", amount, Color.WHITE)
	get_parent().add_child(number)
	number.global_position = global_position

func _update_health_tint() -> void:
	var ratio := clampf(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	visual.modulate = LOW_HEALTH_TINT.lerp(Color.WHITE, ratio)


func _flash_brightness() -> void:
	visual.modulate = Color(2.4, 2.4, 2.4, 1.0)
	var tween := create_tween()
	var ratio := clampf(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	tween.tween_property(visual, "modulate", LOW_HEALTH_TINT.lerp(Color.WHITE, ratio), 0.08)

func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	spear_weapon.visible = false
	set_collision_layer_value(4, false)
	call_deferred("_spawn_weapon_pickup", global_position)
	defeated.emit()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 0.15, 0.16)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback(queue_free)

func _spawn_weapon_pickup(drop_position: Vector2) -> void:
	var pickup := WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
	pickup.configure_weapon(WeaponPickup.WeaponType.FIRE_SPEAR if _fire_variant else WeaponPickup.WeaponType.SPEAR)
	get_parent().add_child(pickup)
	pickup.global_position = drop_position