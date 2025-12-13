
extends CanvasLayer

signal chat_message_sent(message: String)
signal username_clicked(username: String)

@onready var sound_button: TextureButton = $TopRightButtons / SoundButton
@onready var pose_button: TextureButton = $ChatBar / RightButtons / PoseButton
@onready var avatar_refresh_button: TextureButton = $ChatBar / RightButtons / AvatarRefresh
@onready var report_button: TextureButton = $ChatBar / MiddleButtons / ReportButton
@onready var directory_button: TextureButton = $ChatBar / MiddleButtons / DirectoryButton
@onready var ignore_button: TextureButton = $ChatBar / MiddleButtons / IgnoreButton
@onready var temp_button_1: TextureButton = $ChatBar / MiddleButtons / TempButton
@onready var temp_button_2: TextureButton = $ChatBar / MiddleButtons / TempButton2
@onready var temp_button_3: TextureButton = $ChatBar / MiddleButtons / TempButton3
@onready var emote_button: TextureButton = $ChatBar / LeftButtons / EmoteButton
@onready var chat_log_button: TextureButton = $ChatBar / LeftButtons / ChatlogButton
@onready var chat_input: TextEdit = $ChatBar / ChatInput
@onready var chat_log_window: Panel = $ChatLogWindow
@onready var chat_log_messages: RichTextLabel = $ChatLogWindow / MarginContainer / ScrollContainer / Messages
@onready var chat_scroll: ScrollContainer = $ChatLogWindow / MarginContainer / ScrollContainer
@onready var location_label: Label = $LocationLabel

var chat_system: CanvasLayer = null
var button_manager: Node = null
var chat_log_open: bool = false
var current_username: String = "Player"
var message_count: int = 0
var max_messages: int = 100
const MAX_MESSAGE_LENGTH: = 255


func _ready() -> void :
	setup_button_manager()
	setup_chat_input()
	setup_chat_log()

	if has_node("/root/PlayerPreferences"):
		var prefs = get_node("/root/PlayerPreferences")
		prefs.chat_color_changed.connect(_on_chat_color_changed)


func _on_chat_color_changed(username: String, color: Color) -> void :
	pass


func setup_button_manager() -> void :
	button_manager = preload("res://scripts/misc/ButtonManager.gd").new()
	add_child(button_manager)

	var buttons: = {
		"sound": sound_button, 
		"pose": pose_button, 
		"avatar_refresh": avatar_refresh_button, 
		"emote": emote_button, 
		"chat_log": chat_log_button, 
		"report": report_button, 
		"directory": directory_button, 
		"ignore": ignore_button, 
		"temp_1": temp_button_1, 
		"temp_2": temp_button_2, 
		"temp_3": temp_button_3
	}

	button_manager.initialize(buttons)
	button_manager.sound_toggled.connect(_on_sound_toggled)
	button_manager.pose_toggled.connect(_on_pose_toggled)
	button_manager.avatar_refresh_requested.connect(_on_avatar_refresh_requested)
	button_manager.chat_log_requested.connect(_on_chat_log_toggled)


func setup_chat_input() -> void :
	chat_input.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	chat_input.scroll_fit_content_height = true
	chat_input.gui_input.connect(_on_chat_input_gui_input)
	chat_input.focus_mode = Control.FOCUS_ALL
	chat_input.text_changed.connect(_on_chat_text_changed)


func setup_chat_log() -> void :
	if chat_log_messages:
		chat_log_messages.bbcode_enabled = true
		chat_log_messages.scroll_following = true
		chat_log_messages.fit_content = true
		chat_log_messages.meta_underlined = false
		chat_log_messages.meta_clicked.connect(_on_chat_username_clicked)
		chat_log_messages.selection_enabled = true
		chat_log_messages.context_menu_enabled = true

	if chat_scroll:
		chat_scroll.follow_focus = true


func _on_chat_username_clicked(meta: Variant) -> void :
	if typeof(meta) == TYPE_STRING:
		username_clicked.emit(str(meta))


func _on_chat_input_gui_input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_send_chat_message()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			get_viewport().set_input_as_handled()


func _send_chat_message() -> void :
	var message: = chat_input.text.strip_edges()
	if message.is_empty():
		return
	chat_message_sent.emit(message)
	chat_input.text = ""


func _on_chat_text_changed() -> void :
	if chat_input.text.length() > MAX_MESSAGE_LENGTH:
		var caret_pos = chat_input.get_caret_column()
		chat_input.text = chat_input.text.substr(0, MAX_MESSAGE_LENGTH)
		chat_input.set_caret_column(min(caret_pos, MAX_MESSAGE_LENGTH))


func _on_sound_toggled(enabled: bool) -> void :
	if AudioManager:
		AudioManager.set_master_sound(enabled)


func _on_pose_toggled(is_sitting: bool) -> void :
	pass


func _on_avatar_refresh_requested() -> void :
	pass


func _on_chat_log_toggled() -> void :
	chat_log_open = not chat_log_open
	toggle_chat_log()


func toggle_chat_log() -> void :
	chat_log_window.visible = chat_log_open

	if chat_log_open:
		await get_tree().process_frame
		await get_tree().process_frame
		if chat_scroll:
			chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)


func add_chat_message(username: String, message: String) -> void :
	if not chat_log_messages:
		return

	message_count += 1

	var safe_msg: String = message
	safe_msg = safe_msg.replace("\\", "\\\\")
	safe_msg = safe_msg.replace("_", "\\_")
	safe_msg = safe_msg.replace("[", "\\[")
	safe_msg = safe_msg.replace("]", "\\]")

	var is_own: = (username == current_username)
	var username_color: Color

	if is_own:
		username_color = Color("#FF6B6B")
	elif has_node("/root/PlayerPreferences"):
		var prefs = get_node("/root/PlayerPreferences")
		username_color = prefs.get_chat_color(username)
	else:
		username_color = Color.WHITE

	var formatted_text: = "[url=%s][color=#%s]%s:[/color][/url] [color=#FFFFFF]%s[/color]\n" % [
		username, 
		username_color.to_html(), 
		username, 
		safe_msg
	]

	chat_log_messages.append_text(formatted_text)

	if message_count > max_messages:
		var full_text = chat_log_messages.text
		var first_newline = full_text.find("\n")
		if first_newline != -1:
			chat_log_messages.clear()
			chat_log_messages.append_text(full_text.substr(first_newline + 1))
			message_count = max_messages


	if chat_log_open:
		call_deferred("_scroll_to_bottom")


func _scroll_to_bottom() -> void :
	if chat_scroll and is_instance_valid(chat_scroll):
		await get_tree().process_frame
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)


func show_chat_bubble(player_id: int, username: String, message: String, world_pos: Vector2) -> void :
	if chat_system:
		chat_system.show_chat_bubble(player_id, username, message, world_pos)


func update_player_bubble_position(player_id: int, world_pos: Vector2) -> void :
	if chat_system:
		chat_system.update_player_position(player_id, world_pos)


func clear_player_bubbles(player_id: int) -> void :
	if chat_system:
		chat_system.clear_player_bubbles(player_id)


func set_username(username: String) -> void :
	current_username = username


func is_blocking_input() -> bool:
	return chat_input.has_focus()


func set_chat_system(system: CanvasLayer) -> void :
	chat_system = system


func update_location_display(map_id: int, barton_id: int) -> void :
	if not location_label:
		return
	location_label.text = "%d Barton %d" % [map_id, barton_id]


func is_sitting() -> bool:
	return button_manager.is_player_sitting() if button_manager else false


func is_sound_enabled() -> bool:
	return button_manager.is_sound_enabled() if button_manager else true
