# Client-side Map Navigation
extends Node

signal map_loaded(map_id: int)
signal transition_started(from_map: int, to_map: int)
signal transition_completed(map_id: int)

@export var map_width: float = 1536.0
@export var map_height: float = 1536.0

const MAP_SCALE: float = 1.0
const EDGE_CLEARANCE: float = 60.0
var current_barton_id: int = 1000
var current_map_id: int = 5
var barton_grid: Array = []
var current_row: int = 1
var current_col: int = 1
var current_map: Node2D = null
var transitioning: bool = false
var edge_north: Area2D = null
var edge_south: Area2D = null
var edge_east: Area2D = null
var edge_west: Area2D = null


func initialize_barton(barton_data: Dictionary, start_map_id: int) -> void:
	current_barton_id = barton_data.get("barton_id", 1000)
	barton_grid = barton_data.get("grid", [])
	
	print("Loaded barton %d with grid: %s" % [current_barton_id, barton_grid])
	
	find_map_in_grid(start_map_id)
	load_map(start_map_id)


func find_map_in_grid(map_id: int) -> void:
	for row in range(barton_grid.size()):
		for col in range(barton_grid[row].size()):
			if barton_grid[row][col] == map_id:
				current_row = row
				current_col = col
				print("Found map %d at grid position [%d, %d]" % [map_id, row, col])
				return
	
	current_row = 1
	current_col = 1


func load_map(map_id: int, spawn_position: Vector2 = Vector2.ZERO) -> Node2D:
	disconnect_edge_areas()
	
	if current_map:
		current_map.queue_free()
		current_map = null
	
	var scene_path := "res://maps/map_%d.tscn" % map_id
	
	if not ResourceLoader.exists(scene_path):
		push_error("Map scene not found: %s" % scene_path)
		return null
	
	print("Loading map scene: %s" % scene_path)
	
	var scene: PackedScene = load(scene_path)
	current_map = scene.instantiate()
	current_map.z_index = -1000
	
	current_map_id = map_id
	
	var background: Sprite2D = current_map.get_node_or_null("Background")
	if background and background.texture:
		var tex_size := background.texture.get_size()
		map_width = tex_size.x * background.scale.x
		map_height = tex_size.y * background.scale.y
		print("Map dimensions: %fx%f" % [map_width, map_height])
	
	connect_edge_areas()
	map_loaded.emit(map_id)
	
	return current_map


func connect_edge_areas() -> void:
	if not current_map:
		return
	
	edge_north = current_map.get_node_or_null("EdgeNorth")
	if not edge_north:
		edge_north = current_map.get_node_or_null("Edges/NorthEdge")
	
	edge_south = current_map.get_node_or_null("EdgeSouth")
	if not edge_south:
		edge_south = current_map.get_node_or_null("Edges/SouthEdge")
	
	edge_east = current_map.get_node_or_null("EdgeEast")
	if not edge_east:
		edge_east = current_map.get_node_or_null("Edges/EastEdge")
	
	edge_west = current_map.get_node_or_null("EdgeWest")
	if not edge_west:
		edge_west = current_map.get_node_or_null("Edges/WestEdge")
	
	if edge_north:
		edge_north.body_entered.connect(_on_edge_entered.bind("north"))
		print("Connected to NorthEdge")
	
	if edge_south:
		edge_south.body_entered.connect(_on_edge_entered.bind("south"))
		print("Connected to SouthEdge")
	
	if edge_east:
		edge_east.body_entered.connect(_on_edge_entered.bind("east"))
		print("Connected to EastEdge")
	
	if edge_west:
		edge_west.body_entered.connect(_on_edge_entered.bind("west"))
		print("Connected to WestEdge")


func disconnect_edge_areas() -> void:
	if edge_north and edge_north.body_entered.is_connected(_on_edge_entered):
		edge_north.body_entered.disconnect(_on_edge_entered)
	if edge_south and edge_south.body_entered.is_connected(_on_edge_entered):
		edge_south.body_entered.disconnect(_on_edge_entered)
	if edge_east and edge_east.body_entered.is_connected(_on_edge_entered):
		edge_east.body_entered.disconnect(_on_edge_entered)
	if edge_west and edge_west.body_entered.is_connected(_on_edge_entered):
		edge_west.body_entered.disconnect(_on_edge_entered)
	
	edge_north = null
	edge_south = null
	edge_east = null
	edge_west = null


func _on_edge_entered(body: Node2D, direction: String) -> void:
	if barton_grid.is_empty() or transitioning:
		return
	
	# Check if it's the player and has sufficient velocity
	if not body.has_method("get_velocity"):
		return
	
	var velocity: Vector2 = body.velocity
	if velocity.length() < 10.0:
		return
	
	print("Edge entered: %s by %s (velocity: %s)" % [direction, body.name, velocity])
	
	var new_row := current_row
	var new_col := current_col
	var came_from := ""
	
	match direction:
		"north":
			if current_row > 0:
				new_row = current_row - 1
				came_from = "south"
		"south":
			if current_row < barton_grid.size() - 1:
				new_row = current_row + 1
				came_from = "north"
		"west":
			if current_col > 0:
				new_col = current_col - 1
				came_from = "east"
		"east":
			if current_col < barton_grid[0].size() - 1:
				new_col = current_col + 1
				came_from = "west"
	
	if new_row == current_row and new_col == current_col:
		print("Cannot transition %s - at grid boundary" % direction)
		return
	
	if barton_grid[new_row][new_col] == 0:
		print("Cannot transition %s - no map at [%d, %d]" % [direction, new_row, new_col])
		return
	
	call_deferred("transition_to_map", body, new_row, new_col, came_from)


func transition_to_map(player_body: Node2D, new_row: int, new_col: int, came_from: String) -> void:
	if transitioning:
		return
	
	transitioning = true
	
	var next_map_id: int = barton_grid[new_row][new_col]
	
	print("Transitioning from map %d [%d,%d] to map %d [%d,%d]" % [
		current_map_id, current_row, current_col,
		next_map_id, new_row, new_col
	])
	
	transition_started.emit(current_map_id, next_map_id)
	
	current_row = new_row
	current_col = new_col
	
	var spawn_pos := calculate_spawn_position(came_from)
	load_map(next_map_id, spawn_pos)
	
	if player_body:
		player_body.global_position = spawn_pos
		print("Player positioned at: %s (transition)" % spawn_pos)
	
	transition_completed.emit(next_map_id)
	
	await get_tree().create_timer(0.2).timeout
	transitioning = false
	print("Transition complete")


func calculate_spawn_position(came_from: String) -> Vector2:
	match came_from:
		"north":
			return Vector2(map_width / 2, EDGE_CLEARANCE)
		"south":
			return Vector2(map_width / 2, map_height - EDGE_CLEARANCE)
		"west":
			return Vector2(EDGE_CLEARANCE, map_height / 2)
		"east":
			return Vector2(map_width - EDGE_CLEARANCE, map_height / 2)
		_:
			return Vector2(map_width / 2, map_height / 2)


func get_spawn_position_for_map() -> Vector2:
	if not current_map:
		return Vector2(map_width / 2, map_height / 2)
	
	var spawn_marker: Marker2D = current_map.get_node_or_null("SpawnPoint")
	if spawn_marker:
		return spawn_marker.global_position
	
	return Vector2(map_width / 2, map_height / 2)


func is_transitioning() -> bool:
	return transitioning
