extends Control

const GameLogicScript = preload("res://scripts/GameLogic.gd")
const Enums = preload("res://scripts/Enums.gd")
const PieceScript = preload("res://scripts/Piece.gd")

@onready var game_board = $GameBoard
@onready var preview_p1 = $VBoxContainer/NextPieceContainer/NextPiecePreviewP1
@onready var preview_p2 = $VBoxContainer/NextPieceContainer/NextPiecePreviewP2
@onready var preview_p3 = $VBoxContainer/NextPieceContainer/NextPiecePreviewP3
@onready var preview_p4 = $VBoxContainer/NextPieceContainer/NextPiecePreviewP4
@onready var preview_p5 = $VBoxContainer/NextPieceContainer/NextPiecePreviewP5
@onready var preview_p6 = $VBoxContainer/NextPieceContainer/NextPiecePreviewP6
@onready var preview_p7 = $VBoxContainer/NextPieceContainer/NextPiecePreviewP7
@onready var preview_p8 = $VBoxContainer/NextPieceContainer/NextPiecePreviewP8
@onready var score_label = $VBoxContainer/StatsContainer/ScoreLabel
@onready var level_label = $VBoxContainer/StatsContainer/LevelLabel
@onready var lines_label = $VBoxContainer/StatsContainer/LinesLabel
@onready var pause_overlay = $PauseOverlay

var local_player_number: int = 0
var local_player_count: int = 2
var previews: Array = []

# Track previous action states to detect press/release
var prev_move_left: bool = false
var prev_move_right: bool = false
var prev_move_down: bool = false

func _ready():
	local_player_number = Network.starting_player_number
	local_player_count = Network.starting_player_count
	game_board.init_board(local_player_count)
	
	# Populate the previews array
	previews = [preview_p1, preview_p2, preview_p3, preview_p4, preview_p5, preview_p6, preview_p7, preview_p8]
	
	# Show only previews for active players and initialize them
	for i in range(previews.size()):
		if i < local_player_count:
			previews[i].visible = true
			previews[i].board_tile_size = game_board.tile_size
		else:
			previews[i].visible = false

	print("Main ready, connecting signals")
	Network.player_disconnected.connect(_on_player_disconnected)

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

func _physics_process(_delta):
	# Check pause action
	if Input.is_action_just_pressed("pause"):
		_on_pause_pressed()
		return
	
	# Check movement and rotation actions
	if Input.is_action_just_pressed("rotate_cw"):
		_on_button("CW", true)
	if Input.is_action_just_pressed("rotate_ccw"):
		_on_button("CCW", true)
	
	# Detect press/release transitions for continuous actions
	var curr_move_left = Input.is_action_pressed("move_left")
	var curr_move_right = Input.is_action_pressed("move_right")
	var curr_move_down = Input.is_action_pressed("move_down")
	
	# LEFT
	if curr_move_left and not prev_move_left:
		_on_button("LEFT", true)
	elif not curr_move_left and prev_move_left:
		_on_button("LEFT", false)
	
	# RIGHT
	if curr_move_right and not prev_move_right:
		_on_button("RIGHT", true)
	elif not curr_move_right and prev_move_right:
		_on_button("RIGHT", false)
	
	# DOWN
	if curr_move_down and not prev_move_down:
		_on_button("DOWN", true)
	elif not curr_move_down and prev_move_down:
		_on_button("DOWN", false)
	
	# Update previous states
	prev_move_left = curr_move_left
	prev_move_right = curr_move_right
	prev_move_down = curr_move_down

func _input(event):
	# Only handle UI button presses from the on-screen buttons
	# Controller and keyboard input is now handled in _physics_process()
	if not event is InputEventMouseButton:
		get_tree().root.set_input_as_handled()

func _on_button(control: String, pressed: bool) -> void:
	Network.rpc_player_input.rpc_id(1, local_player_number, control, pressed)

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_state(data: PackedByteArray):
	var state_dict = bytes_to_var(data)
	game_board.apply_state(state_dict)
	score_label.text = "Score: " + str(state_dict.score)
	level_label.text = "Level: " + str(state_dict.level)
	lines_label.text = "Lines: " + str(state_dict.lines_cleared)
	for i in range(state_dict.players.size()):
		var pd = state_dict.players[i]
		if pd.next_locs.size() > 0:
			var dummy_piece = PieceScript.new(pd.next_type, pd.player_number, 0, local_player_count)
			for j in range(pd.next_locs.size()):
				dummy_piece.locations[j] = Vector2i(pd.next_locs[j][0], pd.next_locs[j][1])
			if i < previews.size():
				previews[i].set_piece(dummy_piece, i, local_player_count)

func _on_pause_pressed():
	Network.rpc_player_input.rpc_id(1, local_player_number, "PAUSE", true)

func set_paused(p: bool) -> void:
	pause_overlay.visible = p
	$Player1Area/VBoxContainer/TopButtonRow/PauseButton.disabled = p
	$Player1Area/VBoxContainer/TopButtonRow/RotateLeftButton.disabled = p
	$Player1Area/VBoxContainer/TopButtonRow/RotateRightButton.disabled = p
	$Player1Area/VBoxContainer/BottomButtonRow/LeftButton.disabled = p
	$Player1Area/VBoxContainer/BottomButtonRow/DownButton.disabled = p
	$Player1Area/VBoxContainer/BottomButtonRow/RightButton.disabled = p

func _on_player_disconnected(_id):
	pass

func _on_main_menu_pressed():
	print("[CLIENT Main] _on_main_menu_pressed: Calling rpc_leave_game on server and returning to Lobby scene")
	Network.rpc_leave_game.rpc_id(1)
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

@rpc("authority", "call_local", "reliable")
func trigger_game_over(score: int, level: int):
	print("[CLIENT Main] trigger_game_over: score=", score, " level=", level, " - changing to GameOver scene")
	Network.final_score = score
	Network.final_level = level
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
