extends RefCounted

const Enums = preload("res://scripts/Enums.gd")

var player_count: int = 2
var board_width: int = 0
var board: Array = []
var players: Array = []
var current_level: int = 0
var score: int = 0
var game_over: bool = false

func init(p_player_count: int, starting_level: int) -> void:
	player_count = p_player_count
	board_width = (4 * player_count) + 6
	current_level = starting_level
	board = []
	for r in range(Enums.TOTAL_ROWS):
		var row = []
		for c in range(board_width):
			row.append(Enums.TileType.BLANK)
		board.append(row)