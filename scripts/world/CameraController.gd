class_name CameraController
extends Camera2D

@export var target: Node2D = null
@export var map_width: float = 1536.0
@export var map_height: float = 1536.0

func _ready() -> void :
	enabled = true
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0
	set_process_mode(Node.PROCESS_MODE_INHERIT)
	zoom = Vector2(1.4, 1.4)

func set_target(new_target: Node2D) -> void :
	target = new_target

func set_map_bounds(width: float, height: float) -> void :
	map_width = width
	map_height = height
	limit_left = 0
	limit_top = 0
	limit_right = int(map_width)
	limit_bottom = int(map_height)

func _process(_delta: float) -> void :
	if not target:
		return
	global_position = target.global_position
