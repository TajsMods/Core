class_name TajsCoreUiHooks
extends Node

var _event_bus
var _last_menu: int = 0

func setup(event_bus) -> void:
    _event_bus = event_bus

func _ready() -> void:
    if not _autoload_ready("Signals"):
        return
    Signals.menu_set.connect(_on_menu_set)
    Signals.popup.connect(_on_popup)
    Signals.prompt.connect(_on_prompt)

func _on_menu_set(menu: int, tab: int) -> void:
    if menu != Utils.menu_types.NONE and _last_menu == Utils.menu_types.NONE:
        _emit_event("ui.menu_opened", {"menu": menu, "tab": tab})
    elif menu == Utils.menu_types.NONE and _last_menu != Utils.menu_types.NONE:
        _emit_event("ui.menu_closed", {"menu": _last_menu, "tab": tab})
    _last_menu = menu

func _on_popup(popup_id: String) -> void:
    _emit_event("ui.popup_shown", {"id": popup_id})

func _on_prompt(title: String, _desc: String, _callback: Callable) -> void:
    _emit_event("ui.popup_shown", {"id": title})

func _emit_event(event_name: String, data: Dictionary, cancellable: bool = false) -> Dictionary:
    if _event_bus == null:
        return {}
    if _event_bus.has_method("emit_event"):
        return _event_bus.emit_event(event_name, "core", data, cancellable)
    if _event_bus.has_method("emit"):
        var payload := {"source": "core", "timestamp": Time.get_unix_time_from_system(), "data": data, "cancellable": cancellable, "cancelled": false}
        _event_bus.emit(event_name, payload)
        return payload
    return {}

func _autoload_ready(autoload_name: String) -> bool:
    var tree = Engine.get_main_loop()
    if not (tree is SceneTree):
        return false
    return tree.get_root().has_node(autoload_name)
