class_name TajsCoreEventBus
extends RefCounted

var _listeners: Dictionary = {}
var _sticky: Dictionary = {}
var _logger

func _init(logger = null) -> void:
    _logger = logger

func on(event: String, callable: Callable, owner = null, once: bool = false) -> void:
    if event == "":
        return
    if not _listeners.has(event):
        _listeners[event] = []
    var entry := {
        "callable": callable,
        "owner": owner,
        "once": once
    }
    if _sticky.has(event):
        _safe_call(entry, _sticky[event])
        if once:
            return
    _listeners[event].append(entry)

func off(event: String, callable: Callable) -> void:
    if not _listeners.has(event):
        return
    var entries: Array = _listeners[event]
    var filtered: Array = []
    for entry in entries:
        if entry["callable"].is_valid() and entry["callable"] != callable:
            filtered.append(entry)
    _listeners[event] = filtered

func emit(event: String, payload: Dictionary = {}, sticky: bool = false) -> void:
    if sticky:
        _sticky[event] = payload
    if not _listeners.has(event):
        return
    var entries: Array = _listeners[event].duplicate()
    for entry in entries:
        if entry["owner"] != null and not is_instance_valid(entry["owner"]):
            _listeners[event].erase(entry)
            continue
        _safe_call(entry, payload)
        if entry["once"]:
            _listeners[event].erase(entry)

func _safe_call(entry: Dictionary, payload: Dictionary) -> void:
    var callable: Callable = entry["callable"]
    if callable == null or not callable.is_valid():
        return
    callable.call(payload)

func _log_warn(message: String) -> void:
    if _logger != null and _logger.has_method("warn"):
        _logger.warn("event_bus", message)
