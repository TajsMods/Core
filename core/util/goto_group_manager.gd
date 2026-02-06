class_name TajsCoreGotoGroupManager
extends Node

const LOG_NAME := "TajsCore:GoToGroup"

signal groups_changed

var _core: Variant = null
var _groups_cache: Array = []
var _bounds_cache: Dictionary = {} # group instance_id -> Rect2
var _cache_dirty: bool = true
var _nav_tween: Tween = null


func setup(core: Variant) -> void:
    _core = core


func _ready() -> void:
    var tree := get_tree()
    if tree == null:
        return
    tree.node_added.connect(_on_node_added)
    tree.node_removed.connect(_on_node_removed)


func _on_node_added(node: Node) -> void:
    if node.is_in_group("selectable") or node.is_in_group("window"):
        _invalidate_cache()


func _on_node_removed(_node: Node) -> void:
    _invalidate_cache()


func _invalidate_cache() -> void:
    _cache_dirty = true
    _bounds_cache.clear()


## Get all Node Groups currently on the desktop
func get_all_groups() -> Array:
    if _cache_dirty:
        _refresh_groups_cache()
    return _groups_cache


## Refresh the groups cache
func _refresh_groups_cache() -> void:
    _groups_cache.clear()
    var tree := get_tree()
    if tree == null:
        _cache_dirty = false
        return
    for window: Variant in tree.get_nodes_in_group("selectable"):
        if window.get("window") == "group":
            _groups_cache.append(window)
    _cache_dirty = false
    groups_changed.emit()


## Get the bounding rectangle of all nodes within a group
## Returns the combined Rect2 of all enclosed nodes, or the group's own rect if empty
func get_group_bounds(group: Variant) -> Rect2:
    if not is_instance_valid(group):
        return Rect2()

    var group_id: Variant = group.get_instance_id()
    if _bounds_cache.has(group_id):
        return _bounds_cache[group_id]

    var group_rect: Variant = group.get_rect()
    var bounds: Rect2 = Rect2()
    var has_nodes: bool = false
    var tree := get_tree()
    if tree == null:
        return Rect2()

    for window: Variant in tree.get_nodes_in_group("selectable"):
        if window == group:
            continue
        if window.get("window") == "group":
            continue
        var window_rect: Variant = window.get_rect()
        if group_rect.encloses(window_rect):
            if not has_nodes:
                bounds = window_rect
                has_nodes = true
            else:
                bounds = bounds.merge(window_rect)

    if not has_nodes:
        bounds = group_rect

    _bounds_cache[group_id] = bounds
    return bounds


## Navigate camera to focus on a specific group
func navigate_to_group(group: Variant) -> void:
    if not is_instance_valid(group):
        _notify("exclamation", "Group no longer exists")
        return

    var bounds: Variant = get_group_bounds(group)
    if bounds.size == Vector2.ZERO or bounds.size.x < 1 or bounds.size.y < 1:
        _notify("exclamation", "Group is empty")
        return

    if _nav_tween and _nav_tween.is_valid():
        _nav_tween.kill()

    var padding_x: Variant = bounds.size.x * 0.15
    var padding_y: Variant = bounds.size.y * 0.15
    var padded_bounds: Variant = bounds.grow_individual(padding_x, padding_y, padding_x, padding_y)

    var viewport := get_viewport()
    if viewport == null:
        return
    var viewport_size: Variant = viewport.get_visible_rect().size

    var zoom_x: Variant = viewport_size.x / padded_bounds.size.x
    var zoom_y: Variant = viewport_size.y / padded_bounds.size.y
    var target_zoom_value: Variant = min(zoom_x, zoom_y)

    target_zoom_value = clamp(target_zoom_value, 0.1, 1.2)
    var target_zoom: Variant = Vector2(target_zoom_value, target_zoom_value)

    var center: Variant = bounds.position + bounds.size / 2
    var camera: Variant = viewport.get_camera_2d()
    if camera == null:
        _emit_center_camera(center)
        return

    if camera.has_method("clamp_pos"):
        center = camera.clamp_pos(center)
    else:
        var limit: Variant = camera.get("limit")
        if limit:
            center = Vector2(
                clampf(center.x, -limit, limit),
                clampf(center.y, -limit, limit)
            )

    _nav_tween = create_tween()
    var _ignored: Variant = _nav_tween.set_ease(Tween.EASE_OUT)
    var _ignored_trans: Variant = _nav_tween.set_trans(Tween.TRANS_CUBIC)
    var _ignored_parallel: Variant = _nav_tween.set_parallel(true)
    var _ignored_pos: Variant = _nav_tween.tween_property(camera, "position", center, 0.35)
    var _ignored_zoom: Variant = _nav_tween.tween_property(camera, "zoom", target_zoom, 0.35)
    var _ignored_target: Variant = _nav_tween.tween_property(camera, "target_zoom", target_zoom, 0.35)

    var group_name: Variant = get_group_name(group)
    _notify("check", "Navigated to: " + group_name)
    _play_sound("click2")


