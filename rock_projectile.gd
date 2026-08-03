class_name RockProjectile
extends Area2D

const PROJECTILE_SIZE := 16.0
const BORDER_WIDTH := 2.0
const RANGE_PIXELS := 64.0 * 3.0
const SPEED := 520.0
const DAMAGE := 5
const ROTATION_SPEED := 8.5

const BORDER_COLOR := Color("#1A64B5FF")
const FILL_COLOR := Color("#B0D1E7")

var direction := Vector2.RIGHT
var shooter: Node
var damage := DAMAGE
var _travelled := 0.0
var _ending := false


func configure(new_direction: Vector2, new_shooter: Node, new_damage: int) -> void:
	direction = new_direction.normalized()
	shooter = new_shooter
	damage = new_damage


func _ready() -> void:
	add_to_group("rock_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _ending:
		return
	var distance := SPEED * delta
	if _travelled + distance >= RANGE_PIXELS:
		distance = RANGE_PIXELS - _travelled
	if _sweep_for_hit(distance):
		return
	position += direction * distance
	_travelled += distance
	rotation += ROTATION_SPEED * delta
	if _travelled >= RANGE_PIXELS:
		_start_terminal_arc()

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
	if shooter is CollisionObject2D:
		query.exclude.append(shooter.get_rid())
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	global_position = result.position
	_hit(result.collider)
	return true


func _draw() -> void:
	var half := PROJECTILE_SIZE * 0.5
	draw_rect(
		Rect2(Vector2(-half, -half), Vector2.ONE * PROJECTILE_SIZE),
		BORDER_COLOR,
		true,
		-1.0,
		false
	)
	var inner_size := PROJECTILE_SIZE - BORDER_WIDTH * 2.0
	draw_rect(
		Rect2(
			Vector2.ONE * -inner_size * 0.5,
			Vector2.ONE * inner_size
		),
		FILL_COLOR,
		true,
		-1.0,
		false
	)


func _on_body_entered(body: Node2D) -> void:
	if _ending or body == shooter:
		return
	_hit(body)


func _on_area_entered(area: Area2D) -> void:
	if _ending or area == shooter:
		return
	_hit(area)


func _hit(target: Node) -> void:
	_ending = true
	set_deferred("monitoring", false)
	if target.is_in_group("enemies"):
		if target.has_method("show_projectile_hit"):
			target.call("show_projectile_hit", BORDER_COLOR)
	if target.is_in_group("enemies") or target.has_method("take_damage"):
		if target.has_method("take_damage"):
			target.call("take_damage", damage)
	_start_terminal_arc()


func _start_terminal_arc() -> void:
	_ending = true
	set_deferred("monitoring", false)
	var terminal_position := position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", terminal_position + Vector2(0.0, -24.0), 0.25)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", terminal_position, 0.25)
	tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.65, 0.25)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
