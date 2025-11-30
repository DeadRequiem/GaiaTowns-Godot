extends CanvasLayer

const ChatBubble = preload("res://scenes/ui/ChatBubble.tscn")
const EMPTY_STACK_LIFETIME: float = 2.0
const MIN_POOL_SIZE: int = 20
const MAX_POOL_SIZE: int = 50

var player_stacks: Dictionary = {}
var bubble_pool: Array = []


func get_bubble_from_pool() -> Node:
	if bubble_pool.is_empty():
		var bubble = ChatBubble.instantiate()
		add_child(bubble)
		return bubble

	var bubble = bubble_pool.pop_back()
	bubble.visible = true
	return bubble


func return_bubble_to_pool(bubble: Node) -> void:
	if not is_instance_valid(bubble):
		return

	if bubble_pool.size() < MAX_POOL_SIZE:
		bubble.visible = false
		bubble.position = Vector2.ZERO

		if bubble.has_method("clear_messages"):
			bubble.clear_messages()

		bubble_pool.append(bubble)
	else:
		bubble.queue_free()


func show_chat_bubble(player_id: int, username: String, message: String, world_pos: Vector2) -> void:
	if not player_stacks.has(player_id):
		var stack = get_bubble_from_pool()
		stack.name = "Stack_%d" % player_id
		stack.set_username(username)

		player_stacks[player_id] = {
			"stack": stack,
			"world_pos": world_pos,
			"last_message_time": Time.get_ticks_msec() / 1000.0
		}

	var stack_data = player_stacks[player_id]

	if not is_instance_valid(stack_data.stack):
		var stack = get_bubble_from_pool()
		stack.name = "Stack_%d" % player_id
		stack.set_username(username)
		stack_data.stack = stack

	stack_data.world_pos = world_pos
	stack_data.last_message_time = Time.get_ticks_msec() / 1000.0
	stack_data.stack.add_message(message)

	update_stack_position(player_id)


func update_stack_position(player_id: int) -> void:
	if not player_stacks.has(player_id):
		return

	var stack_data = player_stacks[player_id]
	if not is_instance_valid(stack_data.stack):
		return

	var stack = stack_data.stack
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return

	var world_pos: Vector2 = stack_data.world_pos
	var canvas_transform := get_viewport().get_canvas_transform()
	var screen_pos := canvas_transform * world_pos
	screen_pos.y -= 80
	screen_pos.y -= stack.size.y
	screen_pos.x -= 67.5
	screen_pos.x += 20

	stack.position = screen_pos


func update_all_positions() -> void:
	for player_id in player_stacks.keys():
		update_stack_position(player_id)


func update_player_position(player_id: int, world_pos: Vector2) -> void:
	if not player_stacks.has(player_id):
		return

	var stack_data = player_stacks[player_id]
	if not is_instance_valid(stack_data.stack):
		return

	stack_data.world_pos = world_pos
	update_stack_position(player_id)


func clear_player_bubbles(player_id: int) -> void:
	if not player_stacks.has(player_id):
		return

	var stack_data = player_stacks[player_id]

	if is_instance_valid(stack_data.stack):
		return_bubble_to_pool(stack_data.stack)

	player_stacks.erase(player_id)


func clear_all_bubbles() -> void:
	for player_id in player_stacks.keys():
		var stack_data = player_stacks[player_id]
		if is_instance_valid(stack_data.stack):
			return_bubble_to_pool(stack_data.stack)

	player_stacks.clear()


func _process(_delta: float) -> void:
	update_all_positions()

	var current_time := Time.get_ticks_msec() / 1000.0
	var to_remove := []

	for player_id in player_stacks.keys():
		var stack_data = player_stacks[player_id]

		if not is_instance_valid(stack_data.stack):
			to_remove.append(player_id)
			continue

		if stack_data.stack.messages.is_empty():
			var time_since_last: float = current_time - stack_data.last_message_time
			if time_since_last >= EMPTY_STACK_LIFETIME:
				to_remove.append(player_id)

	for player_id in to_remove:
		clear_player_bubbles(player_id)


func _exit_tree() -> void:
	for bubble in bubble_pool:
		if is_instance_valid(bubble):
			bubble.queue_free()

	bubble_pool.clear()
