class_name TajsCoreNodeCompatibilityFilter
extends RefCounted

const LOG_NAME = "NodeCompatibilityFilter"

# Cache of window connector info to avoid loading scenes repeatedly
var _window_connectors_cache: Dictionary = {}
var _cache_built: bool = false

var _logger


func _init(logger = null) -> void:
    _logger = logger


## Build cache of window connector information
func build_cache() -> void:
    if _cache_built:
        return

    _window_connectors_cache.clear()

    for window_id in Data.windows:
        var window_data: Dictionary = Data.windows[window_id]

        # Skip windows without scenes
        if not window_data.has("scene") or window_data.scene.is_empty():
            continue

        # Try to get connector info from the scene
        var connector_info := _get_window_connector_info(window_id, window_data)
        if not connector_info.is_empty():
            _window_connectors_cache[window_id] = connector_info

    _cache_built = true
    _log_info("Built node compatibility cache for %d windows" % _window_connectors_cache.size())


## Get connector info for a specific window (lazy load if needed)
func get_connector_info(window_id: String) -> Dictionary:
    if not _cache_built:
        build_cache()
    return _window_connectors_cache.get(window_id, {})


## Get connector info for a window by loading its scene
func _get_window_connector_info(window_id: String, window_data: Dictionary) -> Dictionary:
    var scene_path: String = "res://scenes/windows/" + window_data.scene + ".tscn"

    if not ResourceLoader.exists(scene_path):
        return {}

    # Load scene to inspect ResourceContainers
    var scene: PackedScene = load(scene_path)
    if not scene:
        return {}

    var instance: Node = scene.instantiate()
    if not instance:
        return {}

    var info := {
        "id": window_id,
        "name": window_data.get("name", window_id),
        "description": window_data.get("description", ""),
        "category": window_data.get("category", ""),
        "sub_category": window_data.get("sub_category", ""),
        "icon": window_data.get("icon", ""),
        "inputs": [],
        "outputs": []
    }

    # Try using window.containers property (preferred method per game design)
    if "containers" in instance:
        var containers = instance.containers
        if containers is Array:
            for container in containers:
                if container is ResourceContainer:
                    var connector_data = _extract_connector_data(container)
                    if not connector_data.is_empty():
                        if container.is_in_group("input"):
                            info.inputs.append(connector_data)
                        if container.is_in_group("output"):
                            info.outputs.append(connector_data)

    # Fallback: recursive search if containers property didn't find anything
    if info.inputs.is_empty() and info.outputs.is_empty():
        _collect_connectors(instance, info)

    # Post-process: Infer dynamic output types from typed inputs
    # Many processing nodes (Verifier, Antivirus, etc.) output the same type as their input
    _infer_passthrough_outputs(info)

    # Clean up
    instance.queue_free()

    return info


## For pass-through nodes, dynamic outputs should inherit type from typed inputs
func _infer_passthrough_outputs(info: Dictionary) -> void:
    # Find the first non-speed typed input (usually the "file" input)
    var typed_file_input: Dictionary = {}
    for input in info.inputs:
        var shape = input.get("shape", "")
        # Skip flow/speed inputs (circle is usually clock/speed, we want file shapes like square)
        if shape != "" and shape != "any" and shape != "circle":
            typed_file_input = input
            break

    # If no typed file input found, check for any non-circle typed input
    if typed_file_input.is_empty():
        for input in info.inputs:
            var shape = input.get("shape", "")
            if shape != "" and shape != "any":
                typed_file_input = input
                break

    # Update dynamic outputs to inherit from typed input
    if not typed_file_input.is_empty():
        for i in range(info.outputs.size()):
            var output = info.outputs[i]
            if output.get("shape", "") == "any":
                # Inherit shape and color from typed input
                output["shape"] = typed_file_input.get("shape", "any")
                output["color"] = typed_file_input.get("color", "white")
                # Update name to remove "(Dynamic)" and show inherited type
                var base_name = output.get("name", "Output").replace(" (Dynamic)", "")
                output["name"] = base_name
                info.outputs[i] = output


## Extract connector data from a ResourceContainer (safely, without requiring tree entry)
func _extract_connector_data(rc: ResourceContainer) -> Dictionary:
    var shape := ""
    var color := ""

    # Safely extract shape/color - can't use get_connection_shape() because data isn't populated yet
    if not rc.override_connector.is_empty():
        shape = rc.override_connector
        color = rc.override_color if not rc.override_color.is_empty() else "white"
    elif not rc.default_resource.is_empty() and Data.resources.has(rc.default_resource):
        var resource_data: Dictionary = Data.resources[rc.default_resource]
        shape = resource_data.get("connection", "")
        color = resource_data.get("color", "white")

    if shape.is_empty():
        return {}

    return {
        "shape": shape,
        "color": color,
        "name": rc.name,
        "resource_id": rc.default_resource
    }


