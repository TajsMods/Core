extends "res://scripts/desktop.gd"


# Guard wire-drag handlers against null cursor_connector (Upload Labs 2.1 fix)
func _on_connection_dragged(connection: String, type: int, at: Vector2) -> void:
    if cursor_connector == null:
        cursor_connector = get_node_or_null("CursorConnector")
    if cursor_connector == null:
        return
    super._on_connection_dragged(connection, type, at)


func _on_connection_dropped(connection: String, type: int, at: Vector2) -> void:
    if cursor_connector == null:
        cursor_connector = get_node_or_null("CursorConnector")
    if cursor_connector == null:
        return
    super._on_connection_dropped(connection, type, at)


# Guard save() against null windows and connectors (Upload Labs 2.1 fix)
func save() -> Dictionary:
    if windows == null:
        windows = get_node_or_null("Windows")
    if connectors == null:
        connectors = get_node_or_null("Connectors")
    if windows == null or connectors == null:
        return {"windows": [], "connectors": {}}
    var desktop_data: Dictionary = {"windows": [], "connectors": {}}
    var windows_to_save: Array[WindowContainer] = []
    @warning_ignore("unsafe_method_access")
    for child: Variant in windows.get_children():
        if child is WindowContainer:
            windows_to_save.append(child)

    var group_layer: Variant = get_node_or_null("CoreLayer_qol_groups")
    if group_layer != null:
        @warning_ignore("unsafe_method_access")
        for child: Variant in group_layer.get_children():
            if child is WindowContainer:
                @warning_ignore("unsafe_method_access")
                if child.has_method("get") and str(child.get("window")) == "group":
                    if not windows_to_save.has(child):
                        windows_to_save.append(child)

    @warning_ignore("unsafe_method_access")
    for window: Variant in windows_to_save:
        @warning_ignore("unsafe_method_access")
        desktop_data.windows.append(window.save())
    for connector: Connector in connectors.get_children():
        desktop_data.connectors[connector.input_id] = connector.save()

    return desktop_data


func add_windows_from_data(data: Dictionary, importing: bool = false) -> Array[WindowContainer]:
    var created_windows: Array[WindowContainer]
    var resolver: Variant = _get_scene_resolver()

    for window_id: String in data:
        @warning_ignore("unsafe_method_access")
        if not data[window_id].has("filename"):
            continue
        var filename: String = str(data[window_id].filename)
        var path: String = _resolve_window_path(filename, resolver)
        if path == "" or not ResourceLoader.exists(path):
            continue
        var new_object: Control = get_node_or_null("Desktop/Windows/" + window_id)
        if not new_object:
            @warning_ignore("unsafe_method_access")
            new_object = load(path).instantiate()
            new_object.set("importing", importing)
            for key: String in data[window_id]:
                new_object.set(key, data[window_id][key])
            new_object.name = window_id
            $Windows.add_child(new_object)
            created_windows.append(new_object)
        else:
            new_object.name = window_id
            for key: String in data[window_id]:
                new_object.set(key, data[window_id][key])

    return created_windows


func copy(windows_to_copy: Array[WindowContainer]) -> Dictionary:
    if windows_to_copy.is_empty():
        return {"windows": [], "connectors": {}, "rect": Rect2()}

    if connectors == null:
        connectors = get_node_or_null("Connectors")
    if connectors == null:
        return {"windows": [], "connectors": {}, "rect": Rect2()}

    var dict: Dictionary = {"windows": [], "connectors": {}}
    var rect: Rect2 = windows_to_copy[0].get_rect()
    var connections: Dictionary = {}

    for window: WindowContainer in windows_to_copy:
        rect = rect.merge(window.get_rect())
        @warning_ignore("unsafe_method_access")
        for resource: ResourceContainer in window.get("containers"):
            connections[resource.id] = resource.outputs_id

    for window: WindowContainer in windows_to_copy:
        if !window.can_export:
            continue
        var data: Dictionary = window.export()
        @warning_ignore("unsafe_method_access")
        dict["windows"].append(data)
        for resource: String in data.container_data:
            var new_outputs: Array[String] = []
            for output: String in data.container_data[resource].outputs_id:
                if connections.has(output):
                    new_outputs.append(output)
            data.container_data[resource].outputs_id = new_outputs

    for connector: Connector in connectors.get_children():
        if connections.has(connector.input_id):
            dict["connectors"][connector.input_id] = connector.save()

    dict["rect"] = rect
    return dict

