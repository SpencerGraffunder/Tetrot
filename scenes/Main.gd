extends Control

const GameLogicScript = preload("res://scripts/GameLogic.gd")
const Enums = preload("res://scripts/Enums.gd")
const PieceScript = preload("res://scripts/Piece.gd")

@onready var game_board = $GameBoard
@onready var preview_p1 = $HBoxContainer/NextPiecePreviewP1
@onready var preview_p2 = $HBoxContainer/NextPiecePreviewP2

var logic: GameLogicScript

func _ready():
	logic = GameLogicScript.new()
	logic.reset(2, Network.starting_level)
	logic.game_over_triggered.connect(_on_game_over)
	logic.state_changed.connect(_on_state_changed)
	game_board.set_state(logic.state)
	preview_p1.board_tile_size = game_board.tile_size
	preview_p2.board_tile_size = game_board.tile_size
	$Player1Area/VBoxContainer/BottomButtonRow/LeftButton.button_down.connect(func(): _on_button("LEFT", true))
	$Player1Area/VBoxContainer/BottomButtonRow/LeftButton.button_up.connect(func(): _on_button("LEFT", false))
	$Player1Area/VBoxContainer/BottomButtonRow/RightButton.button_down.connect(func(): _on_button("RIGHT", true))
	$Player1Area/VBoxContainer/BottomButtonRow/RightButton.button_up.connect(func(): _on_button("RIGHT", false))
	$Player1Area/VBoxContainer/BottomButtonRow/DownButton.button_down.connect(func(): _on_button("DOWN", true))
	$Player1Area/VBoxContainer/BottomButtonRow/DownButton.button_up.connect(func(): _on_button("DOWN", false))
	$Player1Area/VBoxContainer/TopButtonRow/RotateLeftButton.button_down.connect(func(): _on_button("CCW", true))
	$Player1Area/VBoxContainer/TopButtonRow/RotateRightButton.button_down.connect(func(): _on_button("CW", true))

func _physics_process(_delta):
	if not multiplayer.is_server():
		return
	if logic:
		logic.tick()
		sync_state.rpc(var_to_bytes(serialize_state()))

func serialize_state() -> Dictionary:
	var board_data = []
	for row in logic.state.board:
		board_data.append(row.duplicate())
	var players_data = []
	for p in logic.state.players:
		var piece_locs = []
		var piece_type = -1
		var piece_player = -1
		if p.active_piece != null:
			for loc in p.active_piece.locations:
				piece_locs.append([loc.x, loc.y])
			piece_type = p.active_piece.piece_type
			piece_player = p.active_piece.player_number
		var next_locs = []
		var next_type = -1
		if p.next_piece != null:
			for loc in p.next_piece.locations:
				next_locs.append([loc.x, loc.y])
			next_type = p.next_piece.piece_type
		players_data.append({
			"player_number": p.player_number,
			"piece_locs": piece_locs,
			"piece_type": piece_type,
			"piece_player": piece_player,
			"next_locs": next_locs,
			"next_type": next_type
		})
	return {
		"board": board_data,
		"players": players_data,
		"score": logic.state.score,
		"level": logic.state.current_level
	}

@rpc("authority", "call_remote", "unreliable_ordered")
func sync_state(data: PackedByteArray):
	var state_dict = bytes_to_var(data)
	game_board.apply_state(state_dict)
	for i in range(state_dict.players.size()):
		var pd = state_dict.players[i]
		if pd.next_locs.size() > 0:
			var dummy_piece = PieceScript.new(pd.next_type, pd.player_number, 0, 2)
			for j in range(pd.next_locs.size()):
				dummy_piece.locations[j] = Vector2i(pd.next_locs[j][0], pd.next_locs[j][1])
			if i == 0:
				preview_p1.set_piece(dummy_piece, 0)
			elif i == 1:
				preview_p2.set_piece(dummy_piece, 1)

func _input(event):
	var control = get_control_from_input(event)
	if control == "":
		return
	print("player number: ", Network.get_player_number())
	var pressed = false
	if event is InputEventKey:
		pressed = event.pressed
	elif event is InputEventScreenTouch or event is InputEventMouseButton:
		pressed = event.pressed
	send_input.rpc_id(1, Network.get_player_number(), control, pressed)

@rpc("any_peer", "call_remote", "reliable")
func send_input(player_number: int, control: String, pressed: bool):
	if multiplayer.is_server():
		logic.do_input(player_number, control, pressed)

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
	send_input.rpc_id(1, Network.get_player_number(), control, pressed)
	if multiplayer.is_server():
		logic.do_input(Network.get_player_number(), control, pressed)

func _on_state_changed():
	game_board.queue_redraw()
	if logic.state.players.size() > 0 and logic.state.players[0].next_piece != null:
		preview_p1.set_piece(logic.state.players[0].next_piece, 0)
	if logic.state.players.size() > 1 and logic.state.players[1].next_piece != null:
		preview_p2.set_piece(logic.state.players[1].next_piece, 1)
	game_board.queue_redraw()

func _on_game_over():
	print("Game over! Score: ", logic.state.score)
