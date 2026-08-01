class_name IslandPlayer
extends CharacterBody2D

signal health_changed(health: int, max_health: int)
signal experience_changed(level: int, experience: int, required: int)
signal died

const SVG_PATH := "res://art/player.svg"
const PLAYER_SIZE := 48.0
const ROCK_PROJECTILE_SCENE := preload("res://rock_projectile.tscn")
const ARROW_PROJECTILE_SCENE := preload("res://arrow_projectile.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://damage_number.tscn")
const WEAPON_PICKUP_SCENE := preload("res://weapon_pickup.tscn")
const ATTACK_BUFFER_SECONDS := 0.2
const AIM_DEADZONE := 0.25
const ARCHER_CHARGE_DURATION := 1.0
const ARCHER_BASE_DAMAGE := 1
const ARCHER_MAX_DAMAGE := 12
const ARCHER_BASE_SPEED := 150.0
const ARCHER_MAX_SPEED := 300.0
const BOW_RECOIL_DISTANCE := 14.0
const BOW_RECOIL_VISUAL_OFFSET := 8.0
const BOW_RECOIL_DURATION := 0.16
const BOW_ARROW_ORIGIN := BowWeapon.MUZZLE_OFFSET + BowWeapon.STRING_OFFSET
const BOW_DRAW_DISTANCE := 16.0
const TRIPLE_BOW_BASE_DAMAGE := 8
const TRIPLE_BOW_ARROW_SPEED := 330.0
const TRIPLE_BOW_SALVO_INTERVAL := 0.1
const TRIPLE_BOW_SALVO_COOLDOWN := 1.5
const SWORD_ATTACK_INNER_RADIUS := SwordWeapon.MOUNT_OFFSET
const SWORD_ATTACK_OUTER_RADIUS := SwordWeapon.MOUNT_OFFSET + SwordWeapon.BLADE_LENGTH
const SWORD_ATTACK_DAMAGE := 8
const SWORD_ATTACK_COOLDOWN := 0.7
const SWORD_WINDUP_DURATION := 0.1
const SWORD_SWING_DURATION := 0.2
const SWORD_DAMAGE_MOMENT := 0.1
const SWORD_OBSTACLE_COOLDOWN := 0.3
const PLAYER_INVULNERABILITY_DURATION := 0.5

@export var move_speed := 220.0
@export var archer_attack_cooldown := 0.2
@export_range(0.0, 1.0, 0.05) var right_stick_release_buffer := 0.3
@export_range(1.0, 20.0, 0.5) var automatic_aim_turn_speed := 8.0

@onready var visual: Node2D = $Visual
@onready var spawn_transform: Node2D = $Visual/SpawnTransform
@onready var rock_weapon: Node2D = $RockWeapon
@onready var bow_weapon: Node2D = $BowWeapon
@onready var triple_bow_weapon: Node2D = $TripleBowWeapon
@onready var bow_fire_flash: Node2D = $BowFireFlash
@onready var bow_charge_effect: BowChargeEffect = $BowChargeEffect
@onready var sword_weapon: SwordWeapon = $SwordWeapon
@onready var sword_slash_effect: SwordSlashEffect = $SwordSlashEffect
@onready var ability_arrow_preview: Node2D = $AbilityArrowPreview
@onready var triple_arrow_preview: Node2D = $TripleArrowPreview
@onready var landing_particles: GPUParticles2D = $LandingParticles
@onready var beam_glow: Polygon2D = $ArrivalFX/BeamGlow
@onready var beam_core: Polygon2D = $ArrivalFX/BeamCore
@onready var impact_flash: Polygon2D = $ArrivalFX/ImpactFlash
@onready var player_shadow: PlayerShadowRenderer = get_parent().get_node("PlayerShadow")

var _facing_left := true
var _spawn_animating := false
var _spawn_tween: Tween
var _recoil_tween: Tween
var _rock_in_flight := false
var _attack_buffer_remaining := 0.0
var _gamepad_aim_active := false
var _last_input_is_gamepad := false
var _right_stick_release_remaining := 0.0
var _last_aim_direction := Vector2.RIGHT
var _archer_ability_unlocked := false
var _equipped_weapon_type := WeaponPickup.WeaponType.ROCK
var _archer_charge_requested := false
var _archer_charging := false
var _archer_charge_time := 0.0
var _archer_cooldown_remaining := 0.0
var _triple_bow_requested := false
var _triple_bow_salvo_remaining := 0
var _triple_bow_salvo_timer := 0.0
var _triple_bow_cooldown_remaining := 0.0
var _triple_bow_direction := Vector2.RIGHT
var _dead := false
var _sword_attacking := false
var _sword_swing_time := 0.0
var _sword_windup_remaining := 0.0
var _sword_cooldown_remaining := 0.0
var _sword_damage_applied := false
var _sword_swing_direction := Vector2.RIGHT
var _sword_hit_targets: Array[Node] = []
var _sword_rebounding := false
var _sword_rebound_tween: Tween
var _invulnerability_remaining := 0.0

