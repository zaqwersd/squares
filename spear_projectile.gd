class_name SpearProjectile
extends Area2D

signal returned

const RANGE := 64.0 * 9.0
const SPEED := 384.0
const SHAFT_LENGTH := 96.0
const SHAFT_WIDTH := 8.0
const HEAD_LENGTH := 22.0
const FIRE_BURN_SCENE := preload("res://fire_burn_effect.gd")

var direction := Vector2.RIGHT
var shooter: CollisionObject2D
var friendly := false
var fire_variant := false
var killer_variant := false
var damage := 18
var speed := SPEED
var _travelled := 0.0
var _ending := false
var _flame_time := 0.0


func configure(new_direction: Vector2, new_shooter: CollisionObject2D, is_friendly: bool, new_damage: int, is_fire: bool, is_killer: bool = false, new_speed := SPEED) -> void:
	direction = new_direction.normalized()
	shooter = new_shooter
	friendly = is_friendly
	fire_variant = is_fire
	killer_variant = is_killer
	damage = new_damage
	speed = new_speed
	collision_mask = 10 if friendly else 6
	rotation = direction.angle()


func _ready() -> void:
	z_index = 11
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_flame_time += delta
	if fire_variant:
		queue_redraw()
	if _ending:
		return
	var distance := minf(speed * delta, RANGE - _travelled)
	if distance <= 0.0:
		_begin_dissolve()
		return
	if _sweep_for_hit(distance):
		return
	global_position += direction * distance
	_travelled += distance
	if _travelled >= RANGE:
		_begin_dissolve()


func _sweep_for_hit(distance: float) -> bool:
	# The hit volume is the moving trapezoid head, sampled across its width.
	var perpendicular := Vector2(-direction.y, direction.x)
	var head_base := global_position + direction * (SHAFT_LENGTH - 2.0)
	var head_tip := global_position + direction * (SHAFT_LENGTH + HEAD_LENGTH + distance)
	var best_result: Dictionary = {}
	for lateral in [0.0, -7.0, 7.0]:
		var offset := perpendicular * float(lateral)
		var query := PhysicsRayQueryParameters2D.create(head_base + offset, head_tip + offset, collision_mask)
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.hit_from_inside = true
		query.exclude = [get_rid()]
		if is_instance_valid(shooter):
			query.exclude.append(shooter.get_rid())
		var result := get_world_2d().direct_space_state.intersect_ray(query)
		if not result.is_empty() and (best_result.is_empty() or head_base.distance_squared_to(result.position) < head_base.distance_squared_to(best_result.position)):
			best_result = result
	if best_result.is_empty():
		return false
	global_position = best_result.position - direction * (SHAFT_LENGTH + HEAD_LENGTH)
	_hit(best_result.collider)
	return true

func _hit(target: Node) -> void:
	if _ending:
		return
	if target.has_method("take_damage") and (friendly or not target.is_in_group("enemies")):
		target.call("take_damage", damage)
		if fire_variant:
			_apply_fire(target)
	if friendly and target.is_in_group("enemies") and target.has_method("show_projectile_hit"):
		target.call("show_projectile_hit", Color("#1A64B5"))
	_begin_dissolve()


func _apply_fire(target: Node) -> void:
	var existing := target.get_node_or_null("FireBurnEffect") as Node2D
	if existing != null:
		existing.refresh()
		return
	var effect := FIRE_BURN_SCENE.new() as Node2D
	target.add_child(effect)
	effect.call("configure", 5, 3.0)


func _begin_dissolve() -> void:
	if _ending:
		return
	_ending = true
	set_deferred("monitoring", false)
	var end_position := position + direction * 10.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", end_position, 0.3)
	tween.parallel().tween_property(self, "scale", Vector2(0.62, 0.62), 0.3)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_finish)


func _finish() -> void:
	emit_signal("returned")
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not _ending and body != shooter:
		_hit(body)


func _on_area_entered(area: Area2D) -> void:
	if not _ending and area != shooter:
		_hit(area)


func _draw() -> void:
	var border_color := Color("#1A64B5") if friendly else Color("#8B1E2D")
	draw_rect(Rect2(0.0, -SHAFT_WIDTH * 0.5, SHAFT_LENGTH, SHAFT_WIDTH), border_color, true, -1.0, false)
	draw_rect(Rect2(2.0, -2.0, SHAFT_LENGTH - 4.0, 4.0), Color.WHITE, true, -1.0, false)
	var head_color := Color("#321047") if killer_variant else (Color("#FF9634") if fire_variant else Color.WHITE)
	var head := PackedVector2Array([Vector2(SHAFT_LENGTH - 2.0, -8.0), Vector2(SHAFT_LENGTH + HEAD_LENGTH, -4.0), Vector2(SHAFT_LENGTH + HEAD_LENGTH, 4.0), Vector2(SHAFT_LENGTH - 2.0, 8.0)])
	draw_colored_polygon(head, border_color)
	var inner := PackedVector2Array([Vector2(SHAFT_LENGTH + 1.0, -6.0), Vector2(SHAFT_LENGTH + HEAD_LENGTH - 2.0, -2.0), Vector2(SHAFT_LENGTH + HEAD_LENGTH - 2.0, 2.0), Vector2(SHAFT_LENGTH + 1.0, 6.0)])
	draw_colored_polygon(inner, head_color)
	if fire_variant:
		var flicker := 3.0 + sin(_flame_time * 7.0) * 2.0
		draw_rect(Rect2(SHAFT_LENGTH + 6.0, -flicker, 8.0, flicker * 2.0), Color(1.0, 0.32, 0.08, 0.8), true, -1.0, false)
		for index in range(4):
			var flame_phase := _flame_time * 5.0 + float(index) * 1.71
			var flame_x := SHAFT_LENGTH + 2.0 + float(index) * 5.0
			var flame_y := sin(flame_phase) * 8.0
			draw_rect(Rect2(flame_x, flame_y, 4.0, 4.0), Color("#FFCA45"), true, -1.0, false)
