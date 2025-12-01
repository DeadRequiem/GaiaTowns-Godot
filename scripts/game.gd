#Godot Client Side
extends Node2D

const RemotePlayerScene = preload("res://scenes/RemotePlayer.tscn")

@onready var player: Node2D = $Player
@onready var camera: CameraController = $Camera2D
@onready var map_manager: Node = $MapManager
@onready var ui: CanvasLayer = $UI
@onready var chat_system: CanvasLayer = $ChatSystem

var remote_players: Dictionary = {}
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.05
var audio_manager: Node = null
var current_objects_node: Node = null
var chat_commands: Node = null


func _ready() -> void:
	var user_data = load_user_data()
	
	if not user_data:
		push_error("No user data found!")
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.location.href = '/';")
		return
	
	setup_audio()
	setup_chat_commands()
	setup_connections()
	setup_camera()
	setup_chat()
	
	player.set_username(user_data.username)
	player.set_avatar_url(user_data.avatar_url)
	var proxied_avatar = get_proxied_avatar_url(user_data.avatar_url)
	player.player_avatar.load_avatar(proxied_avatar)
	ui.set_username(user_data.username)
	Server.connect_to_server()


func setup_audio() -> void:
	if has_node("/root/AudioManager"):
		audio_manager = get_node("/root/AudioManager")
	else:
		push_warning("AudioManager autoload not found")


func setup_chat_commands() -> void:
	chat_commands = preload("res://scripts/misc/ChatCommands.gd").new()
	add_child(chat_commands)
	chat_commands.local_action.connect(_on_command_local_action)


func get_proxied_avatar_url(avatar_url: String) -> String:
	var timestamp = Time.get_unix_time_from_system()
	var separator = "&" if avatar_url.contains("?") else "?"
	var url_with_cache_buster = avatar_url + separator + "t=" + str(timestamp)
	
	if OS.has_feature("web"):
		var base_url = JavaScriptBridge.eval("window.location.origin")
		if base_url:
			return str(base_url) + "/avatar-proxy?url=" + url_with_cache_buster.uri_encode()
	
	return "http://localhost:5000/avatar-proxy?url=" + url_with_cache_buster.uri_encode()


func load_user_data() -> Dictionary:
	if not OS.has_feature("web"):
		push_error("Game must be run in browser")
		return {}
	
	var username = JavaScriptBridge.eval("window.gameUsername")
	var avatar_url = JavaScriptBridge.eval("window.gameAvatarUrl")
	
	if username == null or avatar_url == null:
		push_error("Missing user credentials from Flask")
		return {}
	
	return {
		"username": str(username),
		"avatar_url": str(avatar_url)
	}


func setup_connections() -> void:
	Server.connection_success.connect(_on_connection_success)
	Server.barton_data_received.connect(_on_barton_data_received)
	Server.remote_player_joined.connect(_on_player_joined)
	Server.remote_player_update.connect(_on_player_update)
	Server.remote_player_left.connect(_on_player_left)
	Server.chat_message_received.connect(_on_chat_message_received)
	Server.avatar_refresh_received.connect(_on_avatar_refresh_received)
	Server.admin_status_confirmed.connect(_on_admin_status_confirmed)	
	map_manager.map_loaded.connect(_on_map_loaded)
	map_manager.transition_completed.connect(_on_transition_completed)
	
	if ui:
		if ui.button_manager:
			ui.button_manager.pose_toggled.connect(_on_ui_pose_toggled)
			ui.button_manager.avatar_refresh_requested.connect(_on_avatar_refresh_requested)
		ui.chat_message_sent.connect(_on_chat_message_sent)


func setup_camera() -> void:
	camera.set_target(player)


func setup_chat() -> void:
	ui.set_chat_system(chat_system)


func _on_ui_pose_toggled(is_sitting: bool) -> void:
	player.set_kneeling(is_sitting)


func _on_avatar_refresh_requested() -> void:
	var proxied_avatar = get_proxied_avatar_url(player.avatar_url)
	player.player_avatar.load_avatar(proxied_avatar)
	Server.send_avatar_refresh(player.avatar_url)


func _on_avatar_refresh_received(peer_id: int, new_avatar_url: String) -> void:
	if remote_players.has(peer_id):
		var proxied_avatar = get_proxied_avatar_url(new_avatar_url)
		remote_players[peer_id].load_avatar(proxied_avatar)


func _on_admin_status_confirmed(is_admin: bool) -> void:
	pass