func paste(data: Dictionary) -> void:
    var seed_value: int = int(randi() / 10.0)
    var new_windows: Dictionary = {}
    var to_connect: Dictionary[String, Array] = {}
    var source_windows: Array[Dictionary] = []
    var required: int = 0

    if typeof(data.windows) == TYPE_DICTIONARY:
        for window_name: String in data.windows:
            source_windows.append({"name": window_name, "data": data.windows[window_name]})
    elif typeof(data.windows) == TYPE_ARRAY:
        for window_value: Variant in data.windows:
            if typeof(window_value) != TYPE_DICTIONARY:
                continue
            @warning_ignore("unsafe_method_access")
            source_windows.append({"name": str(window_value.get("name", "Window")), "data": window_value})
    else:
        return

    for window_entry: Dictionary in source_windows:
        var window_name: String = str(window_entry.get("name", "Window"))
        var window_data: Dictionary = window_entry.get("data", {})
        if window_data.is_empty():
            continue
        required += 1

        var container_data: Variant = window_data.get("container_data", {})
        if typeof(container_data) == TYPE_DICTIONARY:
            for resource: String in container_data:
                @warning_ignore("unsafe_method_access")
                @warning_ignore("unsafe_call_argument")
                var resource_id_hash: int = container_data[resource].id.hash()
                var new_resource_name: String = Utils.generate_id_from_seed(resource_id_hash + seed_value)
                container_data[resource].id = new_resource_name
                @warning_ignore("unsafe_method_access")
                container_data[resource].erase("count")
                to_connect[new_resource_name] = []
                for output: String in container_data[resource].outputs_id:
                    to_connect[new_resource_name].append(Utils.generate_id_from_seed(output.hash() + seed_value))
                @warning_ignore("unsafe_method_access")
                container_data[resource].outputs_id.clear()

        var new_window_name: String = find_window_name(window_name)
        new_windows[new_window_name] = window_data.duplicate(true)
        @warning_ignore("unsafe_method_access")
        if new_windows[new_window_name].has("position"):
            new_windows[new_window_name].position -= data.rect.position - Globals.camera_center.snappedf(50) + (data.rect.size * 0.5)

    var limit: int = _get_node_limit()
    if limit >= 0 and required > limit - Globals.max_window_count:
        Signals.notify.emit("exclamation", "build_limit_reached")
        Sound.play("error")
        return

    data.windows = new_windows
    var windows_added: Array[WindowContainer]
    @warning_ignore("unsafe_call_argument")
    windows_added = add_windows_from_data(data.windows, true)
    Globals.set_selection(windows_added, [])

    for i: String in data.connectors:
        var new_id: String = Utils.generate_id_from_seed(i.hash() + seed_value)
        data.connectors[i].pivot_pos -= data.rect.position - Globals.camera_center.snappedf(50) + (data.rect.size / 2)
        @warning_ignore("unsafe_property_access")
        $Connectors.connector_data[new_id] = data.connectors[i]

    var connection_remaining: Dictionary[String, Array] = to_connect.duplicate(true)
    for i: String in to_connect:
        var container: ResourceContainer = get_resource(i)
        if !container: continue
        if container.resource.is_empty(): continue
        for output: String in to_connect[i]:
            Signals.create_connection.emit(i, output)
        var _ignored: Variant = connection_remaining.erase(i)

    for i: String in connection_remaining:
        for output: String in connection_remaining[i]:
            Signals.create_connection.emit(i, output)

    @warning_ignore("unsafe_property_access")
    @warning_ignore("unsafe_method_access")
    $Connectors.connector_data.clear()

func _resolve_window_path(filename: String, resolver: Variant) -> String:
    if filename == "":
        return ""
    if resolver != null:
        @warning_ignore("unsafe_method_access")
        return resolver.resolve_scene_path(filename)
    return "res://scenes/windows/".path_join(filename)

func _get_scene_resolver() -> Variant:
    var core: Variant = Engine.get_meta("TajsCore", null)
    if core != null and core.window_scenes != null:
        return core.window_scenes
    return null

@warning_ignore("unsafe_method_access")
func _get_node_limit() -> int:
    var core: Variant = Engine.get_meta("TajsCore", null)
    @warning_ignore("unsafe_method_access")
    if core != null and core.has_method("get"):
        @warning_ignore("unsafe_method_access")
        var helper: Variant = core.get("node_limit_helpers")
        @warning_ignore("unsafe_method_access")
        if helper != null and helper.has_method("get_node_limit"):
            @warning_ignore("unsafe_method_access")
            return helper.get_node_limit()
    return Utils.MAX_WINDOW


func find_window_name(cur_name: String) -> String:
    if windows == null:
        windows = get_node_or_null("Windows")
    var group_layer: Variant = get_node_or_null("CoreLayer_qol_groups")

    var id: int
    @warning_ignore("unsafe_call_argument")
    while _window_name_exists(cur_name + str(id), windows, group_layer):
        id += 1

    return cur_name + str(id)


