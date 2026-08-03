class_name BossRewardPanel
extends Control

signal reward_selected(reward_id: int)

const CARD_COUNT := 3
const CARD_SIZE := Vector2(220.0, 390.0)
const CARD_GAP := 26.0
const FLIP_DURATION := 0.48
const GEL_COLOR := Color("#00E3A86B")
const CARD_BACK := Color("#18232A")
const CARD_FACE := Color("#102029E8")
const ALL_REWARDS: Array[int] = [0, 1, 2, 3, 4]
const RARITY_WEIGHTS := [3, 2, 1]
const COMMON_CARD := Color("#69C9F0")
const RARE_CARD := Color("#B79AEE")
const LEGENDARY_CARD := Color("#FFD36B")
const CORE_TEXTURE := preload("res://art/slime_king_core.svg")
const DEFAULT_FLAVOR_TEXT := "\u2026\u2026"

var _visible_since := 0.0
var _selected := 0
var _choices: Array[int] = [0, 1, 2]
var _stick_latched := false
var _using_gamepad := false
var _confirmed := false
var _rng := RandomNumberGenerator.new()
var _display_font: Font

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var font_path := "res://fonts/AiDianFengYaHei" + String.chr(0xFF08) + "ShangYongMianFei" + String.chr(0xFF09) + "-2.ttf"
	_display_font = ResourceLoader.load(font_path) as Font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

func set_reward_seed(seed_value: int) -> void:
	_rng.seed = seed_value ^ 0x44B055

func show_choices() -> void:
	_selected = 0
	_confirmed = false
	_choices.clear()
	var candidates: Array[int] = []
	for reward_id in ALL_REWARDS:
		candidates.append(reward_id)
	for draw_index in CARD_COUNT:
		if candidates.is_empty():
			break
		var total_weight := 0
		for reward_id in candidates:
			total_weight += RARITY_WEIGHTS[_rarity_for_reward(reward_id)]
		var roll := _rng.randi_range(1, total_weight)
		var accumulated := 0
		var selected_index := 0
		for candidate_index in candidates.size():
			accumulated += RARITY_WEIGHTS[_rarity_for_reward(candidates[candidate_index])]
			if roll <= accumulated:
				selected_index = candidate_index
				break
		_choices.append(candidates[selected_index])
		candidates.remove_at(selected_index)
	_visible_since = float(Time.get_ticks_msec()) / 1000.0
	show()
	queue_redraw()

func _rarity_for_reward(reward_id: int) -> int:
	if reward_id == 0:
		return 2
	if reward_id == 2 or reward_id == 3:
		return 1
	return 0
func _card_color(reward_id: int) -> Color:
	match _rarity_for_reward(reward_id):
		1:
			return RARE_CARD
		2:
			return LEGENDARY_CARD
	return COMMON_CARD
func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or _confirmed:
		return
	if event is InputEventMouseMotion:
		_using_gamepad = false
		var hovered := _card_at(event.position)
		if hovered >= 0:
			_selected = hovered
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_using_gamepad = false
		var clicked := _card_at(event.position)
		if clicked >= 0:
			_selected = clicked
			_confirm()
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X:
		_using_gamepad = true
		if absf(event.axis_value) < 0.28:
			_stick_latched = false
		elif not _stick_latched and absf(event.axis_value) >= 0.58:
			_selected = posmod(_selected + (1 if event.axis_value > 0.0 else -1), CARD_COUNT)
			_stick_latched = true
	elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed:
		_using_gamepad = true
		_confirm()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			_selected = posmod(_selected - 1, CARD_COUNT)
		elif event.keycode == KEY_RIGHT:
			_selected = posmod(_selected + 1, CARD_COUNT)
		elif event.keycode in [KEY_ENTER, KEY_SPACE]:
			_confirm()

func _confirm() -> void:
	if _confirmed:
		return
	_confirmed = true
	reward_selected.emit(_choices[_selected])
	hide()

