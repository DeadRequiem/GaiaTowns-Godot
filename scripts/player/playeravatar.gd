# Player Avatar
extends Node

signal avatar_loaded()

const FRAME_TORSO_FRONT := 0
const FRAME_TORSO_BACK  := 1
const FRAME_KNEEL_FRONT := 2
const FRAME_KNEEL_BACK  := 3
const FRAME_STAND_FRONT := 4
const FRAME_STAND_BACK  := 5
const FRAME_WALK_LEG_1  := 6
const FRAME_WALK_LEG_2  := 7
const FRAME_WALK_LEG_3  := 8
const FRAME_WALK_LEG_4  := 9

const FALLBACK_AVATAR := "res://assets/fallback_avatar.png"

@export var torso_sprite: Sprite2D
@export var legs_sprite: Sprite2D
@export var http_request: HTTPRequest

var avatar_url: String = ""
var strip_texture: Texture2D
var frames: Array[Texture2D] = []
var leg_frames: Array[Texture2D] = []
var face: String = "front"
var facing_lr: String = "right"
var leg_index: int = 0
var leg_timer: float = 0.0
var leg_frame_time: float = 0.12
var is_loading: bool = false
var pending_url: String = ""


func _ready() -> void:
	if http_request:
		if not http_request.request_completed.is_connected(_on_http_request_completed):
			http_request.request_completed.connect(_on_http_request_completed)


func load_avatar(url: String) -> void:
	# Handle local resources (fallback avatar)
	if url.begins_with("res://"):
		strip_texture = load(url)
		if strip_texture:
			slice_strip()
			avatar_loaded.emit()
			print("Local avatar loaded: " + url)
		else:
			push_error("Failed to load local avatar: " + url)
			load_fallback_avatar()
		return
	
	# Normalize to strip format
	var strip_url := to_strip_url(url)
	if is_loading:
		pending_url = strip_url
		return
	
	avatar_url = strip_url
	is_loading = true
	
	# Add cache-busting parameter
	var final_url := strip_url
	if not "?t=" in final_url and not "?" in final_url:
		final_url = strip_url + "?t=" + str(Time.get_unix_time_from_system())
	
	var headers := PackedStringArray([
		"Referer: https://www.gaiaonline.com/",
		"Cache-Control: no-cache, no-store, must-revalidate",
		"Pragma: no-cache"
	])
	
	print("Loading avatar from: %s" % final_url)
	http_request.request(final_url, headers)

func to_strip_url(url: String) -> String:
	if url.is_empty():
		return ""
	
	# Split off query parameters (like ?t=timestamp)
	var parts := url.split("?")
	var base_url := parts[0]
	var query_params := parts[1] if parts.size() > 1 else ""
	
	# Convert to strip format
	if base_url.ends_with("_flip.png"):
		base_url = base_url.replace("_flip.png", "_strip.png")
	elif base_url.ends_with(".png") and not base_url.ends_with("_strip.png"):
		base_url = base_url.replace(".png", "_strip.png")
	
	if not query_params.is_empty():
		return base_url + "?" + query_params
	return base_url

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
	slice_strip()
	avatar_loaded.emit()
	print("Avatar loaded successfully")
	check_pending_load()

func load_fallback_avatar() -> void:
	"""Load the fallback avatar when remote loading fails"""
	if ResourceLoader.exists(FALLBACK_AVATAR):
		strip_texture = load(FALLBACK_AVATAR)
		slice_strip()
		avatar_loaded.emit()
		print("Fallback avatar loaded")
	else:
		push_error("Fallback avatar not found at: " + FALLBACK_AVATAR)

func check_pending_load() -> void:
	"""Check if there's a pending avatar load request"""
	if not pending_url.is_empty():
		var url_to_load := pending_url
		pending_url = ""
		load_avatar(url_to_load)

func slice_strip() -> void:
	frames.clear()
	leg_frames.clear()	
	if not strip_texture:
		return
	
	var frame_width := strip_texture.get_width() / 10.0
	var frame_height := float(strip_texture.get_height())
	
	print("Strip texture size: %dx%d" % [strip_texture.get_width(), strip_texture.get_height()])
	print("Frame size: %dx%d" % [frame_width, frame_height])	
	for i in range(10):
		var tex := AtlasTexture.new()
		tex.atlas = strip_texture
		tex.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.append(tex)
	
	leg_frames = frames.slice(FRAME_WALK_LEG_1, FRAME_WALK_LEG_4 + 1)	
	print("Frames created: %d, Leg frames: %d" % [frames.size(), leg_frames.size()])

func update_animation(delta: float, is_walking: bool, is_kneeling: bool, in_water: bool) -> void:
	if is_walking and leg_frames.size() > 0 and not in_water:
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
		var frame_idx := get_torso_frame(is_walking, is_kneeling)
		torso_sprite.texture = frames[frame_idx]
	
	var flip := (facing_lr == "right")
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

func get_torso_frame(is_walking: bool, is_kneeling: bool) -> int:
	if is_kneeling:
		return FRAME_KNEEL_BACK if face == "back" else FRAME_KNEEL_FRONT
	if is_walking:
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
