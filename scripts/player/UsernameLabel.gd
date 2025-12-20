extends Label


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_theme_font_size_override("font_size", 14)
	z_index = 100


func set_username(username: String, color_hex: String = "000000") -> void:
	if username.length() > Config.MAX_USERNAME_LENGTH:
		text = username.substr(0, Config.MAX_USERNAME_LENGTH)
	else:
		text = username
	
	var color = Color.html(color_hex) if not color_hex.is_empty() else Color.BLACK
	add_theme_color_override("font_color", color)
