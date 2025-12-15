extends Node

const USE_PRODUCTION_SERVER = false

const PRODUCTION_URL = "wss://deaddreamers.com/ws"
const LOCAL_URL = "ws://127.0.0.1:9090"
const CONNECTION_TIMEOUT = 10.0
const MAX_RECONNECT_ATTEMPTS = 3
const RECONNECT_DELAY = 2.0
const PING_INTERVAL = 30.0  # Send ping every 30 seconds
const PING_TIMEOUT = 60.0   # Consider disconnected if no pong in 60 seconds

signal connection_success
signal connection_failed
signal connection_timeout
signal server_disconnected
signal message_received(message: Dictionary)

var ws_peer: WebSocketPeer = null
var connected: bool = false
var reconnect_attempts: int = 0
var connection_timer: float = 0.0
var attempting_connection: bool = false
var my_peer_id: String = ""

# Ping/Pong tracking
var last_ping_sent: float = 0.0
var last_pong_received: float = 0.0
var ping_timer: float = 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	# Handle connection timeout
	if attempting_connection:
		connection_timer += delta
		if connection_timer >= CONNECTION_TIMEOUT:
			_on_connection_timeout()
	
	# Poll WebSocket
	if ws_peer:
		ws_peer.poll()
		var state = ws_peer.get_ready_state()
		
		match state:
			WebSocketPeer.STATE_OPEN:
				if not connected:
					_on_connected_to_server()
				
				# Handle ping/pong keepalive
				ping_timer += delta
				if ping_timer >= PING_INTERVAL:
					ping_timer = 0.0
					_send_ping()
				
				# Don't check for ping timeout - let server handle it
				
				# Read incoming messages
				while ws_peer.get_available_packet_count() > 0:
					var packet = ws_peer.get_packet()
					var json_string = packet.get_string_from_utf8()
					_handle_message(json_string)
			
			WebSocketPeer.STATE_CLOSING:
				pass
			
			WebSocketPeer.STATE_CLOSED:
				if connected:
					_on_server_disconnected()
				connected = false


func get_server_url() -> String:
	return PRODUCTION_URL if USE_PRODUCTION_SERVER else LOCAL_URL


func connect_to_server() -> void:
	attempting_connection = true
	connection_timer = 0.0
	ping_timer = 0.0
	last_pong_received = Time.get_ticks_msec() / 1000.0
	
	ws_peer = WebSocketPeer.new()
	var server_url = get_server_url()
	print("NetworkManager: Connecting to %s" % server_url)
	
	var err = ws_peer.connect_to_url(server_url)
	
	if err != OK:
		push_error("NetworkManager: Failed to connect: %d" % err)
		attempting_connection = false
		attempt_reconnect()


func disconnect_from_server() -> void:
	if ws_peer:
		ws_peer.close()
		ws_peer = null
	connected = false
	my_peer_id = ""
	reset_connection()


func _force_disconnect() -> void:
	"""Force disconnect and trigger reconnection"""
	print("[NetworkManager] Force disconnecting due to timeout")
	if ws_peer:
		ws_peer.close()
	connected = false
	_on_server_disconnected()


func send_message(message: Dictionary) -> void:
	if not connected or not ws_peer:
		push_warning("Cannot send message - not connected")
		return
	
	var json_string = JSON.stringify(message)
	var err = ws_peer.send_text(json_string)
	
	if err != OK:
		push_error("Failed to send message: %d" % err)


func _send_ping() -> void:
	"""Send keepalive ping to server"""
	if not connected or not ws_peer:
		return
	
	last_ping_sent = Time.get_ticks_msec() / 1000.0
	
	# Send a lightweight ping message
	var ping_msg = {
		"type": "ping",
		"timestamp": last_ping_sent
	}
	
	var json_string = JSON.stringify(ping_msg)
	ws_peer.send_text(json_string)


func _handle_message(json_string: String) -> void:
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse JSON: %s" % json_string)
		return
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Message is not a dictionary")
		return
	
	# Handle pong response
	if data.has("type") and data["type"] == "pong":
		last_pong_received = Time.get_ticks_msec() / 1000.0
		return
	
	message_received.emit(data)


func _on_connected_to_server() -> void:
	attempting_connection = false
	connection_timer = 0.0
	reconnect_attempts = 0
	connected = true
	last_pong_received = Time.get_ticks_msec() / 1000.0
	connection_success.emit()
	print("NetworkManager: Connected successfully to %s" % get_server_url())


func _on_connection_timeout() -> void:
	attempting_connection = false
	connection_timer = 0.0
	connected = false
	
	if ws_peer:
		ws_peer.close()
		ws_peer = null
	
	connection_timeout.emit()
	attempt_reconnect()


func _on_server_disconnected() -> void:
	connected = false
	my_peer_id = ""
	server_disconnected.emit()
	attempt_reconnect()


func attempt_reconnect() -> void:
	if reconnect_attempts < MAX_RECONNECT_ATTEMPTS:
		reconnect_attempts += 1
		print("NetworkManager: Reconnect attempt %d/%d" % [reconnect_attempts, MAX_RECONNECT_ATTEMPTS])
		
		await get_tree().create_timer(RECONNECT_DELAY * reconnect_attempts).timeout
		connect_to_server()
	else:
		push_error("NetworkManager: Max reconnection attempts reached")
		connection_failed.emit()


func reset_connection() -> void:
	reconnect_attempts = 0
	attempting_connection = false
	connection_timer = 0.0
	connected = false
	my_peer_id = ""
	ping_timer = 0.0
	last_ping_sent = 0.0
	last_pong_received = 0.0


func is_server_connected() -> bool:
	return connected


func get_peer_id() -> String:
	return my_peer_id


func set_peer_id(peer_id: String) -> void:
	my_peer_id = peer_id
	print("NetworkManager: Assigned peer ID: %s" % peer_id)
