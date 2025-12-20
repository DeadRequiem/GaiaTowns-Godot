extends CharacterBody2D

@onready var torso_sprite: Sprite2D = $Torso
@onready var legs_sprite: Sprite2D = $Legs
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var username_label: Label = $UsernameLabel

var peer_id: String = ""
var username: String = ""
var username_color: String = "000000"
var avatar_url: String = ""

var target_position: Vector2 = Vector2.ZERO
var is_walking: bool = false
var is_kneeling: bool = false
var in_water: bool = false
var face: String = "front"
var facing_lr: String = "right"

var strip_texture: Texture2D
var frames: Array[Texture2D] = []
var leg_frames: Array[Texture2D] = []
var leg_index: int = 0
var leg_timer: float = 0.0
var is_loading: bool = false
var avatar_queue: Array[String] = []
var is_being_carried: bool = false
var is_carrying_someone: bool = false
var carrier_node: Node2D = null

var is_thrown: bool = false
var throw_start: Vector2 = Vector2.ZERO
var throw_end: Vector2 = Vector2.ZERO
var throw_timer: float = 0.0

signal avatar_loaded()


func _ready() -> void:
	if not torso_sprite:
		push_error("RemotePlayer: TorsoSprite node not found!")
		return
	if not legs_sprite:
		push_error("RemotePlayer: LegsSprite node not found!")
		return
	if not http_request:
		push_error("RemotePlayer: HTTPRequest node not found!")
		return
	if not username_label:
		push_error("RemotePlayer: UsernameLabel node not found!")
		return

	setup_sprite_rendering()

	if not http_request.request_completed.is_connected(_on_http_request_completed):
		http_request.request_completed.connect(_on_http_request_completed)


func _exit_tree() -> void:
	if http_request and http_request.request_completed.is_connected(_on_http_request_completed):
		http_request.request_completed.disconnect(_on_http_request_completed)


func setup_sprite_rendering() -> void:
	if torso_sprite:
		torso_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	if legs_sprite:
		legs_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func initialize(id: String, player_username: String, player_avatar_url: String, pos: Vector2, color_hex: String = "000000") -> void:
	peer_id = id
	username = player_username
	username_color = color_hex
	avatar_url = player_avatar_url
	global_position = pos
	target_position = pos
	set_username(username, username_color)
	load_avatar(avatar_url)


func set_username(new_username: String, color_hex: String = "000000") -> void:
	username = new_username
	username_color = color_hex
	if username_label:
		username_label.set_username(username, username_color)
		await get_tree().process_frame

		var label_width: float = username_label.size.x
		username_label.position.x = -label_width / 2.0 + 10.0
		username_label.position.y = 76.0


func update_from_network(pos: Vector2, state: Dictionary, facing: Dictionary) -> void:
	var distance: float = global_position.distance_to(pos)

	if distance > Config.TELEPORT_THRESHOLD:
		global_position = pos
		target_position = pos
	else:
		if not is_being_carried and not is_thrown:
			target_position = pos

	is_walking = state.get("is_moving", false)
	is_kneeling = state.get("is_kneeling", false)
	in_water = state.get("in_water", false)
	is_being_carried = state.get("is_being_carried", false)
	is_carrying_someone = state.get("is_carrying", false)

	face = facing.get("direction", "front")
	facing_lr = facing.get("facing_lr", "right")


func set_carrier_node(node: Node2D) -> void:
	carrier_node = node


func set_thrown(target_pos: Vector2, duration: float = 0.0, peak: float = 0.0) -> void:
	is_thrown = true
	throw_start = global_position
	throw_end = target_pos
	throw_timer = 0.0
	is_being_carried = false
	carrier_node = null


func _process(delta: float) -> void:
	if is_thrown:
		_process_throw(delta)
		return

	if is_being_carried and carrier_node and is_instance_valid(carrier_node):
		var desired_pos: Vector2 = carrier_node.global_position + Config.CARRY_OFFSET
		global_position = global_position.lerp(desired_pos, 20.0 * delta)
		update_animation(delta, is_walking, is_kneeling, in_water)
		z_index = int(get_feet_position().y)
		update_sprite_offset()
		global_position = global_position.round()
		return

	var distance: float = global_position.distance_to(target_position)

	if distance > Config.POSITION_THRESHOLD:
		var old_pos: Vector2 = global_position
		global_position = global_position.lerp(target_position, Config.INTERPOLATION_SPEED * delta)
		var vel: Vector2 = (global_position - old_pos) / delta
		if vel.length() > 10.0:
			update_facing(vel)
	else:
		global_position = target_position

	update_animation(delta, is_walking, is_kneeling, in_water)
	z_index = int(get_feet_position().y)
	update_sprite_offset()
	global_position = global_position.round()


func _process_throw(delta: float) -> void:
	throw_timer += delta
	var t: float = clamp(throw_timer / Config.THROW_DURATION, 0.0, 1.0)
	var horiz: Vector2 = throw_start.lerp(throw_end, t)
	var arc_y: float = 4.0 * Config.THROW_PEAK_HEIGHT * t * (1.0 - t)
	global_position = Vector2(horiz.x, horiz.y - arc_y)

	update_animation(delta, is_walking, is_kneeling, in_water)
	z_index = int(get_feet_position().y)
	update_sprite_offset()
	global_position = global_position.round()

	if throw_timer >= Config.THROW_DURATION:
		is_thrown = false
		throw_timer = 0.0
		global_position = throw_end
		target_position = throw_end
		return


