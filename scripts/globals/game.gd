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
	player.player_avatar.load_avatar(proxied_avatar)
	ui.set_username(UserSession.username)
	NetworkManager.connect_to_server()


func setup_audio() -> void:
	if has_node("/root/AudioManager"):
		audio_manager = get_node("/root/AudioManager")

func setup_connections() -> void:
	NetworkManager.connection_success.connect(_on_connection_success)
	Server.barton_data_received.connect(_on_barton_data_received)
	Server.remote_player_joined.connect(_on_player_joined)
	Server.remote_player_update.connect(_on_player_update)
	Server.remote_player_left.connect(_on_player_left)
	Server.chat_message_received.connect(_on_chat_message_received)
	Server.avatar_refresh_received.connect(_on_avatar_refresh_received)
	map_manager.map_loaded.connect(_on_map_loaded)
	map_manager.transition_completed.connect(_on_transition_completed)
	
	if ui:
		if ui.button_manager:
			ui.button_manager.pose_toggled.connect(_on_ui_pose_toggled)
			ui.button_manager.avatar_refresh_requested.connect(_on_avatar_refresh_requested)
		ui.chat_message_sent.connect(_on_chat_message_sent)
	
	if audio_manager:
		Server.music_track_changed.connect(audio_manager._on_music_track_changed)


func setup_camera() -> void:
	camera.set_target(player)
func setup_chat() -> void:
	ui.set_chat_system(chat_system)

# UI callbacks
func _on_ui_pose_toggled(is_sitting: bool) -> void:
	player.set_kneeling(is_sitting)

func _on_avatar_refresh_requested() -> void:
	var proxied_avatar = UserSession.get_proxied_avatar_url(player.avatar_url)
	player.player_avatar.load_avatar(proxied_avatar)
	Server.send_avatar_refresh(player.avatar_url)

func _on_avatar_refresh_received(peer_id: int, new_avatar_url: String) -> void:
	if remote_players.has(peer_id):
		var proxied_avatar = UserSession.get_proxied_avatar_url(new_avatar_url)
		remote_players[peer_id].load_avatar(proxied_avatar)

func _on_chat_message_sent(message: String) -> void:
	var sanitized = sanitize_chat_message(message)
	if sanitized.is_empty():
		return
	Server.send_chat_message(sanitized)

func sanitize_chat_message(message: String) -> String:
	"""Sanitize chat message - HTML escape FIRST, then remove BBCode"""
	message = message.strip_edges()
	message = message.replace("&", "&amp;")
	message = message.replace("<", "&lt;")
	message = message.replace(">", "&gt;")
	message = message.replace('"', "&quot;")
	message = message.replace("'", "&#39;")
	message = message.replace("[", "").replace("]", "")
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

# Connection callbacks
func _on_connection_success() -> void:
	var spawn_pos := Vector2(768, 768)
	Server.join_barton(UserSession.username, UserSession.avatar_url, map_manager.current_barton_id,
					   map_manager.current_map_id, spawn_pos)

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


# Main loop
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
	var state = player.get_state()
	var facing = player.get_facing()
	Server.send_player_update(player.global_position, state, facing)


# Mp Callbacks
func _on_player_joined(peer_id: int, player_username: String, avatar_url_remote: String,
		pos: Vector2, state: Dictionary, facing: Dictionary) -> void:

	if remote_players.has(peer_id):
		push_warning("Player %d already exists, removing old instance" % peer_id)
		var old_player = remote_players[peer_id]
		remote_players.erase(peer_id)
		
		if is_instance_valid(old_player):
			old_player.queue_free()

		await get_tree().process_frame

	var remote_player = RemotePlayerScene.instantiate()
	remote_player.name = "RemotePlayer_%d" % peer_id
	add_child(remote_player)
	var proxied_avatar = UserSession.get_proxied_avatar_url(avatar_url_remote)
	remote_player.initialize(peer_id, player_username, proxied_avatar, pos)
	remote_player.update_from_network(pos, state, facing)
	remote_players[peer_id] = remote_player


func _on_player_update(peer_id: int, pos: Vector2, state: Dictionary, facing: Dictionary) -> void:
	if remote_players.has(peer_id):
		remote_players[peer_id].update_from_network(pos, state, facing)

func _on_player_left(peer_id: int) -> void:
	if remote_players.has(peer_id):
		remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)
	ui.clear_player_bubbles(peer_id)
