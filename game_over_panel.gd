class_name GameOverPanel
extends Control

var _title: Label
var _restart_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_content()
	hide_panel()


func show_game_over() -> void:
	show()
	_restart_button.grab_focus()
	queue_redraw()


func hide_panel() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_request_restart()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_request_restart()
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		_request_restart()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.09, 0.78), true)


func _build_content() -> void:
	var font := _load_game_font()
	_title = Label.new()
	_title.text = "GAME OVER"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.position = Vector2(-180.0, -104.0)
	_title.size = Vector2(360.0, 56.0)
	_title.add_theme_font_size_override("font_size", 36)
	if font != null:
		_title.add_theme_font_override("font", font)
	_title.add_theme_color_override("font_color", Color.WHITE)
	add_child(_title)

	_restart_button = Button.new()
	_restart_button.text = "RESTART"
	_restart_button.set_anchors_preset(Control.PRESET_CENTER)
	_restart_button.position = Vector2(-92.0, -20.0)
	_restart_button.size = Vector2(184.0, 46.0)
	_restart_button.add_theme_font_size_override("font_size", 20)
	if font != null:
		_restart_button.add_theme_font_override("font", font)
	_restart_button.add_theme_stylebox_override("normal", _make_button_style(Color("#1A64B5")))
	_restart_button.add_theme_stylebox_override("hover", _make_button_style(Color("#2C82D2")))
	_restart_button.add_theme_stylebox_override("pressed", _make_button_style(Color("#164D89")))
	_restart_button.pressed.connect(_request_restart)
	add_child(_restart_button)


func _load_game_font() -> Font:
	for filename in DirAccess.get_files_at("res://fonts"):
		if filename.ends_with(".ttf"):
			return load("res://fonts/" + filename) as Font
	return null


func _make_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _request_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
