
extends Node

const USE_PRODUCTION_SERVER = false

const PRODUCTION_URL = "wss://deaddreamers.com/ws"
const LOCAL_URL = "ws://127.0.0.1:9090"
const CONNECTION_TIMEOUT = 10.0
const MAX_RECONNECT_ATTEMPTS = 3
const RECONNECT_DELAY = 2.0

signal connection_success
signal connection_failed
signal connection_timeout
signal server_disconnected

var peer: WebSocketMultiplayerPeer = null
var connected: bool = false
var reconnect_attempts: int = 0
var connection_timer: float = 0.0
var attempting_connection: bool = false


func _ready() -> void :

	await get_tree().process_frame
	setup_multiplayer_signals()


func setup_multiplayer_signals() -> void :
	"Connect multiplayer peer signals"
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void :
	if attempting_connection:
		connection_timer += delta
		if connection_timer >= CONNECTION_TIMEOUT:
			_on_connection_timeout()


func get_server_url() -> String:
	"Get the appropriate server URL based on toggle"
	if USE_PRODUCTION_SERVER:
		return PRODUCTION_URL
	else:
		return LOCAL_URL


func connect_to_server() -> void :
	"Initiate connection to the game server"
	attempting_connection = true
	connection_timer = 0.0

	peer = WebSocketMultiplayerPeer.new()
	var server_url = get_server_url()
	print("NetworkManager: Connecting to %s" % server_url)

	var err = peer.create_client(server_url)

	if err != OK:
		push_error("NetworkManager: Failed to create client: %d" % err)
		attempting_connection = false
		attempt_reconnect()
		return

	multiplayer.multiplayer_peer = peer


func disconnect_from_server() -> void :
	"Disconnect from the server"
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	connected = false
	reset_connection()


func _on_connected_to_server() -> void :
	attempting_connection = false
	connection_timer = 0.0
	reconnect_attempts = 0
	connected = true
	connection_success.emit()
	print("NetworkManager: Connected successfully to %s" % get_server_url())


func _on_connection_failed() -> void :
	attempting_connection = false
	connection_timer = 0.0
	connected = false
	connection_failed.emit()
	attempt_reconnect()


func _on_connection_timeout() -> void :
	attempting_connection = false
	connection_timer = 0.0
	connected = false

	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null

	connection_timeout.emit()
	attempt_reconnect()


func _on_server_disconnected() -> void :
	connected = false
	server_disconnected.emit()
	attempt_reconnect()


func attempt_reconnect() -> void :
	"Attempt to reconnect with exponential backoff"
	if reconnect_attempts < MAX_RECONNECT_ATTEMPTS:
		reconnect_attempts += 1
		print("NetworkManager: Reconnect attempt %d/%d" % [reconnect_attempts, MAX_RECONNECT_ATTEMPTS])

		await get_tree().create_timer(RECONNECT_DELAY * reconnect_attempts).timeout
		connect_to_server()
	else:
		push_error("NetworkManager: Max reconnection attempts reached")


func reset_connection() -> void :
	"Reset connection state"
	reconnect_attempts = 0
	attempting_connection = false
	connection_timer = 0.0
	connected = false


func is_server_connected() -> bool:
	"Check if connected to server"
	return connected


func get_peer_id() -> int:
	"Get the current multiplayer peer ID"
	return multiplayer.get_unique_id()
