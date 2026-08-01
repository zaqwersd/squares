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
const PLAYER_BORDER_COLOR := Color("#1A64B5")
const ENEMY_BORDER_COLOR := Color("#8B1E2D")

enum WeaponType { ROCK, BOW, SWORD, TRIPLE_BOW }

@onready var bow_display: BowWeapon = $BowDisplay
@onready var triple_bow_display: TripleBowWeapon = $TripleBowDisplay
@onready var rock_display: RockWeapon = $RockDisplay
@onready var ground_shadow: Polygon2D = $GroundShadow
@onready var sword_display: SwordWeapon = $SwordDisplay
@onready var pickup_hint: PickupHint = $PickupHint

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
	ground_shadow.scale.x = 1.0 if weapon_type in [WeaponType.BOW, WeaponType.TRIPLE_BOW] else 0.64
	var border_color := PLAYER_BORDER_COLOR if _is_player_owned else ENEMY_BORDER_COLOR
	bow_display.border_color = border_color
	triple_bow_display.border_color = border_color
	sword_display.outline_color = border_color


func _process(delta: float) -> void:
	_bob_time += delta
	_age += delta
	var bob_offset := sin(_bob_time * 3.0) * 3.0
	bow_display.position.y = bob_offset
	triple_bow_display.position.y = bob_offset
	rock_display.position.y = bob_offset
	sword_display.position.y = bob_offset
	var weapon_bottom := BOW_BOTTOM_OFFSET if weapon_type in [WeaponType.BOW, WeaponType.TRIPLE_BOW] else ROCK_BOTTOM_OFFSET
	if weapon_type == WeaponType.SWORD:
		weapon_bottom = SWORD_BOTTOM_OFFSET
	ground_shadow.position.y = bob_offset + weapon_bottom + SHADOW_GAP_FROM_WEAPON_BOTTOM
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


func _update_nearby_player() -> void:
	var player := get_parent().get_node_or_null("Player") as IslandPlayer
	if player == null:
		return
	if global_position.distance_squared_to(player.global_position) <= 56.0 * 56.0:
		_nearby_player = player
	elif _nearby_player == player:
		_nearby_player = null


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
