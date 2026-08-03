class_name ChestRevealOverlay
extends Control

const SLOWDOWN_DURATION := 1.15
const PANEL_FADE_DURATION := 0.32
const RESUME_DURATION := 0.42
const MIN_TIME_SCALE := 0.035

enum State { IDLE, OPENING, PANEL, RESUMING }

var _state := State.IDLE
var _state_started_msec := 0
var _source_position := Vector2.ZERO
var _beam_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()


func begin_opening(source_position: Vector2) -> void:
	_source_position = source_position
	_state = State.OPENING
	_state_started_msec = Time.get_ticks_msec()
	_beam_time = 0.0
	show()
	queue_redraw()


func begin_panel() -> void:
	if _state != State.OPENING:
		return
	_state = State.PANEL
	_state_started_msec = Time.get_ticks_msec()
	Engine.time_scale = 1.0
	get_tree().paused = true
	queue_redraw()


func release_panel() -> void:
	if _state != State.PANEL:
		return
	_state = State.RESUMING
	_state_started_msec = Time.get_ticks_msec()
	get_tree().paused = false
	Engine.time_scale = MIN_TIME_SCALE

func _process(_delta: float) -> void:
	if _state == State.IDLE:
		return
	_beam_time = float(Time.get_ticks_msec()) / 1000.0
	var elapsed := _elapsed_seconds()
	match _state:
		State.OPENING:
			var slowdown_progress := clampf(elapsed / SLOWDOWN_DURATION, 0.0, 1.0)
			Engine.time_scale = lerpf(1.0, MIN_TIME_SCALE, _smoothstep(slowdown_progress))
		State.PANEL:
			pass
		State.RESUMING:
			var resume_progress := clampf(elapsed / RESUME_DURATION, 0.0, 1.0)
			Engine.time_scale = lerpf(MIN_TIME_SCALE, 1.0, _smoothstep(resume_progress))
			if resume_progress >= 1.0:
				Engine.time_scale = 1.0
				_state = State.IDLE
				hide()
	queue_redraw()


func _draw() -> void:
	if _state == State.IDLE:
		return
	var elapsed := _elapsed_seconds()
	var black_alpha := 0.0
	var beam_alpha := 0.0
	if _state == State.OPENING:
		var progress := clampf(elapsed / SLOWDOWN_DURATION, 0.0, 1.0)
		beam_alpha = 0.45 + progress * 0.42
	elif _state == State.PANEL:
		var fade_progress := clampf(elapsed / PANEL_FADE_DURATION, 0.0, 1.0)
		black_alpha = 0.78 * fade_progress
		beam_alpha = (1.0 - fade_progress) * 0.95
	else:
		var resume_progress := clampf(elapsed / RESUME_DURATION, 0.0, 1.0)
		black_alpha = 0.78 * (1.0 - resume_progress)
		# The white burst is gone once the black transition releases the game.
	if black_alpha > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, black_alpha), true)
	if beam_alpha > 0.01:
		_draw_transition_beams(beam_alpha)


func _draw_transition_beams(alpha: float) -> void:
	for beam_index in range(18):
		var cycle: float = floor(_beam_time * 0.34 + float(beam_index) * 0.173)
		var angle_seed: float = sin((float(beam_index) * 31.71 + cycle * 17.23) * 12.9898) * 43758.5453
		var pulse: float = fposmod(_beam_time * 0.34 + float(beam_index) * 0.173, 1.0)
		var spin_direction: float = -1.0 if fposmod(absf(angle_seed), 2.0) < 1.0 else 1.0
		var angle: float = fposmod(angle_seed, TAU) + spin_direction * pulse * (0.38 + float(beam_index % 4) * 0.10)
		var direction := Vector2(cos(angle), sin(angle))
		var perpendicular := Vector2(-direction.y, direction.x)
		var inner_radius := 18.0 + pulse * 20.0
		var outer_radius := inner_radius + lerpf(150.0, 36.0, pulse)
		var inner_width := lerpf(8.0, 2.0, pulse)
		var outer_width := lerpf(34.0, 7.0, pulse)
		var inner_center := _source_position + direction * inner_radius
		var outer_center := _source_position + direction * outer_radius
		var bright := Color(1.0, 1.0, 1.0, alpha * (1.0 - pulse) * 0.82)
		var clear := Color(1.0, 1.0, 1.0, 0.0)
		var points := PackedVector2Array([
			inner_center - perpendicular * inner_width,
			inner_center + perpendicular * inner_width,
			outer_center + perpendicular * outer_width,
			outer_center - perpendicular * outer_width,
		])
		draw_polygon(points, PackedColorArray([bright, bright, clear, clear]))


func _elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - _state_started_msec) / 1000.0


func _smoothstep(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)