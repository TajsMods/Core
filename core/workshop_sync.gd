class_name TajsCoreWorkshopSync
extends Node

const LOG_NAME := "TajemnikTV-Core:WorkshopSync"

# Steam UGC Item State Flags (from Steamworks SDK)
const STATE_NONE := 0
const STATE_SUBSCRIBED := 1
const STATE_LEGACY_ITEM := 2
const STATE_INSTALLED := 4
const STATE_NEEDS_UPDATE := 8
const STATE_DOWNLOADING := 16
const STATE_DOWNLOAD_PENDING := 32

# Settings
var sync_on_startup := true
var high_priority_downloads := true
var force_download_all := true

# State
var _steam_available := false
var _sync_in_progress := false
var _triggered_ids: Dictionary = {}
var _pending_downloads: Dictionary = {}
var _total_triggered := 0
var _completed_count := 0
var _successful_count := 0
var _sync_timer: Timer = null
var _initial_timestamps: Dictionary = {}
const SYNC_TIMEOUT_SECONDS := 7.0

# Callbacks
var _on_restart_required: Callable = Callable()
var _debug_log_callback: Callable = Callable()
var _logger: Variant = null

signal sync_started()
signal sync_completed(updated_count: int)
signal download_progress(file_id: int, bytes_downloaded: int, bytes_total: int)
signal download_completed(workshop_id: int, success: bool)
signal restart_required(reason: String)

func setup(logger: Variant = null) -> void:
    _logger = logger

func _ready() -> void:
    _check_steam_availability()
    if _steam_available:
        _connect_steam_signals()

func _process(_delta: float) -> void:
    if _steam_available:
        var steam: Variant = _get_steam_api()
        if steam and steam.has_method("run_callbacks"):
            steam.run_callbacks()

func _get_steam_api() -> Object:
    if Engine.get_main_loop() and Engine.get_main_loop().root.has_node("GlobalSteam"):
        var global_steam: Variant = Engine.get_main_loop().root.get_node("GlobalSteam")
        if global_steam.initialized and global_steam.api != null:
            return global_steam.api
    if Engine.has_singleton("Steam"):
        return Engine.get_singleton("Steam")
    return null

func _check_steam_availability() -> void:
    if Engine.get_main_loop() and Engine.get_main_loop().root.has_node("GlobalSteam"):
        var global_steam: Variant = Engine.get_main_loop().root.get_node("GlobalSteam")
        if global_steam.initialized and global_steam.api != null:
            _steam_available = true
            _log("Steam is available via GlobalSteam. Workshop Sync enabled.")
            return
    if Engine.has_singleton("Steam"):
        var steam: Variant = Engine.get_singleton("Steam")
        if steam != null:
            _steam_available = true
            _log("Steam is available via Engine singleton. Workshop Sync enabled.")
            return
    _log("Steam not available. Workshop Sync disabled.")
    _steam_available = false

func _connect_steam_signals() -> void:
    var steam: Variant = _get_steam_api()
    if steam == null:
        return
    if steam.has_signal("item_downloaded"):
        if not steam.is_connected("item_downloaded", _on_item_downloaded):
            var _ignored: Variant = steam.connect("item_downloaded", _on_item_downloaded)
            _log("Connected to item_downloaded signal.")
    else:
        _log("item_downloaded signal not found. Will use timeout.")

func cancel_sync() -> void:
    if _sync_in_progress:
        _log("Sync cancelled.")
        _sync_in_progress = false
        _pending_downloads.clear()
        if _sync_timer and is_instance_valid(_sync_timer):
            _sync_timer.stop()

