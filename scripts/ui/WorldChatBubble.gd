extends Node2D

# cfgs
const MAX_MESSAGES = 3
const BUBBLE_OFFSET = Vector2(10, -80)
const BUBBLE_WIDTH = 135
const MESSAGE_PADDING = 2
const USERNAME_PADDING = 4
const CORNER_RADIUS = 6
const MESSAGE_SPACING = 2
const USERNAME_FONT_SIZE = 10
const MESSAGE_FONT_SIZE = 13
const LINE_HEIGHT_MULTIPLIER = 1.2
const MESSAGE_BG_COLOR = Color(1, 1, 1, 1)
const MESSAGE_BORDER_COLOR = Color(0.545, 0.451, 0.333, 1)
const MESSAGE_TEXT_COLOR = Color(0.176, 0.141, 0.086, 1)
const USERNAME_BG_COLOR = Color(0.961, 0.902, 0.827, 1)
const DIVIDER_COLOR = Color(0.7, 0.6, 0.5, 1)

var messages: Array = []
var username: String = ""
var drawer: Node2D = null


func _ready() -> void:
	position = BUBBLE_OFFSET
	z_index = 9999
	z_as_relative = false


func set_username(new_username: String) -> void:
	username = new_username


func add_message(text: String) -> void:
	var lifetime = _calculate_lifetime(text)
	var current_time = Time.get_ticks_msec() / 1000.0
	
	var message_data = {
		"text": text,
		"expire_time": current_time + lifetime,
		"fade_start_time": current_time + lifetime - 0.5
	}
	
	messages.append(message_data)
	
	if messages.size() > MAX_MESSAGES:
		messages.pop_front()
	
	_rebuild_bubble()


func _rebuild_bubble() -> void:
	if is_instance_valid(drawer):
		drawer.queue_free()
	
	drawer = BubbleDrawer.new()
	drawer.username = username
	drawer.messages = messages.duplicate()
	
	if FontManager and FontManager.fonts_loaded:
		drawer.chat_font = FontManager.get_chat_font()
	
	drawer._calculate_dimensions()
	add_child(drawer)
	
	var total_height = drawer.total_height
	drawer.position = Vector2(-BUBBLE_WIDTH / 2.0, -total_height)
	
	drawer.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(drawer, "modulate:a", 1.0, 0.15)


func _calculate_lifetime(text: String) -> float:
	var char_count = text.length()
	if char_count <= 20:
		return 4.0
	elif char_count <= 40:
		return 6.0
	elif char_count <= 80:
		return 8.0
	else:
		return 10.0


