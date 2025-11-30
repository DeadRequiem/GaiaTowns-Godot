# remoteplayer.gd - Network-driven player representation
extends CharacterBody2D

const INTERPOLATION_SPEED: float = 10.0
const POSITION_THRESHOLD: float = 5.0
const KNEEL_Y_OFFSET: float = 25.0
const ALLOWED_AVATAR_DOMAINS = [
	"a1cdn.gaiaonline.com"
]

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


func is_valid_avatar_url(url: String) -> bool:
	if url.is_empty():
		return false
	
	# Must be HTTPS
	if not url.begins_with("https://"):
		push_warning("Avatar URL must use HTTPS: %s" % url)
		return false
	
	# Check domain whitelist
	var is_allowed_domain = false
	for domain in ALLOWED_AVATAR_DOMAINS:
		if url.contains(domain):
			is_allowed_domain = true
			break
	
	if not is_allowed_domain:
		push_warning("Avatar URL from untrusted domain: %s" % url)
		return false
	
	# Must be an image file (png/jpg/gif) - check for extension before query params
	var base_url = url.split("?")[0]  # Remove query params like ?t=timestamp
	if not (base_url.ends_with(".png") or base_url.ends_with(".jpg") or 
			base_url.ends_with(".jpeg") or base_url.ends_with(".gif")):
		push_warning("Avatar URL must be an image file: %s" % url)
		return false
	
	# Check path structure for Gaia avatars
	if not (url.contains("/dress-up/avatar/") or url.contains("/avatar/")):
		push_warning("Avatar URL has unexpected path structure: %s" % url)
		return false
	
	return true


func load_avatar(url: String) -> void:
	avatar_url = url
	
	# Validate URL before loading
	if not is_valid_avatar_url(url):
		push_error("Invalid avatar URL for remote player %d: '%s'" % [peer_id, url])
		# TODO: Load fallback/default avatar instead
		return
	
	if player_avatar:
		player_avatar.load_avatar(url)


func update_from_network(pos: Vector2, state: Dictionary, facing: Dictionary) -> void:
	target_position = pos
	
	is_walking = state.get("is_moving", false)
	is_kneeling = state.get("is_kneeling", false)
	in_water = state.get("in_water", false)
	
	face = facing.get("direction", "front")
	facing_lr = facing.get("facing_lr", "right")


func _process(delta: float) -> void:
	# Smooth interpolation to target
	var distance := global_position.distance_to(target_position)
	
	if distance > POSITION_THRESHOLD:
		var old_pos := global_position
		global_position = global_position.lerp(target_position, INTERPOLATION_SPEED * delta)
		
		# Calculate velocity for avatar facing update
		var vel := (global_position - old_pos) / delta
		if vel.length() > 10.0:  # Only update if moving meaningfully
			player_avatar.update_facing(vel)
	
	# Sync avatar state
	player_avatar.face = face
	player_avatar.facing_lr = facing_lr
	player_avatar.update_animation(delta, is_walking, is_kneeling, in_water)
	
	update_sprite_offset()


func update_sprite_offset() -> void:
	var offset_y := KNEEL_Y_OFFSET if is_kneeling else 0.0
	player_avatar.set_visual_offset(offset_y)


func get_feet_position() -> Vector2:
	return global_position + Vector2(0, 60)
