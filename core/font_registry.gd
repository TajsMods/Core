class_name TajsCoreFontRegistry
extends RefCounted

const DEFAULT_PERSIST_PATH := "user://tajs_core_font_theme.tres"

var _logger: Variant
var _settings: Variant
var _theme_manager: Variant

var _fonts: Dictionary = {} # font_id -> Font
var _font_paths: Dictionary = {} # font_id -> String
var _class_font_ids: Dictionary = {} # class_name -> font_id
var _errors: Array = []
var _warnings: Array = []
var _fallback_uses: int = 0

func _init(logger: Variant = null, settings: Variant = null, theme_manager: Variant = null) -> void:
    _logger = logger
    _settings = settings
    _theme_manager = theme_manager

func register_font(font_id: String, resource_path: String) -> Dictionary:
    var id := font_id.strip_edges()
    if id == "":
        return _fail("font_id_empty", {"id": font_id})
    if not _is_namespaced(id):
        return _fail("font_id_must_be_namespaced_modid.localid", {"id": id})
    if resource_path == "":
        return _fail("font_path_empty", {"id": id, "path": resource_path})
    if not ResourceLoader.exists(resource_path):
        return _fail("font_path_not_found", {"id": id, "path": resource_path})

    var font_res: Variant = load(resource_path)
    if not (font_res is Font):
        return _fail("font_resource_invalid", {"id": id, "path": resource_path})

    _fonts[id] = font_res
    _font_paths[id] = resource_path
    return {"ok": true, "id": id, "path": resource_path}

func has_font(font_id: String) -> bool:
    return _fonts.has(font_id)

func get_font(font_id: String) -> Font:
    return _fonts.get(font_id, null)

func list_fonts() -> Dictionary:
    return _font_paths.duplicate(true)

func apply_font_to_class(class_name: String, font_id: String, property_name: String = "font") -> Dictionary:
    var id := font_id.strip_edges()
    var target_class := class_name.strip_edges()
    if target_class == "":
        return _fail("class_name_empty", {"class_name": class_name, "font_id": id})
    if not _fonts.has(id):
        var fallback_font: Font = _get_fallback_font()
        if fallback_font == null:
            return _fail("font_not_registered", {"class_name": target_class, "font_id": id})
        _fallback_uses += 1
        _warn("font_not_registered_using_fallback", {"class_name": target_class, "font_id": id})
        var fallback_theme := _get_game_theme()
        if fallback_theme == null:
            return _fail("theme_unavailable", {"class_name": target_class, "font_id": id})
        fallback_theme.set_font(property_name, target_class, fallback_font)
        return {"ok": true, "class_name": target_class, "font_id": id, "property": property_name, "fallback_used": true}
    _class_font_ids[target_class] = id

    var theme := _get_game_theme()
    if theme == null:
        return _fail("theme_unavailable", {"class_name": target_class, "font_id": id})
    theme.set_font(property_name, target_class, _fonts[id])
    return {"ok": true, "class_name": target_class, "font_id": id, "property": property_name}

func apply_font_to_node(node: Node, font_id: String, opts: Dictionary = {}) -> Dictionary:
    if node == null:
        return _fail("node_null", {"font_id": font_id})
    var id := font_id.strip_edges()
    if not _fonts.has(id):
        var fallback_font: Font = _get_fallback_font()
        if fallback_font == null:
            return _fail("font_not_registered", {"font_id": id, "node": str(node.name)})
        _fallback_uses += 1
        _warn("font_not_registered_using_fallback", {"font_id": id, "node": str(node.name)})
        return _apply_font_to_node_with_font(node, fallback_font, id, opts, true)
    if node is RichTextLabel:
        return _apply_font_to_rich_text(node, id, opts)
    if node is Control:
        return _apply_font_to_node_with_font(node, _fonts[id], id, opts, false)
    return _fail("node_not_control", {"font_id": id, "node": str(node.name)})

func apply_font_to_tree(root: Node, font_id: String, class_filter: String = "Control") -> Dictionary:
    if root == null:
        return _fail("root_null", {"font_id": font_id})
    var id := font_id.strip_edges()
    var font_to_use: Font = _fonts.get(id, null)
    var used_fallback := false
    if font_to_use == null:
        font_to_use = _get_fallback_font()
        if font_to_use == null:
            return _fail("font_not_registered", {"font_id": id})
        _fallback_uses += 1
        used_fallback = true
        _warn("font_not_registered_using_fallback", {"font_id": id, "target": "tree"})
    var count := 0
    count = _apply_font_tree_recursive(root, font_to_use, id, class_filter, count)
    return {"ok": true, "font_id": id, "applied_count": count, "class_filter": class_filter, "fallback_used": used_fallback}

