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


func _ready() -> void:
	if not UserSession.has_valid_credentials():
		push_error("No user data found!")
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.location.href = '/';")
		return
	
	setup_audio()
	setup_connections()
	setup_camera()
	setup_chat()
	
	player.set_username(UserSession.username)
	player.set_avatar_url(UserSession.avatar_url)
	var proxied_avatar = UserSession.get_proxied_avatar_url(UserSession.avatar_url)
	player.load_avatar(proxied_avatar)
	ui.set_username(UserSession.username)
	NetworkManager.connect_to_server()


func setup_audio() -> void:
	if has_node("/root/AudioManager"):
		audio_manager = get_node("/root/AudioManager")
		print("[GAME] AudioManager found and stored")


func setup_connections() -> void:
	NetworkManager.connection_success.connect(_on_connection_success)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	
	Server.barton_data_received.connect(_on_barton_data_received)
	Server.remote_player_joined.connect(_on_player_joined)
	Server.remote_player_update.connect(_on_player_update)
	Server.remote_player_left.connect(_on_player_left)
	Server.chat_message_received.connect(_on_chat_message_received)
	Server.avatar_refresh_received.connect(_on_avatar_refresh_received)
	map_manager.map_loaded.connect(_on_map_loaded)
	map_manager.transition_completed.connect(_on_transition_completed)
	
	# Connect music track changes to AudioManager
	if audio_manager and not Server.music_track_changed.is_connected(_on_music_track_changed):
		Server.music_track_changed.connect(_on_music_track_changed)
		print("[GAME] Connected music_track_changed signal to local handler")
	
	if ui:
		await get_tree().process_frame
		if ui.button_manager:
			ui.button_manager.pose_toggled.connect(_on_ui_pose_toggled)
			ui.button_manager.avatar_refresh_requested.connect(_on_avatar_refresh_requested)
		ui.chat_message_sent.connect(_on_chat_message_sent)


func setup_camera() -> void:
	camera.set_target(player)


func setup_chat() -> void:
	ui.set_chat_system(chat_system)


func _on_music_track_changed(track_name: String) -> void:
	print("[GAME] Music track change received: ", track_name)
	if audio_manager and audio_manager.has_method("_on_music_track_changed"):
		audio_manager._on_music_track_changed(track_name)
		print("[GAME] Forwarded to AudioManager")
	else:
		push_warning("[GAME] AudioManager not available or missing _on_music_track_changed method")


func _on_ui_pose_toggled(is_sitting: bool) -> void:
	player.set_kneeling(is_sitting)


func _on_avatar_refresh_requested() -> void:
	var clean_url = UserSession.avatar_url.split("?")[0]
	UserSession.avatar_url = clean_url
	var proxied_avatar = UserSession.get_proxied_avatar_url(clean_url)
	player.load_avatar(proxied_avatar)
	Server.send_avatar_refresh(clean_url)


func _on_avatar_refresh_received(peer_id: String, new_avatar_url: String) -> void:
	if remote_players.has(peer_id):
		var clean_url = new_avatar_url.split("?")[0]
		var proxied_avatar = UserSession.get_proxied_avatar_url(clean_url)
		remote_players[peer_id].load_avatar(proxied_avatar)


func _on_chat_message_sent(message: String) -> void:
	var sanitized = sanitize_chat_message(message)
	if sanitized.is_empty():
		return
	Server.send_chat_message(sanitized)


func sanitize_chat_message(message: String) -> String:
	# Strip edges but preserve emojis and unicode
	message = message.strip_edges()
	
	# Only remove BBCode brackets that could break formatting
	# Allow emojis like 🤔 and text emotes like (っ °Д °;)っ
	message = message.replace("[url", "").replace("[/url", "")
	message = message.replace("[color", "").replace("[/color", "")
	message = message.replace("[b]", "").replace("[/b]", "")
	message = message.replace("[i]", "").replace("[/i]", "")
	message = message.replace("[u]", "").replace("[/u]", "")
	
	return message


