class_name WeaponPickup
extends Area2D

const LIFETIME_SECONDS := 15.0
const BLINK_START_SECONDS := 10.0
const BLINK_INITIAL_HZ := 2.0
const BLINK_FINAL_HZ := 10.0
const SHADOW_GAP_FROM_WEAPON_BOTTOM := 8.0
const BOW_BOTTOM_OFFSET := 20.0
const ROCK_BOTTOM_OFFSET := 8.0
const SWORD_BOTTOM_OFFSET := 8.0
const SPEAR_TOTAL_LENGTH := 118.0
const SPEAR_DROP_ROTATION := -PI * 0.25
const SWORD_DROP_ROTATION := -PI * 0.25
const SWORD_TOTAL_LENGTH := 48.0
const GREATSWORD_TOTAL_LENGTH := 58.0
const SPEAR_PICKUP_RADIUS := 32.0
const PLAYER_BORDER_COLOR := Color("#1A64B5")
const ENEMY_BORDER_COLOR := Color("#8B1E2D")

enum WeaponType { ROCK, BOW, SWORD, TRIPLE_BOW, GREATSWORD, SPEAR, FIRE_SPEAR, KILLER_SPEAR }

@onready var bow_display: BowWeapon = $BowDisplay
@onready var triple_bow_display: TripleBowWeapon = $TripleBowDisplay
@onready var rock_display: RockWeapon = $RockDisplay
@onready var ground_shadow: Polygon2D = $GroundShadow
@onready var sword_display: SwordWeapon = $SwordDisplay
@onready var greatsword_display: GreatswordWeapon = $GreatswordDisplay
@onready var spear_display: Node2D = $SpearDisplay
@onready var pickup_hint: PickupHint = $PickupHint
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var weapon_type := WeaponType.BOW

var _nearby_player: Node2D
var _bob_time := 0.0
var _age := 0.0
var _is_player_owned := false


func _ready() -> void:
	add_to_group("weapon_pickups")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_weapon_visual()
	pickup_hint.visible = false


func configure_weapon(new_weapon_type: int, is_player_owned := false) -> void:
	weapon_type = new_weapon_type
	_is_player_owned = is_player_owned
	if is_node_ready():
		_apply_weapon_visual()


func get_weapon_type() -> int:
	return weapon_type


func _apply_weapon_visual() -> void:
	bow_display.visible = weapon_type == WeaponType.BOW
	triple_bow_display.visible = weapon_type == WeaponType.TRIPLE_BOW
	rock_display.visible = weapon_type == WeaponType.ROCK
	sword_display.visible = weapon_type == WeaponType.SWORD
	greatsword_display.visible = weapon_type == WeaponType.GREATSWORD
	spear_display.visible = weapon_type in [WeaponType.SPEAR, WeaponType.FIRE_SPEAR, WeaponType.KILLER_SPEAR]
	spear_display.set("fire_variant", weapon_type == WeaponType.FIRE_SPEAR)
	spear_display.set("killer_variant", weapon_type == WeaponType.KILLER_SPEAR)
	var border_color := PLAYER_BORDER_COLOR if _is_player_owned else ENEMY_BORDER_COLOR
	bow_display.border_color = border_color
	triple_bow_display.border_color = border_color
	sword_display.outline_color = border_color
	greatsword_display.outline_color = border_color
	spear_display.set("border_color", border_color)
	var is_spear := weapon_type in [WeaponType.SPEAR, WeaponType.FIRE_SPEAR, WeaponType.KILLER_SPEAR]
	var is_sword := weapon_type == WeaponType.SWORD
	var is_greatsword := weapon_type == WeaponType.GREATSWORD
	var is_blade_pickup := is_sword or is_greatsword
	var is_long_pickup := is_spear or is_blade_pickup
	spear_display.position = Vector2.ZERO
	spear_display.rotation = SPEAR_DROP_ROTATION if is_spear else 0.0
	sword_display.position = Vector2.ZERO
	sword_display.rotation = SWORD_DROP_ROTATION if is_sword else 0.0
	greatsword_display.position = Vector2.ZERO
	greatsword_display.rotation = SWORD_DROP_ROTATION if is_greatsword else 0.0
	ground_shadow.rotation = 0.0
	ground_shadow.scale = Vector2.ONE
	if is_long_pickup:
		var shadow_length := 86.0 if is_spear else (62.0 if is_greatsword else 44.0)
		ground_shadow.polygon = PackedVector2Array([
			Vector2(-shadow_length * 0.5, -3.0), Vector2(shadow_length * 0.5, -3.0),
			Vector2(shadow_length * 0.5, 3.0), Vector2(-shadow_length * 0.5, 3.0),
		])
	else:
		ground_shadow.polygon = PackedVector2Array([Vector2(-11.0, -2.0), Vector2(11.0, -2.0), Vector2(11.0, 2.0), Vector2(-11.0, 2.0)])
	_configure_pickup_shape(is_spear)

