class_name TajsCoreBoardGeometry
extends Node

const WINDOW_LAYER_PATH := "Windows"
const GROUP_LAYER_PATH := "CoreLayer_qol_groups"
const NOTES_LAYER_PATH := "StickyNotesContainer"

var _core: Variant
var _logger: Variant
var _event_bus: Variant

var _items_by_id: Dictionary = {}
var _tracked_nodes: Dictionary = {} # item_id -> WeakRef(node)
var _dirty := true
var _last_refresh_msec: int = 0

func setup(core: Variant, logger: Variant = null, event_bus: Variant = null) -> void:
    _core = core
    _logger = logger
    _event_bus = event_bus
    _bind_events()

func _ready() -> void:
    var tree := get_tree()
    if tree != null:
        if not tree.node_added.is_connected(_on_tree_node_added):
            tree.node_added.connect(_on_tree_node_added)
        if not tree.node_removed.is_connected(_on_tree_node_removed):
            tree.node_removed.connect(_on_tree_node_removed)

func mark_dirty() -> void:
    _dirty = true

func get_all_items(opts: Dictionary = {}) -> Array:
    _refresh_cache_if_needed(bool(opts.get("force_refresh", false)))
    var out: Array = []
    var allowed_types: Array = opts.get("types", [])
    for item_id: String in _items_by_id.keys():
        var item: Dictionary = _items_by_id[item_id]
        if not _accept_type(str(item.get("type", "")), allowed_types):
            continue
        if not bool(opts.get("include_hidden", true)) and not bool(item.get("visible", true)):
            continue
        out.append(item.duplicate(true))
    return out

func get_board_bounds(opts: Dictionary = {}) -> Rect2:
    var items: Array = get_all_items(opts)
    return _merge_item_bounds(items)

func get_item_bounds(item_id: String) -> Rect2:
    _refresh_cache_if_needed(false)
    if not _items_by_id.has(item_id):
        return Rect2()
    var rect: Variant = _items_by_id[item_id].get("rect", Rect2())
    return rect if rect is Rect2 else Rect2()

func get_viewport_world_rect() -> Rect2:
    var tree := get_tree()
    if tree == null:
        return Rect2()
    var viewport: Viewport = tree.root.get_viewport()
    if viewport == null:
        return Rect2()
    var camera: Camera2D = viewport.get_camera_2d()
    var visible_size: Vector2 = viewport.get_visible_rect().size
    if camera == null:
        return Rect2(Vector2.ZERO, visible_size)
    var world_size := visible_size / camera.zoom
    var top_left := camera.global_position - world_size * 0.5
    return Rect2(top_left, world_size)

func query_in_rect(rect: Rect2, opts: Dictionary = {}) -> Array:
    var items: Array = get_all_items(opts)
    var mode: String = str(opts.get("mode", "intersects")).to_lower()
    var out: Array = []
    for item: Dictionary in items:
        var item_rect: Variant = item.get("rect", Rect2())
        if not (item_rect is Rect2):
            continue
        var matches := false
        if mode == "enclosed":
            matches = rect.encloses(item_rect)
        elif mode == "center":
            matches = rect.has_point(item_rect.get_center())
        else:
            matches = rect.intersects(item_rect)
        if matches:
            out.append(item)
    if bool(opts.get("sort_by_distance", false)):
        var from_pos: Vector2 = opts.get("position", rect.get_center())
        out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            var ar: Rect2 = a.get("rect", Rect2())
            var br: Rect2 = b.get("rect", Rect2())
            return from_pos.distance_squared_to(ar.get_center()) < from_pos.distance_squared_to(br.get_center())
        )
    return out

func query_nearest_item(position: Vector2, opts: Dictionary = {}) -> Dictionary:
    var items: Array = get_all_items(opts)
    var best: Dictionary = {}
    var best_dist := INF
    for item: Dictionary in items:
        var item_rect: Variant = item.get("rect", Rect2())
        if not (item_rect is Rect2):
            continue
        var center: Vector2 = item_rect.get_center()
        var dist := position.distance_squared_to(center)
        if dist < best_dist:
            best_dist = dist
            best = item
    return best.duplicate(true) if not best.is_empty() else {}