var max_health := 50
var health := 50
var level := 1
var experience := 0
var strength := 0
var defense := 0


func _ready() -> void:
	_ensure_movement_actions()
	_ensure_attack_actions()
	_build_visual_from_svg()
	_update_aim_indicator()

func get_experience_required() -> int:
	return ceili(8.0 + 4.0 * float(level) + 1.5 * float(level * level))


func add_experience(amount: int) -> void:
	experience += maxi(0, amount)
	var leveled_up := false
	while experience >= get_experience_required():
		experience -= get_experience_required()
		level += 1
		strength += 1
		defense += 1
		max_health += 5
		health = mini(max_health, health + 5)
		leveled_up = true
	if leveled_up:
		health_changed.emit(health, max_health)
	experience_changed.emit(level, experience, get_experience_required())

func _physics_process(delta: float) -> void:
	_update_invulnerability(delta)
	if _spawn_animating or _dead:
		velocity = Vector2.ZERO
		return
	_update_attack(delta)
	_update_triple_bow(delta)
	_update_archer_ability(delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed

	if direction.x < 0.0:
		_set_facing_left(true)
	elif direction.x > 0.0:
		_set_facing_left(false)
	var right_stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if right_stick.length() >= AIM_DEADZONE:
		_right_stick_release_remaining = right_stick_release_buffer
	elif _last_input_is_gamepad:
		_right_stick_release_remaining = maxf(0.0, _right_stick_release_remaining - delta)
		if _right_stick_release_remaining <= 0.0 and not direction.is_zero_approx():
			_gamepad_aim_active = true
			var target_aim := direction.normalized()
			var turn_weight := minf(1.0, delta * automatic_aim_turn_speed)
			_last_aim_direction = _last_aim_direction.slerp(target_aim, turn_weight).normalized()
	_update_aim_indicator()

	var previous_position := position
	move_and_slide()
	if not position.is_equal_approx(previous_position):
		var shadow := get_parent().get_node_or_null("PlayerShadow") as Node2D
		if shadow != null:
			shadow.queue_redraw()
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_last_input_is_gamepad = false
		_gamepad_aim_active = false
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		_last_input_is_gamepad = true
		if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y] and absf(event.axis_value) > AIM_DEADZONE:
			_gamepad_aim_active = true
	if event.is_action_pressed("attack"):
		if _equipped_weapon_type == WeaponPickup.WeaponType.BOW:
			_archer_charge_requested = true
			if _archer_cooldown_remaining <= 0.0:
				_begin_archer_charge()
		elif _equipped_weapon_type == WeaponPickup.WeaponType.TRIPLE_BOW:
			_triple_bow_requested = true
			_begin_triple_bow_salvo()
		elif _equipped_weapon_type == WeaponPickup.WeaponType.SWORD:
			_begin_sword_swing()
		else:
			_attack_buffer_remaining = ATTACK_BUFFER_SECONDS
	if event.is_action_released("attack"):
		_archer_charge_requested = false
		_triple_bow_requested = false
		if _archer_charging:
			_fire_charged_arrow()

func _update_attack(delta: float) -> void:
	_attack_buffer_remaining = maxf(0.0, _attack_buffer_remaining - delta)
	_sword_cooldown_remaining = maxf(0.0, _sword_cooldown_remaining - delta)
	_update_sword_swing(delta)
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() >= AIM_DEADZONE:
		_gamepad_aim_active = true
		_last_aim_direction = stick.normalized()
		_right_stick_release_remaining = right_stick_release_buffer
	if _equipped_weapon_type == WeaponPickup.WeaponType.SWORD and Input.is_action_pressed("attack"):
		_begin_sword_swing()
	if _equipped_weapon_type != WeaponPickup.WeaponType.ROCK:
		return
	if Input.is_action_pressed("attack"):
		_attack_buffer_remaining = ATTACK_BUFFER_SECONDS
	if not _rock_in_flight and _attack_buffer_remaining > 0.0:
		_fire_rock()
		_attack_buffer_remaining = 0.0


