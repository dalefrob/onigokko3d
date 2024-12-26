extends Node
# Autoload named Lobby

# These signals can be connected to by a UI lobby scene or the game scene.
signal server_created
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS = 20

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players = {}

# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
# For example, the value of "name" can be set to something the player
# entered in a UI scene.
var player_info = {
	"name": "Name",
	"color": Color.WHITE.to_rgba32()
}

var players_loaded = 0

var server_info = {
	"map": "res://game.tscn"
}


func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		return error
	
	multiplayer.multiplayer_peer = peer
	DisplayServer.window_set_title("Client (%s)" % multiplayer.get_unique_id())


func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	DisplayServer.window_set_title("Server (1)")
	
	server_created.emit()
	# players[1] = player_info
	# player_connected.emit(1, player_info) NOTE Why emit when no players are connected yet?


# NOTE This was in the template, why is this necessary?
func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null


# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_peer_connected(id):
	_register_player.rpc_id(id, player_info)
	print("%s -- %s (%s) connected" % [multiplayer.get_unique_id(), player_info.name, id])


@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info # Add player to the register
	# A new player was just registered - let other parts of the game know
	player_connected.emit(new_player_id, new_player_info)


func _on_peer_disconnected(id):
	print("%s disconnected: %s" % [players[id].name, id])
	players.erase(id)
	player_disconnected.emit(id)


# On connected to server
func _on_connected_ok():
	# Register my own player
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)


# On couldn't connect to server
func _on_connected_fail():
	multiplayer.multiplayer_peer = null


func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
