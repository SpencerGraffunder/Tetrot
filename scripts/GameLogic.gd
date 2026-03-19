extends RefCounted

const Enums = preload("res://scripts/Enums.gd")
const PieceScript = preload("res://scripts/Piece.gd")
const GameStateScript = preload("res://scripts/GameState.gd")
const PlayerStateScript = preload("res://scripts/PlayerState.gd")

const FALL_DELAY_VALUES = {
	0: 48, 1: 43, 2: 38, 3: 33, 4: 28, 5: 23,
	6: 18, 7: 13, 8: 8, 9: 6, 10: 5, 13: 4,
	16: 3, 19: 2, 29: 1
}
const SCORING_VALUES = { 0: 0, 1: 40, 2: 100, 3: 300, 4: 1200 }
const DAS_DEFAULT = [2, 7]  # (3-1, 8-1)
const DAS_SINGLE = [5, 15]  # (6-1, 16-1)

var state: GameStateScript
var fall_threshold: int = 48
var lines_cleared: int = 0
var die_counter: int = 0
var clearing_lines: Array = []
var has_leveled_up: bool = false
var paused: bool = false

signal game_over_triggered
signal state_changed

func get_das_values() -> Array:
	if state.player_count == 1:
		return DAS_SINGLE
	return DAS_DEFAULT

func get_fall_threshold(level: int) -> int:
	var x = level
	while x >= 0:
		if FALL_DELAY_VALUES.has(x):
			return FALL_DELAY_VALUES[x]
		x -= 1
	return 48

func reset(player_count: int, starting_level: int) -> void:
	state = GameStateScript.new()
	state.init(player_count, starting_level)
	fall_threshold = get_fall_threshold(starting_level)
	lines_cleared = 10 * starting_level
	die_counter = 0
	clearing_lines = []
	has_leveled_up = false
	paused = false

	for i in range(player_count):
		var p = PlayerStateScript.new(i)
		state.players.append(p)

	if player_count > 1:
		for player in state.players:
			player.spawn_column = roundi(
				(((state.board_width - 1.0) / player_count) * player.player_number +
				(state.board_width / float(player_count)) * (player.player_number + 1)) / 2.0
			)
	else:
		state.players[0].spawn_column = state.board_width / 2

func do_input(player_number: int, control: String, pressed: bool) -> void:
	if player_number >= state.players.size():
		return
	var player = state.players[player_number]

	if pressed:
		if player.active_piece != null:
			if control == "CCW":
				if player.active_piece.can_rotate(state.board, state.players, Enums.Rotation.CCW):
					player.active_piece.rotate(Enums.Rotation.CCW)
			elif control == "CW":
				if player.active_piece.can_rotate(state.board, state.players, Enums.Rotation.CW):
					player.active_piece.rotate(Enums.Rotation.CW)
		if control == "LEFT":
			player.is_move_left_pressed = true
			player.das_threshold = 0
			player.das_counter = 0
			player.is_move_right_pressed = false
		elif control == "RIGHT":
			player.is_move_right_pressed = true
			player.das_threshold = 0
			player.das_counter = 0
			player.is_move_left_pressed = false
		elif control == "DOWN":
			player.is_move_down_pressed = true
			player.down_counter = 0
	else:
		if control == "LEFT":
			player.is_move_left_pressed = false
		elif control == "RIGHT":
			player.is_move_right_pressed = false
		elif control == "DOWN":
			player.is_move_down_pressed = false

func lock_piece(player_number: int) -> void:
	var player = state.players[player_number]
	var piece_locked_into_another = false
	var max_row_index = 0

	for loc in player.active_piece.locations:
		if state.board[loc.y][loc.x] != Enums.TileType.BLANK:
			piece_locked_into_another = true
		var tile_type = player.active_piece.tile_type if state.player_count == 1 else player_number
		state.board[loc.y][loc.x] = tile_type
		if loc.y > max_row_index:
			max_row_index = loc.y

	if player.active_piece.piece_type == Enums.PieceType.I:
		player.spawn_delay_threshold = ((max_row_index + 2) / 4) * 2 + 10
	else:
		player.spawn_delay_threshold = ((max_row_index + 3) / 4) * 2 + 10

	var was_line_added = false
	for row_index in range(state.board.size()):
		var can_clear = true
		for tile in state.board[row_index]:
			if tile == Enums.TileType.BLANK:
				can_clear = false
				break
		if can_clear:
			was_line_added = true
			var already_in_list = false
			for line in clearing_lines:
				if line.board_index == row_index:
					already_in_list = true
			if not already_in_list:
				clearing_lines.append({ "player_number": player_number, "board_index": row_index, "counter": 20 })

	if was_line_added:
		player.state = Enums.TetrisState.CLEAR
	else:
		player.state = Enums.TetrisState.SPAWN_DELAY

	player.active_piece = null
	if piece_locked_into_another:
		for p in state.players:
			p.state = Enums.TetrisState.DIE

