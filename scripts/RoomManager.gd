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
	while true:
		var code = ""
		for i in range(3):
			code += CHARS[randi() % CHARS.length()]
		if not rooms.has(code):
			return code
	return ""

func create_room(creator_id: int, starting_level: int) -> String:
	var code = generate_code()
	var room = Room.new(code, creator_id)
	room.starting_level = starting_level
	rooms[code] = room
	peer_to_room[creator_id] = code
	print("Room created: ", code, " by peer ", creator_id)
	return code

func join_room(peer_id: int, code: String) -> bool:
	code = code.to_lower()
	if not rooms.has(code):
		return false
	var room = rooms[code]
	if room.started:
		return false
	if room.peers.size() >= 8:
		return false
	room.peers.append(peer_id)
	peer_to_room[peer_id] = code
	print("Peer ", peer_id, " joined room ", code)
	return true

func leave_room(peer_id: int) -> void:
	if not peer_to_room.has(peer_id):
		return
	var code = peer_to_room[peer_id]
	peer_to_room.erase(peer_id)
	if not rooms.has(code):
		return
	var room = rooms[code]
	room.peers.erase(peer_id)
	if room.peers.is_empty() or peer_id == room.creator:
		dissolve_room(code)

func dissolve_room(code: String) -> void:
	if not rooms.has(code):
		return
	var room = rooms[code]
	for peer_id in room.peers:
		peer_to_room.erase(peer_id)
	rooms.erase(code)
	print("Room dissolved: ", code)

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
		return null
	var code = peer_to_room[peer_id]
	if not rooms.has(code):
		return null
	return rooms[code]

func tick(delta: float) -> void:
	for code in rooms.keys():
		var room = rooms[code]
		if room.started and room.logic != null:
			room.logic.tick()
		else:
			room.idle_timer += delta
			if room.idle_timer >= ROOM_TIMEOUT:
				print("Room timed out: ", code)
				dissolve_room(code)

func _on_game_over(code: String) -> void:
	dissolve_room(code)
