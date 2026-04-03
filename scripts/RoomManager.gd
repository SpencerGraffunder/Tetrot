extends Node

const GameLogicScript = preload("res://scripts/GameLogic.gd")
const ROOM_TIMEOUT = 900  # 15 minutes in seconds
const CHARS = "0123456789abcdefghijklmnopqrstuvwxyz"

var rooms: Dictionary = {}  # code -> Room
var peer_to_room: Dictionary = {}  # peer_id -> room_code

class Room:
	var code: String
	var peers: Array = []  # peer ids
	var logic: Object = null
	var started: bool = false
	var creator: int = 0
	var starting_level: int = 0
	var idle_timer: float = 0.0

	func _init(p_code: String, p_creator: int):
		code = p_code
		creator = p_creator
		peers.append(p_creator)

func generate_code() -> String:
	var code_length = 3
	if OS.has_feature("local"):
		code_length = 1
	while true:
		var code = ""
		for i in range(code_length):
			code += String.chr(randi() % 26 + 97) # 97 is 'a', 26 letters
		if not rooms.has(code):
			return code
	return ""

func create_room(creator_id: int, starting_level: int) -> String:
	var code = generate_code()
	var room = Room.new(code, creator_id)
	room.starting_level = starting_level
	rooms[code] = room
	peer_to_room[creator_id] = code
	print("[SERVER RoomManager] create_room: Room created: ", code, " by peer ", creator_id, " at level ", starting_level)
	return code

func join_room(peer_id: int, code: String) -> bool:
	code = code.to_lower()
	if not rooms.has(code):
		print("[SERVER RoomManager] join_room: Room ", code, " not found")
		return false
	var room = rooms[code]
	if room.started:
		print("[SERVER RoomManager] join_room: Room ", code, " already started")
		return false
	if room.peers.size() >= 8:
		print("[SERVER RoomManager] join_room: Room ", code, " is full")
		return false
	if not room.peers.has(peer_id):
		room.peers.append(peer_id)
	peer_to_room[peer_id] = code
	print("[SERVER RoomManager] join_room: Peer ", peer_id, " joined room ", code, " (now ", room.peers.size(), " peers)")
	return true

func reassign_peer(code: String, old_peer_id: int, new_peer_id: int) -> void:
	if not rooms.has(code):
		print("[SERVER RoomManager] reassign_peer: Room ", code, " not found")
		return
	var room = rooms[code]
	if old_peer_id == new_peer_id:
		print("[SERVER RoomManager] reassign_peer: old_peer_id and new_peer_id are the same (", old_peer_id, ")")
		return
	if not room.peers.has(old_peer_id):
		print("[SERVER RoomManager] reassign_peer: old_peer_id ", old_peer_id, " not in room ", code)
		return
	# Remove old peer, add new peer
	room.peers.erase(old_peer_id)
	if not room.peers.has(new_peer_id):
		room.peers.append(new_peer_id)
	peer_to_room.erase(old_peer_id)
	peer_to_room[new_peer_id] = code
	print("[SERVER RoomManager] reassign_peer: Reassigned ", old_peer_id, " to ", new_peer_id, " in room ", code)

func leave_room(peer_id: int) -> void:
	print("[SERVER RoomManager] leave_room: Peer ", peer_id, " leaving")
	if not peer_to_room.has(peer_id):
		print("[SERVER RoomManager] leave_room: Peer not in any room")
		return
	var code = peer_to_room[peer_id]
	peer_to_room.erase(peer_id)
	if not rooms.has(code):
		print("[SERVER RoomManager] leave_room: Room ", code, " not found")
		return
	var room = rooms[code]
	room.peers.erase(peer_id)
	print("[SERVER RoomManager] leave_room: Room ", code, " now has ", room.peers.size(), " peers")
	if room.peers.is_empty():
		print("[SERVER RoomManager] leave_room: Room is now empty, dissolving")
		dissolve_room(code)
	else:
		print("[SERVER RoomManager] leave_room: Room still has players, keeping it alive")

func dissolve_room(code: String) -> void:
	if not rooms.has(code):
		print("[SERVER RoomManager] dissolve_room: Room ", code, " not found")
		return
	var room = rooms[code]
	print("[SERVER RoomManager] dissolve_room: Dissolving room ", code, " with peers: ", room.peers)
	for peer_id in room.peers:
		peer_to_room.erase(peer_id)
	rooms.erase(code)
	print("[SERVER RoomManager] dissolve_room: Room ", code, " dissolved")

func start_room(code: String) -> bool:
	if not rooms.has(code):
		return false
	var room = rooms[code]
	if room.started:
		return false
	room.logic = GameLogicScript.new()
	room.logic.reset(room.peers.size(), room.starting_level)
	room.logic.game_over_triggered.connect(func(): _on_game_over(code))
	room.started = true
	print("Room started: ", code, " with ", room.peers.size(), " players")
	return true

func get_room_for_peer(peer_id: int) -> Room:
	if not peer_to_room.has(peer_id):
		print("[SERVER RoomManager] get_room_for_peer: peer_id ", peer_id, " not in peer_to_room. peer_to_room=", peer_to_room)
		return null
	var code = peer_to_room[peer_id]
	if not rooms.has(code):
		print("[SERVER RoomManager] get_room_for_peer: code ", code, " not in rooms. rooms=", rooms.keys())
		return null
	return rooms[code]

func tick(delta: float) -> void:
	for code in rooms.keys():
		var room = rooms[code]
		if room.started and room.logic != null:
			room.logic.tick()
			_sync_room_state(code)
		else:
			room.idle_timer += delta
			if room.idle_timer >= ROOM_TIMEOUT:
				print("Room timed out: ", code)
				dissolve_room(code)

func _sync_room_state(code: String) -> void:
	if not rooms.has(code):
		return
	var room = rooms[code]
	var state_data = _serialize_state(room)
	for peer_id in room.peers:
		Network.rpc_sync_state.rpc_id(peer_id, state_data)

func _serialize_state(room) -> PackedByteArray:
	var board_data = []
	for row in room.logic.state.board:
		board_data.append(row.duplicate())
	var players_data = []
	for p in room.logic.state.players:
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
	return var_to_bytes({
		"board": board_data,
		"players": players_data,
		"score": room.logic.state.score,
		"level": room.logic.state.current_level,
		"lines_cleared": room.logic.lines_cleared
	})

func _on_game_over(code: String) -> void:
	if not rooms.has(code):
		print("[SERVER RoomManager] _on_game_over: Room ", code, " not found")
		return
	var room = rooms[code]
	print("[SERVER RoomManager] _on_game_over: Sending game over to ", room.peers.size(), " peers in room ", code)
	for peer_id in room.peers:
		print("[SERVER RoomManager] _on_game_over: Sending rpc_game_over to peer ", peer_id)
		Network.rpc_game_over.rpc_id(peer_id, room.logic.state.score, room.logic.state.current_level)
	dissolve_room(code)