func _process(delta: float) -> void:
	_bob_time += delta
	_age += delta
	var bob_offset := sin(_bob_time * 3.0) * 3.0
	bow_display.position.y = bob_offset
	triple_bow_display.position.y = bob_offset
	rock_display.position.y = bob_offset
	sword_display.position.y = bob_offset
	greatsword_display.position.y = bob_offset
	spear_display.position.y = bob_offset
	var weapon_bottom := BOW_BOTTOM_OFFSET if weapon_type in [WeaponType.BOW, WeaponType.TRIPLE_BOW] else ROCK_BOTTOM_OFFSET
	if weapon_type == WeaponType.SWORD:
		weapon_bottom = SWORD_BOTTOM_OFFSET
	elif weapon_type == WeaponType.GREATSWORD:
		weapon_bottom = 18.0
	if weapon_type in [WeaponType.SPEAR, WeaponType.FIRE_SPEAR, WeaponType.KILLER_SPEAR]:
		# The horizontal shadow sits below the rotated spear's lowest visible tip.
		ground_shadow.position = Vector2(0.0, bob_offset + 59.0)
	elif weapon_type == WeaponType.SWORD:
		var sword_center := Vector2(8.0, 0.0).rotated(SWORD_DROP_ROTATION)
		ground_shadow.position = Vector2(sword_center.x, bob_offset + 30.0)
	elif weapon_type == WeaponType.GREATSWORD:
		var greatsword_center := Vector2(11.0, 0.0).rotated(SWORD_DROP_ROTATION)
		ground_shadow.position = Vector2(greatsword_center.x, bob_offset + 38.0)
	else:
		ground_shadow.position = Vector2(0.0, bob_offset + weapon_bottom + SHADOW_GAP_FROM_WEAPON_BOTTOM)
	_update_nearby_player()
	var player_nearby := is_instance_valid(_nearby_player)
	pickup_hint.visible = player_nearby
	if player_nearby:
		pickup_hint.set_gamepad_active(_nearby_player.call("is_gamepad_input_active"))
	if _age >= BLINK_START_SECONDS:
		var blink_progress := inverse_lerp(BLINK_START_SECONDS, LIFETIME_SECONDS, _age)
		var blink_hz := lerpf(BLINK_INITIAL_HZ, BLINK_FINAL_HZ, blink_progress)
		var pulse := 0.5 + sin((_age - BLINK_START_SECONDS) * TAU * blink_hz) * 0.5
		_set_weapon_flicker(pulse)
	else:
		_set_weapon_flicker(1.0)
	if _age >= LIFETIME_SECONDS:
		queue_free()


func _set_weapon_flicker(pulse: float) -> void:
	var brightness := lerpf(0.35, 1.0, pulse)
	var alpha := lerpf(0.28, 1.0, pulse)
	var color := Color(brightness, brightness, brightness, alpha)
	bow_display.modulate = color
	triple_bow_display.modulate = color
	rock_display.modulate = color
	sword_display.modulate = color
	greatsword_display.modulate = color
	spear_display.modulate = color


func _update_nearby_player() -> void:
	var player := get_parent().get_node_or_null("Player") as IslandPlayer
	if player == null:
		return
	var is_spear := weapon_type in [WeaponType.SPEAR, WeaponType.FIRE_SPEAR, WeaponType.KILLER_SPEAR]
	var nearby := global_position.distance_squared_to(player.global_position) <= 56.0 * 56.0
	if is_spear:
		var axis := Vector2.RIGHT.rotated(SPEAR_DROP_ROTATION)
		var center := global_position + spear_display.position
		var start := center - axis * (SPEAR_TOTAL_LENGTH * 0.5)
		var end := center + axis * (SPEAR_TOTAL_LENGTH * 0.5)
		nearby = _distance_to_segment(player.global_position, start, end) <= SPEAR_PICKUP_RADIUS
	if nearby:
		_nearby_player = player
	elif _nearby_player == player:
		_nearby_player = null


func _configure_pickup_shape(is_spear: bool) -> void:
	collision_shape.rotation = SPEAR_DROP_ROTATION - PI * 0.5 if is_spear else 0.0
	if is_spear:
		var capsule := CapsuleShape2D.new()
		capsule.radius = 6.0
		capsule.height = SPEAR_TOTAL_LENGTH
		collision_shape.shape = capsule
	else:
		var circle := CircleShape2D.new()
		circle.radius = 28.0
		collision_shape.shape = circle


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var projection := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * projection)


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_nearby_player):
		return
	if event.is_action_pressed("interact"):
		_nearby_player.call("equip_weapon_pickup", self)
		get_viewport().set_input_as_handled()


func consume() -> void:
	set_deferred("monitoring", false)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is IslandPlayer:
		_nearby_player = body


func _on_body_exited(body: Node2D) -> void:
	if body == _nearby_player:
		_nearby_player = null