func _window_name_exists(candidate: String, windows_node: Node, group_layer: Node) -> bool:
    if windows_node != null and windows_node.has_node(candidate):
        return true
    if group_layer != null and group_layer.has_node(candidate):
        return true
    return false

func get_connection_at(connection: String, type: int, cursor_pos: Vector2) -> ConnectorButton:
    var resource: ResourceContainer = get_resource(connection)
    if !resource:
        return null
    var windows_node: Node = get_node_or_null("Windows")
    if windows_node == null:
        return null
    var is_self: bool = false
    for window: WindowContainer in windows_node.get_children():
        if window is not WindowBase:
            continue
        if !window.is_visible_in_tree():
            continue
        @warning_ignore("unsafe_method_access")
        is_self = window.get("containers").has(resource)
        @warning_ignore("unsafe_cast")
        var window_base: WindowBase = window as WindowBase

        if window_base.get_rect().grow(10).has_point(cursor_pos):
            var best_match: ConnectorButton
            for container: ResourceContainer in window_base.containers:
                var button: ConnectorButton = container.get_node_or_null("InputConnector")
                if !button:
                    button = container.get_node_or_null("OutputConnector")
                    if !button:
                        continue

                if button.disabled or !button.is_visible_in_tree() or !button.can_connect(resource, type):
                    continue

                if button.get_global_rect().has_point(cursor_pos):
                    best_match = button
                    break

                if !best_match and !is_self:
                    if !button.has_connection():
                        best_match = button

            if best_match:
                return best_match
    return null
func _on_create_window(window: WindowContainer) -> void:
    if window == null:
        return
    if windows == null:
        windows = get_node_or_null("Windows")
    if windows == null:
        call_deferred("_retry_create_window", window)
        return
    super._on_create_window(window)


func _retry_create_window(window: WindowContainer) -> void:
    if not is_instance_valid(window):
        return
    for i: Variant in range(2):
        @warning_ignore("unsafe_property_access")
        await Engine.get_main_loop().process_frame
        if windows == null:
            windows = get_node_or_null("Windows")
        if windows != null:
            super._on_create_window(window)
            return


func update_heatspot() -> void:
    if windows == null:
        windows = get_node_or_null("Windows")
    if windows == null:
        return

    var window_count: int = windows.get_child_count()
    if window_count == 0:
        heatspot = Vector2.ZERO
        @warning_ignore("unsafe_call_argument")
        heatspot_volume = linear_to_db(min(0.8, 0.01 + 0.12 * Globals.max_window_count))
        if ambience == null:
            ambience = get_node_or_null("AmbiencePlayer")
        if ambience != null:
            ambience.set("position", heatspot)
            ambience.set("volume_db", heatspot_volume)
            ambience.set("max_distance", 2000 * (0.02 * Globals.max_window_count + 1))
        return

    var sum: Vector2 = Vector2.ZERO
    for i: WindowContainer in windows.get_children():
        sum += i.position
    heatspot = sum / window_count
    @warning_ignore("unsafe_call_argument")
    heatspot_volume = linear_to_db(min(0.8, 0.01 + 0.12 * Globals.max_window_count))

    if ambience == null:
        ambience = get_node_or_null("AmbiencePlayer")
    if ambience == null:
        return

    ambience.set("position", heatspot)
    ambience.set("volume_db", heatspot_volume)
    ambience.set("max_distance", 2000 * (0.02 * Globals.max_window_count + 1))


func update_selection() -> void:
    if selections == null:
        selections = get_node_or_null("Selections")
    if selections == null:
        _clear_selection_rids()
        return
    super.update_selection()


func _clear_selection_rids() -> void:
    if window_selections == null:
        window_selections = {}
    if grabber_selections == null:
        grabber_selections = {}

    for i: WindowContainer in window_selections:
        RenderingServer.canvas_item_clear(window_selections[i])
        RenderingServer.free_rid(window_selections[i])

    for i: Control in grabber_selections:
        RenderingServer.canvas_item_clear(grabber_selections[i])
        RenderingServer.free_rid(grabber_selections[i])

    window_selections.clear()
    grabber_selections.clear()


func _on_tool_set() -> void:
    if input_blocker == null:
        input_blocker = get_node_or_null("InputBlocker")
    if input_blocker == null:
        return
    input_blocker.set("visible", get_blocker_visibility())


func _on_screen_transition_started() -> void:
    if input_blocker == null:
        input_blocker = get_node_or_null("InputBlocker")
    if input_blocker == null:
        return
    super._on_screen_transition_started()
