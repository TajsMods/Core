class_name TajsCoreEventBus
extends RefCounted

## Lightweight pub/sub event bus used by Taj's mods.
##
## Payloads are dictionaries by convention. Handlers should accept a single
## [code]Dictionary[/code] argument.
var _listeners: Dictionary = {}
var _sticky: Dictionary = {}
var _logger: Variant

func _init(logger: Variant = null) -> void:
    _logger = logger

## Subscribes [param callable] to [param event].
##
## If [param once] is true, handler runs once then auto-unsubscribes.
## If a sticky payload already exists, it is delivered immediately.
func on(event: String, callable: Callable, owner: Variant = null, once: bool = false) -> void:
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

## Unsubscribes a specific callable from an event.
func off(event: String, callable: Callable) -> void:
    if not _listeners.has(event):
        return
    var entries: Array = _listeners[event]
    var filtered: Array = []
    for entry: Variant in entries:
        if entry["callable"].is_valid() and entry["callable"] != callable:
            filtered.append(entry)
    _listeners[event] = filtered

## Emits an event with optional dictionary payload.
##
## Non-dictionary payload values are ignored and replaced with an empty dictionary.
## Set [param sticky] to cache latest payload for late subscribers.
func emit(event: String, payload: Variant = null, sticky: bool = false) -> void:
    var safe_payload: Dictionary = {}
    if payload is Dictionary:
        safe_payload = payload
    if sticky:
        _sticky[event] = safe_payload
    if not _listeners.has(event):
        return
    var entries: Array = _listeners[event].duplicate()
    for entry: Variant in entries:
        if entry["owner"] != null and not is_instance_valid(entry["owner"]):
            _listeners[event].erase(entry)
            continue
        _safe_call(entry, safe_payload)
        if entry["once"]:
            _listeners[event].erase(entry)

## Emits a standardized event payload with metadata.
##
## Returns the emitted payload dictionary so callers can inspect cancellation flags.
func emit_event(event: String, source: String, data: Dictionary = {}, cancellable: bool = false, sticky: bool = false) -> Dictionary:
    var payload := {
        "source": source,
        "timestamp": Time.get_unix_time_from_system(),
        "data": data,
        "cancellable": cancellable,
        "cancelled": false
    }
    emit(event, payload, sticky)
    return payload

func get_listener_count(event: String) -> int:
    if not _listeners.has(event):
        return 0
    return _listeners[event].size()

func list_events() -> Array[String]:
    var events: Array[String] = []
    for key: Variant in _listeners.keys():
        events.append(str(key))
    return events

func get_sticky(event: String) -> Dictionary:
    if _sticky.has(event):
        return _sticky[event].duplicate(true)
    return {}

func _safe_call(entry: Dictionary, payload: Dictionary) -> void:
    var callable: Callable = entry["callable"]
    if callable == null or not callable.is_valid():
        _log_error("Invalid event handler.")
        return
    callable.call(payload)

func _log_warn(message: String) -> void:
    if _logger != null and _logger.has_method("warn"):
        _logger.warn("event_bus", message)

func _log_error(message: String) -> void:
    if _logger != null and _logger.has_method("error"):
        _logger.error("event_bus", message)
