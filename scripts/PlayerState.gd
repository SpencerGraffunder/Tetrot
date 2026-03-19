extends RefCounted

const Enums = preload("res://scripts/Enums.gd")

var player_number: int

var active_piece = null
var next_piece = null
var next_piece_type = null

var spawn_delay_counter: int = 0
var spawn_delay_threshold: int = 100
var fall_counter: int = 0
var das_counter: int = 0
var das_threshold: int = 0
var down_counter: int = 0

var is_move_right_pressed: bool = false
var is_move_left_pressed: bool = false
var is_move_down_pressed: bool = false

var state: int = Enums.TetrisState.SPAWN
var spawn_column: int = 0

func _init(p_player_number: int):
	player_number = p_player_number