func focus_item(item_id: String, opts: Dictionary = {}) -> bool:
    _refresh_cache_if_needed(false)
    if not _items_by_id.has(item_id):
        return false
    var item: Dictionary = _items_by_id[item_id]
    var rect: Rect2 = item.get("rect", Rect2())
    if rect.size == Vector2.ZERO:
        return false
    var center := rect.get_center()

    var viewport := get_tree().root.get_viewport() if get_tree() != null else null
    var camera: Camera2D = viewport.get_camera_2d() if viewport != null else null
    if camera == null:
        var signals := _get_autoload("Signals")
        if signals != null and signals.has_signal("center_camera"):
            signals.emit_signal("center_camera", center)
            return true
        return false

    var should_fit := bool(opts.get("fit", false))
    if should_fit:
        var padding: float = float(opts.get("padding", 0.15))
        var viewport_size: Vector2 = viewport.get_visible_rect().size
        var padded: Rect2 = rect.grow_individual(rect.size.x * padding, rect.size.y * padding, rect.size.x * padding, rect.size.y * padding)
        var zoom_x: float = viewport_size.x / maxf(padded.size.x, 1.0)
        var zoom_y: float = viewport_size.y / maxf(padded.size.y, 1.0)
        var zoom_value: float = clampf(minf(zoom_x, zoom_y), 0.1, 1.6)
        camera.zoom = Vector2(zoom_value, zoom_value)
        if camera.get("target_zoom") != null:
            camera.set("target_zoom", Vector2(zoom_value, zoom_value))
    elif opts.has("zoom"):
        var zv: float = clampf(float(opts.get("zoom", 1.0)), 0.1, 1.6)
        camera.zoom = Vector2(zv, zv)
        if camera.get("target_zoom") != null:
            camera.set("target_zoom", Vector2(zv, zv))

    if camera.has_method("clamp_pos"):
        center = camera.clamp_pos(center)
    camera.position = center
    return true

func _refresh_cache_if_needed(force_refresh: bool) -> void:
    _update_tracked_rects()
    if not force_refresh and not _dirty:
        return
    _rebuild_cache()

func _rebuild_cache() -> void:
    _items_by_id.clear()
    _tracked_nodes.clear()
    var desktop := _get_desktop()
    if desktop == null:
        _dirty = false
        return

    _collect_windows(desktop)
    _collect_groups_layer(desktop)
    _collect_notes(desktop)
    _dirty = false
    _last_refresh_msec = Time.get_ticks_msec()

func _collect_windows(desktop: Node) -> void:
    var windows: Node = desktop.get_node_or_null(WINDOW_LAYER_PATH)
    if windows == null:
        return
    for child: Node in windows.get_children():
        if child is Control:
            var item_type := "window"
            if str(child.get("window")) == "group":
                item_type = "group"
            _store_item(child, item_type)

func _collect_groups_layer(desktop: Node) -> void:
    var groups: Node = desktop.get_node_or_null(GROUP_LAYER_PATH)
    if groups == null:
        return
    for child: Node in groups.get_children():
        if child is Control:
            _store_item(child, "group")

func _collect_notes(desktop: Node) -> void:
    var notes: Node = desktop.get_node_or_null(NOTES_LAYER_PATH)
    if notes != null:
        for child: Node in notes.get_children():
            if child is Control:
                _store_item(child, "note")
    var tree := get_tree()
    if tree == null:
        return
    for node: Node in tree.get_nodes_in_group("tajs_sticky_note"):
        if node is Control:
            _store_item(node, "note")

