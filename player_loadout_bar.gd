class_name PlayerLoadoutBar
extends Control

const BORDER := Color.BLACK
const WEAPON_BACKGROUND := Color("#D8D8D8")
const AUTO_BACKGROUND := Color("#DCC88F")
const AUTO_ICON_MAXIMUM_SIZE := 24.0
const WEAPON_PICKUP_SCENE := preload("res://weapon_pickup.tscn")

@export var player_path: NodePath
@onready var player: IslandPlayer = get_node(player_path) as IslandPlayer

var _last_weapon := -1
var _last_skills: Array = []
var _weapon_preview: WeaponPickup

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_weapon_preview = WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
	_weapon_preview.collision_layer = 0
	_weapon_preview.collision_mask = 0
	_weapon_preview.monitoring = false
	_weapon_preview.z_index = 0
	add_child(_weapon_preview)
	_weapon_preview.get_node_or_null("GroundShadow").hide()
	_weapon_preview.get_node_or_null("PickupHint").hide()
	_weapon_preview.process_mode = Node.PROCESS_MODE_DISABLED
	_refresh_weapon_preview(player.get_equipped_weapon_type())
	queue_redraw()

func _process(_delta: float) -> void:
	var weapon := player.get_equipped_weapon_type()
	var skills := player.get_auto_skills()
	if weapon != _last_weapon:
		_last_weapon = weapon
		_refresh_weapon_preview(weapon)
		queue_redraw()
	if skills != _last_skills:
		_last_skills = skills.duplicate()
		queue_redraw()

func _refresh_weapon_preview(weapon_type: int) -> void:
	_weapon_preview.configure_weapon(weapon_type, true)
	var icon_scale := _weapon_icon_scale(weapon_type)
	_weapon_preview.scale = Vector2.ONE * icon_scale
	var center := _weapon_visual_center(weapon_type)
	_weapon_preview.position = Vector2(16.0, 16.0) - center * icon_scale

func _weapon_visual_center(weapon_type: int) -> Vector2:
	var bounds := _weapon_visual_bounds(weapon_type)
	var center := bounds.get_center()
	if weapon_type in [WeaponPickup.WeaponType.SWORD, WeaponPickup.WeaponType.GREATSWORD]:
		center = center.rotated(-PI * 0.25)
	return center

func _weapon_icon_scale(weapon_type: int) -> float:
	if weapon_type == WeaponPickup.WeaponType.ROCK:
		return (32.0 / 3.0) / 16.0
	var dimensions := _weapon_visual_bounds(weapon_type).size
	if weapon_type in [WeaponPickup.WeaponType.SWORD, WeaponPickup.WeaponType.GREATSWORD, WeaponPickup.WeaponType.SPEAR, WeaponPickup.WeaponType.FIRE_SPEAR, WeaponPickup.WeaponType.KILLER_SPEAR]:
		var rotated_side := (dimensions.x + dimensions.y) * 0.70710678
		dimensions = Vector2(rotated_side, rotated_side)
	var drawable_size := 32.0
	return minf(drawable_size / dimensions.x, drawable_size / dimensions.y)

func _weapon_visual_bounds(weapon_type: int) -> Rect2:
	match weapon_type:
		WeaponPickup.WeaponType.ROCK:
			return Rect2(-8.0, -8.0, 16.0, 16.0)
		WeaponPickup.WeaponType.BOW:
			return Rect2(-15.0, -21.0, 26.0, 42.0)
		WeaponPickup.WeaponType.TRIPLE_BOW:
			return Rect2(-15.0, -37.0, 26.0, 74.0)
		WeaponPickup.WeaponType.SWORD:
			return Rect2(-17.0, -9.0, 50.0, 18.0)
		WeaponPickup.WeaponType.GREATSWORD:
			return Rect2(-19.0, -19.0, 60.0, 38.0)
		WeaponPickup.WeaponType.SPEAR, WeaponPickup.WeaponType.FIRE_SPEAR, WeaponPickup.WeaponType.KILLER_SPEAR:
			return Rect2(-59.0, -9.0, 118.0, 18.0)
	return Rect2(-8.0, -8.0, 16.0, 16.0)
func _draw() -> void:
	var weapon_rect := Rect2(0.0, 0.0, 32.0, 32.0)
	var auto_rect := Rect2(32.0, 0.0, 64.0, 32.0)
	draw_rect(weapon_rect, WEAPON_BACKGROUND, true)
	draw_rect(auto_rect, AUTO_BACKGROUND, true)
	draw_rect(weapon_rect, BORDER, false, 2.0)
	draw_rect(auto_rect, BORDER, false, 2.0)
	for slot_index in range(mini(2, _last_skills.size())):
		AutoRewardIcon.draw_on(self, int(_last_skills[slot_index]), Vector2(48.0 + float(slot_index) * 32.0, 16.0), AutoRewardIcon.scale_to_fit(int(_last_skills[slot_index]), AUTO_ICON_MAXIMUM_SIZE))