func start_sync() -> void:
    if not _steam_available:
        _log("Cannot sync: Steam not available.")
        return
    if _sync_in_progress:
        _log("Sync already in progress. Cancelling previous sync...")
        cancel_sync()
    _sync_in_progress = true
    _total_triggered = 0
    _completed_count = 0
    _successful_count = 0
    _pending_downloads.clear()
    var _ignored: Variant = emit_signal("sync_started")
    _log("Starting Workshop Sync...")
    var steam: Variant = _get_steam_api()
    if steam == null:
        _log("Failed to get Steam API.")
        _finish_sync()
        return
    var num_subscribed := _get_num_subscribed_items(steam)
    _log("Found " + str(num_subscribed) + " subscribed items.")
    if num_subscribed == 0:
        _finish_sync()
        return
    var subscribed_items := _get_subscribed_items(steam, num_subscribed)
    for file_id: Variant in subscribed_items:
        if _triggered_ids.has(file_id):
            continue
        var state := steam.getItemState(file_id) as int
        _log("Item " + str(file_id) + " state: " + str(state) + " (" + _state_to_string(state) + ")")
        _initial_timestamps[file_id] = _get_item_timestamp(steam, file_id)
        var should_trigger := false
        if force_download_all:
            should_trigger = (state & STATE_SUBSCRIBED) != 0
        else:
            should_trigger = _should_download(state)
        if should_trigger:
            _trigger_download(steam, file_id)
    if _total_triggered == 0:
        _log("All subscribed items are up to date.")
        _finish_sync()
    else:
        _log("Triggered downloads for " + str(_total_triggered) + " items.")
        _notify("download", "Workshop updates started (" + str(_total_triggered) + " items)")
        _start_sync_timer()

func _get_item_timestamp(steam: Variant, file_id: int) -> int:
    var install_info: Variant = steam.getItemInstallInfo(file_id)
    if install_info is Dictionary and install_info.has("timestamp"):
        return install_info["timestamp"]
    return 0

func _on_sync_timeout() -> void:
    if not _sync_in_progress:
        return
    _log("Sync timeout reached. Checking for silent updates...")
    var steam: Variant = _get_steam_api()
    if steam:
        var silent_updates := 0
        for file_id: Variant in _initial_timestamps:
            var old_ts: Variant = _initial_timestamps[file_id]
            var new_ts: Variant = _get_item_timestamp(steam, file_id)
            if new_ts > old_ts:
                _log("Detected silent update for item " + str(file_id) + " (Timestamp changed: " + str(old_ts) + " -> " + str(new_ts) + ")")
                silent_updates += 1
        if silent_updates > 0:
            _log("Found " + str(silent_updates) + " items updated silently.")
            _successful_count += silent_updates
    _pending_downloads.clear()
    _finish_sync()

func _get_num_subscribed_items(steam: Variant) -> int:
    if not steam.has_method("get_method_list"):
        return 0
    var methods: Variant = steam.get_method_list()
    for m: Variant in methods:
        if m["name"] == "getNumSubscribedItems":
            var args: Variant = m.get("args", [])
            if args.size() > 0:
                return steam.getNumSubscribedItems(true)
            return steam.getNumSubscribedItems()
    return 0

func _get_subscribed_items(steam: Variant, _count: int) -> Array:
    if not steam.has_method("get_method_list"):
        return []
    var methods: Variant = steam.get_method_list()
    for m: Variant in methods:
        if m["name"] == "getSubscribedItems":
            var args: Variant = m.get("args", [])
            if args.size() > 0:
                return steam.getSubscribedItems(true)
            return steam.getSubscribedItems()
    return []

func _should_download(state: int) -> bool:
    if state & STATE_NEEDS_UPDATE:
        return true
    if (state & STATE_SUBSCRIBED) and not (state & STATE_INSTALLED):
        return true
    return false

func _state_to_string(state: int) -> String:
    var flags: Array[String] = []
    if state & STATE_SUBSCRIBED:
        flags.append("Subscribed")
    if state & STATE_LEGACY_ITEM:
        flags.append("Legacy")
    if state & STATE_INSTALLED:
        flags.append("Installed")
    if state & STATE_NEEDS_UPDATE:
        flags.append("NeedsUpdate")
    if state & STATE_DOWNLOADING:
        flags.append("Downloading")
    if state & STATE_DOWNLOAD_PENDING:
        flags.append("DownloadPending")
    if flags.is_empty():
        return "None"
    return ", ".join(flags)

func _start_sync_timer() -> void:
    if _sync_timer == null:
        _sync_timer = Timer.new()
        _sync_timer.one_shot = true
        var _ignored: Variant = _sync_timer.timeout.connect(_on_sync_timeout)
        add_child(_sync_timer)
    _sync_timer.start(SYNC_TIMEOUT_SECONDS)
    _log("Sync timeout started (" + str(SYNC_TIMEOUT_SECONDS) + " seconds)")

func _trigger_download(steam: Variant, file_id: int) -> void:
    _log("Triggering download for item: " + str(file_id))
    steam.downloadItem(file_id, high_priority_downloads)
    _triggered_ids[file_id] = true
    _pending_downloads[file_id] = true
    _total_triggered += 1