func _store_item(node: Control, base_type: String) -> void:
    var item_type := base_type
    var item_id := _build_item_id(node, item_type)
    var rect := Rect2(node.position, node.size)
    _items_by_id[item_id] = {
        "id": item_id,
        "type": item_type,
        "name": str(node.name),
        "window_type_id": str(node.get("window")),
        "is_node": item_type == "window",
        "rect": rect,
        "center": rect.get_center(),
        "position": node.position,
        "size": node.size,
        "visible": node.visible,
        "path": str(node.get_path())
    }
    _tracked_nodes[item_id] = weakref(node)

func _build_item_id(node: Control, item_type: String) -> String:
    if item_type == "note":
        var note_id := str(node.get("note_id"))
        if note_id != "":
            return "note:%s" % note_id
    return "%s:%s" % [item_type, str(node.name)]

func _update_tracked_rects() -> void:
    if _tracked_nodes.is_empty():
        return
    var invalid_ids: Array[String] = []
    for item_id: String in _tracked_nodes.keys():
        var node_ref: WeakRef = _tracked_nodes[item_id]
        var node: Variant = node_ref.get_ref() if node_ref != null else null
        if not (node is Control) or not is_instance_valid(node):
            invalid_ids.append(item_id)
            continue
        if not _items_by_id.has(item_id):
            continue
        var item: Dictionary = _items_by_id[item_id]
        var new_rect := Rect2(node.position, node.size)
        var old_rect: Rect2 = item.get("rect", Rect2())
        if old_rect.position != new_rect.position or old_rect.size != new_rect.size or bool(item.get("visible", true)) != node.visible:
            item["rect"] = new_rect
            item["center"] = new_rect.get_center()
            item["position"] = node.position
            item["size"] = node.size
            item["visible"] = node.visible
            _items_by_id[item_id] = item
    for item_id: String in invalid_ids:
        _tracked_nodes.erase(item_id)
        _items_by_id.erase(item_id)
        _dirty = true

func _merge_item_bounds(items: Array) -> Rect2:
    var has_any := false
    var out := Rect2()
    for item: Dictionary in items:
        var rect: Variant = item.get("rect", Rect2())
        if not (rect is Rect2):
            continue
        if not has_any:
            out = rect
            has_any = true
        else:
            out = out.merge(rect)
    return out

func _accept_type(item_type: String, allowed_types: Array) -> bool:
    if allowed_types.is_empty():
        return true
    if item_type == "window" and allowed_types.has("node"):
        return true
    return allowed_types.has(item_type)

func _bind_events() -> void:
    if _event_bus == null or not _event_bus.has_method("on"):
        return
    _event_bus.on("core.desktop.window_created", Callable(self, "_on_window_changed"), self)
    _event_bus.on("core.desktop.window_initialized", Callable(self, "_on_window_changed"), self)
    _event_bus.on("core.desktop.window_deleted", Callable(self, "_on_window_changed"), self)
    _event_bus.on("core.desktop.window_moved", Callable(self, "_on_window_changed"), self)
    _event_bus.on("game.desktop_ready", Callable(self, "_on_window_changed"), self)

func _on_window_changed(_payload: Dictionary = {}) -> void:
    _dirty = true

func _on_tree_node_added(node: Node) -> void:
    if _is_relevant_node(node):
        _dirty = true

func _on_tree_node_removed(node: Node) -> void:
    if _is_relevant_node(node):
        _dirty = true

func _is_relevant_node(node: Node) -> bool:
    if node == null:
        return false
    if node.is_in_group("tajs_sticky_note"):
        return true
    var path_text := str(node.get_path())
    return path_text.contains("/%s/" % WINDOW_LAYER_PATH) or path_text.contains("/%s/" % NOTES_LAYER_PATH) or path_text.contains("/%s/" % GROUP_LAYER_PATH)

func _get_desktop() -> Node:
    var globals := _get_autoload("Globals")
    if globals == null:
        return null
    return globals.get("desktop")

func _get_autoload(autoload_name: String) -> Node:
    var tree: Variant = Engine.get_main_loop()
    if not (tree is SceneTree):
        return null
    return tree.get_root().get_node_or_null(autoload_name)
