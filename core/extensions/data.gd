extends "res://scripts/data.gd"

func update_save(data: Dictionary) -> void:
    super (data)
    var core: Variant = Engine.get_meta("TajsCore", null)
    @warning_ignore("unsafe_method_access")
    if core != null and core.window_scenes != null:
        @warning_ignore("unsafe_method_access")
        core.window_scenes.normalize_saved_windows(data)
