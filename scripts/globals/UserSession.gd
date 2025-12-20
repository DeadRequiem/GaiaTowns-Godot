extends Node

signal credentials_loaded(username: String, avatar_url: String)
signal admin_status_changed(is_admin: bool)

var username: String = ""
var avatar_url: String = ""
var keycode: String = ""
var admin_token: String = ""
var is_admin: bool = false
var username_color: String = "000000"


func _ready() -> void:
	load_credentials()


func get_server_url() -> String:
	return Config.get_http_url()


func get_random_fallback_avatar() -> String:
	var dir = DirAccess.open(Config.FALLBACK_AVATAR_FOLDER)
	if not dir:
		push_error("Cannot open fallback avatar folder: " + Config.FALLBACK_AVATAR_FOLDER)
		return ""

	var avatars: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			avatars.append(Config.FALLBACK_AVATAR_FOLDER + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	if avatars.is_empty():
		push_error("No fallback avatars found in: " + Config.FALLBACK_AVATAR_FOLDER)
		return ""

	return avatars[randi() % avatars.size()]


func load_credentials() -> void:
	if OS.has_feature("web"):
		var username_js = JavaScriptBridge.eval("window.gameUsername || ''")
		var avatar_url_js = JavaScriptBridge.eval("window.gameAvatarUrl || ''")
		var keycode_js = JavaScriptBridge.eval("window.gameKeycode || ''")
		var admin_token_js = JavaScriptBridge.eval(
			"document.cookie.split('; ').find(row => row.startsWith('admin_token='))?.split('=')[1] || ''"
		)

		username = str(username_js) if username_js != null else ""
		avatar_url = str(avatar_url_js) if avatar_url_js != null else ""
		keycode = str(keycode_js) if keycode_js != null else ""
		admin_token = str(admin_token_js) if admin_token_js != null else ""

		# Generate guest username if none provided
		if username.is_empty():
			username = generate_guest_username()

		# Use fallback avatar if URL is invalid or empty
		if avatar_url.is_empty() or not Config.is_valid_avatar_url(avatar_url):
			avatar_url = get_random_fallback_avatar()
			if avatar_url.is_empty():
				push_error("UserSession: Failed to get fallback avatar!")
			else:
				print("UserSession: Using fallback avatar: ", avatar_url)

		print("UserSession: Loaded credentials")
		print("  Username: ", username)
		print("  Avatar URL: ", avatar_url if not avatar_url.begins_with("res://") else "(fallback)")
		print("  Keycode: ", "***" if not keycode.is_empty() else "(MISSING!)")
		print("  Admin Token: ", "***" if not admin_token.is_empty() else "(none)")
		
		if keycode.is_empty():
			push_warning("UserSession: No keycode loaded! User may not be able to join.")

		credentials_loaded.emit(username, avatar_url)
	else:
		username = generate_guest_username()
		avatar_url = get_random_fallback_avatar()
		keycode = ""
		admin_token = ""
		credentials_loaded.emit(username, avatar_url)


func generate_guest_username() -> String:
	var random_number = randi() % 100000
	return "Guest_%05d" % random_number


func get_proxied_avatar_url(url: String) -> String:
	if url.begins_with("res://"):
		return url
	
	if not Config.is_valid_avatar_url(url):
		return get_random_fallback_avatar()

	var strip_url: = Config.to_strip_url(url)
	var cache_token: = str(int(Time.get_unix_time_from_system()))
	var busted_url: = "%s?t=%s" % [strip_url, cache_token]

	if OS.has_feature("web"):
		var encoded: = busted_url.uri_encode()
		var server_url: String = get_server_url()
		var proxied_url: String = "%s/avatar-proxy?url=%s" % [server_url, encoded]
		
		if Config.USE_PRODUCTION == false:
			print("UserSession: Proxied avatar URL: %s" % proxied_url)
		
		return proxied_url

	return get_random_fallback_avatar()


func set_admin_status(admin: bool) -> void:
	is_admin = admin
	admin_status_changed.emit(is_admin)
	if is_admin:
		print("UserSession: Admin status confirmed")
	else:
		print("UserSession: Not an admin")


func has_valid_credentials() -> bool:
	return not username.is_empty() and not avatar_url.is_empty()
