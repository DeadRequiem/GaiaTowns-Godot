# ChatBubble.gd - Stack of chat bubbles for one player
extends VBoxContainer

const MAX_BUBBLES = 3

var username: String = ""
var messages: Array = []

@onready var username_label: Label = $UsernamePanel/UsernameLabel
@onready var messages_container: VBoxContainer = $MessagesContainer


func _ready() -> void:
	username_label.text = username


func set_username(new_username: String) -> void:
	username = new_username
	if username_label:
		username_label.text = username


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
	style.content_margin_top = 6.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 6.0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	
	panel.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.176, 0.141, 0.086, 1))
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(115, 0)
	
	panel.add_child(label)
	messages_container.add_child(panel)
	
	var lifetime := calculate_lifetime(text)
	
	var message_data := {
		"panel": panel,
		"style": style,
		"lifetime": 0.0,
		"max_lifetime": lifetime
	}
	
	messages.append(message_data)
	
	if messages.size() > MAX_BUBBLES:
		var oldest = messages.pop_front()
		if is_instance_valid(oldest.panel):
			oldest.panel.queue_free()
	
	update_last_message_style()
	
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


func _process(delta: float) -> void:
	var i := 0
	var needs_style_update := false
	
	while i < messages.size():
		var msg = messages[i]
		
		if not is_instance_valid(msg.panel):
			messages.remove_at(i)
			needs_style_update = true
			continue
		
		msg.lifetime += delta
		
		if msg.lifetime >= msg.max_lifetime - 0.5:
			msg.panel.modulate.a = (msg.max_lifetime - msg.lifetime) / 0.5
		
		if msg.lifetime >= msg.max_lifetime:
			msg.panel.queue_free()
			messages.remove_at(i)
			needs_style_update = true
		else:
			i += 1
	
	if needs_style_update:
		update_last_message_style()
