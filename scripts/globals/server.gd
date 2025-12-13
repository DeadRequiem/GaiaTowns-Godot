
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
	if UserSession:
		UserSession.admin_status_changed.connect(_on_admin_status_changed)

func _on_connection_success():
	connection_success.emit()

func _on_admin_status_changed(is_admin: bool):
	admin_status_confirmed.emit(is_admin)

func connect_to_server():
	if NetworkManager:
		NetworkManager.connect_to_server()

func join_barton(username: String, avatar_url: String, barton_id: int, map_id: int, position: Vector2):
	_join_barton.rpc_id(1, username, avatar_url, barton_id, map_id, position, UserSession.admin_token)

func change_map(map_id: int, position: Vector2):
	_change_map.rpc_id(1, map_id, position)

func send_player_update(position: Vector2, state: Dictionary, facing: Dictionary):
	_update_player.rpc_id(1, position, state, facing)

func send_chat_message(message: String):
	_send_chat_message.rpc_id(1, message)

func send_avatar_refresh(avatar_url: String):
	_refresh_avatar.rpc_id(1, avatar_url)





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

@rpc("authority", "reliable")
func _change_music_track(track_name: String):
	music_track_changed.emit(track_name)

@rpc("authority", "reliable")
func _avatar_refreshed(peer_id: int, avatar_url: String):
	avatar_refresh_received.emit(peer_id, avatar_url)

@rpc("authority", "reliable")
func _confirm_admin_status(is_admin: bool):
	UserSession.set_admin_status(is_admin)
	admin_status_confirmed.emit(is_admin)

@rpc("authority", "reliable")
func _send_player_list(player_list: Array):
	pass

@rpc("any_peer", "reliable")
func _join_barton(username: String, avatar_url: String, barton_id: int, map_id: int, position: Vector2, admin_token: String):
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

@rpc("any_peer", "reliable")
func _refresh_avatar(avatar_url: String):
	pass

@rpc("any_peer", "reliable")
func _request_player_list():
	pass