func _process(_delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var i = 0
	var needs_update = false
	
	while i < messages.size():
		var msg = messages[i]
		
		if current_time >= msg.fade_start_time and current_time < msg.expire_time:
			var fade_duration = 0.5
			var time_remaining = msg.expire_time - current_time
			if is_instance_valid(drawer):
				drawer.modulate.a = time_remaining / fade_duration
		
		if current_time >= msg.expire_time:
			messages.remove_at(i)
			needs_update = true
		else:
			i += 1
	
	if needs_update:
		if messages.is_empty():
			if is_instance_valid(drawer):
				drawer.queue_free()
			drawer = null
		else:
			_rebuild_bubble()


func clear_messages() -> void:
	messages.clear()
	if is_instance_valid(drawer):
		drawer.queue_free()
		drawer = null


class BubbleDrawer extends Node2D:
	var username: String = ""
	var messages: Array = []
	var chat_font: Font = null
	var total_height: float = 0
	
	
	func _ready() -> void:
		if not chat_font:
			chat_font = ThemeDB.fallback_font
		queue_redraw()
	
	
	func _calculate_dimensions() -> void:
		if not chat_font:
			chat_font = ThemeDB.fallback_font
		
		total_height = 0
		
		if not username.is_empty():
			total_height += USERNAME_FONT_SIZE * LINE_HEIGHT_MULTIPLIER + USERNAME_PADDING * 2
			total_height += 1
		
		for msg in messages:
			var lines = _wrap_text(msg.text, BUBBLE_WIDTH - (MESSAGE_PADDING * 2), MESSAGE_FONT_SIZE)
			total_height += (lines.size() * MESSAGE_FONT_SIZE * LINE_HEIGHT_MULTIPLIER) + (MESSAGE_PADDING * 2) + MESSAGE_SPACING
	
	
	func _draw() -> void:
		if username.is_empty() and messages.is_empty():
			return
		
		var y_offset = 0.0
		
		if not username.is_empty():
			var username_height = USERNAME_FONT_SIZE * LINE_HEIGHT_MULTIPLIER + USERNAME_PADDING * 2
			var username_rect = Rect2(0, y_offset, BUBBLE_WIDTH, username_height)
			
			_draw_rounded_rect(username_rect, USERNAME_BG_COLOR, MESSAGE_BORDER_COLOR, true, true, false, false)
			
			var text_x = MESSAGE_PADDING
			var text_y = y_offset + USERNAME_PADDING + USERNAME_FONT_SIZE
			draw_string(chat_font, Vector2(text_x, text_y), username, HORIZONTAL_ALIGNMENT_LEFT, -1, USERNAME_FONT_SIZE, MESSAGE_TEXT_COLOR)
			
			y_offset += username_height
			
			if messages.size() > 0:
				draw_line(Vector2(2, y_offset), Vector2(BUBBLE_WIDTH - 2, y_offset), DIVIDER_COLOR, 1)
				y_offset += 1
		
		for i in messages.size():
			var msg = messages[i]
			var lines = _wrap_text(msg.text, BUBBLE_WIDTH - (MESSAGE_PADDING * 2), MESSAGE_FONT_SIZE)
			var message_height = (lines.size() * MESSAGE_FONT_SIZE * LINE_HEIGHT_MULTIPLIER) + (MESSAGE_PADDING * 2)
			
			var message_rect = Rect2(0, y_offset, BUBBLE_WIDTH, message_height)
			
			var is_first = (i == 0 and username.is_empty())
			var is_last = (i == messages.size() - 1)
			
			_draw_rounded_rect(message_rect, MESSAGE_BG_COLOR, MESSAGE_BORDER_COLOR, is_first, is_first, is_last, is_last)
			
			var text_y = y_offset + MESSAGE_PADDING + MESSAGE_FONT_SIZE
			for line in lines:
				var text_x = MESSAGE_PADDING
				draw_string(chat_font, Vector2(text_x, text_y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, MESSAGE_FONT_SIZE, MESSAGE_TEXT_COLOR)
				text_y += MESSAGE_FONT_SIZE * LINE_HEIGHT_MULTIPLIER
			
			y_offset += message_height + MESSAGE_SPACING
	
	
	func _wrap_text(text: String, max_width: float, font_size: int) -> Array[String]:
		var lines: Array[String] = []
		var current_line = ""

		for i in range(text.length()):
			var char = text[i]
			var test_line = current_line + char
			var line_width = chat_font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			
			# Check if we should wrap
			if line_width > max_width:
				# Try to break at last space
				var last_space = current_line.rfind(" ")
				if last_space > 0:
					# Break at space
					lines.append(current_line.substr(0, last_space))
					current_line = current_line.substr(last_space + 1) + char
				else:
					# No space found, break at character
					if not current_line.is_empty():
						lines.append(current_line)
					current_line = char
			else:
				current_line = test_line
		
		if not current_line.is_empty():
			lines.append(current_line)
		
		return lines
	
	
	func _draw_rounded_rect(rect: Rect2, fill_color: Color, border_color: Color, top_left: bool, top_right: bool, bottom_left: bool, bottom_right: bool) -> void:
		var radius = CORNER_RADIUS
		var border_width = 1.5
		
		draw_rect(rect, fill_color)
		
		if top_left:
			_draw_rounded_corner(rect.position + Vector2(radius, radius), radius, fill_color, PI, PI * 1.5)
		if top_right:
			_draw_rounded_corner(rect.position + Vector2(rect.size.x - radius, radius), radius, fill_color, PI * 1.5, PI * 2)
		if bottom_left:
			_draw_rounded_corner(rect.position + Vector2(radius, rect.size.y - radius), radius, fill_color, PI * 0.5, PI)
		if bottom_right:
			_draw_rounded_corner(rect.position + Vector2(rect.size.x - radius, rect.size.y - radius), radius, fill_color, 0, PI * 0.5)
		
		if top_left and top_right:
			draw_line(rect.position + Vector2(radius, 0), rect.position + Vector2(rect.size.x - radius, 0), border_color, border_width)
		elif top_left:
			draw_line(rect.position + Vector2(radius, 0), rect.position + Vector2(rect.size.x, 0), border_color, border_width)
		elif top_right:
			draw_line(rect.position, rect.position + Vector2(rect.size.x - radius, 0), border_color, border_width)
		else:
			draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), border_color, border_width)
		
		var right_start = radius if top_right else 0
		var right_end = rect.size.y - (radius if bottom_right else 0)
		draw_line(rect.position + Vector2(rect.size.x, right_start), rect.position + Vector2(rect.size.x, right_end), border_color, border_width)
		
		if bottom_left and bottom_right:
			draw_line(rect.position + Vector2(rect.size.x - radius, rect.size.y), rect.position + Vector2(radius, rect.size.y), border_color, border_width)
		elif bottom_left:
			draw_line(rect.position + Vector2(rect.size.x, rect.size.y), rect.position + Vector2(radius, rect.size.y), border_color, border_width)
		elif bottom_right:
			draw_line(rect.position + Vector2(rect.size.x - radius, rect.size.y), rect.position + Vector2(0, rect.size.y), border_color, border_width)
		else:
			draw_line(rect.position + Vector2(rect.size.x, rect.size.y), rect.position + Vector2(0, rect.size.y), border_color, border_width)
		
		var left_end = rect.size.y - (radius if bottom_left else 0)
		var left_start = radius if top_left else 0
		draw_line(rect.position + Vector2(0, left_end), rect.position + Vector2(0, left_start), border_color, border_width)
		
		if top_left:
			draw_arc(rect.position + Vector2(radius, radius), radius, PI, PI * 1.5, 8, border_color, border_width)
		if top_right:
			draw_arc(rect.position + Vector2(rect.size.x - radius, radius), radius, PI * 1.5, PI * 2, 8, border_color, border_width)
		if bottom_left:
			draw_arc(rect.position + Vector2(radius, rect.size.y - radius), radius, PI * 0.5, PI, 8, border_color, border_width)
		if bottom_right:
			draw_arc(rect.position + Vector2(rect.size.x - radius, rect.size.y - radius), radius, 0, PI * 0.5, 8, border_color, border_width)
	
	
	func _draw_rounded_corner(center: Vector2, radius: float, color: Color, start_angle: float, end_angle: float) -> void:
		var points = PackedVector2Array()
		points.append(center)
		
		var steps = 8
		for i in range(steps + 1):
			var angle = start_angle + (end_angle - start_angle) * i / steps
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		
		draw_colored_polygon(points, color)
