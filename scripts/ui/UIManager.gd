# UI Manager - Handles all game UI elements
extends CanvasLayer

signal chat_message_sent(message: String)
signal sound_toggled(enabled: bool)
signal pose_toggled(is_sitting: bool)

@onready var sound_button: TextureButton = $TopRightButtons/SoundButton
@onready var pose_button: TextureButton = $ChatBar/RightButtons/PoseButton
@onready var report_button: TextureButton = $ChatBar/RightButtons/ReportButton
@onready var directory_button: TextureButton = $ChatBar/RightButtons/DirectoryButton
@onready var ignore_button: TextureButton = $ChatBar/RightButtons/IgnoreButton
@onready var emote_button: TextureButton = $ChatBar/LeftButtons/EmoteButton
@onready var chat_log_button: TextureButton = $ChatBar/LeftButtons/ChatlogButton
@onready var chat_input: TextEdit = $ChatBar/ChatInput
@onready var chat_log_window: Panel = $ChatLogWindow
@onready var chat_log_messages: VBoxContainer = $ChatLogWindow/ScrollContainer/Messages
@onready var location_label: Label = $LocationLabel  # New location display

var chat_system: CanvasLayer = null
var sound_enabled: bool = true
var is_sitting: bool = false
var chat_log_open: bool = false
var emote_menu_open: bool = false
var current_username: String = "Player"
var max_messages: int = 100
const MAX_MESSAGE_LENGTH := 255


func _ready() -> void:
	setup_connections()
	
	chat_input.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	chat_input.scroll_fit_content_height = true
	chat_input.gui_input.connect(_on_chat_input_gui_input)
	chat_input.focus_mode = Control.FOCUS_ALL
	chat_input.text_changed.connect(_on_chat_text_changed)
	
	# Location display will be set when map loads


func setup_connections() -> void:
	sound_button.pressed.connect(_on_sound_toggled)
	pose_button.pressed.connect(_on_pose_toggled)
	report_button.pressed.connect(_on_report_pressed)
	directory_button.pressed.connect(_on_directory_pressed)
	ignore_button.pressed.connect(_on_ignore_pressed)
	emote_button.pressed.connect(_on_emote_toggled)
	chat_log_button.pressed.connect(_on_chat_log_toggled)


func _on_chat_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_send_chat_message()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			get_viewport().set_input_as_handled()


func _send_chat_message() -> void:
	var message := chat_input.text.strip_edges()
	if message.is_empty():
		return
	chat_message_sent.emit(message)
	chat_input.text = ""


func _on_chat_text_changed() -> void:
	if chat_input.text.length() > MAX_MESSAGE_LENGTH:
		var caret_pos = chat_input.get_caret_column()
		chat_input.text = chat_input.text.substr(0, MAX_MESSAGE_LENGTH)
		# Restore caret position (clamped to new length)
		chat_input.set_caret_column(min(caret_pos, MAX_MESSAGE_LENGTH))


func _on_sound_toggled() -> void:
	sound_enabled = not sound_enabled
	sound_toggled.emit(sound_enabled)


func _on_pose_toggled() -> void:
	is_sitting = not is_sitting
	pose_toggled.emit(is_sitting)


func _on_chat_log_toggled() -> void:
	chat_log_open = not chat_log_open
	toggle_chat_log()


func _on_emote_toggled() -> void:
	emote_menu_open = not emote_menu_open


func _on_report_pressed() -> void:
	pass


func _on_directory_pressed() -> void:
	pass


func _on_ignore_pressed() -> void:
	pass


func toggle_chat_log() -> void:
	chat_log_window.visible = chat_log_open
	
	if chat_log_open:
		await get_tree().process_frame
		var scroll := chat_log_window.get_node("ScrollContainer") as ScrollContainer
		if scroll:
			scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


func add_chat_message(username: String, message: String) -> void:
	if not chat_log_messages:
		return
	
	var label := Label.new()
	var is_own := (username == current_username)
	var color := Color.WHITE if not is_own else Color.LIGHT_BLUE
	
	label.text = username + ": " + message
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	chat_log_messages.add_child(label)
	
	if chat_log_messages.get_child_count() > max_messages:
		var oldest := chat_log_messages.get_child(0)
		oldest.queue_free()
	
	await get_tree().process_frame
	var scroll := chat_log_window.get_node("ScrollContainer") as ScrollContainer
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


func show_chat_bubble(player_id: int, username: String, message: String, world_pos: Vector2) -> void:
	if chat_system:
		chat_system.show_chat_bubble(player_id, username, message, world_pos)


func update_player_bubble_position(player_id: int, world_pos: Vector2) -> void:
	if chat_system:
		chat_system.update_player_position(player_id, world_pos)


func clear_player_bubbles(player_id: int) -> void:
	if chat_system:
		chat_system.clear_player_bubbles(player_id)


func set_username(username: String) -> void:
	current_username = username


func is_blocking_input() -> bool:
	return chat_input.has_focus()


func set_chat_system(system: CanvasLayer) -> void:
	chat_system = system


# NEW: Update location display
func update_location_display(map_id: int, barton_id: int) -> void:
	if not location_label:
		return
	
	# Format: Map ID | Barton | Barton Number
	location_label.text = "%d Barton %d" % [map_id, barton_id]