func clear_lines() -> void:
	var future_lines = []
	var present_lines = []
	for line in clearing_lines:
		line.counter -= 1
		if line.counter <= 0:
			present_lines.append(line)
		else:
			future_lines.append(line)

	for clearing_line in present_lines:
		for shifting_line in future_lines:
			if clearing_line.board_index > shifting_line.board_index:
				shifting_line.board_index += 1

	for line in present_lines:
		state.board.remove_at(line.board_index)
		var new_row = []
		for c in range(state.board_width):
			new_row.append(Enums.TileType.BLANK)
		state.board.insert(0, new_row)

	clearing_lines = future_lines

	var count = present_lines.size()
	if count > 0:
		var scoring_key = min(count, 4)
		state.score += SCORING_VALUES[scoring_key] * (state.current_level + 1)

		var level_threshold = 10 * (mini(state.player_count, 3) + 2 * state.current_level)
		if not has_leveled_up:
			if lines_cleared + count >= level_threshold:
				state.current_level += 1
				has_leveled_up = true
				fall_threshold = get_fall_threshold(state.current_level)
		else:
			var mod_threshold = 10 * mini(3, state.player_count)
			if lines_cleared % mod_threshold + count >= mod_threshold:
				state.current_level += 1
				fall_threshold = get_fall_threshold(state.current_level)

		lines_cleared += count

func tick() -> void:
	if paused:
		return

	var das_values = get_das_values()

	for player in state.players:
		if player.is_move_left_pressed or player.is_move_right_pressed:
			player.das_counter += 1

	clear_lines()

	for player_number in range(state.player_count):
		var player = state.players[player_number]

		if player.state == Enums.TetrisState.SPAWN:
			if player.next_piece == null or player.next_piece.can_move(state.board, state.players, null) == Enums.MoveAllowance.CAN:
				player.spawn_delay_counter += 1
				var active_type: int
				if player.next_piece_type == null:
					active_type = randi() % 7
				else:
					active_type = player.next_piece.piece_type
				var next_type = randi() % 7
				if next_type == active_type:
					next_type = randi() % 7
				player.next_piece_type = next_type
				player.active_piece = PieceScript.new(active_type, player_number, player.spawn_column, state.player_count)
				player.next_piece = PieceScript.new(next_type, player_number, player.spawn_column, state.player_count)
				player.state = Enums.TetrisState.PLAY
				player.fall_counter = 0
				player.spawn_delay_counter = 0

		if player.state == Enums.TetrisState.PLAY:
			if player.is_move_left_pressed or player.is_move_right_pressed:
				if player.das_counter > player.das_threshold:
					var dir = Enums.Direction.LEFT if player.is_move_left_pressed else Enums.Direction.RIGHT
					if player.active_piece.can_move(state.board, state.players, dir) == Enums.MoveAllowance.CAN:
						player.active_piece.move(dir)
						if player.das_threshold == 0:
							player.das_threshold = das_values[1]
							if player.das_counter + das_values[0] > das_values[1]:
								player.das_counter = das_values[1] - das_values[0]
							else:
								player.das_counter -= 1
						else:
							player.das_threshold = das_values[0]
							player.das_counter = 0

			if player.is_move_down_pressed:
				player.down_counter += 1
				if player.down_counter > 2:
					var down_result = player.active_piece.can_move(state.board, state.players, Enums.Direction.DOWN)
					if down_result == Enums.MoveAllowance.CAN:
						player.active_piece.move(Enums.Direction.DOWN)
						player.fall_counter = 0
					elif down_result == Enums.MoveAllowance.CANT_BOARD:
						lock_piece(player_number)
					player.down_counter = 0

			player.fall_counter += 1
			if player.fall_counter >= fall_threshold and player.active_piece != null:
				var fall_result = player.active_piece.can_move(state.board, state.players, Enums.Direction.DOWN)
				if fall_result == Enums.MoveAllowance.CANT_BOARD:
					lock_piece(player_number)
				elif fall_result == Enums.MoveAllowance.CAN:
					player.active_piece.move(Enums.Direction.DOWN)
				player.fall_counter = 0

		if player.state == Enums.TetrisState.CLEAR:
			var still_clearing = false
			for line in clearing_lines:
				if line.player_number == player.player_number:
					still_clearing = true
			if not still_clearing:
				player.state = Enums.TetrisState.SPAWN_DELAY

		elif player.state == Enums.TetrisState.SPAWN_DELAY:
			player.spawn_delay_counter += 1
			player.is_move_down_pressed = false
			if player.spawn_delay_counter > player.spawn_delay_threshold:
				player.spawn_delay_counter = 0
				player.state = Enums.TetrisState.SPAWN

		if player.state == Enums.TetrisState.DIE:
			die_counter += 1
			if die_counter >= 120:
				for p in state.players:
					p.state = Enums.TetrisState.GAME_OVER

		if player.state == Enums.TetrisState.GAME_OVER:
			state.game_over = true
			game_over_triggered.emit()
			return

	state_changed.emit()