func _on_chat_message_received(peer_id: String, sender_username: String, message: String) -> void:
	ui.add_chat_message(sender_username, message)
	
	var sender_pos := Vector2.ZERO
	var local_id := NetworkManager.get_peer_id()
	var bubble_id := peer_id
	
	# Check if it's our own message
	if peer_id == local_id or sender_username == UserSession.username:
		sender_pos = player.global_position
		bubble_id = local_id if not local_id.is_empty() else UserSession.username
	elif remote_players.has(peer_id):
		sender_pos = remote_players[peer_id].global_position
		bubble_id = peer_id
	else:
		return
	
	var adjusted_pos = sender_pos + Vector2(10, 0)
	ui.show_chat_bubble(bubble_id, sender_username, message, adjusted_pos)


func _on_connection_success() -> void:
	var spawn_pos := Vector2(768, 768)
	var clean_avatar = UserSession.avatar_url.split("?")[0]
	Server.join_barton(UserSession.username, clean_avatar, map_manager.current_barton_id,
					   map_manager.current_map_id, spawn_pos)


func _on_server_disconnected() -> void:
	print("Server disconnected - clearing all remote players")
	clear_all_remote_players()
	ui.add_chat_message("System", "Connection lost. Attempting to reconnect...")


func _on_connection_failed() -> void:
	print("Connection failed")
	ui.add_chat_message("System", "Failed to connect to server")


func _on_barton_data_received(barton_data: Dictionary, start_map_id: int) -> void:
	map_manager.initialize_barton(barton_data, start_map_id)


func _on_map_loaded(_map_id: int) -> void:
	if current_objects_node:
		if is_instance_valid(current_objects_node):
			current_objects_node.queue_free()
		current_objects_node = null
	
	await get_tree().process_frame
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
	var local_id := NetworkManager.get_peer_id()
	
	# Update local player bubble position
	var local_bubble_id = local_id if not local_id.is_empty() else UserSession.username
	var adjusted_player_pos = player.global_position + Vector2(10, 0)
	ui.update_player_bubble_position(local_bubble_id, adjusted_player_pos)
	
	# Update remote player bubble positions
	for peer_id in remote_players.keys():
		var rp = remote_players[peer_id]
		if is_instance_valid(rp):
			var adjusted_remote_pos = rp.global_position + Vector2(10, 0)
			ui.update_player_bubble_position(peer_id, adjusted_remote_pos)
	
	if not Server.connected:
		return
	if ui.is_blocking_input():
		return
	
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer -= UPDATE_INTERVAL
		send_player_state()


func send_player_state() -> void:
	var state = player.get_state()
	var facing = player.get_facing()
	Server.send_player_update(player.global_position, state, facing)


func _on_player_joined(peer_id: String, player_username: String, avatar_url_remote: String,
		pos: Vector2, state: Dictionary, facing: Dictionary) -> void:
	
	if remote_players.has(peer_id):
		push_warning("Player %s already exists, removing old instance" % peer_id)
		var old_player = remote_players[peer_id]
		remote_players.erase(peer_id)
		
		if is_instance_valid(old_player):
			old_player.queue_free()
		
		await get_tree().process_frame
	
	var remote_player = RemotePlayerScene.instantiate()
	remote_player.name = "RemotePlayer_%s" % peer_id
	add_child(remote_player)
	var proxied_avatar = UserSession.get_proxied_avatar_url(avatar_url_remote)
	remote_player.initialize(peer_id, player_username, proxied_avatar, pos)
	remote_player.update_from_network(pos, state, facing)
	remote_players[peer_id] = remote_player


func _on_player_update(peer_id: String, pos: Vector2, state: Dictionary, facing: Dictionary) -> void:
	if remote_players.has(peer_id):
		remote_players[peer_id].update_from_network(pos, state, facing)


func _on_player_left(peer_id: String) -> void:
	print("Player %s left - cleaning up" % peer_id)
	if remote_players.has(peer_id):
		if is_instance_valid(remote_players[peer_id]):
			remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)
	ui.clear_player_bubbles(peer_id)
