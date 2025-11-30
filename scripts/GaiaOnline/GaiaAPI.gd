# Gaia API Singleton - Handles user authentication and data
extends Node

signal user_data_ready(user_data: Dictionary)

const GSI_BASE_URL := "https://www.gaiaonline.com/chat/gsi/json.php"

var user_data: Dictionary = {}
var is_authenticated: bool = false

# Fallback for local testing
var debug_mode: bool = true
var debug_username: String = "TestPlayer"
var debug_avatar_url: String = "https://a1cdn.gaiaonline.com/dress-up/avatar/ava/04/76/473a36c72c57604_flip.png"


func _ready() -> void:
	# Check if we're running in a browser
	if OS.has_feature("web"):
		debug_mode = false
		# JavaScript will call set_user_data_from_js() with user info
		print("Running in browser - waiting for user data from JavaScript")
	else:
		print("Running locally - using debug credentials")
		# Use debug credentials for local testing
		set_debug_user_data()


func set_debug_user_data() -> void:
	"""Used for local testing when not in browser"""
	user_data = {
		"gaia_id": 0,
		"username": debug_username,
		"avatar_url": debug_avatar_url,
		"user_level": 0,
		"account_age": 0,
		"gender": "Unknown"
	}
	is_authenticated = true
	user_data_ready.emit(user_data)
	print("Debug user data set: %s" % user_data["username"])


func set_user_data_from_js(data: Dictionary) -> void:
	"""Called by JavaScript bridge when user data is fetched from GSI"""
	if data.is_empty():
		push_error("Received empty user data from JavaScript")
		return
	
	user_data = data
	is_authenticated = true
	user_data_ready.emit(user_data)
	print("User authenticated: %s (ID: %d)" % [user_data.get("username", "Unknown"), user_data.get("gaia_id", 0)])


func get_username() -> String:
	return user_data.get("username", "Guest")


func get_user_id() -> int:
	return user_data.get("gaia_id", 0)


func get_avatar_url() -> String:
	var url: String = user_data.get("avatar_url", "")
	
	# Ensure we're using the _strip version
	if url.ends_with("_flip.png"):
		url = url.split("?")[0]  # Remove query params first
		url = url.replace("_flip.png", "_strip.png")
	
	return url


func get_user_level() -> int:
	return user_data.get("user_level", 0)


func is_user_authenticated() -> bool:
	return is_authenticated


func reload_avatar() -> String:
	"""Force reload avatar with fresh cache buster"""
	var base_url := get_avatar_url()
	if base_url.is_empty():
		return ""
	
	# Add fresh timestamp for cache busting
	return base_url + "?t=" + str(Time.get_ticks_msec())
