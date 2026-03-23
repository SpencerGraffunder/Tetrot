extends Control

@onready var ip_input = $VBoxContainer/IPLineEdit
@onready var status_label = $VBoxContainer/StatusLabel
@onready var host_button = $VBoxContainer/HBoxContainer/HostButton
@onready var join_button = $VBoxContainer/HBoxContainer/JoinButton
@onready var level_input = $VBoxContainer/HBoxContainer2/StartingLevelSpinBox
@onready var keyboard_spacer = $VBoxContainer/KeyboardSpacer

const SAVE_PATH = "user://settings.cfg"

func _ready():
	Network.connection_succeeded.connect(_on_connection_succeeded)
	Network.connection_failed.connect(_on_connection_failed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		ip_input.text = config.get_value("network", "last_ip", "")

func _on_host_pressed():
	Network.starting_level = int(level_input.value)
	Network.host_game()
	host_button.text = "Start"
	host_button.pressed.disconnect(_on_host_pressed)
	host_button.pressed.connect(_on_start_pressed)
	status_label.text = "Waiting for player..."

func _on_start_pressed():
	Network.start_game.rpc()

func _on_join_pressed():
	var address = ip_input.text.strip_edges()
	if address == "":
		address = "127.0.0.1"
	var config = ConfigFile.new()
	config.set_value("network", "last_ip", address)
	config.save(SAVE_PATH)
	Network.starting_level = int(level_input.value)
	Network.join_game(address)
	status_label.text = "Connecting..."

func _on_connection_succeeded():
	status_label.text = "Connected!"

func _on_connection_failed():
	status_label.text = "Connection failed."

func _process(_delta):
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var keyboard_height = DisplayServer.virtual_keyboard_get_height()
		keyboard_spacer.custom_minimum_size.y = keyboard_height
