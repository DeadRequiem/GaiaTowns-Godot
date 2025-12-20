extends Node

const WorldChatBubble = preload("res://scenes/ui/WorldChatBubble.tscn")

var player_bubbles: Dictionary = {}  # player_id -> bubble_instance


func show_chat_bubble(player_node: Node2D, player_id: String, username: String, message: String) -> void:
	if not is_instance_valid(player_node):
		push_warning("WorldChatManager: Invalid player node for %s" % player_id)
		return
	
	var bubble: Node2D = null

	if player_bubbles.has(player_id):
		bubble = player_bubbles[player_id]

		if not is_instance_valid(bubble) or bubble.get_parent() != player_node:
			if is_instance_valid(bubble):
				bubble.queue_free()
			bubble = null

	if bubble == null:
		bubble = WorldChatBubble.instantiate()
		bubble.name = "ChatBubble"
		player_node.add_child(bubble)
		bubble.set_username(username)
		player_bubbles[player_id] = bubble

	bubble.add_message(message)


func clear_player_bubble(player_id: String) -> void:
	if not player_bubbles.has(player_id):
		return
	
	var bubble = player_bubbles[player_id]
	if is_instance_valid(bubble):
		bubble.queue_free()
	
	player_bubbles.erase(player_id)

func clear_all_bubbles() -> void:
	for player_id in player_bubbles.keys():
		var bubble = player_bubbles[player_id]
		if is_instance_valid(bubble):
			bubble.queue_free()
	player_bubbles.clear()

func update_player_username(player_id: String, new_username: String) -> void:
	if not player_bubbles.has(player_id):
		return
	
	var bubble = player_bubbles[player_id]
	if is_instance_valid(bubble):
		bubble.set_username(new_username)

func _exit_tree() -> void:
	clear_all_bubbles()