func _fire_rock() -> void:
	var aim_direction := _get_attack_direction()
	if aim_direction.is_zero_approx():
		return
	_last_aim_direction = aim_direction
	_set_facing_left(aim_direction.x < 0.0)
	_rock_in_flight = true
	var projectile := ROCK_PROJECTILE_SCENE.instantiate() as Area2D
	projectile.call("configure", aim_direction, self, RockProjectile.DAMAGE + strength)
	projectile.tree_exited.connect(_on_rock_returned)
	get_parent().add_child(projectile)
	projectile.global_position = global_position + aim_direction * 34.0


func _on_rock_returned() -> void:
	_rock_in_flight = false
	_attack_buffer_remaining = 0.0
	_update_aim_indicator()


func _begin_sword_swing() -> void:
	if _sword_attacking or _sword_cooldown_remaining > 0.0:
		return
	_sword_attacking = true
	_sword_cooldown_remaining = SWORD_ATTACK_COOLDOWN
	_sword_windup_remaining = SWORD_WINDUP_DURATION
	_sword_swing_time = 0.0
	_sword_damage_applied = false
	_sword_hit_targets.clear()
	_sword_swing_direction = _get_attack_direction()
	sword_weapon.set_aim_direction(_sword_swing_direction)
	sword_slash_effect.hide_slash()


func _update_sword_swing(delta: float) -> void:
	if not _sword_attacking:
		return
	# Keep the current slash phase, while rotating the whole action with live player aim.
	var live_aim_direction := _get_attack_direction()
	if not live_aim_direction.is_zero_approx():
		_sword_swing_direction = live_aim_direction
	var swing_delta := delta
	if _sword_windup_remaining > 0.0:
		var used_windup := minf(swing_delta, _sword_windup_remaining)
		_sword_windup_remaining -= used_windup
		swing_delta -= used_windup
		var windup_progress := smoothstep(0.0, 1.0, 1.0 - _sword_windup_remaining / SWORD_WINDUP_DURATION)
		sword_weapon.set_windup_direction(_sword_swing_direction, windup_progress)
		if _sword_windup_remaining > 0.0:
			return
		sword_weapon.set_swing_direction(_sword_swing_direction, 0.0)
		sword_slash_effect.begin_swing(_sword_swing_direction)
	if swing_delta <= 0.0:
		return
	var previous_progress := _sword_swing_time / SWORD_SWING_DURATION
	_sword_swing_time = minf(SWORD_SWING_DURATION, _sword_swing_time + swing_delta)
	var current_progress := _sword_swing_time / SWORD_SWING_DURATION
	sword_weapon.set_swing_direction(_sword_swing_direction, current_progress)
	sword_slash_effect.set_swing_progress(current_progress, _sword_swing_direction)
	_deal_sword_damage(previous_progress, current_progress)
	if _sword_swing_time >= SWORD_SWING_DURATION:
		_sword_attacking = false


func _deal_sword_damage(from_progress: float, to_progress: float) -> void:
	var swing_sector := sword_weapon.get_swing_sector_polygon(_sword_swing_direction, from_progress, to_progress)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy in _sword_hit_targets:
			continue
		if not _blade_touches_body(swing_sector, enemy):
			continue
		_sword_hit_targets.append(enemy)
		enemy.take_damage(SWORD_ATTACK_DAMAGE + strength)


func _interrupt_sword_on_obstacle() -> void:
	if _sword_rebounding:
		return
	_sword_attacking = false
	_sword_windup_remaining = 0.0
	_sword_cooldown_remaining = SWORD_OBSTACLE_COOLDOWN
	sword_slash_effect.hide_slash()
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
	_sword_rebound_tween.tween_callback(_finish_sword_rebound)


func _finish_sword_rebound() -> void:
	_sword_rebounding = false
	_update_aim_indicator()

func _blade_touches_body(blade_polygon: PackedVector2Array, body: Node) -> bool:
	var collision_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or not collision_shape.shape is RectangleShape2D:
		return false
	var rectangle := collision_shape.shape as RectangleShape2D
	var half_size := rectangle.size * 0.5
	var body_polygon := PackedVector2Array([
		collision_shape.global_transform * Vector2(-half_size.x, -half_size.y),
		collision_shape.global_transform * Vector2(half_size.x, -half_size.y),
		collision_shape.global_transform * Vector2(half_size.x, half_size.y),
		collision_shape.global_transform * Vector2(-half_size.x, half_size.y),
	])
	return not Geometry2D.intersect_polygons(blade_polygon, body_polygon).is_empty()


func _is_bow_weapon() -> bool:
	return _equipped_weapon_type in [WeaponPickup.WeaponType.BOW, WeaponPickup.WeaponType.TRIPLE_BOW]