func _card_at(point: Vector2) -> int:
	for index in CARD_COUNT:
		if _card_rect(index).has_point(point):
			return index
	return -1

func _card_rect(index: int) -> Rect2:
	var total_width := CARD_SIZE.x * CARD_COUNT + CARD_GAP * (CARD_COUNT - 1)
	return Rect2(Vector2((size.x - total_width) * 0.5 + float(index) * (CARD_SIZE.x + CARD_GAP), (size.y - CARD_SIZE.y) * 0.5), CARD_SIZE)

func _draw() -> void:
	if not visible:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	for index in CARD_COUNT:
		var flip_progress := clampf((now - _visible_since - float(index) * 0.15) / FLIP_DURATION, 0.0, 1.0)
		var rect := _card_rect(index)
		draw_set_transform(rect.get_center(), 0.0, Vector2(maxf(absf(cos(flip_progress * PI)), 0.025), 1.0))
		if flip_progress < 0.5:
			_draw_card_back()
		else:
			_draw_card_front(index, now)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_card_back() -> void:
	var rect := Rect2(-CARD_SIZE * 0.5, CARD_SIZE)
	draw_rect(rect, CARD_BACK, true)
	draw_rect(rect, Color.WHITE, false, 3.0)
	draw_rect(Rect2(-54.0, -70.0, 108.0, 108.0), Color("#0D5B55"), false, 4.0)
	draw_rect(Rect2(-26.0, -42.0, 52.0, 52.0), GEL_COLOR, true)

func _draw_card_front(index: int, now: float) -> void:
	var reward_id := _choices[index]
	var rect := Rect2(-CARD_SIZE * 0.5, CARD_SIZE)
	var card_color := _card_color(reward_id)
	draw_rect(rect, card_color, true)
	var card_shadow := card_color.darkened(0.28)
	draw_rect(Rect2(rect.position + Vector2(0.0, CARD_SIZE.y - 16.0), Vector2(CARD_SIZE.x, 16.0)), card_shadow, true)
	var border := Color.WHITE
	border.a = 1.0 if index == _selected else 0.55
	draw_rect(rect, border, false, 3.0)
	if index == _selected and _using_gamepad:
		_draw_gamepad_selection_pulse(now)
	var preview_rect := Rect2(-76.0, -174.0, 152.0, 118.0)
	draw_rect(preview_rect, Color.WHITE, false, 2.0)
	_draw_preview(reward_id, Vector2(0.0, -115.0))
	var font := _display_font if _display_font != null else ThemeDB.fallback_font
	_draw_outlined_string(font, Vector2(-92.0, -25.0), _title_for_reward(reward_id), 184.0, 22, Color.WHITE)
	draw_line(Vector2(-82.0, 2.0), Vector2(82.0, 2.0), Color("#07111666"), 1.0, false)
	var lines := _wrap_text_lines(_description_for_reward(reward_id), font, 16, 180.0)
	for line_index in lines.size():
		_draw_outlined_string(font, Vector2(-90.0, 32.0 + float(line_index) * 24.0), lines[line_index], 180.0, 16, Color.WHITE)
	draw_line(Vector2(-82.0, 108.0), Vector2(82.0, 108.0), Color("#07111666"), 1.0, false)
	var flavor_lines := _wrap_text_lines(_flavor_for_reward(reward_id), font, 14, 180.0)
	var flavor_start_y := 143.0 - float(flavor_lines.size() - 1) * 11.0
	for line_index in flavor_lines.size():
		draw_string(font, Vector2(-90.0, flavor_start_y + float(line_index) * 22.0), flavor_lines[line_index], HORIZONTAL_ALIGNMENT_CENTER, 180.0, 14, Color("#4D5560"))

func _draw_outlined_string(font: Font, position_value: Vector2, text_value: String, width: float, font_size: int, text_color: Color) -> void:
	draw_string_outline(font, position_value, text_value, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 2, Color.BLACK)
	draw_string(font, position_value, text_value, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, text_color)


