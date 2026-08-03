class_name SwordmasterEnemy
extends CharacterBody2D

signal defeated

const WAVE_SCENE := preload("res://crescent_wave.tscn")
const DASH_TRAIL_SCRIPT := preload("res://sharpshooter_dash_trail.gd")
const GREATSWORD_ATTACK := preload("res://greatsword_attack.gd")
const MOVEMENT_ESCAPE := preload("res://enemy_movement_escape.gd")
const DAMAGE_NUMBER_SCENE := preload("res://damage_number.tscn")
const WEAPON_PICKUP_SCENE := preload("res://weapon_pickup.tscn")
const MOVE_SPEED := 175.0
const HEALTH := 48
const STRENGTH := 1
const DEFENSE := 2
const ATTACK_DAMAGE := GREATSWORD_ATTACK.BASE_SWING_DAMAGE + STRENGTH
const WAVE_DAMAGE := GREATSWORD_ATTACK.BASE_WAVE_DAMAGE + STRENGTH
const WINDUP := 0.2
const SWING := 0.3
const COOLDOWN := 0.5
const WAVE_COOLDOWN := 1.0
const MELEE_RANGE := 96.0
const WAVE_RANGE := 192.0
const COMBO_REST_DURATION := 1.5

@onready var visual: Sprite2D = $Visual
@onready var weapon: Node2D = $GreatswordWeapon
@onready var slash_effect: Node2D = $GreatswordSlashEffect
var target: Node2D
var health := HEALTH
var _cooldown := 0.0
var _windup := 0.0
var _swing_time := 0.0
var _swinging := false
var _direction := Vector2.RIGHT
var _damaged := false
var _return_hit_reset := false
var _dead := false
var _greatsword_attack = GREATSWORD_ATTACK.new()
var _dash_visual_tween: Tween
var _movement_escape = MOVEMENT_ESCAPE.new()

func configure(new_target: Node2D, spawn_seed: int) -> void:
	target = new_target
	_movement_escape.configure(spawn_seed ^ 0x91F)

func _ready() -> void:
	add_to_group("enemies")
	slash_effect.hide_slash()

func _physics_process(delta: float) -> void:
	var island_map := get_parent() as IslandMap
	if island_map != null:
		target = island_map.get_enemy_target(global_position, target)
	if _dead or not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	var to_target := target.global_position - global_position
	_direction = to_target.normalized() if not to_target.is_zero_approx() else _direction
	visual.flip_h = _direction.x > 0.0
	_cooldown = maxf(0.0, _cooldown - delta)
	if _swinging:
		_update_swing(delta)
		return
	weapon.set_aim_direction(_direction)
	var has_clear_line := island_map == null or island_map.has_clear_archer_line_of_fire(global_position, target.global_position, self)
	if _cooldown <= 0.0:
		# Both close and distant attacks are the same two-pass swing. At range the swordmaster
		# skips the telegraph, then rides the two dashes forward while the wave is released.
		_begin_swing(false)
		return
	var move_direction := island_map.get_swordsman_navigation_direction(global_position) if island_map != null else _direction
	if move_direction.is_zero_approx():
		move_direction = _direction
	if island_map != null and not _movement_escape.is_escaping():
		move_direction = island_map.get_obstacle_sliding_direction(global_position, move_direction, self)
	move_direction = _movement_escape.choose_direction(self, move_direction, MOVE_SPEED, delta)
	velocity = move_direction * MOVE_SPEED
	move_and_slide()
	_movement_escape.report_motion(self, move_direction, MOVE_SPEED, delta)

func _begin_swing(skip_windup := false) -> void:
	_swinging = true
	_damaged = false
	_greatsword_attack.begin(skip_windup)
	_cooldown = GREATSWORD_ATTACK.TOTAL_COOLDOWN
	slash_effect.hide_slash()

