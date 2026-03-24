extends Node

const PORT = 7777
const MAX_PEERS = 64
var SERVER_ADDRESS: String = "tetrotserver.nuclearquads.com"

var players: Dictionary = {}
var starting_level: int = 0
var final_score: int = 0
var final_level: int = 0
var is_dedicated_server: bool = false

signal player_connected(id)
signal player_disconnected(id)
signal connection_failed
signal connection_succeeded
signal room_created(code)
signal room_joined(player_count)
signal room_updated(player_count, starting_level)
signal game_starting(player_number, player_count, starting_level)

func _ready():
	if OS.has_feature("local"):
		SERVER_ADDRESS = "127.0.0.1"
	if DisplayServer.get_name() == "headless":
		is_dedicated_server = true
		start_dedicated_server()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func start_dedicated_server():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PEERS)
	multiplayer.multiplayer_peer = peer
	print("Dedicated server started on port ", PORT)

func connect_to_server():
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(SERVER_ADDRESS, PORT)
	multiplayer.multiplayer_peer = peer

func host_game():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	print("Hosting on port ", PORT)

func join_game(address: String):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = peer

func get_player_number() -> int:
	if multiplayer.is_server():
		return 0
	var my_id = multiplayer.get_unique_id()
	if players.has(my_id):
		return players[my_id].player_number
	return -1

func _physics_process(_delta):
	if is_dedicated_server:
		RoomManager.tick(_delta)

func _on_peer_connected(id):
	print("Peer connected: ", id)
	if is_dedicated_server:
		players[id] = { "id": id }
	player_connected.emit(id)

func _on_peer_disconnected(id):
	print("Peer disconnected: ", id)
	if is_dedicated_server:
		RoomManager.leave_room(id)
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server():
	print("Connected to server!")
	connection_succeeded.emit()

func _on_connection_failed():
	print("Connection failed.")
	connection_failed.emit()

# ---- CLIENT -> SERVER RPCs ----

@rpc("any_peer", "call_remote", "reliable")
func rpc_create_room(level: int):
	if not is_dedicated_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	var code = RoomManager.create_room(sender, level)
	rpc_room_created.rpc_id(sender, code)

@rpc("any_peer", "call_remote", "reliable")
func rpc_join_room(code: String):
	if not is_dedicated_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	var success = RoomManager.join_room(sender, code)
	if success:
		var room = RoomManager.get_room_for_peer(sender)
		rpc_room_joined.rpc_id(sender, room.peers.size())
		# notify all peers in room of updated count
		for peer_id in room.peers:
			rpc_room_updated.rpc_id(peer_id, room.peers.size(), room.starting_level)
	else:
		rpc_join_failed.rpc_id(sender)

@rpc("any_peer", "call_remote", "reliable")
func rpc_update_level(level: int):
	if not is_dedicated_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	var room = RoomManager.get_room_for_peer(sender)
	if room == null or room.creator != sender:
		return
	room.starting_level = level
	for peer_id in room.peers:
		rpc_room_updated.rpc_id(peer_id, room.peers.size(), room.starting_level)

@rpc("any_peer", "call_remote", "reliable")
func rpc_start_game():
	if not is_dedicated_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	var room = RoomManager.get_room_for_peer(sender)
	if room == null or room.creator != sender:
		return
	var success = RoomManager.start_room(room.code)
	if success:
		for i in range(room.peers.size()):
			rpc_game_starting.rpc_id(room.peers[i], i, room.peers.size(), room.starting_level)

@rpc("any_peer", "call_remote", "reliable")
func rpc_player_input(player_number: int, control: String, pressed: bool):
	if not is_dedicated_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	var room = RoomManager.get_room_for_peer(sender)
	if room == null or not room.started:
		return
	room.logic.do_input(player_number, control, pressed)

# ---- SERVER -> CLIENT RPCs ----

@rpc("authority", "call_remote", "reliable")
func rpc_room_created(code: String):
	room_created.emit(code)

@rpc("authority", "call_remote", "reliable")
func rpc_room_joined(player_count: int):
	room_joined.emit(player_count)

@rpc("authority", "call_remote", "reliable")
func rpc_room_updated(player_count: int, level: int):
	room_updated.emit(player_count, level)

@rpc("authority", "call_remote", "reliable")
func rpc_join_failed():
	connection_failed.emit()

@rpc("authority", "call_remote", "reliable")
func rpc_game_starting(player_number: int, player_count: int, level: int):
	players[multiplayer.get_unique_id()] = { "player_number": player_number }
	starting_level = level
	game_starting.emit(player_number, player_count, level)

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_state(_data: PackedByteArray):
	pass
