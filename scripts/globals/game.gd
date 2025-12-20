extends Node2D

const RemotePlayerScene = preload("res://scenes/RemotePlayer.tscn")

@onready var player: Node2D = $Player
@onready var camera: CameraController = $Camera2D
@onready var map_manager: Node = $MapManager
@onready var ui: CanvasLayer = $UI
@onready var world_chat_manager: Node = $WorldChatManager

var remote_players: Dictionary = {}
var update_timer: float = 0.0
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
	Server.player_pickup_received.connect(_on_player_pickup)
	Server.player_thrown_received.connect(_on_player_thrown)
	Server.player_dropped_received.connect(_on_player_dropped)
	Server.command_response_received.connect(_on_command_response)

	map_manager.map_loaded.connect(_on_map_loaded)
	map_manager.transition_completed.connect(_on_transition_completed)

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
	
	# Check byte size using Config constant
	if sanitized.to_utf8_buffer().size() > Config.MAX_MESSAGE_SIZE:
		ui.add_chat_message("System", "Message too long!")
		return
	
	Server.send_chat_message(sanitized)


func sanitize_chat_message(message: String) -> String:
	message = message.strip_edges()
	
	# Basic BBCode sanitization - allow some tags but strip potentially dangerous ones
	var dangerous_tags = ["url", "color", "b", "i", "u", "code", "table", "cell"]
	for tag in dangerous_tags:
		message = message.replace("[" + tag, "")
		message = message.replace("[/" + tag, "")
	
	return message


func _on_chat_message_received(peer_id: String, sender_username: String, message: String) -> void:
	ui.add_chat_message(sender_username, message)
	var local_id = NetworkManager.get_peer_id()

	if peer_id == local_id or sender_username == UserSession.username:
		var bubble_id = local_id if not local_id.is_empty() else UserSession.username
		world_chat_manager.show_chat_bubble(player, bubble_id, sender_username, message)
	elif remote_players.has(peer_id):
		world_chat_manager.show_chat_bubble(remote_players[peer_id], peer_id, sender_username, message)


func _on_connection_success() -> void:
	var spawn_pos = Vector2(768, 768)
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
	# Wait a frame for role message to arrive
	await get_tree().create_timer(0.1).timeout
	# Update our username color
	player.set_username(UserSession.username, UserSession.username_color)


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
	var spawn_pos = player.global_position
	Server.change_map(map_id, spawn_pos)


func clear_all_remote_players() -> void:
	for peer_id in remote_players.keys():
		if is_instance_valid(remote_players[peer_id]):
			remote_players[peer_id].queue_free()
	remote_players.clear()
	world_chat_manager.clear_all_bubbles()


func _process(delta: float) -> void:
	if not Server.connected:
		return

	update_timer += delta
	if update_timer >= Config.UPDATE_INTERVAL:
		update_timer -= Config.UPDATE_INTERVAL
		send_player_state()


func send_player_state() -> void:
	if player.is_being_carried or player.is_thrown:
		return
	var state = player.get_state()
	var facing = player.get_facing()
	Server.send_player_update(player.global_position, state, facing)


func _on_player_joined(peer_id: String, player_username: String, avatar_url_remote: String,
		pos: Vector2, state: Dictionary, facing: Dictionary, username_color: String) -> void:

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
	remote_player.initialize(peer_id, player_username, proxied_avatar, pos, username_color)
	remote_player.update_from_network(pos, state, facing)
	remote_players[peer_id] = remote_player


