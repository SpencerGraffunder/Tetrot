extends Control

const GameLogicScript = preload("res://scripts/GameLogic.gd")
const Enums = preload("res://scripts/Enums.gd")

@onready var game_board = $GameBoard

var logic: GameLogicScript

func _ready():
    logic = GameLogicScript.new()
    logic.reset(2, Network.starting_level)
    logic.game_over_triggered.connect(_on_game_over)
    logic.state_changed.connect(_on_state_changed)
    game_board.set_state(logic.state)
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
        players_data.append({
            "player_number": p.player_number,
            "piece_locs": piece_locs,
            "piece_type": piece_type,
            "piece_player": piece_player
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

func _input(event):
    var control = get_control_from_input(event)
    if control == "":
        return
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

func _on_game_over():
    print("Game over! Score: ", logic.state.score)