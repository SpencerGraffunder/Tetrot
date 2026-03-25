extends ColorRect

const Enums = preload("res://scripts/Enums.gd")
const PieceScript = preload("res://scripts/Piece.gd")

var cols: int
var tile_size: float
var board: Array = []
var tile_textures: Dictionary = {}
var offset: Vector2
var game_state = null

func set_state(new_state) -> void:
	game_state = new_state
	if tile_size == 0:
		cols = game_state.board_width
		tile_size = min(size.x / cols, size.y / Enums.VISIBLE_ROWS)
		offset = Vector2(
			(size.x - (tile_size * cols)) / 2,
			(size.y - (tile_size * Enums.VISIBLE_ROWS)) / 2
		)

func init_board(player_count: int):
	cols = (4 * player_count) + 6
	tile_size = min(size.x / cols, size.y / Enums.VISIBLE_ROWS)
	offset = Vector2(
		(size.x - (tile_size * cols)) / 2,
		(size.y - (tile_size * Enums.VISIBLE_ROWS)) / 2
	)
	board = []
	for r in range(Enums.TOTAL_ROWS):
		var row = []
		for c in range(cols):
			row.append(Enums.EMPTY)
		board.append(row)
	queue_redraw()

func _ready():
	load_textures()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func load_textures():
	tile_textures[0] = load("res://assets/backgroundblock.bmp")
	for i in range(10):
		var image = load("res://assets/tile_%d.png" % i).get_image()
		var tex = ImageTexture.create_from_image(image)
		tile_textures[i + 1] = tex

func _draw():
	if game_state == null:
		return
	for r in range(game_state.board.size()):
		for c in range(game_state.board[r].size()):
			var tile = game_state.board[r][c]
			var tex = tile_textures.get(tile + 2) if tile != Enums.TileType.BLANK else tile_textures.get(0)
			var screen_row = r - 2
			if screen_row < 0:
				continue
			var pos = Vector2(offset.x + c * tile_size, offset.y + screen_row * tile_size)
			if tex:
				draw_texture_rect(tex, Rect2(pos, Vector2(tile_size, tile_size)), false)
	
	for p in game_state.players:
		if p.active_piece != null:
			for loc in p.active_piece.locations:
				var screen_row = loc.y - 2
				if screen_row < 0:
					continue
				var tex = tile_textures.get(p.player_number + 2)
				var pos = Vector2(offset.x + loc.x * tile_size, offset.y + screen_row * tile_size)
				if tex:
					draw_texture_rect(tex, Rect2(pos, Vector2(tile_size, tile_size)), false)

func apply_state(state_dict: Dictionary) -> void:
	game_state = state_dict

	for i in range(game_state.players.size()):
		var pd = game_state.players[i]

		if pd.piece_locs.size() > 0:
			var piece = PieceScript.new(pd.piece_type, pd.piece_player, 0, game_state.players.size())
			for j in range(pd.piece_locs.size()):
				piece.locations[j] = Vector2i(pd.piece_locs[j][0], pd.piece_locs[j][1])
			pd.active_piece = piece
		else:
			pd.active_piece = null

	queue_redraw()