## Recursively collect connector info from a node tree
func _collect_connectors(node: Node, info: Dictionary) -> void:
    if node is ResourceContainer:
        var rc: ResourceContainer = node
        var shape := ""
        var color := ""

        # Safely extract shape/color - can't use get_connection_shape() because data isn't populated yet
        if not rc.override_connector.is_empty():
            shape = rc.override_connector
            color = rc.override_color if not rc.override_color.is_empty() else "white"
        elif not rc.default_resource.is_empty() and Data.resources.has(rc.default_resource):
            var resource_data: Dictionary = Data.resources[rc.default_resource]
            shape = resource_data.get("connection", "")
            color = resource_data.get("color", "white")

        # Check if this container has input/output connectors
        var is_input = node.has_node("InputConnector") or node.is_in_group("input")
        var is_output = node.has_node("OutputConnector") or node.is_in_group("output")

        if not shape.is_empty():
            var connector_data := {
                "shape": shape,
                "color": color,
                "name": node.name,
                "resource_id": rc.default_resource
            }

            if is_input:
                info.inputs.append(connector_data)
            if is_output:
                info.outputs.append(connector_data)
        else:
            # Dynamic/untyped output - has connector but no fixed resource type
            # These ports accept whatever resource is connected to them
            if is_output:
                info.outputs.append({
                    "shape": "any",
                    "color": "white",
                    "name": node.name + " (Dynamic)"
                })
            if is_input:
                info.inputs.append({
                    "shape": "any",
                    "color": "white",
                    "name": node.name + " (Dynamic)"
                })

    # Recurse into children
    for child in node.get_children():
        _collect_connectors(child, info)


## Get list of windows compatible with the given origin pin
## Returns array of window info dictionaries
func get_compatible_nodes(origin_shape: String, origin_color: String, origin_is_output: bool) -> Array[Dictionary]:
    if not _cache_built:
        build_cache()

    var compatible: Array[Dictionary] = []

    for window_id in _window_connectors_cache:
        var window_info: Dictionary = _window_connectors_cache[window_id]

        # If origin is OUTPUT, we need to find windows with compatible INPUTS
        # If origin is INPUT, we need to find windows with compatible OUTPUTS
        var target_pins: Array = window_info.outputs if not origin_is_output else window_info.inputs

        for pin in target_pins:
            if _is_compatible(origin_shape, origin_color, pin.shape, pin.color):
                # Add window to compatible list (only once per window)
                var already_added := false
                for existing in compatible:
                    if existing.id == window_id:
                        already_added = true
                        break

                if not already_added:
                    compatible.append(window_info.duplicate())
                break

    # Sort by category then name
    compatible.sort_custom(_sort_by_category_and_name)

    return compatible


## Check if two connectors are compatible (same logic as ResourceContainer.can_connect)
func _is_compatible(shape1: String, color1: String, shape2: String, color2: String) -> bool:
    # Shape must match
    if shape1 != shape2:
        return false

    # Color must match, or one must be white (wildcard)
    if color1 != "white" and color2 != "white" and color1 != color2:
        return false

    return true


## Sort function for windows
func _sort_by_category_and_name(a: Dictionary, b: Dictionary) -> bool:
    if a.category != b.category:
        return a.category < b.category
    if a.sub_category != b.sub_category:
        return a.sub_category < b.sub_category
    return a.name < b.name


## Get all windows that have a specific INPUT port type
func get_nodes_with_input(shape: String, color: String) -> Array[Dictionary]:
    if not _cache_built:
        build_cache()

    var matching: Array[Dictionary] = []

    for window_id in _window_connectors_cache:
        var window_info: Dictionary = _window_connectors_cache[window_id]
        for input in window_info.inputs:
            if _is_compatible(shape, color, input.shape, input.color):
                matching.append(window_info.duplicate())
                break

    matching.sort_custom(_sort_by_category_and_name)
    return matching


## Get all windows that have a specific OUTPUT port type
func get_nodes_with_output(shape: String, color: String) -> Array[Dictionary]:
    if not _cache_built:
        build_cache()

    var matching: Array[Dictionary] = []

    for window_id in _window_connectors_cache:
        var window_info: Dictionary = _window_connectors_cache[window_id]
        for output in window_info.outputs:
            if _is_compatible(shape, color, output.shape, output.color):
                matching.append(window_info.duplicate())
                break

    matching.sort_custom(_sort_by_category_and_name)
    return matching


## Clear the cache (call if window definitions change)
func clear_cache() -> void:
    _window_connectors_cache.clear()
    _cache_built = false


## Get total number of cached windows
func get_cache_size() -> int:
    return _window_connectors_cache.size()


func _log_info(message: String) -> void:
    if _logger != null and _logger.has_method("info"):
        _logger.info("core", message)
    elif _has_global_class("ModLoaderLog"):
        ModLoaderLog.info(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])


func _has_global_class(class_name_str: String) -> bool:
    for entry in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false
