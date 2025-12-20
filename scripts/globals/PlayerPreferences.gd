
extends Node

signal preference_changed(key: String, value: Variant)
signal chat_color_changed(username: String, color: Color)

const DEFAULT_SPEED_MULTIPLIER: = 1.0
const MIN_SPEED_MULTIPLIER: = 0.5
const MAX_SPEED_MULTIPLIER: = 2.0
const DEFAULT_HUE_SHIFT: = 0.0

var preferences: = {
	"speed_multiplier": DEFAULT_SPEED_MULTIPLIER, 
	"avatar_hue_shift": DEFAULT_HUE_SHIFT, 
	"chat_colors": {}, 
	"sound_enabled": true, 
	"music_volume": 1.0, 
	"sfx_volume": 1.0
}


func _ready() -> void :


	print("PlayerPreferences: Initialized (session-only)")


func set_preference(key: String, value: Variant) -> void :
	"Set a preference (session only, resets on refresh)"
	if preferences.has(key):
		preferences[key] = value
		preference_changed.emit(key, value)


func get_preference(key: String, default: Variant = null) -> Variant:
	"Get a preference value"
	return preferences.get(key, default)



func set_speed_multiplier(multiplier: float) -> void :
	"Set movement speed multiplier (clamped)"
	var clamped: = clampf(multiplier, MIN_SPEED_MULTIPLIER, MAX_SPEED_MULTIPLIER)
	set_preference("speed_multiplier", clamped)


func get_speed_multiplier() -> float:
	"Get current speed multiplier"
	return preferences.get("speed_multiplier", DEFAULT_SPEED_MULTIPLIER)



func set_avatar_hue_shift(hue: float) -> void :
	"Set avatar hue shift (0.0 to 1.0)"
	var clamped: = clampf(hue, 0.0, 1.0)
	set_preference("avatar_hue_shift", clamped)


func get_avatar_hue_shift() -> float:
	"Get current avatar hue shift"
	return preferences.get("avatar_hue_shift", DEFAULT_HUE_SHIFT)


func set_chat_color(username: String, color: Color) -> void :
	"Set custom color for a username in chat (session only)"
	if not preferences.has("chat_colors"):
		preferences["chat_colors"] = {}

	preferences["chat_colors"][username] = color.to_html()
	chat_color_changed.emit(username, color)


func get_chat_color(username: String) -> Color:
	"Get custom color for username, or white if not set"
	if not preferences.has("chat_colors"):
		return Color.WHITE

	var colors: Dictionary = preferences.get("chat_colors", {})
	if colors.has(username):
		return Color.html(colors[username])

	return Color.WHITE


func has_custom_chat_color(username: String) -> bool:
	"Check if username has a custom color"
	if not preferences.has("chat_colors"):
		return false

	var colors: Dictionary = preferences.get("chat_colors", {})
	return colors.has(username)


func remove_chat_color(username: String) -> void :
	"Remove custom color for username (session only)"
	if not preferences.has("chat_colors"):
		return

	var colors: Dictionary = preferences.get("chat_colors", {})
	if colors.has(username):
		colors.erase(username)
		chat_color_changed.emit(username, Color.WHITE)
