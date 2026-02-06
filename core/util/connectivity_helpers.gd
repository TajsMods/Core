class_name TajsCoreConnectivityHelpers
extends RefCounted

func scan_disconnected_windows(min_window_count: int = 2) -> Dictionary:
    var result := {
        "disconnected": {},
        "resource_count": 0,
        "component_count": 0
    }
    var windows_root := _get_windows_root()
    if windows_root == null:
        return result

    var maps := _build_resource_maps(windows_root)
    var all_res_ids: Dictionary = maps["resources"]
    var res_to_window: Dictionary = maps["res_to_window"]
    result["resource_count"] = all_res_ids.size()

    if all_res_ids.is_empty():
        return result

    var adjacency := _build_adjacency(all_res_ids, res_to_window)
    var components := _compute_components(adjacency)
    result["component_count"] = components.size()

    var disconnected := {}
    for comp: Variant in components:
        var distinct_windows := {}
        for res_id: Variant in comp:
            if res_to_window.has(res_id):
                var win: Variant = res_to_window[res_id]
                if win != null:
                    distinct_windows[win.name] = true
        if distinct_windows.size() < min_window_count:
            for win_name: Variant in distinct_windows:
                disconnected[win_name] = true

    result["disconnected"] = disconnected
    return result

func _build_resource_maps(windows_root: Node) -> Dictionary:
    var all_res_ids: Dictionary = {}
    var res_to_window: Dictionary = {}
    for window: Variant in windows_root.get_children():
        if window is WindowContainer:
            var resources := _get_window_resources(window, [])
            for res: Variant in resources:
                if res == null:
                    continue
                if res.id is String and not res.id.is_empty():
                    all_res_ids[res.id] = res
                    res_to_window[res.id] = window
    return {
        "resources": all_res_ids,
        "res_to_window": res_to_window
    }

func _build_adjacency(all_res_ids: Dictionary, res_to_window: Dictionary) -> Dictionary:
    var adjacency: Dictionary = {}
    for res_id: Variant in all_res_ids:
        adjacency[res_id] = []

    for res_id: Variant in all_res_ids:
        var res: Variant = all_res_ids[res_id]
        for out_id: Variant in res.outputs_id:
            if all_res_ids.has(out_id):
                adjacency[res_id].append(out_id)
                adjacency[out_id].append(res_id)

    var window_to_ids: Dictionary = {}
    for res_id: Variant in res_to_window:
        var win: Variant = res_to_window[res_id]
        if win == null:
            continue
        var win_name: String = win.name
        if not window_to_ids.has(win_name):
            window_to_ids[win_name] = []
        window_to_ids[win_name].append(res_id)

    for win_name: Variant in window_to_ids:
        var ids: Array = window_to_ids[win_name]
        for i: Variant in range(ids.size()):
            for j: Variant in range(i + 1, ids.size()):
                var id1: Variant = ids[i]
                var id2: Variant = ids[j]
                adjacency[id1].append(id2)
                adjacency[id2].append(id1)

    return adjacency

func _compute_components(adjacency: Dictionary) -> Array:
    var components: Array = []
    var visited: Dictionary = {}
    for start_id: Variant in adjacency:
        if visited.has(start_id):
            continue
        var component: Array = []
        var queue: Array = [start_id]
        visited[start_id] = true
        var idx := 0
        while idx < queue.size():
            var current: Variant = queue[idx]
            idx += 1
            component.append(current)
            for neighbor: Variant in adjacency[current]:
                if not visited.has(neighbor):
                    visited[neighbor] = true
                    queue.append(neighbor)
        components.append(component)
    return components

func _get_window_resources(node: Node, result: Array) -> Array:
    if node is ResourceContainer:
        result.append(node)
    for child: Variant in node.get_children():
        var _ignored: Variant = _get_window_resources(child, result)
    return result

func _get_windows_root() -> Node:
    if Globals == null or Globals.desktop == null:
        return null
    return Globals.desktop.get_node_or_null("Windows")
