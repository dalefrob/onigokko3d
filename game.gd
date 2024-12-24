extends Node3D
class_name Game

@export var player_scene : PackedScene
@onready var player_nodes : Node = $Players
@onready var spawner := $MultiplayerSpawner
@onready var timer := $Timer
@onready var hud = $HUD

# Server only varaibles
var sv_stopped = true
# Game variables
var demon_id = 0 # Peer that is the demon
var spawn_points : Array[Node]
var spawn_point_index = 0

func _ready() -> void:
	spawn_points = get_tree().get_nodes_in_group("spawnpoint")
	spawner.spawn_function = spawn_player
	
	Network.player_connected.connect(on_player_connected)
	Network.player_disconnected.connect(on_player_disconnected)


# Callback from Network when a player is fully registered
func on_player_connected(peer_id, player_info):
	if multiplayer.is_server():
		call_deferred("add_player", peer_id)


# Callback from Network when a player is unregistered and is gone
func on_player_disconnected(peer_id):
	if multiplayer.is_server():
		call_deferred("remove_player", peer_id)


# Called from server to add a player, which then spawns it in via the replicator
func add_player(id):
	var new_player = spawner.spawn(
		{
			"id": id,
			"pos": get_spawn_point(),
			"info": Network.players[id]
		}
	)
	
	# Start the game if there are enough players
	if multiplayer.get_peers().size() > 1 and sv_stopped:
		sv_stopped = false
		begin_round.rpc()


func get_spawn_point() -> Vector3:
	if spawn_point_index >= spawn_points.size():
		spawn_point_index = 0
	var point = spawn_points[spawn_point_index].position
	spawn_point_index += 1
	return point


func spawn_player(data : Dictionary):
	var player = player_scene.instantiate() as Player
	player.set_multiplayer_authority(data.id, true)
	player.peer_id = data.id
	player.name = str(data.id)
	player.position = data.pos
	player._player_info = data.info
	return player


func remove_player(id):
	var player = player_nodes.get_node_or_null(str(id))
	if player:
		player.queue_free()


@rpc("authority", "call_local", "reliable")
func end_round():
	hud.show_message("Round Ended!")
	if multiplayer.is_server():
		
		await get_tree().create_timer(10).timeout
		if multiplayer.get_peers().size() > 1:
			begin_round.rpc()
		else:
			hud.show_message("Not enough players.")
			sv_stopped = true


@rpc("authority", "call_local", "reliable")
func begin_round():
	hud.show()
	hud.show_message("Round started!")
	
	if multiplayer.is_server():
		demon_id = Network.players.keys().pick_random()
		sync_make_demon.rpc(demon_id)
		
	timer.start(60)


@rpc("authority", "call_local", "reliable")
func sync_teleport_player(id, pos):
	var player = player_nodes.get_node_or_null(str(id))
	if player:
		player.global_position = pos


@rpc("authority", "call_local", "reliable")
func sync_make_demon(new_id):
	# De-demonify the current demon
	if demon_id > 0:
		var old_demon = player_nodes.get_node(str(demon_id))
		old_demon.demon = false
		old_demon.tag_immune = true
	# Set the new demon
	var new_demon = player_nodes.get_node(str(new_id))
	if new_demon:
		demon_id = new_id
		new_demon.demon = true
		# Check to get demon name
		var demon_name = "Someone"
		var demon_color = Color.WHITE
		if Network.players.has(demon_id):
			demon_name = Network.players[demon_id].name
			demon_color = Network.players[demon_id].color
			
		print("%s became the Demon!" % demon_id)
		hud.show_message("[color=%s]%s[/color] is the DEMON!" % [demon_color.to_html(false),demon_name])


@rpc("any_peer", "call_remote", "reliable")
func on_demon_touched_player(other_peer_id):
	if multiplayer.is_server():
		sync_make_demon.rpc(other_peer_id)


func _on_multiplayer_spawner_despawned(node: Node) -> void:
	# When demon quits, make a new demon
	if multiplayer.is_server() and node.demon:
		var new_demon_id = Network.players.keys().pick_random()
		sync_make_demon.rpc(new_demon_id)


func _on_timer_timeout() -> void:
	if multiplayer.is_server():
		end_round.rpc()


func _on_multiplayer_spawner_spawned(node: Node) -> void:
	# Set the player colors and names
	var player = node as Player
	if Network.players.has(player.peer_id):
		player._player_info = Network.players[player.peer_id]
