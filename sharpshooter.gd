class_name SharpshooterEnemy
extends ArcherEnemy

const MOVE_SPEED := 75.0
const SALVO_COOLDOWN := 1.5
const SALVO_INTERVAL := 0.1
const ARROW_BASE_DAMAGE := 8
const STRENGTH := 1
const ARROW_SPEED := 330.0
const DASH_DISTANCE := 128.0
const DASH_DURATION := 0.2
const DASH_COOLDOWN := 1.5
const COOLDOWN_MOVE_SPEED := 60.0
const DASH_TRAIL_SCRIPT := preload("res://sharpshooter_dash_trail.gd")

@onready var triple_arrow_preview: Node2D = $TripleArrowPreview

var _salvo_remaining := 0
var _salvo_timer := 0.0
var _salvo_direction := Vector2.RIGHT
var _dash_remaining := 0.0
var _dash_cooldown := 0.0
var _dash_direction := Vector2.RIGHT
var _trail_elapsed := 0.0
var _dash_then_salvo := false


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
	var island_map := get_parent() as IslandMap
	var firing_origin := global_position
	var has_clear_line := island_map != null and island_map.has_clear_archer_line_of_fire(firing_origin, target.global_position, self)
	var within_range := to_target.length() <= PREFERRED_MAX_RANGE
	var too_close := to_target.length() < PREFERRED_MIN_RANGE
	var can_fire := has_clear_line and within_range
	var navigation_direction := -aim_direction if too_close else _navigation_direction(to_target, not has_clear_line, not has_clear_line)
	_blocked_direction_remaining = maxf(0.0, _blocked_direction_remaining - delta)
	var recovering := _blocked_direction_remaining > 0.0
	if recovering:
		navigation_direction = _blocked_direction
	elif island_map != null:
		navigation_direction = island_map.get_obstacle_sliding_direction(global_position, navigation_direction, self)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	if _dash_remaining > 0.0:
		_update_dash(delta)
		return
	if _salvo_remaining > 0:
		_move_with_recovery(navigation_direction, island_map, delta, COOLDOWN_MOVE_SPEED)
		_update_salvo(delta)
		return
	# A salvo can only follow a dash. During the one-second dash recharge, the
	# sharpshooter repositions deliberately instead of firing a second volley.
	if _dash_cooldown <= 0.0 and can_fire:
		_dash_then_salvo = true
		_begin_dash(_get_attack_dash_direction(aim_direction, navigation_direction))
		return
	_move_with_recovery(navigation_direction, island_map, delta, COOLDOWN_MOVE_SPEED)
	_show_ready_arrows(aim_direction)


func _get_attack_dash_direction(aim_direction: Vector2, navigation_direction: Vector2) -> Vector2:
	var strafe_direction := aim_direction.orthogonal() * _strafe_sign
	if (target.global_position - global_position).length() < PREFERRED_MIN_RANGE:
		return (-aim_direction).slerp(strafe_direction, 0.25).normalized()
	if navigation_direction.is_zero_approx():
		return strafe_direction
	return navigation_direction.slerp(strafe_direction, 0.8).normalized()

func _move_with_recovery(navigation_direction: Vector2, island_map: IslandMap, delta: float, speed: float = MOVE_SPEED) -> void:
	velocity = navigation_direction * speed
	move_and_slide()
	if _blocked_direction_remaining <= 0.0 and get_real_velocity().length() < speed * 0.2:
		_blocked_direction = island_map.get_unblocked_movement_direction(self, navigation_direction, speed, delta) if island_map != null else navigation_direction.orthogonal()
		_strafe_sign *= -1.0
		_blocked_direction_remaining = 0.75
	elif _blocked_direction_remaining <= 0.0:
		_blocked_direction_remaining = 0.0


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
	_salvo_remaining = 3
	_salvo_timer = 0.0
	_salvo_direction = aim_direction
	_show_ready_arrows(aim_direction)


func _update_salvo(delta: float) -> void:
	_salvo_timer -= delta
	while _salvo_remaining > 0 and _salvo_timer <= 0.0:
		var fired_index := 3 - _salvo_remaining
		var angle_offset := deg_to_rad(5.0 - float(fired_index) * 5.0)
		_set_triple_arrow_preview_visible(fired_index, false)
		_fire_divine_arrow(_salvo_direction.rotated(angle_offset))
		_salvo_remaining -= 1
		_salvo_timer += SALVO_INTERVAL
	if _salvo_remaining == 0:
		_attack_cooldown = SALVO_COOLDOWN


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
	_trail_elapsed += step
	if _trail_elapsed >= 0.06:
		_trail_elapsed = 0.0
		_spawn_dash_trail()
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
	trail.global_position = global_position
	trail.configure(_dash_direction)