func get_feet_position() -> Vector2:
	return global_position + Vector2(0, 60)


func load_avatar(url: String) -> void:
	avatar_url = url
	if url.is_empty():
		push_error("Empty avatar URL for remote player %s" % peer_id)
		return
	if not http_request:
		push_error("RemotePlayer: Cannot load avatar - HTTPRequest node missing")
		return
	if url.begins_with("res://"):
		strip_texture = load(url)
		if strip_texture:
			apply_texture_quality_settings()
			slice_strip()
			avatar_loaded.emit()
			print("Local avatar loaded: " + url)
		else:
			push_error("Failed to load local avatar: " + url)
			load_fallback_avatar()
		return
	
	# URL is already proxied and converted to strip format by UserSession
	# Just use it directly
	if is_loading:
		# Replace queued request with latest
		if avatar_queue.is_empty():
			avatar_queue.append(url)
		else:
			avatar_queue[0] = url
		return
	
	avatar_queue.clear()
	is_loading = true

	print("Loading avatar from: %s" % url)
	http_request.request(url)


func apply_texture_quality_settings() -> void:
	if strip_texture and strip_texture is ImageTexture:
		pass


func _on_http_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	is_loading = false

	if result != OK or response_code != 200:
		push_error("Failed to download avatar: result=%d, code=%d" % [result, response_code])
		load_fallback_avatar()
		check_pending_load()
		return

	if body.size() == 0:
		push_error("Received empty body from avatar request")
		load_fallback_avatar()
		check_pending_load()
		return

	var img := Image.new()
	var load_result := img.load_png_from_buffer(body)
	if load_result != OK:
		push_error("Failed to load PNG from buffer: error %d" % load_result)
		load_fallback_avatar()
		check_pending_load()
		return

	strip_texture = ImageTexture.create_from_image(img)
	apply_texture_quality_settings()
	slice_strip()
	avatar_loaded.emit()
	print("Avatar loaded successfully for remote player %s" % peer_id)
	check_pending_load()


func load_fallback_avatar() -> void:
	if ResourceLoader.exists(Config.FALLBACK_AVATAR):
		strip_texture = load(Config.FALLBACK_AVATAR)
		apply_texture_quality_settings()
		slice_strip()
		avatar_loaded.emit()
		print("Fallback avatar loaded for remote player %s" % peer_id)
	else:
		push_error("Fallback avatar not found at: " + Config.FALLBACK_AVATAR)


func check_pending_load() -> void:
	if not avatar_queue.is_empty():
		var url_to_load: String = avatar_queue.pop_front()
		load_avatar(url_to_load)


func slice_strip() -> void:
	frames.clear()
	leg_frames.clear()
	if not strip_texture:
		return

	var frame_width: float = strip_texture.get_width() / 10.0
	var frame_height: float = float(strip_texture.get_height())

	for i in range(10):
		var tex: AtlasTexture = AtlasTexture.new()
		tex.atlas = strip_texture
		tex.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.append(tex)

	leg_frames = frames.slice(Config.FRAME_WALK_LEG_1, Config.FRAME_WALK_LEG_4 + 1)


func update_animation(delta: float, is_walking_state: bool, is_kneeling_state: bool, in_water_state: bool) -> void:
	if is_walking_state and leg_frames.size() > 0 and not in_water_state:
		leg_timer += delta
		if leg_timer >= Config.LEG_FRAME_TIME:
			leg_timer -= Config.LEG_FRAME_TIME
			leg_index = (leg_index + 1) % leg_frames.size()
		legs_sprite.texture = leg_frames[leg_index]
		legs_sprite.visible = true
	else:
		legs_sprite.visible = false
		leg_timer = 0.0
		leg_index = 0

	if frames.size() > 0:
		var frame_idx: int = get_torso_frame(is_walking_state, is_kneeling_state)
		torso_sprite.texture = frames[frame_idx]

	var flip: bool = (facing_lr == "right")
	torso_sprite.flip_h = flip
	legs_sprite.flip_h = flip

	if facing_lr == "right":
		torso_sprite.position.x = 20
		legs_sprite.position.x = 20
	else:
		torso_sprite.position.x = 0
		legs_sprite.position.x = 0


func update_facing(velocity: Vector2) -> void:
	if abs(velocity.x) > abs(velocity.y):
		if velocity.x < 0:
			facing_lr = "left"
		elif velocity.x > 0:
			facing_lr = "right"
	else:
		if velocity.y < 0:
			face = "back"
		elif velocity.y > 0:
			face = "front"


func get_torso_frame(is_walking_state: bool, is_kneeling_state: bool) -> int:
	if is_kneeling_state:
		return Config.FRAME_KNEEL_BACK if face == "back" else Config.FRAME_KNEEL_FRONT
	if is_walking_state:
		return Config.FRAME_TORSO_BACK if face == "back" else Config.FRAME_TORSO_FRONT

	return Config.FRAME_STAND_BACK if face == "back" else Config.FRAME_STAND_FRONT


func set_visual_offset(offset_y: float) -> void:
	torso_sprite.position.y = offset_y
	legs_sprite.position.y = offset_y


func update_sprite_offset() -> void:
	var offset_y: float = Config.KNEEL_Y_OFFSET if is_kneeling else 0.0
	set_visual_offset(offset_y)
