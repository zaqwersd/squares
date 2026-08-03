class_name TreasureChest
extends Area2D

const OPEN_KEY := KEY_E
const OPEN_BUTTON := JOY_BUTTON_A
const OPEN_LABEL := ""

signal opening_started
signal opening_finished

@onready var lid_pivot: Node2D = $LidPivot
@onready var base: Node2D = $Base
@onready var pickup_hint: PickupHint = $PickupHint
@onready var open_sound: AudioStreamPlayer = $OpenSound

var _nearby_player: IslandPlayer
var _opening := false
var _opened := false
var _open_time := 0.0
var _glow_time := 0.0
var _opening_started_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	pickup_hint.set_prompt(
		"E",
		"A",
		String.chr(0x6253) + String.chr(0x5F00)
	)
	pickup_hint.visible = false
	queue_redraw()


func _process(delta: float) -> void:
	_glow_time += delta
	if not _opened:
		queue_redraw()
		_update_nearby_player()
		pickup_hint.visible = is_instance_valid(_nearby_player)
		if pickup_hint.visible:
			pickup_hint.set_gamepad_active(_nearby_player.is_gamepad_input_active())
	if _opening:
		_open_time = float(Time.get_ticks_msec() - _opening_started_msec) / 1000.0
		queue_redraw()
		if _open_time >= 2.0:
			_opening = false
			emit_signal("opening_finished")
			queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _opened or not is_instance_valid(_nearby_player):
		return
	var keyboard_open: bool = false
	var gamepad_open: bool = false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		keyboard_open = key_event.pressed and not key_event.echo and key_event.keycode == OPEN_KEY
	elif event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		gamepad_open = button_event.pressed and button_event.button_index == OPEN_BUTTON
	if keyboard_open or gamepad_open:
		_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	if _opened:
		return
	_opened = true
	_opening = true
	_open_time = 0.0
	_opening_started_msec = Time.get_ticks_msec()
	open_sound.play()
	emit_signal("opening_started")
	pickup_hint.visible = false
	set_deferred("monitoring", false)
	# In front view, the lid moves away from the viewer rather than sideways.
	lid_pivot.rotation = 0.0
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(base, "scale", Vector2(1.07, 0.88), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(lid_pivot, "position", Vector2(0.0, -12.0), 0.84).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lid_pivot, "scale", Vector2(1.0, 0.58), 0.84).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.tween_property(base, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _update_nearby_player() -> void:
	var island_map := get_parent() as IslandMap
	if island_map == null or not is_instance_valid(island_map.player):
		return
	var player := island_map.player
	if global_position.distance_squared_to(player.global_position) <= 58.0 * 58.0:
		_nearby_player = player
	elif _nearby_player == player:
		_nearby_player = null


func _on_body_entered(body: Node2D) -> void:
	if body is IslandPlayer:
		_nearby_player = body


func _on_body_exited(body: Node2D) -> void:
	if body == _nearby_player:
		_nearby_player = null


func _draw() -> void:
	if not _opened:
		_draw_radiant_glow(0.55 + sin(_glow_time * 3.0) * 0.18)
		return
	var opening_ratio := clampf(_open_time / 2.0, 0.0, 1.0)
	_draw_radiant_glow((1.0 - opening_ratio) * 0.82)
	# Burst particles expire before the lid settles into the open pose.
	if not _opening or _open_time > 1.3:
		return
	var particle_progress := clampf(_open_time / 1.3, 0.0, 1.0)
	var glow_alpha := (1.0 - particle_progress) * 0.92
	for index in range(14):
		var angle := float(index) * TAU / 14.0 + 0.23
		var distance := lerpf(8.0, 42.0, particle_progress)
		var size := 4.0 + float(index % 3) * 2.0
		var point := Vector2(cos(angle), sin(angle) * 0.65) * distance + Vector2(0.0, -13.0 - particle_progress * 18.0)
		draw_rect(Rect2(point - Vector2.ONE * size * 0.5, Vector2.ONE * size), Color(1.0, 0.95, 0.62, glow_alpha), true)


func _draw_radiant_glow(alpha: float) -> void:
	if alpha <= 0.01:
		return
	# Three offset cycles keep old rays shrinking away while new tapered rays appear.
	for ray_index in range(11):
		for wave in range(3):
			var cycle: float = floor(_glow_time * 0.32 + float(ray_index) * 0.137 + float(wave) * 0.333)
			var phase: float = fposmod(_glow_time * 0.32 + float(ray_index) * 0.137 + float(wave) * 0.333, 1.0)
			# A stable hash picks a new radial direction whenever this beam respawns.
			var angle_seed: float = sin((cycle + float(ray_index) * 19.19 + float(wave) * 47.71) * 12.9898) * 43758.5453
			var spin_direction: float = -1.0 if fposmod(absf(angle_seed), 2.0) < 1.0 else 1.0
			var spin_amount: float = phase * (0.46 + float((ray_index + wave) % 3) * 0.12)
			var angle: float = fposmod(angle_seed, TAU) + spin_direction * spin_amount
			var direction := Vector2(cos(angle), sin(angle))
			var perpendicular := Vector2(-direction.y, direction.x)
			var scale: float = 1.0 - phase
			var inner_radius: float = 27.0 + phase * 7.0
			var beam_length: float = lerpf(36.0, 8.0, phase)
			var outer_radius: float = inner_radius + beam_length
			var inner_half_width: float = 3.6 * scale
			var outer_half_width: float = (10.0 + float((ray_index + wave) % 4) * 1.5) * scale
			var inner_center := direction * inner_radius
			var outer_center := direction * outer_radius
			var near_color := Color(1.0, 1.0, 1.0, alpha * scale * 0.94)
			var far_color := Color(1.0, 1.0, 1.0, 0.0)
			var points := PackedVector2Array([
				inner_center - perpendicular * inner_half_width,
				inner_center + perpendicular * inner_half_width,
				outer_center + perpendicular * outer_half_width,
				outer_center - perpendicular * outer_half_width,
			])
			var colors := PackedColorArray([near_color, near_color, far_color, far_color])
			draw_polygon(points, colors)