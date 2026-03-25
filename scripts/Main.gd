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
    local_player_number = Network.starting_player_number
    local_player_count = Network.starting_player_count
    game_board.init_board(local_player_count)
    preview_p1.board_tile_size = game_board.tile_size
    preview_p2.board_tile_size = game_board.tile_size

    get_tree().set_auto_accept_quit(false)

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
    pass

func _input(event):
    if event is InputEventKey and event.echo:
        return
    if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
        return
    var control = get_control_from_input(event)
    if control == "":
        return
    var pressed = event.is_pressed()
    if control == "PAUSE" and pressed:
        _on_pause_pressed()
        return
    _on_button(control, pressed)

func get_control_from_input(event) -> String:
    if event.is_action("move_left"): return "LEFT"
    if event.is_action("move_right"): return "RIGHT"
    if event.is_action("move_down"): return "DOWN"
    if event.is_action("rotate_cw"): return "CW"
    if event.is_action("rotate_ccw"): return "CCW"
    if event.is_action("pause"): return "PAUSE"
    return ""

func _on_button(control: String, pressed: bool) -> void:
    Network.rpc_player_input.rpc_id(1, local_player_number, control, pressed)

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_state(data: PackedByteArray):
    print("sync state received")
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
    get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_main_menu_pressed():
    Network.rpc_leave_game.rpc_id(1)

@rpc("authority", "call_local", "reliable")
func trigger_game_over(score: int, level: int):
    Network.final_score = score
    Network.final_level = level
    get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func _notification(what):
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        get_tree().quit()
