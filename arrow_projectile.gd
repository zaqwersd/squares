class_name ArrowProjectile
extends Area2D

const ARROW_LENGTH := 32.0
const ARROW_WIDTH := 8.0
const BORDER_WIDTH := 2.0
const ENEMY_BORDER_COLOR := Color("#8B1E2D")
const PLAYER_BORDER_COLOR := Color("#1A64B5FF")
const FILL_COLOR := Color.WHITE

var direction := Vector2.RIGHT
var shooter: CollisionObject2D
var damage := 10
var speed := 300.0
var max_range := 640.0
var friendly := false
var divine := false
var _travelled := 0.0
var _spent := false


func configure(
	new_direction: Vector2,
	new_shooter: CollisionObject2D,
	is_friendly: bool,
	new_damage: int,
	new_speed: float,
	is_divine: bool = false
) -> void:
	direction = new_direction.normalized()
	shooter = new_shooter
	friendly = is_friendly
	damage = new_damage
	speed = new_speed
	divine = is_divine
	collision_mask = 10 if friendly else 6
	rotation = direction.angle()
	queue_redraw()


func _ready() -> void:
	add_to_group("arrow_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var distance := minf(speed * delta, max_range - _travelled)
	if distance <= 0.0:
		queue_free()
		return
	if _sweep_for_hit(distance):
		return
	global_position += direction * distance
	_travelled += distance
	if _travelled >= max_range:
		queue_free()


func _sweep_for_hit(distance: float) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction * distance,
		collision_mask
	)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.hit_from_inside = true
	query.exclude = [get_rid()]
	if is_instance_valid(shooter):
		query.exclude.append(shooter.get_rid())
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	global_position = result.position
	_hit(result.collider)
	return true


func _draw() -> void:
	if divine:
		# The divine arrow owns one smooth, moving ribbon rather than dropping trail particles.
		var tail_points := PackedVector2Array([Vector2(-72.0, -3.0), Vector2(-72.0, 3.0), Vector2(2.0, 6.0), Vector2(2.0, -6.0)])
		var tail_colors := PackedColorArray([Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.7), Color(1.0, 1.0, 1.0, 0.7)])
		draw_polygon(tail_points, tail_colors)
	var border_color := PLAYER_BORDER_COLOR if friendly else ENEMY_BORDER_COLOR
	var fill_color := FILL_COLOR
	draw_rect(Rect2(0.0, -ARROW_WIDTH * 0.5, ARROW_LENGTH, ARROW_WIDTH), border_color, true, -1.0, false)
	draw_rect(
		Rect2(BORDER_WIDTH, -ARROW_WIDTH * 0.5 + BORDER_WIDTH, ARROW_LENGTH - BORDER_WIDTH * 2.0, ARROW_WIDTH - BORDER_WIDTH * 2.0),
		fill_color,
		true,
		-1.0,
		false
	)



func _on_body_entered(body: Node2D) -> void:
	if _spent or body == shooter:
		return
	_hit(body)


func _on_area_entered(area: Area2D) -> void:
	if _spent or area == shooter:
		return
	_hit(area)


func _hit(target: Node) -> void:
	if _spent:
		return
	_spent = true
	set_deferred("monitoring", false)
	if friendly and target.is_in_group("enemies") and target.has_method("show_projectile_hit"):
		target.call("show_projectile_hit", PLAYER_BORDER_COLOR)
	if target.has_method("take_damage"):
		if friendly or not target.is_in_group("enemies"):
			target.call("take_damage", damage)
	queue_free()