func _on_player_pickup(carrier_peer_id: String, carried_peer_id: String) -> void:
	var local_id = NetworkManager.get_peer_id()

	if carrier_peer_id == local_id:
		# We're the carrier
		if remote_players.has(carried_peer_id):
			player.set_carrying_someone(true, carried_peer_id)
			remote_players[carried_peer_id].set_carrier_node(player)
			remote_players[carried_peer_id].is_being_carried = true
			remote_players[carried_peer_id].global_position = player.global_position + Config.CARRY_OFFSET
			remote_players[carried_peer_id].target_position = remote_players[carried_peer_id].global_position
			print("[GAME] We picked up: ", remote_players[carried_peer_id].username)

	elif carried_peer_id == local_id:
		# We're being carried
		player.set_being_carried(true, carrier_peer_id)
		if remote_players.has(carrier_peer_id):
			player.set_carrier_node(remote_players[carrier_peer_id])
			player.global_position = remote_players[carrier_peer_id].global_position + Config.CARRY_OFFSET
		print("[GAME] We are being carried!")
		ui.add_chat_message("System", "You are being carried!")

	else:
		# Two other players involved
		if remote_players.has(carrier_peer_id):
			remote_players[carrier_peer_id].is_carrying_someone = true
		
		if remote_players.has(carried_peer_id):
			remote_players[carried_peer_id].is_being_carried = true
			if remote_players.has(carrier_peer_id):
				remote_players[carried_peer_id].set_carrier_node(remote_players[carrier_peer_id])


func _on_player_thrown(thrower_peer_id: String, thrown_peer_id: String, new_x: float, new_y: float) -> void:
	var local_id = NetworkManager.get_peer_id()

	if thrower_peer_id == local_id:
		player.set_carrying_someone(false, "")

	if thrown_peer_id == local_id:
		player.set_being_carried(false, "")
		player.set_carrier_node(null)
		player.set_thrown(Vector2(new_x, new_y))

	if remote_players.has(thrower_peer_id):
		remote_players[thrower_peer_id].is_carrying_someone = false

	if remote_players.has(thrown_peer_id):
		remote_players[thrown_peer_id].is_being_carried = false
		remote_players[thrown_peer_id].set_carrier_node(null)
		remote_players[thrown_peer_id].set_thrown(Vector2(new_x, new_y))


func _on_player_dropped(carrier_peer_id: String, dropped_peer_id: String, new_x: float, new_y: float) -> void:
	var local_id = NetworkManager.get_peer_id()

	if carrier_peer_id == local_id:
		player.set_carrying_someone(false, "")

	if dropped_peer_id == local_id:
		player.set_being_carried(false, "")
		player.set_carrier_node(null)
		player.global_position = Vector2(new_x, new_y)

	if remote_players.has(carrier_peer_id):
		remote_players[carrier_peer_id].is_carrying_someone = false

	if remote_players.has(dropped_peer_id):
		remote_players[dropped_peer_id].is_being_carried = false
		remote_players[dropped_peer_id].set_carrier_node(null)
		remote_players[dropped_peer_id].global_position = Vector2(new_x, new_y)
		remote_players[dropped_peer_id].target_position = Vector2(new_x, new_y)


func _on_command_response(message: String, is_error: bool) -> void:
	var prefix = "[ERROR] " if is_error else "[SYSTEM] "
	ui.add_chat_message("System", prefix + message)


func _on_player_update(peer_id: String, pos: Vector2, state: Dictionary, facing: Dictionary) -> void:
	var local_id = NetworkManager.get_peer_id()
	
	if peer_id == local_id:
		if player.is_being_carried:
			return
		return
	
	if remote_players.has(peer_id):
		remote_players[peer_id].update_from_network(pos, state, facing)


func _on_player_left(peer_id: String) -> void:
	if player.is_being_carried and player.carried_by_peer_id == peer_id:
		player.set_being_carried(false, "")
		player.set_carrier_node(null)
		ui.add_chat_message("System", "You were dropped because your carrier left!")
	if player.is_carrying_someone and player.carrying_peer_id == peer_id:
		player.set_carrying_someone(false, "")
	if remote_players.has(peer_id):
		if is_instance_valid(remote_players[peer_id]):
			remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)
	world_chat_manager.clear_player_bubble(peer_id)