## Get the color of a group
func get_group_color(group: Variant) -> Color:
    if not is_instance_valid(group):
        return Color.WHITE

    var custom_color: Variant = group.get("custom_color")
    if custom_color and custom_color != Color.TRANSPARENT:
        return custom_color

    var color_idx: Variant = group.get("color")
    if color_idx == null:
        return Color.WHITE

    var colors_array: Variant = group.get("NEW_COLORS")
    if colors_array == null:
        colors_array = group.get("colors")
    if colors_array == null:
        colors_array = ["1a202c", "1a2b22", "1a292b", "1a1b2b", "211a2b", "2b1a27", "2b1a1a"]

    if color_idx >= 0 and color_idx < colors_array.size():
        return Color(colors_array[color_idx])

    return Color.WHITE


## Get the icon path for a group
func get_group_icon_path(group: Variant) -> String:
    if not is_instance_valid(group):
        return "res://textures/icons/window.png"

    if group.has_method("get_icon"):
        return group.get_icon()

    var custom_icon: Variant = group.get("custom_icon")
    if custom_icon and not custom_icon.is_empty():
        return "res://textures/icons/" + custom_icon + ".png"

    return "res://textures/icons/window.png"


## Get the display name for a group
func get_group_name(group: Variant) -> String:
    if not is_instance_valid(group):
        return "Unknown Group"

    if group.has_method("get_window_name"):
        return group.get_window_name()

    var custom_name: Variant = group.get("custom_name")
    if custom_name and not custom_name.is_empty():
        return custom_name

    return "Group"


## Force refresh of all caches
func force_refresh() -> void:
    _invalidate_cache()
    _refresh_groups_cache()


func _notify(icon: String, message: String) -> void:
    if _core != null and _core.has_method("notify"):
        _core.notify(icon, message)
        return
    var signals: Variant = _get_autoload("Signals")
    if signals != null and signals.has_signal("notify"):
        var _ignored: Variant = signals.emit_signal("notify", icon, message)
        return
    print("%s %s" % [LOG_NAME, message])


func _play_sound(sound_id: String) -> void:
    if _core != null and _core.has_method("play_sound"):
        _core.play_sound(sound_id)
        return
    var sound: Variant = _get_autoload("Sound")
    if sound != null and sound.has_method("play"):
        sound.call("play", sound_id)


func _emit_center_camera(center: Vector2) -> void:
    var signals: Variant = _get_autoload("Signals")
    if signals != null and signals.has_signal("center_camera"):
        var _ignored: Variant = signals.emit_signal("center_camera", center)


func _get_autoload(autoload_name: String) -> Node:
    if Engine.get_main_loop() == null:
        return null
    var root: Variant = Engine.get_main_loop().root
    if root == null:
        return null
    return root.get_node_or_null(autoload_name)
