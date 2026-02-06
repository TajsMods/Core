class_name TajsCoreTransactionCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

var commands: Array = []

func _init(desc: String, cmds: Array) -> void:
    description = desc
    commands = cmds

@warning_ignore("unsafe_method_access", "unsafe_cast")
func execute() -> bool:
    for cmd: Variant in commands:
        if typeof(cmd) == TYPE_OBJECT and cmd != null:
            var obj: Object = cmd
            if obj.has_method("execute"):
                if not obj.call("execute"):
                    return false
    return true

@warning_ignore("unsafe_method_access", "unsafe_cast")
func undo() -> bool:
    for i: int in range(commands.size() - 1, -1, -1):
        var cmd: Variant = commands[i]
        if typeof(cmd) == TYPE_OBJECT and cmd != null:
            var obj: Object = cmd
            if obj.has_method("undo"):
                if not obj.call("undo"):
                    return false
    return true

@warning_ignore("unsafe_method_access", "unsafe_cast")
func is_valid() -> bool:
    for cmd: Variant in commands:
        if typeof(cmd) == TYPE_OBJECT and cmd != null:
            var obj: Object = cmd
            if obj.has_method("is_valid"):
                if not obj.call("is_valid"):
                    return false
    return true
