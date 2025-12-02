# Player
extends CharacterBody2D

const ARRIVAL_THRESHOLD: float = 5.0
const BASE_SPEED: float = 150.0
const KNEEL_Y_OFFSET: float = 25.0

@onready var player_input: Node = $PlayerInput
@onready var player_avatar: Node = $PlayerAvatar
@onready var username_label: Label = $UsernameLabel

var username: String = ""
var avatar_url: String = ""
var is_walking: bool = false
var is_kneeling: bool = false
var in_water: bool = false
var face: String = "front"
var facing_lr: String = "right"

func set_username(new_username: String) -> void:
	username = new_username
	if username_label:
		username_label.set_username(username)
		await get_tree().process_frame
		var avatar_center_x = 10.0
		var label_width = username_label.get_minimum_size().x
		username_label.offset_left = avatar_center_x - (label_width / 2.0)
		username_label.offset_right = avatar_center_x + (label_width / 2.0)

func set_avatar_url(url: String) -> void:
	avatar_url = url

func set_kneeling(kneeling: bool) -> void:
	is_kneeling = kneeling
	if is_kneeling:
		is_walking = false

func load_avatar(url: String) -> void:
	avatar_url = url
	player_avatar.load_avatar(url)

func _process(delta: float) -> void:
	var vel := calculate_velocity(delta)
	if vel != Vector2.ZERO:
		player_avatar.update_facing(vel)
		if not is_kneeling:
			is_walking = true
			velocity = vel
		else:
			is_walking = false
			velocity = Vector2.ZERO
	else:
		is_walking = false
		velocity = Vector2.ZERO
	move_and_slide()
	
	face = player_avatar.face
	facing_lr = player_avatar.facing_lr
	player_avatar.update_animation(delta, is_walking, is_kneeling, in_water)
	z_index = int(get_feet_position().y)
	update_sprite_offset()
	global_position = global_position.round()

func update_sprite_offset() -> void:
	var offset_y := KNEEL_Y_OFFSET if is_kneeling else 0.0
	player_avatar.set_visual_offset(offset_y)

func calculate_velocity(_delta: float) -> Vector2:
	var speed := BASE_SPEED
	var vel := Vector2.ZERO	
	var keyboard_direction: Vector2 = player_input.get_movement_direction()
	if keyboard_direction != Vector2.ZERO:
		vel = keyboard_direction * speed
	elif player_input.has_active_mouse_target():
		var mouse_target: Vector2 = player_input.get_mouse_target()
		var diff: Vector2 = mouse_target - global_position
		
		if diff.length() < ARRIVAL_THRESHOLD:
			player_input.clear_mouse_target()
			return Vector2.ZERO
		
		vel = diff.normalized() * speed
	
	if is_kneeling and vel != Vector2.ZERO:
		return vel.normalized()
	
	return vel

func get_state() -> Dictionary:
	return {
		"is_moving": is_walking,
		"in_water": in_water,
		"is_kneeling": is_kneeling
	}

func get_facing() -> Dictionary:
	return {
		"direction": face,
		"facing_lr": facing_lr
	}

func get_feet_position() -> Vector2:
	return global_position + Vector2(0, 60)
