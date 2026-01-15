class_name TajsCoreTransactionCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

var commands: Array = []

func _init(desc: String, cmds: Array) -> void:
    description = desc
    commands = cmds

func execute() -> bool:
    for cmd in commands:
        if not cmd.execute():
            return false
    return true

func undo() -> bool:
    for i in range(commands.size() - 1, -1, -1):
        if not commands[i].undo():
            return false
    return true

func is_valid() -> bool:
    for cmd in commands:
        if not cmd.is_valid():
            return false
    return true