func _update_swing(delta: float) -> void:
	velocity = Vector2.ZERO
	var step: Dictionary = _greatsword_attack.advance(delta)
	var phase := String(step["phase"])
	if phase == "windup":
		weapon.set_windup_direction(_direction, float(step["windup_progress"]))
		return
	if phase != "swing":
		return
	if bool(step["started_swing"]):
		weapon.set_swing_direction(_direction, 0.0)
		slash_effect.begin_swing(_direction)
		_perform_swing_dash()
		_fire_wave()
	var previous_sweep := float(step["previous_sweep"])
	var progress := float(step["sweep"])
	if bool(step["reset_hits"]):
		_apply_swing_damage(previous_sweep, 1.0, false)
		_damaged = false
		_perform_swing_dash()
		_apply_swing_damage(1.0, progress, true)
	else:
		_apply_swing_damage(previous_sweep, progress, bool(step["reverse"]))
	weapon.set_swing_direction(_direction, progress)
	slash_effect.set_swing_progress(progress, _direction, bool(step["reverse"]))
	if bool(step["finished"]):
		slash_effect.hide_slash()
		_swinging = false
		_cooldown = COMBO_REST_DURATION

func _perform_swing_dash() -> void:
	var trail := DASH_TRAIL_SCRIPT.new() as Node2D
	get_parent().add_child(trail)
	trail.global_position = global_position + _direction * 32.0
	trail.z_index = z_index - 1
	trail.configure(_direction, 32.0, 42.0)
	move_and_collide(_direction * 32.0)
	if _dash_visual_tween != null and _dash_visual_tween.is_valid():
		_dash_visual_tween.kill()
	visual.position = -_direction * 14.0
	_dash_visual_tween = create_tween()
	_dash_visual_tween.set_trans(Tween.TRANS_QUAD)
	_dash_visual_tween.set_ease(Tween.EASE_OUT)
	_dash_visual_tween.tween_property(visual, "position", Vector2.ZERO, 0.12)

func _apply_swing_damage(from_progress: float, to_progress: float, apply_knockback: bool) -> void:
	if _damaged or not _swing_hits_target(from_progress, to_progress):
		return
	_damaged = true
	target.take_damage(ATTACK_DAMAGE)
	if apply_knockback:
		target.move_and_collide(_direction * 12.0)

func _fire_wave() -> void:
	var wave := WAVE_SCENE.instantiate() as CrescentWave
	wave.configure(_direction, WAVE_DAMAGE, target)
	wave.global_position = global_position + _direction * MELEE_RANGE
	get_parent().add_child(wave)
	_cooldown = maxf(_cooldown, GREATSWORD_ATTACK.TOTAL_COOLDOWN)

func _swing_hits_target(from_progress: float, to_progress: float) -> bool:
	var collision_shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return weapon.hits_collision_shape(_direction, from_progress, to_progress, collision_shape)

const LOW_HEALTH_TINT := Color("#7A2730")

func _update_health_tint() -> void:
	var ratio := clampf(float(health) / float(HEALTH), 0.0, 1.0)
	visual.modulate = LOW_HEALTH_TINT.lerp(Color.WHITE, ratio)

func _flash_brightness() -> void:
	visual.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween := create_tween()
	var ratio := clampf(float(health) / float(HEALTH), 0.0, 1.0)
	tween.tween_property(visual, "modulate", LOW_HEALTH_TINT.lerp(Color.WHITE, ratio), 0.075)

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
func _show_damage_number(amount: int) -> void:
	var number := DAMAGE_NUMBER_SCENE.instantiate() as Node2D
	number.configure(amount, Color.WHITE)
	get_parent().add_child(number)
	number.global_position = global_position

func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	weapon.visible = false
	set_collision_layer_value(4, false)
	call_deferred("_spawn_weapon_pickup", global_position)
	defeated.emit()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 0.15, 0.16)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback(queue_free)

func _spawn_weapon_pickup(drop_position: Vector2) -> void:
	var pickup := WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
	pickup.configure_weapon(WeaponPickup.WeaponType.GREATSWORD)
	get_parent().add_child(pickup)
	pickup.global_position = drop_position

func show_projectile_hit(_color: Color) -> void:
	pass