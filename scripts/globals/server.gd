extends Node

signal connection_success
signal barton_data_received(barton_data, current_map_id)
signal remote_player_joined(peer_id, username, avatar_url, position, state, facing)
signal remote_player_update(peer_id, position, state, facing)
signal remote_player_left(peer_id)
signal chat_message_received(peer_id, username, message)
signal music_track_changed(track_name)
signal avatar_refresh_received(peer_id, avatar_url)
signal admin_status_confirmed(is_admin)

var connected: bool:
	get:
		return NetworkManager.is_server_connected() if NetworkManager else false


func _ready():
	await get_tree().process_frame
	if NetworkManager:
		NetworkManager.connection_success.connect(_on_connection_success)
		NetworkManager.message_received.connect(_on_message_received)


func _on_connection_success():
	connection_success.emit()


func _on_message_received(data: Dictionary):
	if not data.has("type"):
		push_warning("Message missing 'type' field")
		return
	
	var msg_type = data["type"]
	
	match msg_type:
		"peer_id_assigned":
			_handle_peer_id_assigned(data)
		"barton_data":
			_handle_barton_data(data)
		"player_joined":
			_handle_player_joined(data)
		"player_update":
			_handle_player_update(data)
		"player_left":
			_handle_player_left(data)
		"chat_message":
			_handle_chat_message(data)
		"avatar_refreshed":
			_handle_avatar_refreshed(data)
		"music_track_changed":
			_handle_music_track_changed(data)
		"admin_status":
			_handle_admin_status(data)
		"error":
			_handle_error(data)
		_:
			print("Unknown message type: ", msg_type)


func _handle_peer_id_assigned(data: Dictionary):
	var peer_id = data.get("peer_id", "")
	if NetworkManager:
		NetworkManager.set_peer_id(peer_id)
	print("[SERVER] Assigned peer ID: ", peer_id)


func _handle_barton_data(data: Dictionary):
	var barton_id = data.get("barton_id", 1000)
	var current_map_id = data.get("current_map_id", 5)
	var grid = data.get("grid", [])
	
	var barton_data = {
		"barton_id": barton_id,
		"grid": grid
	}
	
	barton_data_received.emit(barton_data, current_map_id)


func _handle_player_joined(data: Dictionary):
	var peer_id = data.get("peer_id", "")
	var username = data.get("username", "Player")
	var avatar_url = data.get("avatar_url", "")
	var pos = Vector2(
		data.get("position_x", 768.0),
		data.get("position_y", 768.0)
	)
	var state = data.get("state", {})
	var facing = data.get("facing", {})
	
	remote_player_joined.emit(peer_id, username, avatar_url, pos, state, facing)


func _handle_player_update(data: Dictionary):
	var peer_id = data.get("peer_id", "")
	var pos = Vector2(
		data.get("position_x", 0.0),
		data.get("position_y", 0.0)
	)
	var state = data.get("state", {})
	var facing = data.get("facing", {})
	
	remote_player_update.emit(peer_id, pos, state, facing)


func _handle_player_left(data: Dictionary):
	var peer_id = data.get("peer_id", "")
	remote_player_left.emit(peer_id)


func _handle_chat_message(data: Dictionary):
	var peer_id = data.get("peer_id", "")
	var username = data.get("username", "Player")
	var message = data.get("message", "")
	
	chat_message_received.emit(peer_id, username, message)


func _handle_avatar_refreshed(data: Dictionary):
	var peer_id = data.get("peer_id", "")
	var avatar_url = data.get("avatar_url", "")
	
	avatar_refresh_received.emit(peer_id, avatar_url)


func _handle_music_track_changed(data: Dictionary):
	var track_name = data.get("track_name", "default")
	music_track_changed.emit(track_name)


func _handle_admin_status(data: Dictionary):
	var is_admin = data.get("is_admin", false)
	if UserSession:
		UserSession.set_admin_status(is_admin)
	admin_status_confirmed.emit(is_admin)


func _handle_error(data: Dictionary):
	var error_message = data.get("message", "Unknown error")
	push_error("[SERVER ERROR] " + error_message)
	print("[SERVER ERROR] " + error_message)


# Client -> Server messages

func connect_to_server():
	if NetworkManager:
		NetworkManager.connect_to_server()


func join_barton(username: String, avatar_url: String, barton_id: int, map_id: int, position: Vector2):
	print("[DEBUG] Sending join_barton with username: ", username, " keycode: ", UserSession.keycode if UserSession else "(no UserSession)")
	
	var message = {
		"type": "join_barton",
		"username": username,
		"avatar_url": avatar_url,
		"keycode": UserSession.keycode if UserSession else "",
		"barton_id": barton_id,
		"map_id": map_id,
		"position_x": position.x,
		"position_y": position.y,
		"admin_token": UserSession.admin_token if UserSession else ""
	}
	NetworkManager.send_message(message)


func change_map(map_id: int, position: Vector2):
	var message = {
		"type": "change_map",
		"map_id": map_id,
		"position_x": position.x,
		"position_y": position.y
	}
	NetworkManager.send_message(message)


func send_player_update(position: Vector2, state: Dictionary, facing: Dictionary):
	var message = {
		"type": "update_player",
		"position_x": position.x,
		"position_y": position.y,
		"state": state,
		"facing": facing
	}
	NetworkManager.send_message(message)


func send_chat_message(text: String):
	var message = {
		"type": "send_chat",
		"message": text
	}
	NetworkManager.send_message(message)


func send_avatar_refresh(avatar_url: String):
	var message = {
		"type": "refresh_avatar",
		"avatar_url": avatar_url
	}
	NetworkManager.send_message(message)


func request_player_list():
	var message = {
		"type": "request_player_list"
	}
	NetworkManager.send_message(message)
