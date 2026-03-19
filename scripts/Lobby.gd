extends Control

@onready var ip_input = $VBoxContainer/IPLineEdit
@onready var status_label = $VBoxContainer/HBoxContainer2/StatusLabel
@onready var host_button = $VBoxContainer/HBoxContainer/HostButton
@onready var join_button = $VBoxContainer/HBoxContainer/JoinButton
@onready var level_input = $VBoxContainer/HBoxContainer2/StartingLevelSpinBox

func _ready():
	Network.connection_succeeded.connect(_on_connection_succeeded)
	Network.connection_failed.connect(_on_connection_failed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

func _on_host_pressed():
	Network.starting_level = int(level_input.value)
	Network.host_game()
	status_label.text = "Waiting for player..."

func _on_join_pressed():
	var address = ip_input.text.strip_edges()
	if address == "":
		address = "127.0.0.1"
	Network.starting_level = int(level_input.value)
	Network.join_game(address)
	status_label.text = "Connecting..."

func _on_connection_succeeded():
	status_label.text = "Connected!"

func _on_connection_failed():
	status_label.text = "Connection failed."
