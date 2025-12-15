extends CharacterBody2D

const ARRIVAL_THRESHOLD: float = 5.0
const BASE_SPEED: float = 150.0
const KNEEL_Y_OFFSET: float = 25.0

const FRAME_TORSO_FRONT: = 0
const FRAME_TORSO_BACK: = 1
const FRAME_KNEEL_FRONT: = 2
const FRAME_KNEEL_BACK: = 3
const FRAME_STAND_FRONT: = 4
const FRAME_STAND_BACK: = 5
const FRAME_WALK_LEG_1: = 6
const FRAME_WALK_LEG_2: = 7
const FRAME_WALK_LEG_3: = 8
const FRAME_WALK_LEG_4: = 9
const FALLBACK_AVATAR: = "res://assets/fallback_avatar.png"


@onready var torso_sprite: Sprite2D = $Torso
@onready var legs_sprite: Sprite2D = $Legs
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var username_label: Label = $UsernameLabel


var username: String = ""
var avatar_url: String = ""
var is_walking: bool = false
var is_kneeling: bool = false
var in_water: bool = false
var face: String = "front"
var facing_lr: String = "right"
var speed_multiplier: float = 1.0

var key_left: bool = false
var key_right: bool = false
var key_up: bool = false
var key_down: bool = false
var mouse_target: Vector2 = Vector2.ZERO
var has_mouse_target: bool = false

var strip_texture: Texture2D
var frames: Array[Texture2D] = []
var leg_frames: Array[Texture2D] = []
var leg_index: int = 0
var leg_timer: float = 0.0
var leg_frame_time: float = 0.12
var is_loading: bool = false
var pending_url: String = ""
signal avatar_loaded()


func _ready() -> void:
	set_process_unhandled_input(true)

	if not torso_sprite:
		push_error("Player: TorsoSprite node not found!")
		return
	if not legs_sprite:
		push_error("Player: LegsSprite node not found!")
		return
	if not http_request:
		push_error("Player: HTTPRequest node not found!")
		return
	if not username_label:
		push_error("Player: UsernameLabel node not found!")
		return
	setup_sprite_rendering()

	if not http_request.request_completed.is_connected(_on_http_request_completed):
		http_request.request_completed.connect(_on_http_request_completed)

	if has_node("/root/PlayerPreferences"):
		var prefs = get_node("/root/PlayerPreferences")
		prefs.preference_changed.connect(_on_preference_changed)

		speed_multiplier = prefs.get_speed_multiplier()

		var hue_shift = prefs.get_avatar_hue_shift()
		if hue_shift != 0.0:
			apply_avatar_hue_shift(hue_shift)


func setup_sprite_rendering() -> void:
	"Configure sprites for sharp, high-quality rendering"
	if torso_sprite:
		torso_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	if legs_sprite:
		legs_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _on_preference_changed(key: String, value: Variant) -> void:
	"Handle preference changes in real-time"
	match key:
		"speed_multiplier":
			speed_multiplier = value
		"avatar_hue_shift":
			apply_avatar_hue_shift(value)