func _wrap_text_lines(source_lines: Array[String], font: Font, font_size: int, width: float) -> Array[String]:
	var wrapped: Array[String] = []
	for source_line in source_lines:
		if source_line.is_empty():
			continue
		var current := ""
		for index in source_line.length():
			var character := source_line.substr(index, 1)
			var candidate := current + character
			if not current.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > width:
				wrapped.append(current)
				current = character
			else:
				current = candidate
		if not current.is_empty():
			wrapped.append(current)
	return wrapped
func _flavor_for_reward(reward_id: int) -> Array[String]:
	match reward_id:
		0:
			return ["\u8fd9\u5c42\u51dd\u80f6\u4f3c\u4e4e\u80fd\u8d77\u5230\u7f13\u51b2\u4f5c\u7528\uff0c\u867d\u7136\u6234\u5728\u5934\u4e0a\u4e0d\u592a\u8212\u670d\u3002"]
		1:
			return ["\u5c31\u662f\u51ed\u501f\u8fd9\u6837\u7684\u6838\u5fc3\u529b\u91cf\uff0c\u53f2\u83b1\u59c6\u7684\u6bcf\u4e00\u8df3\u90fd\u5f88\u5f3a\u52b2\u3002"]
		2:
			return ["\u5305\u88f9\u611f\u5f88\u5f3a\u3002"]
		3:
			return ["\u2026\u2026\u5c45\u7136\u73b0\u5728\u8fd8\u5728\u8815\u52a8\u3002\u771f\u6076\u5fc3\u3002"]
		4:
			return ["小史莱姆的智力不足以让它们分辨哪边是好的。它们只认这个环。"]
	return [DEFAULT_FLAVOR_TEXT]
func _title_for_reward(reward_id: int) -> String:
	match reward_id:
		0: return "\u51dd\u80f6\u5e3d\u5b50"
		1: return "\u53f2\u83b1\u59c6\u6838\u5fc3"
		2: return "\u51dd\u80f6\u624b\u5957"
		3: return "\u53f2\u83b1\u59c6\u7684\u6108\u4f24\u7ec4\u7ec7"
		4: return "史莱姆手环"
	return "Unknown reward"
func _description_for_reward(reward_id: int) -> Array[String]:
	match reward_id:
		0: return ["获得3点防御。受到攻击时，向八个方向发射粘液弹。冷却0.5秒。"]
		1: return ["\u6bcf1\u79d2\uff0c\u53d1\u51fa\u5411\u5916\u6269\u6563\u7684\u51b2\u51fb\u6ce2\uff0c\u653b\u51fb\u654c\u4eba\u3002"]
		2: return ["\u6bcf\u6b21\u653b\u51fb\u65f6\uff0c\u5411\u524d\u540e\u5de6\u53f3\u5404\u53d1\u5c04\u4e00\u679a\u7c98\u6db2\u5f39\u3002"]
		3: return ["\u6bcf2\u79d2\uff0c\u56de\u590d1\u70b9\u751f\u547d\u3002"]
		4: return ["召唤两个小史莱姆为你战斗。"]
	return []
func _draw_gamepad_selection_pulse(now: float) -> void:
	var phase := fposmod(now * 1.15, 1.0)
	for ring in range(3):
		var ring_phase := fposmod(phase + float(ring) * 0.32, 1.0)
		var grow := ring_phase * 16.0
		draw_rect(Rect2(-CARD_SIZE * 0.5 - Vector2.ONE * grow, CARD_SIZE + Vector2.ONE * grow * 2.0), Color(1.0, 1.0, 1.0, (1.0 - ring_phase) * 0.75), false, 2.0)

func _draw_preview(reward_id: int, center: Vector2) -> void:
	AutoRewardIcon.draw_on(self, reward_id, center, 1.0)