func _on_item_downloaded(download_result: Variant) -> void:
    var file_id: int = 0
    var result: int = 0
    if download_result is Dictionary:
        file_id = download_result.get("file_id", 0)
        result = download_result.get("result", 0)
        _log("Download callback (dict): file_id=" + str(file_id) + ", result=" + str(result))
    else:
        _log("Download callback (old format): " + str(download_result))
        return
    if not _pending_downloads.has(file_id):
        return
    var _ignored_erase: Variant = _pending_downloads.erase(file_id)
    _completed_count += 1
    if result == 1:
        _log("Item " + str(file_id) + " downloaded successfully.")
        _successful_count += 1
        var _ignored_signal1: Variant = emit_signal("download_completed", file_id, true)
    else:
        _log("Item " + str(file_id) + " download failed with result: " + str(result))
        var _ignored_signal2: Variant = emit_signal("download_completed", file_id, false)
    var _ignored_signal3: Variant = emit_signal("download_progress", file_id, 0, 0)
    if _pending_downloads.is_empty():
        _finish_sync()

func _finish_sync() -> void:
    _sync_in_progress = false
    var _ignored_sync: Variant = emit_signal("sync_completed", _successful_count)
    if _successful_count > 0:
        _log("Workshop Sync complete. " + str(_successful_count) + " items were updated successfully.")
        _notify("check", "Workshop updates finished. Restart recommended.")
        var _ignored_restart: Variant = emit_signal("restart_required", "workshop_updates")
        if _on_restart_required.is_valid():
            _on_restart_required.call()
    elif _total_triggered > 0:
        _log("Workshop Sync finished. No updates detected (checked callbacks and timestamps).")
    else:
        _log("Workshop Sync complete. No updates needed.")

func set_restart_callback(callback: Callable) -> void:
    _on_restart_required = callback

func request_restart(reason: String) -> void:
    var _ignored: Variant = emit_signal("restart_required", reason)
    if _on_restart_required.is_valid():
        _on_restart_required.call()

func show_restart_dialog() -> void:
    _notify("reload", "Restart required")

func set_debug_log_callback(callback: Callable) -> void:
    _debug_log_callback = callback

func is_steam_available() -> bool:
    return _steam_available

func is_syncing() -> bool:
    return _sync_in_progress

func get_subscribed_items() -> Array[Dictionary]:
    var steam: Variant = _get_steam_api()
    if steam == null:
        return []
    var count := _get_num_subscribed_items(steam)
    if count <= 0:
        return []
    var items := _get_subscribed_items(steam, count)
    var results: Array[Dictionary] = []
    for file_id: Variant in items:
        var state := int(steam.getItemState(file_id))
        results.append({
            "id": file_id,
            "state": state,
            "installed": (state & STATE_INSTALLED) != 0
        })
    return results

func get_item_details(workshop_id: int) -> Dictionary:
    var steam: Variant = _get_steam_api()
    if steam == null:
        return {}
    if not steam.has_method("getItemInstallInfo"):
        return {}
    var info: Variant = steam.getItemInstallInfo(workshop_id)
    if info is Dictionary:
        return info
    return {}

func is_item_installed(workshop_id: int) -> bool:
    var steam: Variant = _get_steam_api()
    if steam == null:
        return false
    var state := int(steam.getItemState(workshop_id))
    return (state & STATE_INSTALLED) != 0

func get_item_install_path(workshop_id: int) -> String:
    var info := get_item_details(workshop_id)
    if info.has("folder"):
        return str(info["folder"])
    return ""

func _notify(icon: String, message: String) -> void:
    var signals: Variant = _get_root_node("Signals")
    if signals != null:
        if signals.has_signal("notify"):
            var _ignored: Variant = signals.emit_signal("notify", icon, message)
            return
    _log(message)

func _get_root_node(node_name: String) -> Node:
    if Engine.get_main_loop():
        var root: Variant = Engine.get_main_loop().root
        if root and root.has_node(node_name):
            return root.get_node(node_name)
    return null

func _log(message: String) -> void:
    if _logger != null and _logger.has_method("info"):
        _logger.info("workshop", message)
    elif _has_global_class("ModLoaderLog"):
        ModLoaderLog.info(message, LOG_NAME)
    else:
        print(LOG_NAME + ": " + message)
    if _debug_log_callback.is_valid():
        _debug_log_callback.call(message)


func _has_global_class(class_name_str: String) -> bool:
    for entry: Variant in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false