func apply_avatar_hue_shift(hue: float) -> void:
	"Apply hue shift to avatar sprites"
	if torso_sprite:
		torso_sprite.modulate = Color.from_hsv(hue, 1.0, 1.0)
	if legs_sprite:
		legs_sprite.modulate = Color.from_hsv(hue, 1.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		mouse_target = get_viewport().get_mouse_position()
		var camera: = get_viewport().get_camera_2d()
		if camera:
			mouse_target = camera.get_screen_center_position() + (mouse_target - get_viewport().get_visible_rect().size / 2)
		has_mouse_target = true


func update_keyboard_input() -> void:
	key_left = Input.is_action_pressed("move_left")
	key_right = Input.is_action_pressed("move_right")
	key_up = Input.is_action_pressed("move_up")
	key_down = Input.is_action_pressed("move_down")

	if key_left or key_right or key_up or key_down:
		clear_mouse_target()


func get_movement_direction() -> Vector2:
	var direction: = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return direction


func clear_mouse_target() -> void:
	has_mouse_target = false
	mouse_target = Vector2.ZERO

func set_username(new_username: String) -> void:
	username = new_username
	if username_label:
		username_label.set_username(username)
		await get_tree().process_frame

		var label_width = username_label.size.x
		username_label.position.x = -label_width / 2.0 + 10.0  # Add 10px offset for centered avatar
		username_label.position.y = 76.0


func set_avatar_url(url: String) -> void:
	avatar_url = url


func set_kneeling(kneeling: bool) -> void:
	is_kneeling = kneeling
	if is_kneeling:
		is_walking = false


func _process(delta: float) -> void:
	update_keyboard_input()

	var vel: = calculate_velocity(delta)
	if vel != Vector2.ZERO:
		update_facing(vel)
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

	update_animation(delta, is_walking, is_kneeling, in_water)
	z_index = int(get_feet_position().y)
	update_sprite_offset()
	global_position = global_position.round()


func update_sprite_offset() -> void:
	var offset_y: = KNEEL_Y_OFFSET if is_kneeling else 0.0
	set_visual_offset(offset_y)


func calculate_velocity(_delta: float) -> Vector2:
	var speed: = BASE_SPEED * speed_multiplier
	var vel: = Vector2.ZERO
	var keyboard_direction: Vector2 = get_movement_direction()

	if keyboard_direction != Vector2.ZERO:
		vel = keyboard_direction * speed
		clear_mouse_target()
	elif has_mouse_target:
		var diff: Vector2 = mouse_target - global_position

		if diff.length() < ARRIVAL_THRESHOLD:
			clear_mouse_target()
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

func load_avatar(url: String) -> void:
	avatar_url = url
	if not http_request:
		push_error("Player: Cannot load avatar - HTTPRequest node missing")
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

	if is_loading:
		pending_url = url
		return

	is_loading = true

	var headers: = PackedStringArray([
		"Referer: https://www.gaiaonline.com/",
		"Cache-Control: no-cache, no-store, must-revalidate",
        "Pragma: no-cache"
	])

	print("Loading avatar from: %s" % url)
	http_request.request(url, headers)


func apply_texture_quality_settings() -> void:
	"Apply quality settings to loaded texture"
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

	var img: = Image.new()
	var load_result: = img.load_png_from_buffer(body)
	if load_result != OK:
		push_error("Failed to load PNG from buffer: error %d" % load_result)
		load_fallback_avatar()
		check_pending_load()
		return


	strip_texture = ImageTexture.create_from_image(img)
	apply_texture_quality_settings()
	slice_strip()
	avatar_loaded.emit()
	print("Avatar loaded successfully")
	check_pending_load()


func load_fallback_avatar() -> void:
	"Load the fallback avatar when remote loading fails"
	if ResourceLoader.exists(FALLBACK_AVATAR):
		strip_texture = load(FALLBACK_AVATAR)
		apply_texture_quality_settings()
		slice_strip()
		avatar_loaded.emit()
		print("Fallback avatar loaded")
	else:
		push_error("Fallback avatar not found at: " + FALLBACK_AVATAR)


func check_pending_load() -> void:
	"Check if there's a pending avatar load request"
	if not pending_url.is_empty():
		var url_to_load: = pending_url
		pending_url = ""
		load_avatar(url_to_load)


func slice_strip() -> void:
	frames.clear()
	leg_frames.clear()
	if not strip_texture:
		return

	var frame_width: = strip_texture.get_width() / 10.0
	var frame_height: = float(strip_texture.get_height())

	print("Strip texture size: %dx%d" % [strip_texture.get_width(), strip_texture.get_height()])
	print("Frame size: %dx%d" % [frame_width, frame_height])

	for i in range(10):
		var tex: = AtlasTexture.new()
		tex.atlas = strip_texture
		tex.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.append(tex)

	leg_frames = frames.slice(FRAME_WALK_LEG_1, FRAME_WALK_LEG_4 + 1)
	print("Frames created: %d, Leg frames: %d" % [frames.size(), leg_frames.size()])


func update_animation(delta: float, is_walking_state: bool, is_kneeling_state: bool, in_water_state: bool) -> void:
	if is_walking_state and leg_frames.size() > 0 and not in_water_state:
		leg_timer += delta
		if leg_timer >= leg_frame_time:
			leg_timer -= leg_frame_time
			leg_index = (leg_index + 1) % leg_frames.size()
		legs_sprite.texture = leg_frames[leg_index]
		legs_sprite.visible = true
	else:
		legs_sprite.visible = false
		leg_timer = 0.0
		leg_index = 0

	if frames.size() > 0:
		var frame_idx: = get_torso_frame(is_walking_state, is_kneeling_state)
		torso_sprite.texture = frames[frame_idx]

	var flip: = (facing_lr == "right")
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
		return FRAME_KNEEL_BACK if face == "back" else FRAME_KNEEL_FRONT
	if is_walking_state:
		return FRAME_TORSO_BACK if face == "back" else FRAME_TORSO_FRONT
	return FRAME_STAND_BACK if face == "back" else FRAME_STAND_FRONT


func get_direction() -> String:
	if face == "back":
		return "N"
	else:
		return "S"


func get_facing_lr() -> String:
	return facing_lr


func set_visual_offset(offset_y: float) -> void:
	torso_sprite.position.y = offset_y
	legs_sprite.position.y = offset_y