func _get_attack_direction() -> Vector2:
	if _gamepad_aim_active:
		return _last_aim_direction
	var mouse_direction := get_global_mouse_position() - global_position
	if mouse_direction.length_squared() > 0.001:
		return mouse_direction.normalized()
	return _last_aim_direction

func _update_archer_ability(delta: float) -> void:
	if _equipped_weapon_type != WeaponPickup.WeaponType.BOW:
		_archer_charge_requested = false
		_archer_charging = false
		return
	_archer_cooldown_remaining = maxf(0.0, _archer_cooldown_remaining - delta)
	if (
		_archer_ability_unlocked
		and _archer_charge_requested
		and not _archer_charging
		and _archer_cooldown_remaining <= 0.0
		and Input.is_action_pressed("attack")
	):
		_begin_archer_charge()
	if not _archer_charging:
		return
	_archer_charge_time = minf(ARCHER_CHARGE_DURATION, _archer_charge_time + delta)
	var ratio := _archer_charge_time / ARCHER_CHARGE_DURATION
	var aim_direction := _get_attack_direction()
	_last_aim_direction = aim_direction
	var eased := smoothstep(0.0, 1.0, ratio)
	ability_arrow_preview.position = aim_direction * (BOW_ARROW_ORIGIN - eased * BOW_DRAW_DISTANCE)
	ability_arrow_preview.rotation = aim_direction.angle()
	ability_arrow_preview.scale = Vector2.ONE
	bow_charge_effect.show_charge(aim_direction, BOW_ARROW_ORIGIN - eased * BOW_DRAW_DISTANCE, ratio)

func _show_ready_bow_arrow(aim_direction: Vector2) -> void:
	ability_arrow_preview.visible = true
	ability_arrow_preview.position = aim_direction * BOW_ARROW_ORIGIN
	ability_arrow_preview.rotation = aim_direction.angle()
	ability_arrow_preview.scale = Vector2.ONE

func _begin_archer_charge() -> void:
	if _archer_charging or not _archer_ability_unlocked:
		return
	_archer_charging = true
	_archer_charge_time = 0.0
	ability_arrow_preview.visible = true
	bow_charge_effect.show_charge(_get_attack_direction(), BOW_ARROW_ORIGIN, 0.0)
	_update_aim_indicator()


func _fire_charged_arrow() -> void:
	var ratio := clampf(_archer_charge_time / ARCHER_CHARGE_DURATION, 0.0, 1.0)
	var damage := roundi(ARCHER_BASE_DAMAGE + (ARCHER_MAX_DAMAGE - ARCHER_BASE_DAMAGE + strength) * ratio)
	var arrow_speed := lerpf(ARCHER_BASE_SPEED, ARCHER_MAX_SPEED, ratio)
	var aim_direction := _get_attack_direction()
	var visual_origin := global_position + aim_direction * (BOW_ARROW_ORIGIN - ratio * BOW_DRAW_DISTANCE)
	if not _hit_enemy_before_bow_origin(visual_origin, damage):
		var arrow := ARROW_PROJECTILE_SCENE.instantiate() as Area2D
		arrow.call("configure", aim_direction, self, true, damage, arrow_speed)
		get_parent().add_child(arrow)
		arrow.global_position = visual_origin
	if ratio >= 1.0:
		bow_charge_effect.complete_charge(aim_direction, BOW_ARROW_ORIGIN - BOW_DRAW_DISTANCE)
	else:
		bow_charge_effect.clear()
	bow_fire_flash.call("play", aim_direction, BOW_ARROW_ORIGIN)
	_apply_arrow_recoil(aim_direction)
	_archer_charging = false
	_archer_charge_time = 0.0
	_archer_cooldown_remaining = archer_attack_cooldown
	ability_arrow_preview.visible = false
	_update_aim_indicator()

func _update_triple_bow(delta: float) -> void:
	if _equipped_weapon_type != WeaponPickup.WeaponType.TRIPLE_BOW:
		_triple_bow_requested = false
		_triple_bow_salvo_remaining = 0
		return
	_triple_bow_cooldown_remaining = maxf(0.0, _triple_bow_cooldown_remaining - delta)
	if _triple_bow_salvo_remaining > 0:
		_triple_bow_salvo_timer -= delta
		while _triple_bow_salvo_remaining > 0 and _triple_bow_salvo_timer <= 0.0:
			var fired_index := 3 - _triple_bow_salvo_remaining
			var angle_offset := deg_to_rad(5.0 - float(fired_index) * 5.0)
			_set_triple_arrow_preview_visible(fired_index, false)
			_fire_triple_bow_arrow(_triple_bow_direction.rotated(angle_offset))
			_triple_bow_salvo_remaining -= 1
			_triple_bow_salvo_timer += TRIPLE_BOW_SALVO_INTERVAL
		if _triple_bow_salvo_remaining == 0:
			_triple_bow_cooldown_remaining = TRIPLE_BOW_SALVO_COOLDOWN
	elif _triple_bow_requested and _triple_bow_cooldown_remaining <= 0.0:
		_begin_triple_bow_salvo()


