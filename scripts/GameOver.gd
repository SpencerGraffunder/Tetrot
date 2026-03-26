extends Control

@onready var score_value = $VBoxContainer/HBoxContainer/Score
@onready var level_value = $VBoxContainer/HBoxContainer2/Level

func _ready():
    score_value.text = str(Network.final_score)
    level_value.text = str(Network.final_level)
    $VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)

func _on_main_menu_pressed():
	print("[CLIENT GameOver] _on_main_menu_pressed: Changing to Lobby scene")
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
