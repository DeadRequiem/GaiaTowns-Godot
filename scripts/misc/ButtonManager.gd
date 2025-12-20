
extends Node

signal sound_toggled(enabled: bool)
signal pose_toggled(is_sitting: bool)
signal avatar_refresh_requested()
signal emote_menu_requested()
signal chat_log_requested()
signal report_requested()
signal directory_requested()
signal ignore_requested()
signal temp_button_1_pressed()
signal temp_button_2_pressed()
signal temp_button_3_pressed()


var sound_button: TextureButton
var pose_button: TextureButton
var avatar_refresh_button: TextureButton
var emote_button: TextureButton
var chat_log_button: TextureButton
var report_button: TextureButton
var directory_button: TextureButton
var ignore_button: TextureButton
var temp_button_1: TextureButton
var temp_button_2: TextureButton
var temp_button_3: TextureButton


var sound_enabled: bool = true
var is_sitting: bool = false


func initialize(buttons_dict: Dictionary) -> void :
	sound_button = buttons_dict.get("sound")
	pose_button = buttons_dict.get("pose")
	avatar_refresh_button = buttons_dict.get("avatar_refresh")
	emote_button = buttons_dict.get("emote")
	chat_log_button = buttons_dict.get("chat_log")
	report_button = buttons_dict.get("report")
	directory_button = buttons_dict.get("directory")
	ignore_button = buttons_dict.get("ignore")
	temp_button_1 = buttons_dict.get("temp_1")
	temp_button_2 = buttons_dict.get("temp_2")
	temp_button_3 = buttons_dict.get("temp_3")
	setup_connections()


func setup_connections() -> void :
	if sound_button:
		sound_button.pressed.connect(_on_sound_toggled)

	if pose_button:
		pose_button.pressed.connect(_on_pose_toggled)

	if avatar_refresh_button:
		avatar_refresh_button.pressed.connect(_on_avatar_refresh_pressed)

	if emote_button:
		emote_button.pressed.connect(_on_emote_pressed)

	if chat_log_button:
		chat_log_button.pressed.connect(_on_chat_log_pressed)

	if report_button:
		report_button.pressed.connect(_on_report_pressed)

	if directory_button:
		directory_button.pressed.connect(_on_directory_pressed)

	if ignore_button:
		ignore_button.pressed.connect(_on_ignore_pressed)

	if temp_button_1:
		temp_button_1.pressed.connect(_on_temp_button_1_pressed)

	if temp_button_2:
		temp_button_2.pressed.connect(_on_temp_button_2_pressed)

	if temp_button_3:
		temp_button_3.pressed.connect(_on_temp_button_3_pressed)


func _on_sound_toggled() -> void :
	sound_enabled = not sound_enabled
	sound_toggled.emit(sound_enabled)

func _on_pose_toggled() -> void :
	is_sitting = not is_sitting
	pose_toggled.emit(is_sitting)

func _on_avatar_refresh_pressed() -> void :
	avatar_refresh_requested.emit()

func _on_emote_pressed() -> void :
	emote_menu_requested.emit()

func _on_chat_log_pressed() -> void :
	chat_log_requested.emit()

func _on_report_pressed() -> void :
	report_requested.emit()

func _on_directory_pressed() -> void :
	directory_requested.emit()

func _on_ignore_pressed() -> void :
	ignore_requested.emit()

func _on_temp_button_1_pressed() -> void :
	temp_button_1_pressed.emit()

func _on_temp_button_2_pressed() -> void :
	temp_button_2_pressed.emit()

func _on_temp_button_3_pressed() -> void :
	temp_button_3_pressed.emit()


func is_sound_enabled() -> bool:
	return sound_enabled

func is_player_sitting() -> bool:
	return is_sitting
