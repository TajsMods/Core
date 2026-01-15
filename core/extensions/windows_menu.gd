extends "res://scripts/windows_menu.gd"

func _ready() -> void:
	var core = Engine.get_meta("TajsCore", null)
	if core != null and core.window_menus != null:
		core.window_menus.ensure_tabs($Categories)
	super ()

func open_tab(tab: int) -> void:
	var child: Control = _get_tab_node(tab)
	if child == null:
		return
	child.visible = true
	child.modulate.a = 0
	child.offset_top = 236

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(child, "modulate:a", 1, 0.25)
	tween.tween_property(child, "offset_top", 0, 0.25)
	tween.finished.connect(func() -> void: child.visible = true)

func close_tab(tab: int) -> void:
	var child: Control = _get_tab_node(tab)
	if child == null:
		return
	child.visible = true
	child.modulate.a = 1
	child.offset_top = 0

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(child, "offset_top", 236, 0.25)
	tween.tween_property(child, "modulate:a", 0, 0.25)
	tween.finished.connect(func() -> void: child.visible = false)

func add_window(w: String) -> void:
	var path := _resolve_window_scene(w)
	if path == "":
		return
	var window: WindowContainer = load(path).instantiate()
	window.name = w
	window.global_position = Vector2(Globals.camera_center - window.size / 2).snappedf(50)
	Signals.create_window.emit(window)

func _on_add_pressed() -> void:
	if Globals.max_window_count >= Utils.MAX_WINDOW:
		Signals.notify.emit("exclamation", "build_limit_reached")
		Sound.play("error")
		return
	elif Utils.can_add_window(cur_window):
		add_window(cur_window)
		Signals.set_menu.emit(0, 0)

func _get_tab_node(tab: int) -> Control:
	var core = Engine.get_meta("TajsCore", null)
	if core != null and core.window_menus != null:
		var custom: Control = core.window_menus.get_panel_for_tab(tab, $Categories)
		if custom != null:
			return custom
	if category_tabs.has(tab):
		return $Categories.get_node(category_tabs[tab])
	return null

func _resolve_window_scene(window_id: String) -> String:
	if not Data.windows.has(window_id):
		return ""
	var scene := str(Data.windows[window_id].scene)
	if scene == "":
		return ""
	var core = Engine.get_meta("TajsCore", null)
	if core != null and core.window_scenes != null:
		return core.window_scenes.resolve_scene_path(scene)
	var file_name := scene
	if not file_name.ends_with(".tscn"):
		file_name += ".tscn"
	return "res://scenes/windows".path_join(file_name)
