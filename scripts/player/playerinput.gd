# Player Input Controller
extends Node

signal movement_input(direction: Vector2)
signal mouse_target_set(target_position: Vector2)

var key_left: bool = false
var key_right: bool = false
var key_up: bool = false
var key_down: bool = false

var mouse_target: Vector2 = Vector2.ZERO
var has_mouse_target: bool = false


func _ready() -> void:
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		mouse_target = get_viewport().get_mouse_position()
		# Convert viewport coordinates to global position
		var camera := get_viewport().get_camera_2d()
		if camera:
			mouse_target = camera.get_screen_center_position() + (mouse_target - get_viewport().get_visible_rect().size / 2)
		has_mouse_target = true
		mouse_target_set.emit(mouse_target)


func _process(_delta: float) -> void:
	update_keyboard_input()
	
	var direction := get_movement_direction()
	if direction != Vector2.ZERO:
		has_mouse_target = false
		movement_input.emit(direction)


func update_keyboard_input() -> void:
	key_left = Input.is_action_pressed("ui_left")
	key_right = Input.is_action_pressed("ui_right")
	key_up = Input.is_action_pressed("ui_up")
	key_down = Input.is_action_pressed("ui_down")


func get_movement_direction() -> Vector2:
	var direction := Vector2.ZERO
	
	if key_left:
		direction.x -= 1
	if key_right:
		direction.x += 1
	if key_up:
		direction.y -= 1
	if key_down:
		direction.y += 1
	
	return direction.normalized()


func get_mouse_target() -> Vector2:
	return mouse_target


func has_active_mouse_target() -> bool:
	return has_mouse_target


func clear_mouse_target() -> void:
	has_mouse_target = false
