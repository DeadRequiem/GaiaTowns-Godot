# remoteplayer
extends CharacterBody2D

const INTERPOLATION_SPEED: float = 10.0
const POSITION_THRESHOLD: float = 5.0
const KNEEL_Y_OFFSET: float = 25.0

@onready var player_avatar: Node = $PlayerAvatar
@onready var username_label: Label = $UsernameLabel

var peer_id: int = -1
var username: String = ""
var avatar_url: String = ""

# Network state
var target_position: Vector2 = Vector2.ZERO
var is_walking: bool = false
var is_kneeling: bool = false
var in_water: bool = false
var face: String = "front"
var facing_lr: String = "right"


func initialize(id: int, player_username: String, player_avatar_url: String, pos: Vector2) -> void:
	peer_id = id
	username = player_username
	avatar_url = player_avatar_url
	global_position = pos
	target_position = pos	
	set_username(username)
	load_avatar(avatar_url)

func set_username(new_username: String) -> void:
	username = new_username
	if username_label:
		username_label.set_username(username)
		await get_tree().process_frame
		var avatar_center_x = 10.0
		var label_width = username_label.get_minimum_size().x
		username_label.offset_left = avatar_center_x - (label_width / 2.0)
		username_label.offset_right = avatar_center_x + (label_width / 2.0)

func load_avatar(url: String) -> void:
	avatar_url = url	
	if url.is_empty():
		push_error("Empty avatar URL for remote player %d" % peer_id)
		return
	if player_avatar:
		player_avatar.load_avatar(url)
	else:
		push_error("PlayerAvatar node not found for remote player %d" % peer_id)

func update_from_network(pos: Vector2, state: Dictionary, facing: Dictionary) -> void:
	target_position = pos	
	is_walking = state.get("is_moving", false)
	is_kneeling = state.get("is_kneeling", false)
	in_water = state.get("in_water", false)	
	face = facing.get("direction", "front")
	facing_lr = facing.get("facing_lr", "right")

func _process(delta: float) -> void:
	var distance := global_position.distance_to(target_position)	
	if distance > POSITION_THRESHOLD:
		var old_pos := global_position
		global_position = global_position.lerp(target_position, INTERPOLATION_SPEED * delta)
		var vel := (global_position - old_pos) / delta
		if vel.length() > 10.0:
			player_avatar.update_facing(vel)
	else:
		global_position = target_position
	
	# Sync avatar state
	if player_avatar:
		player_avatar.face = face
		player_avatar.facing_lr = facing_lr
		player_avatar.update_animation(delta, is_walking, is_kneeling, in_water)	
	update_sprite_offset()


func update_sprite_offset() -> void:
	var offset_y := KNEEL_Y_OFFSET if is_kneeling else 0.0
	if player_avatar:
		player_avatar.set_visual_offset(offset_y)

func get_feet_position() -> Vector2:
	return global_position + Vector2(0, 60)
