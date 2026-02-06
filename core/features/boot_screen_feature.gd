class_name TajsCoreBootScreenFeature
extends RefCounted

const LOG_NAME: String = "TajemnikTV-Core:BootScreen"
const APPEND_DELAY: int = 1 # Seconds to wait for vanilla text before appending

var _core: Variant
var _patched: bool = false
var _icon_path: String = "res://textures/icons/puzzle.png"


func setup(core: Variant) -> void:
    _core = core
    _connect_tree_signals()


@warning_ignore("unsafe_method_access")
func _connect_tree_signals() -> void:
    var tree: Variant = Engine.get_main_loop()
    @warning_ignore("unsafe_method_access")
    if tree != null and tree.has_signal("node_added"):
        @warning_ignore("unsafe_method_access")
        if not tree.node_added.is_connected(_on_node_added):
            @warning_ignore("unsafe_method_access")
            tree.node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
    if node.name == "Boot":
        _schedule_patch(node)


@warning_ignore("unsafe_method_access")
func _schedule_patch(boot_node: Node) -> void:
    if _patched:
        return
    # Wait for vanilla boot text to display first, then append our text
    var tree: Variant = Engine.get_main_loop()
    if tree == null:
        return
    @warning_ignore("unsafe_method_access")
    var timer: Variant = tree.create_timer(APPEND_DELAY)
    @warning_ignore("unsafe_method_access")
    timer.timeout.connect(_on_patch_timer_timeout.bind(boot_node))


func _on_patch_timer_timeout(boot_node: Node) -> void:
    if _patched or boot_node == null or not is_instance_valid(boot_node):
        return
    _patch_boot_screen(boot_node)
    _patched = true


@warning_ignore("unsafe_method_access")
func _patch_boot_screen(boot_node: Node) -> void:
    var core_version: String = "1.0.0"
    @warning_ignore("unsafe_method_access")
    if _core != null and _core.has_method("get_version"):
        @warning_ignore("unsafe_method_access")
        core_version = _core.get_version()
    
    var name_label: Variant = boot_node.get_node_or_null("LogoContainer/Name")
    var init_label: Variant = boot_node.get_node_or_null("LogoContainer/Label")
    
    # Append our text after vanilla text instead of replacing
    if name_label and not str(name_label.text).ends_with("+ Taj's Core"):
        name_label.text = name_label.text + " + Taj's Core"
        if init_label:
            init_label.text = init_label.text + " | Core v" + core_version

    var logo_rect: Variant = boot_node.get_node_or_null("LogoContainer/Logo")
    @warning_ignore("unsafe_method_access")
    if logo_rect and not logo_rect.has_node("TajsCoreIcon"):
        var icon_tex: Texture2D = null
        if ResourceLoader.exists(_icon_path):
            icon_tex = load(_icon_path) as Texture2D
        if icon_tex:
            var new_icon: TextureRect = TextureRect.new()
            new_icon.name = "TajsCoreIcon"
            new_icon.texture = icon_tex
            new_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            new_icon.custom_minimum_size = Vector2(110, 110)
            new_icon.size = Vector2(110, 110)
            @warning_ignore("unsafe_call_argument")
            new_icon.position = Vector2(
                (logo_rect.size.x - new_icon.size.x) / 2,
                - new_icon.size.y - 10
            )
            @warning_ignore("unsafe_method_access")
            logo_rect.add_child(new_icon)
