extends ColorRect

const Enums = preload("res://scripts/Enums.gd")
const PieceScript = preload("res://scripts/Piece.gd")

var piece = null
var tile_textures: Dictionary = {}
var board_tile_size: float = 0.0

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	load_textures()

func load_textures():
	tile_textures[0] = load("res://assets/backgroundblock.bmp")
	for i in range(10):
		var image = load("res://assets/tile_%d.png" % i).get_image()
		var tex = ImageTexture.create_from_image(image)
		tile_textures[i + 1] = tex

func set_piece(p, _player_number: int) -> void:
	piece = p
	queue_redraw()

func _draw():
	if piece == null:
		return
	# find bounding box of piece
	var min_x = piece.locations[0].x
	var max_x = piece.locations[0].x
	var min_y = piece.locations[0].y
	var max_y = piece.locations[0].y
	for loc in piece.locations:
		min_x = mini(min_x, loc.x)
		max_x = maxi(max_x, loc.x)
		min_y = mini(min_y, loc.y)
		max_y = maxi(max_y, loc.y)
	var piece_w = max_x - min_x + 1
	var piece_h = max_y - min_y + 1
	var tile_size = board_tile_size if board_tile_size > 0 else minf(size.x / piece_w, size.y / piece_h) * 0.8
	var offset = Vector2(
		(size.x - tile_size * piece_w) / 2,
		(size.y - tile_size * piece_h) / 2
	)
	for loc in piece.locations:
		var tex = tile_textures.get(piece.player_number + 2)
		var pos = Vector2(
			offset.x + (loc.x - min_x) * tile_size,
			offset.y + (loc.y - min_y) * tile_size
		)
		draw_texture_rect(tex, Rect2(pos, Vector2(tile_size, tile_size)), false)
