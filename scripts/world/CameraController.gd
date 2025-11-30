# Client-side Camera Controller
class_name CameraController
extends Camera2D

@export var target: Node2D = null
@export var map_width: float = 1536.0
@export var map_height: float = 1536.0


func _ready() -> void:
	enabled = true
	position_smoothing_enabled = true


func set_target(new_target: Node2D) -> void:
	target = new_target


func set_map_bounds(width: float, height: float) -> void:
	map_width = width
	map_height = height
	
	# Set hard limits so camera can't go outside map
	limit_left = 0
	limit_top = 0
	limit_right = int(map_width)
	limit_bottom = int(map_height)
	
	# Calculate zoom to fit map to viewport
	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom_x: float = viewport_size.x / map_width
	var zoom_y: float = viewport_size.y / map_height
	
	# Use the larger zoom value so map fills viewport (might crop a bit on one axis)
	var target_zoom: float = max(zoom_x, zoom_y)
	zoom = Vector2(target_zoom, target_zoom)
	
	print("Camera zoom set to: %f (viewport: %s, map: %fx%f)" % [target_zoom, viewport_size, map_width, map_height])


func _process(_delta: float) -> void:
	if not target:
		return
	
	update_position()


func update_position() -> void:
	# Let Camera2D handle limits automatically, just follow target
	global_position = target.global_position