func _begin_triple_bow_salvo() -> void:
	if _triple_bow_salvo_remaining > 0 or _triple_bow_cooldown_remaining > 0.0:
		return
	var aim_direction := _get_attack_direction()
	if aim_direction.is_zero_approx():
		return
	_triple_bow_direction = aim_direction
	_triple_bow_salvo_remaining = 3
	_triple_bow_salvo_timer = 0.0
	_show_ready_triple_bow_arrows(_triple_bow_direction)


func _fire_triple_bow_arrow(direction: Vector2) -> void:
	var visual_origin := global_position + direction * BOW_ARROW_ORIGIN
	if not _hit_enemy_before_bow_origin(visual_origin, TRIPLE_BOW_BASE_DAMAGE + strength):
		var arrow := ARROW_PROJECTILE_SCENE.instantiate() as ArrowProjectile
		arrow.configure(direction, self, true, TRIPLE_BOW_BASE_DAMAGE + strength, TRIPLE_BOW_ARROW_SPEED, true)
		get_parent().add_child(arrow)
		arrow.global_position = visual_origin
	bow_fire_flash.play(direction, BOW_ARROW_ORIGIN)

func _hit_enemy_before_bow_origin(visual_origin: Vector2, damage: int) -> bool:
	var island_map := get_parent() as IslandMap
	if island_map == null:
		return false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and island_map.segment_touches_body(global_position, visual_origin, enemy):
			enemy.take_damage(damage)
			return true
	return false

func _show_ready_triple_bow_arrows(aim_direction: Vector2) -> void:
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

func _apply_arrow_recoil(aim_direction: Vector2) -> void:
	move_and_collide(-aim_direction * BOW_RECOIL_DISTANCE)
	var shadow := get_parent().get_node_or_null("PlayerShadow") as Node2D
	if shadow != null:
		shadow.queue_redraw()
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	visual.position = -aim_direction * BOW_RECOIL_VISUAL_OFFSET
	_recoil_tween = create_tween()
	_recoil_tween.set_trans(Tween.TRANS_QUAD)
	_recoil_tween.set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(visual, "position", Vector2.ZERO, BOW_RECOIL_DURATION)


func equip_weapon_pickup(pickup: Node) -> void:
	if _dead or not is_instance_valid(pickup):
		return
	var new_weapon_type: int = pickup.call("get_weapon_type")
	if new_weapon_type != _equipped_weapon_type:
		var drop_position := global_position + _last_aim_direction.orthogonal() * 28.0
		call_deferred("_drop_replaced_weapon", _equipped_weapon_type, drop_position)
	_equipped_weapon_type = new_weapon_type
	_archer_ability_unlocked = _is_bow_weapon()
	_archer_charging = false
	_archer_charge_requested = false
	_triple_bow_requested = false
	_triple_bow_salvo_remaining = 0
	_attack_buffer_remaining = 0.0
	ability_arrow_preview.visible = false
	triple_arrow_preview.visible = false
	bow_charge_effect.clear()
	rock_weapon.visible = false
	bow_weapon.visible = false
	triple_bow_weapon.visible = false
	pickup.call("consume")
	_update_aim_indicator()


func _drop_replaced_weapon(weapon_type: int, drop_position: Vector2) -> void:
	var dropped_weapon := WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
	dropped_weapon.configure_weapon(weapon_type, true)
	get_parent().add_child(dropped_weapon)
	dropped_weapon.global_position = drop_position


func is_gamepad_input_active() -> bool:
	return _last_input_is_gamepad

func unlock_archer_ability() -> void:
	_archer_ability_unlocked = true
	_update_aim_indicator()

func _show_damage_number(amount: int) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate() as Node2D
	damage_number.call("configure", amount, Color("#FF9BA2"))
	get_parent().add_child(damage_number)
	damage_number.global_position = global_position

func heal(amount: int) -> void:
	if _dead:
		return
	var healed_amount := mini(maxi(0, amount), max_health - health)
	if healed_amount <= 0:
		return
	health += healed_amount
	health_changed.emit(health, max_health)
	var healing_number := DAMAGE_NUMBER_SCENE.instantiate() as Node2D
	healing_number.call("configure", healed_amount, Color("#78E08F"))
	get_parent().add_child(healing_number)
	healing_number.global_position = global_position

