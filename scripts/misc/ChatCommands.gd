# ChatCommands.gd
extends Node

const COMMAND_PREFIX := "/"

signal local_action(action_type: String, data: Dictionary)

var commands: Dictionary = {}


func _ready() -> void:
	register_commands()


func register_commands() -> void:
	commands["spin"] = _cmd_spin


func is_command(message: String) -> bool:
	return message.strip_edges().begins_with(COMMAND_PREFIX)


func process(message: String) -> void:
	if not is_command(message):
		return
	
	var stripped := message.strip_edges()
	var parts: PackedStringArray = stripped.substr(1).split(" ", false)
	
	if parts.is_empty():
		return
	
	var cmd := parts[0].to_lower()
	var args: Array = Array(parts.slice(1)) if parts.size() > 1 else []
	
	if commands.has(cmd):
		commands[cmd].call(args)


func _cmd_spin(_args: Array) -> void:
	emit_action("spin")


func emit_action(action: String, data: Dictionary = {}) -> void:
	local_action.emit(action, data)
