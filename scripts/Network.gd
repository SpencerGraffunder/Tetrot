extends Node

const PORT = 7777
const MAX_PLAYERS = 8

var players = {}
var starting_level = 0
var final_score: int = 0
var final_level: int = 0
var my_player_number: int = 0

signal player_connected(id)
signal player_disconnected(id)
signal connection_failed
signal connection_succeeded

func get_player_number() -> int:
	return my_player_number

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func host_game():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	# Add host (server) as player 0
	var my_id = multiplayer.get_unique_id()
	players[my_id] = { "id": my_id, "player_number": 0 }
	print("Hosting on port ", PORT)

func join_game(address: String):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = peer
	print("Joining ", address, ":", PORT)

func _on_peer_connected(id):
	if players.size() == MAX_PLAYERS:
		return;
	if not multiplayer.is_server():
		return  # clients don't need to track this
	var player_number = players.size()
	players[id] = { "id": id, "player_number": player_number }
	print("Added player ", player_number, " with id ", id)
	assign_player_number.rpc_id(id, player_number)
	player_connected.emit(id)

@rpc("authority", "call_remote")
func assign_player_number(number: int):
	my_player_number = number

func _on_peer_disconnected(id):
	print("Peer disconnected: ", id)
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server():
	print("Connected!")
	connection_succeeded.emit()

func _on_connection_failed():
	print("Connection failed.")
	connection_failed.emit()

@rpc("authority", "call_local", "reliable")
func start_game():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	
