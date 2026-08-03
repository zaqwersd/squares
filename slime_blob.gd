class_name SlimeBlob
extends Area2D

const GEL_COLOR := Color("#35F3C5A8")
const BORDER_COLOR := Color("#8B1E2D")
const RANGE := 64.0 * 7.0
const EXPLOSION_SCENE := preload("res://slime_blob_explosion.gd")

var direction := Vector2.RIGHT
var shooter: Node2D
var damage := 12
var speed := 120.0
var travelled := 0.0
var friendly := false
var impact_size := 64.0
var _exploding := false


func configure(new_direction: Vector2, new_shooter: Node2D, new_damage: int, new_speed: float, is_friendly := false, new_impact_size := 64.0) -> void:
	direction = new_direction.normalized()
	shooter = new_shooter
	damage = new_damage
	speed = new_speed
	friendly = is_friendly
	impact_size = new_impact_size
	collision_mask = 10 if friendly else 6


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _exploding:
		return
	var travelled_step := minf(speed * delta, RANGE - travelled)
	var hit_position: Variant = _sweep_for_collision(travelled_step)
	if hit_position != null:
		global_position = hit_position
		_explode()
		return
	global_position += direction * travelled_step
	travelled += travelled_step
	if travelled >= RANGE:
		_explode()


func _sweep_for_collision(distance: float) -> Variant:
	if distance <= 0.0:
		return null
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + direction * distance, collision_mask)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.hit_from_inside = true
	query.exclude = [get_rid()]
	if is_instance_valid(shooter):
		query.exclude.append(shooter.get_rid())
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result.position


func _on_body_entered(body: Node2D) -> void:
	if _exploding or body == shooter:
		return
	_explode()


func _explode() -> void:
	if _exploding:
		return
	_exploding = true
	set_deferred("monitoring", false)
	var effect := EXPLOSION_SCENE.new() as Node2D
	var valid_source: Node2D = shooter if is_instance_valid(shooter) else null
	effect.configure(valid_source, friendly, damage, impact_size)
	effect.global_position = global_position
	get_parent().add_child(effect)
	queue_free()


func _draw() -> void:
	# The projectile follows the same translucent gel language as the king.
	draw_rect(Rect2(-11, -5, 22, 10), Color(0.0, 0.0, 0.0, 0.22), true, -1.0, false)
	var border := Color("#1A64B5") if friendly else BORDER_COLOR
	border.a = 0.62
	draw_rect(Rect2(-12, -12, 24, 24), border, true, -1.0, false)
	draw_rect(Rect2(-9, -9, 18, 18), GEL_COLOR, true, -1.0, false)
	draw_rect(Rect2(-6, -7, 7, 5), Color("#B0FFE2A0"), true, -1.0, false)
