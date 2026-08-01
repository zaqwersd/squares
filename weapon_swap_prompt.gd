extends Control

@onready var title_label: Label = $Panel/Title
@onready var detail_label: Label = $Panel/Detail
@onready var replace_button: Button = $Panel/Replace

var _player: Node
var _pickup: Node


func _ready() -> void:
	visible = false
	$Panel/Replace.pressed.connect(_confirm)
	$Panel/Cancel.pressed.connect(_cancel)


func open_for(player: Node, pickup: Node, weapon_name: String, current_weapon_name: String) -> void:
	_player = player
	_pickup = pickup
	title_label.text = "装备%s？" % weapon_name
	detail_label.text = "将替换当前武器：%s" % current_weapon_name
	visible = true
	replace_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()


func _confirm() -> void:
	if is_instance_valid(_player):
		_player.call("confirm_weapon_swap", _pickup)
	_close()


func _cancel() -> void:
	if is_instance_valid(_player):
		_player.call("cancel_weapon_swap")
	_close()


func _close() -> void:
	visible = false
	_player = null
	_pickup = null
