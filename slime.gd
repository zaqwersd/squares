class_name SlimeEnemy
extends CharacterBody2D

signal defeated

const HIT_EFFECT_SCENE := preload("res://hit_effect.gd")
const DAMAGE_NUMBER_SCENE := preload("res://damage_number.tscn")
const LANDING_EFFECT_SCENE := preload("res://slime_landing_effect.gd")
const MOVEMENT_ESCAPE := preload("res://enemy_movement_escape.gd")
const JUMP_DISTANCE := 64.0 * 1.5
const JUMP_DURATION := 1.0
const LANDING_COOLDOWN := 0.5
const JUMP_DIRECTION_VARIANCE := 0.22
const JUMP_HEIGHT := 30.0
const LANDING_DAMAGE := 4
const LANDING_DAMAGE_HALF_EXTENT := 32.0
const LOW_HEALTH_GEL := Color("#286A36A8")
const FULL_HEALTH_GEL := Color(0.423529, 0.894118, 0.376471, 0.513726)

@onready var visual: Node2D = $Visual
@onready var gel: Polygon2D = $Visual/Gel
@onready var contact_shadow: Polygon2D = $ContactShadow

var target: Node2D
var max_health := 5
var health := 5
var _jumping := false
var _jump_elapsed := 0.0
var _jump_direction := Vector2.RIGHT
var _dead := false
var _cooldown_remaining := 0.0
var _movement_rng := RandomNumberGenerator.new()
var _movement_escape = MOVEMENT_ESCAPE.new()


func configure(new_target: Node2D, spawn_seed: int) -> void:
	target = new_target
	_movement_rng.seed = spawn_seed
	_movement_escape.configure(spawn_seed ^ 0x571)


func _ready() -> void:
	add_to_group("enemies")
	_update_health_visual()


func _physics_process(delta: float) -> void:
	var island_map := get_parent() as IslandMap
	if island_map != null:
		target = island_map.get_enemy_target(global_position, target)
	if _dead or not is_instance_valid(target):
		return
	if not _jumping:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
		if _cooldown_remaining <= 0.0:
			_begin_jump()
		return
	_update_jump(delta)


func _begin_jump() -> void:
	var toward_player := (target.global_position - global_position).normalized()
	var island_map := get_parent() as IslandMap
	var navigation_direction := island_map.get_experience_navigation_direction(global_position) if island_map != null else Vector2.ZERO
	if toward_player.is_zero_approx():
		toward_player = navigation_direction
	if toward_player.is_zero_approx():
		toward_player = Vector2.RIGHT
	if not navigation_direction.is_zero_approx():
		toward_player = toward_player.slerp(navigation_direction, 0.28).normalized()
	var has_clear_line := island_map == null or island_map.has_clear_archer_line_of_fire(global_position, target.global_position, self)
	if not has_clear_line:
		var tangent_sign := -1.0 if _movement_rng.randi_range(0, 1) == 0 else 1.0
		var tangent := toward_player.orthogonal() * tangent_sign
		toward_player = toward_player.slerp(tangent, 0.66).normalized()
	_jump_direction = toward_player.rotated(_movement_rng.randf_range(-JUMP_DIRECTION_VARIANCE, JUMP_DIRECTION_VARIANCE)).normalized()
	if island_map != null:
		_jump_direction = island_map.get_obstacle_sliding_direction(global_position, _jump_direction, self)
	_jumping = true
	_jump_elapsed = 0.0
	visual.scale = Vector2(0.78, 1.22)


func _update_jump(delta: float) -> void:
	_jump_elapsed = minf(JUMP_DURATION, _jump_elapsed + delta)
	var progress := _jump_elapsed / JUMP_DURATION
	var movement_speed := JUMP_DISTANCE / JUMP_DURATION
	var movement := _jump_direction * movement_speed * delta
	move_and_collide(movement)
	_movement_escape.report_motion(self, _jump_direction, movement_speed, delta)
	var arc := sin(progress * PI)
	visual.position.y = -arc * JUMP_HEIGHT
	visual.scale = Vector2(lerpf(0.78, 1.08, arc), lerpf(1.22, 0.92, arc))
	contact_shadow.scale = Vector2(lerpf(0.85, 0.55, arc), lerpf(0.85, 0.55, arc))
	if progress >= 1.0:
		_land()


func _land() -> void:
	_jumping = false
	_cooldown_remaining = LANDING_COOLDOWN
	visual.position = Vector2.ZERO
	visual.scale = Vector2(1.28, 0.72)
	contact_shadow.scale = Vector2.ONE
	var squash_tween := create_tween()
	squash_tween.tween_property(visual, "scale", Vector2.ONE, 0.12)
	var effect := LANDING_EFFECT_SCENE.new() as Node2D
	effect.call("configure", target, LANDING_DAMAGE)
	effect.global_position = global_position
	get_parent().add_child(effect)


func show_projectile_hit(hit_color: Color) -> void:
	if _dead:
		return
	_flash_brightness()
	var effect := HIT_EFFECT_SCENE.new() as Node2D
	effect.call("configure", hit_color)
	get_parent().add_child(effect)
	effect.global_position = global_position


func _flash_brightness() -> void:
	visual.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.075)


func take_damage(amount: int) -> void:
	if _dead:
		return
	_flash_brightness()
	_show_damage_number(amount)
	health = maxi(0, health - amount)
	_update_health_visual()
	if health <= 0:
		_die()


func take_true_damage(amount: int) -> void:
	if _dead:
		return
	_show_damage_number(amount)
	health = maxi(0, health - amount)
	_flash_brightness()
	if health <= 0:
		_die()


func _show_damage_number(amount: int) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate() as Node2D
	damage_number.call("configure", amount, Color.WHITE)
	get_parent().add_child(damage_number)
	damage_number.global_position = global_position


func _update_health_visual() -> void:
	var ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	gel.color = LOW_HEALTH_GEL.lerp(FULL_HEALTH_GEL, ratio)


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	set_collision_layer_value(4, false)
	defeated.emit()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 0.15, 0.16)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback(queue_free)