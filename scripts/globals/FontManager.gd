extends Node

var chat_font: FontVariation
var ui_font: FontVariation
var fonts_loaded: bool = false

func _ready() -> void:
	setup_fonts()

func setup_fonts() -> void:
	var main_font = load("res://assets/fonts/NotoSans-Regular.ttf")
	var symbols_font = load("res://assets/fonts/NotoSansSymbols-Regular.ttf")
	var emoji_font = load("res://assets/fonts/NotoColorEmoji-Regular.ttf")
	
	if not main_font or not symbols_font or not emoji_font:
		push_error("FontManager: Failed to load one or more fonts!")
		fonts_loaded = false
		return

	chat_font = FontVariation.new()
	chat_font.base_font = main_font
	chat_font.fallbacks = [symbols_font, emoji_font]
	chat_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	chat_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	ui_font = FontVariation.new()
	ui_font.base_font = main_font
	ui_font.fallbacks = [symbols_font, emoji_font]
	ui_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	ui_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	fonts_loaded = true

func get_chat_font() -> FontVariation:
	if not fonts_loaded:
		push_warning("FontManager: Fonts not loaded yet!")
	return chat_font

func get_ui_font() -> FontVariation:
	if not fonts_loaded:
		push_warning("FontManager: Fonts not loaded yet!")
	return ui_font

func contains_emoji(text: String) -> bool:
	for i in range(text.length()):
		var code = text.unicode_at(i)
		if is_emoji_codepoint(code):
			return true
	return false

func is_emoji_codepoint(code: int) -> bool:
	return ((code >= 0x1F600 and code <= 0x1F64F) or
		(code >= 0x1F300 and code <= 0x1F5FF) or
		(code >= 0x1F680 and code <= 0x1F6FF) or
		(code >= 0x1F900 and code <= 0x1F9FF) or
		(code >= 0x2600 and code <= 0x26FF) or
		(code >= 0x2700 and code <= 0x27BF) or
		(code >= 0xFE00 and code <= 0xFE0F))