func take_damage(amount: int) -> void:
	if _dead or _invulnerability_remaining > 0.0:
		return
	_invulnerability_remaining = PLAYER_INVULNERABILITY_DURATION
	var final_damage := maxi(1, amount - defense)
	_show_damage_number(final_damage)
	health = maxi(0, health - final_damage)
	health_changed.emit(health, max_health)
	if health <= 0:
		_dead = true
		velocity = Vector2.ZERO
		ability_arrow_preview.visible = false
		bow_charge_effect.clear()
		rock_weapon.visible = false
		bow_weapon.visible = false
		triple_bow_weapon.visible = false
		sword_weapon.visible = false
		died.emit()


func _update_invulnerability(delta: float) -> void:
	if _invulnerability_remaining <= 0.0:
		visual.modulate.a = 1.0
		return
	_invulnerability_remaining = maxf(0.0, _invulnerability_remaining - delta)
	var flash := 0.32 + absf(sin(_invulnerability_remaining * PI * 14.0)) * 0.68
	visual.modulate.a = flash
	if _invulnerability_remaining <= 0.0:
		visual.modulate.a = 1.0


func _update_aim_indicator() -> void:
	var aim_direction := _get_attack_direction()
	if aim_direction.is_zero_approx():
		rock_weapon.visible = false
		bow_weapon.visible = false
		triple_bow_weapon.visible = false
		sword_weapon.visible = false
		return
	if _equipped_weapon_type == WeaponPickup.WeaponType.BOW:
		rock_weapon.visible = false
		sword_weapon.visible = false
		triple_bow_weapon.visible = false
		triple_arrow_preview.visible = false
		bow_weapon.set_aim_direction(aim_direction)
		if _archer_charging:
			return
		if _archer_cooldown_remaining <= 0.0:
			_show_ready_bow_arrow(aim_direction)
		else:
			ability_arrow_preview.visible = false
		return
	if _equipped_weapon_type == WeaponPickup.WeaponType.TRIPLE_BOW:
		rock_weapon.visible = false
		sword_weapon.visible = false
		bow_weapon.visible = false
		ability_arrow_preview.visible = false
		triple_bow_weapon.set_aim_direction(aim_direction)
		if _triple_bow_salvo_remaining == 0:
			if _triple_bow_cooldown_remaining <= 0.0:
				_show_ready_triple_bow_arrows(aim_direction)
			else:
				triple_arrow_preview.visible = false
		return
	ability_arrow_preview.visible = false
	triple_arrow_preview.visible = false
	if _equipped_weapon_type == WeaponPickup.WeaponType.SWORD:
		rock_weapon.visible = false
		bow_weapon.visible = false
		triple_bow_weapon.visible = false
		if _sword_rebounding:
			return
		if _sword_attacking and _sword_windup_remaining > 0.0:
			var windup_progress := smoothstep(0.0, 1.0, 1.0 - _sword_windup_remaining / SWORD_WINDUP_DURATION)
			sword_weapon.set_windup_direction(_sword_swing_direction, windup_progress)
		elif _sword_attacking:
			sword_weapon.set_swing_direction(_sword_swing_direction, minf(1.0, _sword_swing_time / SWORD_SWING_DURATION))
		else:
			sword_weapon.set_aim_direction(aim_direction)
		return
	bow_weapon.visible = false
	triple_bow_weapon.visible = false
	sword_weapon.visible = false
	if _rock_in_flight:
		rock_weapon.visible = false
		return
	rock_weapon.call("set_aim_direction", aim_direction)

