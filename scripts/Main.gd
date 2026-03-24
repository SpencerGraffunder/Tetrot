extends Control

const GameLogicScript = preload("res://scripts/GameLogic.gd")
const Enums = preload("res://scripts/Enums.gd")
const PieceScript = preload("res://scripts/Piece.gd")

@onready var game_board = $GameBoard
@onready var preview_p1 = $HBoxContainer/NextPiecePreviewP1
@onready var preview_p2 = $HBoxContainer/NextPiecePreviewP2
@onready var score_label = $HBoxContainer/VBoxContainer/ScoreLabel
@onready var level_label = $HBoxContainer/VBoxContainer/LevelLabel
@onready var pause_overlay = $PauseOverlay

var local_player_number: int = 0
var local_player_count: int = 2

func _ready():
	get_tree().set_auto_accept_quit(false)
	local_player_number = Network.get_player_number()

	Network.game_starting.connect(_on_game_starting)
	Network.player_disconnected.connect(_on_player_disconnected)

	game_board.init_board(local_player_count)
	game_board.set_state(null)

	preview_p1.board_tile_size = game_board.tile_size
	preview_p2.board_tile_size = game_board.tile_size

	$Player1Area/VBoxContainer/TopButtonRow/PauseButton.button_down.connect(_on_pause_pressed)
	$Player1Area/VBoxContainer/TopButtonRow/RotateLeftButton.button_down.connect(func(): _on_button("CCW", true))
	$Player1Area/VBoxContainer/TopButtonRow/RotateRightButton.button_down.connect(func(): _on_button("CW", true))
	$Player1Area/VBoxContainer/BottomButtonRow/LeftButton.button_down.connect(func(): _on_button("LEFT", true))
	$Player1Area/VBoxContainer/BottomButtonRow/LeftButton.button_up.connect(func(): _on_button("LEFT", false))
	$Player1Area/VBoxContainer/BottomButtonRow/RightButton.button_down.connect(func(): _on_button("RIGHT", true))
	$Player1Area/VBoxContainer/BottomButtonRow/RightButton.button_up.connect(func(): _on_button("RIGHT", false))
	$Player1Area/VBoxContainer/BottomButtonRow/DownButton.button_down.connect(func(): _on_button("DOWN", true))
	$Player1Area/VBoxContainer/BottomButtonRow/DownButton.button_up.connect(func(): _on_button("DOWN", false))
	$PauseOverlay/PausePanel/VBoxContainer/ResumeButton.pressed.connect(_on_pause_pressed)
	$PauseOverlay/PausePanel/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)

func _on_game_starting(player_number: int, player_count: int, _level: int):
	local_player_number = player_number
	local_player_count = player_count
	game_board.init_board(player_count)
	preview_p1.board_tile_size = game_board.tile_size

func _physics_process(_delta):
	pass

func _input(event):
	if event is InputEventKey and event.echo:
		return
	var control = get_control_from_input(event)
	if control == "":
		return
	var pressed = event.pressed if event is InputEventKey else event.pressed
	_on_button(control, pressed)

func get_control_from_input(event) -> String:
	if event is InputEventKey:
		match event.keycode:
			KEY_A: return "LEFT"
			KEY_D: return "RIGHT"
			KEY_S: return "DOWN"
			KEY_Q: return "CCW"
			KEY_E: return "CW"
	return ""

func _on_button(control: String, pressed: bool) -> void:
	Network.rpc_player_input.rpc_id(1, local_player_number, control, pressed)

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_state(data: PackedByteArray):
	var state_dict = bytes_to_var(data)
	game_board.apply_state(state_dict)
	score_label.text = "Score: " + str(state_dict.score)
	level_label.text = "Level: " + str(state_dict.level)
	for i in range(state_dict.players.size()):
		var pd = state_dict.players[i]
		if pd.next_locs.size() > 0:
			var dummy_piece = PieceScript.new(pd.next_type, pd.player_number, 0, local_player_count)
			for j in range(pd.next_locs.size()):
				dummy_piece.locations[j] = Vector2i(pd.next_locs[j][0], pd.next_locs[j][1])
			if i == 0:
				preview_p1.set_piece(dummy_piece, 0)
			elif i == 1:
				preview_p2.set_piece(dummy_piece, 1)

func _on_pause_pressed():
	toggle_pause.rpc()

@rpc("any_peer", "call_local", "reliable")
func toggle_pause():
	pause_overlay.visible = !pause_overlay.visible
	var paused = pause_overlay.visible
	Network.rpc_player_input.rpc_id(1, local_player_number, "PAUSE", paused)
	$Player1Area/VBoxContainer/TopButtonRow/PauseButton.disabled = paused
	$Player1Area/VBoxContainer/TopButtonRow/RotateLeftButton.disabled = paused
	$Player1Area/VBoxContainer/TopButtonRow/RotateRightButton.disabled = paused
	$Player1Area/VBoxContainer/BottomButtonRow/LeftButton.disabled = paused
	$Player1Area/VBoxContainer/BottomButtonRow/DownButton.disabled = paused
	$Player1Area/VBoxContainer/BottomButtonRow/RightButton.disabled = paused

func _on_player_disconnected(_id):
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

@rpc("authority", "call_local", "reliable")
func trigger_game_over(score: int, level: int):
	Network.final_score = score
	Network.final_level = level
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
