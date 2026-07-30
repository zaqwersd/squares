class_name IslandPlayer
extends CharacterBody2D

const SVG_PATH := "res://art/player.svg"
const PLAYER_SIZE := 48.0

@export var move_speed := 220.0

@onready var visual: Node2D = $Visual
@onready var spawn_transform: Node2D = $Visual/SpawnTransform
@onready var landing_particles: GPUParticles2D = $LandingParticles
@onready var beam_glow: Polygon2D = $ArrivalFX/BeamGlow
@onready var beam_core: Polygon2D = $ArrivalFX/BeamCore
@onready var impact_flash: Polygon2D = $ArrivalFX/ImpactFlash
@onready var player_shadow: PlayerShadowRenderer = get_parent().get_node("PlayerShadow")

var _facing_left := true
var _spawn_animating := false
var _spawn_tween: Tween


func _ready() -> void:
	_ensure_movement_actions()
	_build_visual_from_svg()


func _physics_process(_delta: float) -> void:
	if _spawn_animating:
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed

	if direction.x < 0.0:
		_set_facing_left(true)
	elif direction.x > 0.0:
		_set_facing_left(false)

	var previous_position := position
	move_and_slide()
	if not position.is_equal_approx(previous_position):
		var shadow := get_parent().get_node_or_null("PlayerShadow") as Node2D
		if shadow != null:
			shadow.queue_redraw()
func play_spawn_animation() -> void:
	if _spawn_tween != null and _spawn_tween.is_valid():
		_spawn_tween.kill()
	_spawn_animating = true
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


func _ensure_movement_actions() -> void:
	_add_movement_action("move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_movement_action("move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_movement_action("move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_movement_action("move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)


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
