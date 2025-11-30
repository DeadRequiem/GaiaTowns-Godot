# Username Label
extends Label

const MAX_USERNAME_LENGTH: int = 32

func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_TOP

	add_theme_color_override("font_color", Color.BLACK)
	add_theme_font_size_override("font_size", 14)
	z_index = 100


func set_username(username: String) -> void:
	# Truncate if too long
	if username.length() > MAX_USERNAME_LENGTH:
		text = username.substr(0, MAX_USERNAME_LENGTH)
	else:
		text = username