func build_theme(class_map: Dictionary, save_to_user: bool = false, output_path: String = "") -> Dictionary:
    var theme := Theme.new()
    var fallback_count := 0
    for class_name: Variant in class_map.keys():
        var id := str(class_map[class_name]).strip_edges()
        var font_res: Font = _fonts.get(id, null)
        if font_res == null:
            font_res = _get_fallback_font()
            if font_res == null:
                _warn("font_not_registered", {"class_name": str(class_name), "font_id": id})
                continue
            fallback_count += 1
            _fallback_uses += 1
            _warn("font_not_registered_using_fallback", {"class_name": str(class_name), "font_id": id})
        theme.set_font("font", str(class_name), font_res)
    var path := output_path if output_path != "" else DEFAULT_PERSIST_PATH
    if save_to_user:
        var err: Error = ResourceSaver.save(theme, path)
        if err != OK:
            return _fail("theme_save_failed", {"path": path, "error_code": int(err)})
        return {"ok": true, "theme": theme, "saved": true, "path": path, "fallback_count": fallback_count}
    return {"ok": true, "theme": theme, "saved": false, "path": "", "fallback_count": fallback_count}

func maybe_persist_theme(class_map: Dictionary) -> Dictionary:
    if _settings == null:
        return {"ok": false, "error": "settings_unavailable"}
    var enabled := _settings.get_bool("core.fonts.persist_generated_theme", false)
    if not enabled:
        return {"ok": true, "saved": false, "reason": "disabled"}
    var path := _settings.get_string("core.fonts.persist_path", DEFAULT_PERSIST_PATH)
    return build_theme(class_map, true, path)

func get_diagnostics() -> Dictionary:
    return {
        "registered_fonts": _font_paths.duplicate(true),
        "class_bindings": _class_font_ids.duplicate(true),
        "warnings": _warnings.duplicate(true),
        "errors": _errors.duplicate(true),
        "warnings_count": _warnings.size(),
        "errors_count": _errors.size(),
        "fallback_uses": _fallback_uses
    }

func _apply_font_to_rich_text(node: RichTextLabel, font_id: String, opts: Dictionary) -> Dictionary:
    var font_res: Font = _fonts[font_id]
    var props: Array = opts.get("rich_text_props", ["normal_font", "bold_font", "bold_italics_font", "italics_font", "mono_font"])
    for prop: Variant in props:
        node.add_theme_font_override(str(prop), font_res)
    return {"ok": true, "node": str(node.name), "font_id": font_id, "target": "RichTextLabel", "properties": props}

func _apply_font_tree_recursive(node: Node, font_res: Font, font_id: String, class_filter: String, count: int) -> int:
    if class_filter == "RichTextLabel" and node is RichTextLabel:
        var rich := node as RichTextLabel
        for prop: String in ["normal_font", "bold_font", "bold_italics_font", "italics_font", "mono_font"]:
            rich.add_theme_font_override(prop, font_res)
        count += 1
    elif class_filter == "Label" and node is Label:
        (node as Label).add_theme_font_override("font", font_res)
        count += 1
    elif class_filter == "Control" and node is Control:
        (node as Control).add_theme_font_override("font", font_res)
        count += 1
    for child: Node in node.get_children():
        count = _apply_font_tree_recursive(child, font_res, font_id, class_filter, count)
    return count

func _apply_font_to_node_with_font(node: Node, font_res: Font, font_id: String, opts: Dictionary, fallback_used: bool) -> Dictionary:
    var prop := str(opts.get("property", "font"))
    var class_name := str(opts.get("class_name", ""))
    if class_name == "":
        class_name = "Control"
    (node as Control).add_theme_font_override(prop, font_res)
    return {"ok": true, "node": str(node.name), "class_name": class_name, "font_id": font_id, "property": prop, "fallback_used": fallback_used}

func _get_game_theme() -> Theme:
    if _theme_manager != null and _theme_manager.has_method("get_game_theme"):
        return _theme_manager.get_game_theme()
    if ResourceLoader.exists("res://themes/main.tres"):
        return load("res://themes/main.tres")
    return null

func _get_fallback_font() -> Font:
    var theme := _get_game_theme()
    if theme == null:
        return null
    var rich_font: Font = theme.get_font("normal_font", "RichTextLabel")
    if rich_font != null:
        return rich_font
    var label_font: Font = theme.get_font("font", "Label")
    if label_font != null:
        return label_font
    return theme.get_font("font", "Control")

func _is_namespaced(id: String) -> bool:
    var idx := id.find(".")
    return idx > 0 and idx < id.length() - 1

func _warn(code: String, data: Dictionary = {}) -> void:
    var entry := {"code": code, "data": data}
    _warnings.append(entry)
    if _logger != null and _logger.has_method("warn"):
        _logger.warn("fonts", "%s %s" % [code, JSON.stringify(data)])

func _fail(code: String, data: Dictionary = {}) -> Dictionary:
    var entry := {"code": code, "data": data}
    _errors.append(entry)
    if _logger != null and _logger.has_method("warn"):
        _logger.warn("fonts", "%s %s" % [code, JSON.stringify(data)])
    return {"ok": false, "error": code}.merged(data, true)
