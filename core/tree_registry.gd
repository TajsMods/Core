class_name TajsCoreTreeRegistry
extends RefCounted

const RESEARCH_BUTTON_SCENE := preload("res://scenes/research_button.tscn")
const ASCENSION_BUTTON_SCENE := preload("res://scenes/ascension_button.tscn")

var _research_ops: Array = []
var _ascension_ops: Array = []

func add_research_node(def: Dictionary) -> void:
    _research_ops.append({"type": "add", "def": def.duplicate(true)})

func move_research_node(def: Dictionary) -> void:
    _research_ops.append({"type": "move", "def": def.duplicate(true)})

func add_ascension_node(def: Dictionary) -> void:
    _ascension_ops.append({"type": "add", "def": def.duplicate(true)})

func move_ascension_node(def: Dictionary) -> void:
    _ascension_ops.append({"type": "move", "def": def.duplicate(true)})

func apply_research_tree(screen: Node, tree: Node) -> void:
    if screen == null or tree == null:
        return
    var handler := Callable(screen, "_on_research_selected")
    for op in _research_ops:
        var def: Dictionary = op["def"]
        if op["type"] == "add":
            var node := RESEARCH_BUTTON_SCENE.instantiate()
            node.name = str(def.get("name", node.name))
            _configure_node_position(tree, node, def)
            if handler.is_valid() and node.has_signal("selected"):
                node.selected.connect(handler)
            tree.add_child(node)
        elif op["type"] == "move":
            var target := tree.get_node_or_null(str(def.get("name", "")))
            if target != null:
                _configure_node_position(tree, target, def)

func apply_ascension_tree(screen: Node, tree: Node) -> void:
    if screen == null or tree == null:
        return
    var handler := Callable(screen, "_on_research_selected")
    for op in _ascension_ops:
        var def: Dictionary = op["def"]
        if op["type"] == "add":
            var node := ASCENSION_BUTTON_SCENE.instantiate()
            node.name = str(def.get("name", node.name))
            _configure_ascension_node(tree, node, def)
            if handler.is_valid() and node.has_signal("selected"):
                node.selected.connect(handler)
            tree.add_child(node)
        elif op["type"] == "move":
            var target := tree.get_node_or_null(str(def.get("name", "")))
            if target != null:
                _configure_ascension_node(tree, target, def)

func clear() -> void:
    _research_ops.clear()
    _ascension_ops.clear()

func _configure_node_position(tree: Node, node: Node, def: Dictionary) -> void:
    var pos := Vector2(float(def.get("x", 0)), float(def.get("y", 0)))
    var ref_id := str(def.get("ref", ""))
    if ref_id != "":
        var ref_node_path: String = str(node.name) if ref_id == "self" else str(ref_id)
        var ref := tree.get_node_or_null(ref_node_path)
        if ref != null:
            pos += Vector2(ref.position.x, ref.position.y)
    node.position = pos

func _configure_ascension_node(tree: Node, node: Node, def: Dictionary) -> void:
    var ref_id := str(def.get("ref", ""))
    if def.has("angle") or def.has("radius"):
        var angle := float(def.get("angle", 0.0))
        var radius := int(def.get("radius", 0))
        if angle < 0:
            angle += 360.0
        node.set("angle_degrees", angle)
        node.set("radius", radius)
        if ref_id != "":
            var ref_node_path: String = str(node.name) if ref_id == "self" else str(ref_id)
            var ref := tree.get_node_or_null(ref_node_path)
            if ref != null:
                node.set("center", ref)
        if node.has_method("update_radial_pos"):
            node.update_radial_pos()
    else:
        _configure_node_position(tree, node, def)
