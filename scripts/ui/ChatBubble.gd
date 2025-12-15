extends VBoxContainer

const MAX_BUBBLES = 3

var username: String = ""
var messages: Array = []

@onready var username_label: Label = $UsernamePanel/UsernameLabel
@onready var messages_container: VBoxContainer = $MessagesContainer


func _ready() -> void:
	set("theme_override_constants/separation", 0)
	
	# Apply font to username label
	if username_label and FontManager.fonts_loaded:
		username_label.add_theme_font_override("font", FontManager.get_chat_font())
	
	if not username.is_empty() and username_label:
		username_label.text = username
		username_label.visible = true


func set_username(new_username: String) -> void:
	username = new_username
	if username_label:
		username_label.text = username
		username_label.visible = true
		
		# Apply font
		if FontManager.fonts_loaded:
			username_label.add_theme_font_override("font", FontManager.get_chat_font())
		
		username_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		username_label.reset_size()
		username_label.queue_redraw()


func add_message(text: String) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_width_top = 0
	style.border_color = Color(0.545, 0.451, 0.333, 1)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.176, 0.141, 0.086, 1))
	label.add_theme_font_size_override("font_size", 14)
	
	# CRITICAL: Apply the font with emoji/Unicode support
	if FontManager.fonts_loaded:
		label.add_theme_font_override("font", FontManager.get_chat_font())
	
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(150, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	
	panel.add_child(label)
	messages_container.add_child(panel)
	
	var lifetime := calculate_lifetime(text)
	var current_time := Time.get_ticks_msec() / 1000.0
	
	var message_data := {
		"panel": panel,
		"style": style,
		"expire_time": current_time + lifetime,
		"fade_start_time": current_time + lifetime - 0.5
	}
	
	messages.append(message_data)
	
	if messages.size() > MAX_BUBBLES:
		var oldest = messages.pop_front()
		if is_instance_valid(oldest.panel):
			oldest.panel.queue_free()
	
	update_last_message_style()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)


func calculate_lifetime(text: String) -> float:
	var char_count := text.length()
	if char_count <= 20:
		return 4.0
	elif char_count <= 40:
		return 6.0
	elif char_count <= 80:
		return 8.0
	else:
		return 10.0


func clear_messages() -> void:
	for msg in messages:
		if is_instance_valid(msg.panel):
			msg.panel.queue_free()
	
	messages.clear()
	username = ""
	
	if username_label:
		username_label.text = ""


func update_last_message_style() -> void:
	for i in range(messages.size()):
		if not is_instance_valid(messages[i].panel):
			continue
		
		var style: StyleBoxFlat = messages[i].style
		
		if i == messages.size() - 1:
			style.corner_radius_bottom_left = 8
			style.corner_radius_bottom_right = 8
		else:
			style.corner_radius_bottom_left = 0
			style.corner_radius_bottom_right = 0


func _process(_delta: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	var i := 0
	var needs_style_update := false
	
	while i < messages.size():
		var msg = messages[i]
		
		if not is_instance_valid(msg.panel):
			messages.remove_at(i)
			needs_style_update = true
			continue
		
		if current_time >= msg.fade_start_time and current_time < msg.expire_time:
			var fade_duration := 0.5
			var time_remaining: float = msg.expire_time - current_time
			msg.panel.modulate.a = time_remaining / fade_duration
		
		if current_time >= msg.expire_time:
			msg.panel.queue_free()
			messages.remove_at(i)
			needs_style_update = true
		else:
			i += 1
	
	if needs_style_update:
		update_last_message_style()