func play_spawn_animation() -> void:
	if _spawn_tween != null and _spawn_tween.is_valid():
		_spawn_tween.kill()
	_spawn_animating = true
	_archer_charging = false
	_archer_charge_requested = false
	ability_arrow_preview.visible = false
	triple_arrow_preview.visible = false
	bow_charge_effect.clear()
	rock_weapon.visible = false
	bow_weapon.visible = false
	triple_bow_weapon.visible = false
	sword_weapon.visible = false
	velocity = Vector2.ZERO
	landing_particles.emitting = false
	beam_glow.color = Color(1.0, 1.0, 1.0, 0.0)
	beam_core.color = Color(1.0, 1.0, 1.0, 0.0)
	beam_glow.scale = Vector2(0.05, 1.0)
	beam_core.scale = Vector2(0.05, 1.0)
	impact_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	impact_flash.scale = Vector2.ONE * 0.25
	player_shadow.spawn_scale = 0.06
	var offscreen_height := get_viewport_rect().size.y + PLAYER_SIZE
	spawn_transform.position = Vector2(0.0, -offscreen_height)
	spawn_transform.scale = Vector2(0.58, 1.55)
	for child in spawn_transform.get_children():
		var polygon := child as Polygon2D
		if polygon != null:
			polygon.color = Color.WHITE

	# Let camera placement settle for one frame before the fast descent.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_spawn_tween = create_tween()
	_spawn_tween.set_trans(Tween.TRANS_QUAD)
	_spawn_tween.set_ease(Tween.EASE_IN)
	_spawn_tween.tween_property(spawn_transform, "position", Vector2.ZERO, 0.2)
	_spawn_tween.parallel().tween_property(
		spawn_transform, "scale", Vector2(0.72, 1.38), 0.2
	)
	_spawn_tween.parallel().tween_property(
		beam_core, "scale", Vector2.ONE, 0.16
	)
	_spawn_tween.parallel().tween_property(
		beam_glow, "scale", Vector2.ONE, 0.2
	)
	_spawn_tween.parallel().tween_property(
		beam_core, "color", Color(1.0, 1.0, 1.0, 0.96), 0.14
	)
	_spawn_tween.parallel().tween_property(
		beam_glow, "color", Color(1.0, 1.0, 1.0, 0.3), 0.18
	)
	_spawn_tween.parallel().tween_property(player_shadow, "spawn_scale", 1.0, 0.2)
	_spawn_tween.tween_callback(_on_spawn_landed)
	_spawn_tween.set_trans(Tween.TRANS_QUAD)
	_spawn_tween.set_ease(Tween.EASE_OUT)
	_spawn_tween.tween_property(
		spawn_transform, "scale", Vector2(1.3, 0.62), 0.075
	)
	for child in spawn_transform.get_children():
		var polygon := child as Polygon2D
		if polygon != null:
			_spawn_tween.parallel().tween_property(
				polygon, "color", polygon.get_meta("base_color", Color.WHITE), 0.17
			)
	_spawn_tween.set_trans(Tween.TRANS_BACK)
	_spawn_tween.tween_property(spawn_transform, "scale", Vector2.ONE, 0.22)
	_spawn_tween.tween_callback(_finish_spawn_animation)


func _on_spawn_landed() -> void:
	landing_particles.restart()
	landing_particles.emitting = true
	impact_flash.scale = Vector2.ONE * 0.25
	impact_flash.color = Color(1.0, 1.0, 1.0, 0.95)
	beam_core.color = Color(1.0, 1.0, 1.0, 1.0)
	beam_glow.color = Color(1.0, 1.0, 1.0, 0.48)
	var light_tween := create_tween().set_parallel(true)
	light_tween.set_trans(Tween.TRANS_QUAD)
	light_tween.set_ease(Tween.EASE_OUT)
	light_tween.tween_property(impact_flash, "scale", Vector2.ONE * 2.15, 0.2)
	light_tween.tween_property(
		impact_flash, "color", Color(1.0, 1.0, 1.0, 0.0), 0.2
	)
	light_tween.tween_property(
		beam_core, "color", Color(1.0, 1.0, 1.0, 0.0), 0.14
	)
	light_tween.tween_property(
		beam_glow, "color", Color(1.0, 1.0, 1.0, 0.0), 0.2
	)
	light_tween.tween_property(
		beam_core, "scale", Vector2(0.04, 1.0), 0.14
	)
	light_tween.tween_property(
		beam_glow, "scale", Vector2(0.04, 1.0), 0.2
	)


func _finish_spawn_animation() -> void:
	spawn_transform.position = Vector2.ZERO
	spawn_transform.scale = Vector2.ONE
	beam_glow.color.a = 0.0
	beam_core.color.a = 0.0
	beam_glow.scale = Vector2.ONE
	beam_core.scale = Vector2.ONE
	impact_flash.color.a = 0.0
	player_shadow.spawn_scale = 1.0
	for child in spawn_transform.get_children():
		var polygon := child as Polygon2D
		if polygon != null:
			polygon.color = polygon.get_meta("base_color", polygon.color)
	_spawn_animating = false
	_update_aim_indicator()


