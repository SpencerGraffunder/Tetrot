extends Node

const PORT = 7777
const MAX_PEERS = 64
var SERVER_ADDRESS: String = "tetrotserver.nuclearquads.com"

var players: Dictionary = {}
var starting_level: int = 0
var final_score: int = 0
var final_level: int = 0
var is_dedicated_server: bool = false
var starting_player_number: int = 0
var starting_player_count: int = 2

signal player_connected(id)
signal player_disconnected(id)
signal connection_failed
signal connection_succeeded
signal room_created(code)
signal room_joined(player_count, code)
signal room_updated(player_count, starting_level)

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
	peer.create_server(PORT, MAX_PEERS, 9)
	multiplayer.multiplayer_peer = peer
	print("Dedicated server started on port ", PORT)

func connect_to_server():
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(SERVER_ADDRESS, PORT, 9)
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
	print("[SERVER/CLIENT] Peer connected: ", id, " (is_dedicated_server=", is_dedicated_server, ")")
	if is_dedicated_server:
		players[id] = { "id": id }
	player_connected.emit(id)

func _on_peer_disconnected(id):
	print("[SERVER/CLIENT] Peer disconnected: ", id, " (is_dedicated_server=", is_dedicated_server, ")")
	if is_dedicated_server:
		RoomManager.leave_room(id)
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server():
	print("[CLIENT] Connected to server!")
	connection_succeeded.emit()

func _on_connection_failed():
	print("[CLIENT] Connection failed.")
	connection_failed.emit()

# ---- CLIENT -> SERVER RPCs ----

@rpc("any_peer", "call_remote", "reliable")
func rpc_create_room(level: int):
	if not is_dedicated_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	print("[SERVER] rpc_create_room: Peer ", sender, " creating room with level ", level)
	var code = RoomManager.create_room(sender, level)
	print("[SERVER] rpc_create_room: Created room code: ", code)
	rpc_room_created.rpc_id(sender, code)

@rpc("any_peer", "call_remote", "reliable")
func rpc_join_room(code: String):
	if not is_dedicated_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	print("[SERVER] rpc_join_room: Peer ", sender, " trying to join room ", code)
	var success = RoomManager.join_room(sender, code)
	if success:
		var room = RoomManager.get_room_for_peer(sender)
		print("[SERVER] rpc_join_room: Success - joining peer and notifying room with ", room.peers.size(), " peers")
		rpc_room_joined.rpc_id(sender, room.peers.size(), room.code)
		# notify all peers in room of updated count
		for peer_id in room.peers:
			print("[SERVER] rpc_join_room: Notifying peer ", peer_id, " of room update")
			rpc_room_updated.rpc_id(peer_id, room.peers.size(), room.starting_level)
	else:
		print("[SERVER] rpc_join_room: Failed - sending join_failed to peer ", sender)
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
	print("[SERVER] rpc_start_game: Peer ", sender, " starting game")
	var room = RoomManager.get_room_for_peer(sender)
	if room == null or room.creator != sender:
		print("[SERVER] rpc_start_game: FAILED - room null or not creator")
		return
	var success = RoomManager.start_room(room.code)
	if success:
		print("[SERVER] rpc_start_game: Starting game for ", room.peers.size(), " peers")
		for i in range(room.peers.size()):
			print("[SERVER] rpc_start_game: Sending rpc_game_starting to peer ", room.peers[i], " with player number ", i)
			rpc_game_starting.rpc_id(room.peers[i], i, room.peers.size(), room.starting_level)

@rpc("any_peer", "call_remote", "reliable")
func rpc_player_input(player_number: int, control: String, pressed: bool):
	if not is_dedicated_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	var room = RoomManager.get_room_for_peer(sender)
	if room == null or not room.started:
		return
	if control == "PAUSE":
		room.logic.paused = !room.logic.paused
		for peer_id in room.peers:
			rpc_set_paused.rpc_id(peer_id, room.logic.paused)
		return
	room.logic.do_input(player_number, control, pressed)

@rpc("authority", "call_remote", "reliable")
func rpc_set_paused(paused: bool):
	var main = get_tree().current_scene
	if main == null or not main.has_method("set_paused"):
		return
	main.set_paused(paused)

@rpc("any_peer", "call_remote", "reliable")
func rpc_leave_game():
	if not is_dedicated_server:
		print("[SERVER] rpc_leave_game called but not server, returning")
		return
	var sender = multiplayer.get_remote_sender_id()
	print("[SERVER] rpc_leave_game: Peer ", sender, " is leaving game")
	var room = RoomManager.get_room_for_peer(sender)
	print("[SERVER] rpc_leave_game: Room found: ", room != null, " Room code: ", room.code if room != null else "NONE")
	print("[SERVER] rpc_leave_game: Sending rpc_go_to_lobby only to sender peer ", sender)
	rpc_go_to_lobby.rpc_id(sender)
	if room != null:
		print("[SERVER] rpc_leave_game: Room had ", room.peers.size(), " peers")
		RoomManager.leave_room(sender)
		print("[SERVER] rpc_leave_game: After leaving, room has ", room.peers.size(), " peers")

@rpc("authority", "call_remote", "reliable")
func rpc_go_to_lobby():
	print("[CLIENT] rpc_go_to_lobby received, changing scene to Lobby")
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

# ---- SERVER -> CLIENT RPCs ----

@rpc("authority", "call_remote", "reliable")
func rpc_room_created(code: String):
	print("[CLIENT] rpc_room_created: Room created with code: ", code)
	room_created.emit(code)

@rpc("authority", "call_remote", "reliable")
func rpc_room_joined(player_count: int, code: String):
	print("[CLIENT] rpc_room_joined: Joined room ", code, " with ", player_count, " players")
	room_joined.emit(player_count, code)

@rpc("authority", "call_remote", "reliable")
func rpc_room_updated(player_count: int, level: int):
	print("[CLIENT] rpc_room_updated: Room updated - ", player_count, " players, level ", level)
	room_updated.emit(player_count, level)

@rpc("authority", "call_remote", "reliable")
func rpc_join_failed():
	connection_failed.emit()

@rpc("authority", "call_remote", "reliable")
func rpc_game_starting(player_number: int, player_count: int, level: int):
	print("[CLIENT] rpc_game_starting: I am player ", player_number, " of ", player_count, " at level ", level)
	players[multiplayer.get_unique_id()] = { "player_number": player_number }
	starting_level = level
	starting_player_number = player_number
	starting_player_count = player_count
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_state(data: PackedByteArray):
	var main = get_tree().current_scene
	if main == null or not main.has_method("rpc_sync_state"):
		return
	main.rpc_sync_state(data)

@rpc("authority", "call_remote", "reliable")
func rpc_game_over(score: int, level: int):
	print("[CLIENT] rpc_game_over received with score: ", score, " level: ", level)
	final_score = score
	final_level = level
	var main = get_tree().current_scene
	if main.has_method("trigger_game_over"):
		main.trigger_game_over(score, level)
		
