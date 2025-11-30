# Godot Client Side Singleton
extends Node

const SERVER_URL = "ws://127.0.0.1:9090"
const CONNECTION_TIMEOUT = 10.0
const MAX_RECONNECT_ATTEMPTS = 3
const RECONNECT_DELAY = 2.0

var peer = WebSocketMultiplayerPeer.new()
var connected = false
var reconnect_attempts = 0
var connection_timer = 0.0
var attempting_connection = false

# User credentials from web page
var username: String = ""
var avatar_url: String = ""

signal connection_success
signal barton_data_received(barton_data, current_map_id)
signal remote_player_joined(peer_id, username, avatar_url, position, state, facing)
signal remote_player_update(peer_id, position, state, facing)
signal remote_player_left(peer_id)
signal chat_message_received(peer_id, username, message)


func _ready():
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Load credentials from JavaScript
	load_credentials_from_web()


func load_credentials_from_web():
	"""Load username and avatar URL from the web page JavaScript"""
	if OS.has_feature("web"):
		# Access JavaScript window variables
		var js_code = """
		(function() {
			return {
				username: window.gameUsername || '',
				avatar_url: window.gameAvatarUrl || ''
			};
		})();
		"""
		var result = JavaScriptBridge.eval(js_code)
		
		if result and typeof(result) == TYPE_DICTIONARY:
			username = result.get("username", "")
			avatar_url = result.get("avatar_url", "")
			
			print("Loaded credentials from web:")
			print("  Username: ", username)
			print("  Avatar URL: ", avatar_url)
			
			if username.is_empty() or avatar_url.is_empty():
				push_error("Failed to load credentials from web page!")
		else:
			push_error("Failed to get credentials from JavaScript")
	else:
		# For testing in editor
		username = "TestUser"
		avatar_url = "https://via.placeholder.com/64"
		print("Running in editor - using test credentials")


func _process(delta: float) -> void:
	if attempting_connection:
		connection_timer += delta
		if connection_timer >= CONNECTION_TIMEOUT:
			_on_connection_timeout()


func connect_to_server():
	attempting_connection = true
	connection_timer = 0.0
	
	var err = peer.create_client(SERVER_URL)
	if err != OK:
		push_error("Failed to create client: %d" % err)
		attempting_connection = false
		attempt_reconnect()
		return
	
	multiplayer.multiplayer_peer = peer
	print("Attempting connection to server...")


func _on_connected_to_server():
	attempting_connection = false
	connection_timer = 0.0
	reconnect_attempts = 0
	connected = true
	print("Connected to server successfully")
	connection_success.emit()


func _on_connection_failed():
	attempting_connection = false
	connection_timer = 0.0
	connected = false
	attempt_reconnect()


func _on_connection_timeout():
	attempting_connection = false
	connection_timer = 0.0
	connected = false
	
	# Clean up the peer
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	
	attempt_reconnect()


func _on_server_disconnected():
	connected = false
	attempt_reconnect()


func attempt_reconnect():
	if reconnect_attempts < MAX_RECONNECT_ATTEMPTS:
		reconnect_attempts += 1
		await get_tree().create_timer(RECONNECT_DELAY).timeout
		
		# Create new peer for reconnection
		peer = WebSocketMultiplayerPeer.new()
		connect_to_server()


func reset_connection():
	"""Manually reset connection state for fresh reconnect attempt"""
	reconnect_attempts = 0
	attempting_connection = false
	connection_timer = 0.0
	connected = false


func join_barton(username: String, avatar_url: String, barton_id: int, map_id: int, position: Vector2):
	if not connected:
		push_warning("Cannot join barton: not connected to server")
		return
	_join_barton.rpc_id(1, username, avatar_url, barton_id, map_id, position)


func change_map(map_id: int, position: Vector2):
	if not connected:
		push_warning("Cannot change map: not connected to server")
		return
	_change_map.rpc_id(1, map_id, position)


func send_player_update(position: Vector2, state: Dictionary, facing: Dictionary):
	if not connected:
		return
	_update_player.rpc_id(1, position, state, facing)


func send_chat_message(message: String):
	if not connected:
		push_warning("Cannot send chat: not connected to server")
		return
	_send_chat_message.rpc_id(1, message)


@rpc("authority", "reliable")
func _send_barton_data(barton_data: Dictionary, current_map_id: int):
	barton_data_received.emit(barton_data, current_map_id)


@rpc("authority", "reliable")
func _player_joined(peer_id: int, username: String, avatar_url: String,
				   position: Vector2, state: Dictionary, facing: Dictionary):
	remote_player_joined.emit(peer_id, username, avatar_url, position, state, facing)


@rpc("authority", "unreliable")
func _player_update(peer_id: int, position: Vector2, state: Dictionary, facing: Dictionary):
	remote_player_update.emit(peer_id, position, state, facing)


@rpc("authority", "reliable")
func _player_left(peer_id: int):
	remote_player_left.emit(peer_id)


@rpc("authority", "reliable")
func _receive_chat_message(peer_id: int, username: String, message: String):
	chat_message_received.emit(peer_id, username, message)


@rpc("any_peer", "reliable")
func _join_barton(username: String, avatar_url: String, barton_id: int, map_id: int, position: Vector2):
	pass


@rpc("any_peer", "reliable")
func _change_map(map_id: int, position: Vector2):
	pass


@rpc("any_peer", "unreliable") 
func _update_player(position: Vector2, state: Dictionary, facing: Dictionary):
	pass


@rpc("any_peer", "reliable")
func _send_chat_message(message: String):
	pass