func _ensure_movement_actions() -> void:
	_add_movement_action("move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_movement_action("move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_movement_action("move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_movement_action("move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)

func _ensure_attack_actions() -> void:
	for action in ["aim_left", "aim_right", "aim_up", "aim_down", "attack", "interact"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
	_add_joy_axis_action("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis_action("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis_action("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis_action("aim_down", JOY_AXIS_RIGHT_Y, 1.0)

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse_event)
	_add_joy_axis_action("attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var shoulder_event := InputEventJoypadButton.new()
	shoulder_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputMap.action_add_event("attack", shoulder_event)
	var interact_key := InputEventKey.new()
	interact_key.physical_keycode = KEY_E
	if not InputMap.action_has_event("interact", interact_key):
		InputMap.action_add_event("interact", interact_key)
	var interact_button := InputEventJoypadButton.new()
	interact_button.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event("interact", interact_button):
		InputMap.action_add_event("interact", interact_button)


func _add_joy_axis_action(action: StringName, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _add_movement_action(
	action: StringName,
	keys: Array[Key],
	joy_axis: JoyAxis,
	axis_value: float
) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)

	for keycode in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keycode
		if not InputMap.action_has_event(action, key_event):
			InputMap.action_add_event(action, key_event)

	var joy_event := InputEventJoypadMotion.new()
	joy_event.axis = joy_axis
	joy_event.axis_value = axis_value
	if not InputMap.action_has_event(action, joy_event):
		InputMap.action_add_event(action, joy_event)

func _set_facing_left(value: bool) -> void:
	if _facing_left == value:
		return
	_facing_left = value
	visual.scale.x = 1.0 if _facing_left else -1.0


func _build_visual_from_svg() -> void:
	for child in spawn_transform.get_children():
		child.free()

	var source := FileAccess.get_file_as_string(SVG_PATH)
	if source.is_empty():
		push_error("Could not read player SVG: %s" % SVG_PATH)
		return

	var parser := XMLParser.new()
	var open_error := parser.open_buffer(source.to_utf8_buffer())
	if open_error != OK:
		push_error("Could not parse player SVG: %s" % error_string(open_error))
		return

	var view_box := Rect2(0.0, 0.0, PLAYER_SIZE, PLAYER_SIZE)
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue

		var element_name := parser.get_node_name()
		var attributes := _read_attributes(parser)
		if element_name == "svg" and attributes.has("viewBox"):
			view_box = _parse_view_box(attributes["viewBox"])
		elif element_name == "rect":
			_add_rect_node(attributes, view_box, source)


func _read_attributes(parser: XMLParser) -> Dictionary:
	var attributes := {}
	for index in parser.get_attribute_count():
		attributes[parser.get_attribute_name(index)] = parser.get_attribute_value(index)
	return attributes


func _parse_view_box(value: String) -> Rect2:
	var parts := value.replace(",", " ").split(" ", false)
	if parts.size() != 4:
		return Rect2(0.0, 0.0, PLAYER_SIZE, PLAYER_SIZE)
	return Rect2(
		float(parts[0]),
		float(parts[1]),
		float(parts[2]),
		float(parts[3])
	)


func _add_rect_node(attributes: Dictionary, view_box: Rect2, source: String) -> void:
	var x := float(attributes.get("x", "0"))
	var y := float(attributes.get("y", "0"))
	var width := float(attributes.get("width", "0"))
	var height := float(attributes.get("height", "0"))
	if width <= 0.0 or height <= 0.0:
		return

	var scale_factor := PLAYER_SIZE / maxf(view_box.size.x, view_box.size.y)
	var top_left := (Vector2(x, y) - view_box.position) * scale_factor
	top_left -= Vector2.ONE * PLAYER_SIZE * 0.5
	var size := Vector2(width, height) * scale_factor

	var polygon := Polygon2D.new()
	polygon.name = attributes.get("id", "rect")
	polygon.polygon = PackedVector2Array([
		top_left,
		top_left + Vector2(size.x, 0.0),
		top_left + size,
		top_left + Vector2(0.0, size.y),
	])
	polygon.color = _get_fill_color(attributes)
	polygon.set_meta("base_color", polygon.color)
	polygon.antialiased = false
	polygon.set_meta("svg_element", "rect")
	polygon.set_meta("svg_attributes", attributes.duplicate())
	polygon.set_meta("svg_source_path", SVG_PATH)
	polygon.set_meta("svg_source", source)
	spawn_transform.add_child(polygon)


func _get_fill_color(attributes: Dictionary) -> Color:
	var fill := String(attributes.get("fill", ""))
	var style := String(attributes.get("style", ""))
	for declaration in style.split(";"):
		var pair := declaration.split(":", true, 1)
		if pair.size() == 2 and pair[0].strip_edges() == "fill":
			fill = pair[1].strip_edges()
			break
	return Color.from_string(fill, Color.WHITE)