func _on_command_local_action(action_type: String, data: Dictionary) -> void:
	match action_type:
		"refresh_avatar":
			_on_avatar_refresh_requested()
		"spin":
			if player.is_kneeling:
				player.start_spin()
		"invert":
				player.toggle_invert()

func _on_chat_message_sent(message: String) -> void:
	if chat_commands and chat_commands.is_command(message):
		chat_commands.process(message)
		return
	
	var sanitized = sanitize_chat_message(message)
	if sanitized.is_empty():
		return
	Server.send_chat_message(sanitized)


func sanitize_chat_message(message: String) -> String:
	message = message.strip_edges()
	message = message.replace("[", "").replace("]", "")
	message = message.replace("&", "&amp;")
	message = message.replace("<", "&lt;")
	message = message.replace(">", "&gt;")
	return message


func _on_chat_message_received(peer_id: int, sender_username: String, message: String) -> void:
	ui.add_chat_message(sender_username, message)
	
	var sender_pos := Vector2.ZERO
	
	if peer_id == multiplayer.get_unique_id() or peer_id == -1:
		sender_pos = player.global_position
	elif remote_players.has(peer_id):
		sender_pos = remote_players[peer_id].global_position
	else:
		return
	
	ui.show_chat_bubble(peer_id, sender_username, message, sender_pos)


func _on_connection_success() -> void:
	var spawn_pos := Vector2(768, 768)
	Server.join_barton(player.username, player.avatar_url, map_manager.current_barton_id,
					   map_manager.current_map_id, spawn_pos)


func _on_barton_data_received(barton_data: Dictionary, start_map_id: int) -> void:
	map_manager.initialize_barton(barton_data, start_map_id)


func _on_map_loaded(map_id: int) -> void:
	if current_objects_node and is_instance_valid(current_objects_node):
		current_objects_node.queue_free()
		current_objects_node = null
	
	if map_manager.current_map:
		add_child(map_manager.current_map)
		
		var objects_node = map_manager.current_map.get_node_or_null("Objects")
		if objects_node:
			objects_node.reparent(self)
			current_objects_node = objects_node
	
	camera.set_map_bounds(map_manager.map_width, map_manager.map_height)
	
	if player.global_position == Vector2.ZERO:
		player.global_position = map_manager.get_spawn_position_for_map()
	
	ui.update_location_display(map_manager.current_map_id, map_manager.current_barton_id)


func _on_transition_completed(map_id: int) -> void:
	clear_all_remote_players()
	var spawn_pos := player.global_position
	Server.change_map(map_id, spawn_pos)


func clear_all_remote_players() -> void:
	for peer_id in remote_players.keys():
		if is_instance_valid(remote_players[peer_id]):
			remote_players[peer_id].queue_free()
	
	remote_players.clear()
	chat_system.clear_all_bubbles()


func _process(delta: float) -> void:
	var local_id := multiplayer.get_unique_id()
	ui.update_player_bubble_position(local_id, player.global_position)
	
	for peer_id in remote_players.keys():
		var rp = remote_players[peer_id]
		if is_instance_valid(rp):
			ui.update_player_bubble_position(peer_id, rp.global_position)
	
	if not Server.connected:
		return
	
	if ui.is_blocking_input():
		return
	
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer -= UPDATE_INTERVAL
		send_player_state()


func send_player_state() -> void:
	var state := {
		"is_moving": player.is_walking,
		"in_water": false,
		"is_kneeling": player.is_kneeling
	}
	
	var facing := {
		"direction": player.face,
		"facing_lr": player.facing_lr
	}
	
	Server.send_player_update(player.global_position, state, facing)


func _on_player_joined(peer_id: int, player_username: String, avatar_url_remote: String,
		position: Vector2, state: Dictionary, facing: Dictionary) -> void:
	
	if remote_players.has(peer_id):
		push_warning("Player %d already exists, removing old instance" % peer_id)
		remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)
	
	var remote_player = RemotePlayerScene.instantiate()
	remote_player.name = "RemotePlayer_%d" % peer_id
	add_child(remote_player)
	
	var proxied_avatar = get_proxied_avatar_url(avatar_url_remote)
	remote_player.initialize(peer_id, player_username, proxied_avatar, position)
	remote_player.update_from_network(position, state, facing)
	
	remote_players[peer_id] = remote_player


func _on_player_update(peer_id: int, position: Vector2, state: Dictionary, facing: Dictionary) -> void:
	if remote_players.has(peer_id):
		var remote_player = remote_players[peer_id]
		remote_player.update_from_network(position, state, facing)


func _on_player_left(peer_id: int) -> void:
	if remote_players.has(peer_id):
		remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)
	ui.clear_player_bubbles(peer_id)
