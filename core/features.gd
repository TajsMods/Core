class_name TajsCoreFeatures
extends RefCounted

var _settings
var _features: Dictionary = {}

func setup(settings) -> void:
    _settings = settings
    _load_overrides()

func register_feature(feature_id: String, default_enabled: bool, description: String = "") -> void:
    if feature_id == "":
        return
    if not _features.has(feature_id):
        _features[feature_id] = {
            "enabled": default_enabled,
            "default": default_enabled,
            "description": description
        }
    var overrides := _get_overrides()
    if overrides.has(feature_id):
        _features[feature_id]["enabled"] = bool(overrides[feature_id])
    else:
        _save_override(feature_id, default_enabled)

func is_feature_enabled(feature_id: String) -> bool:
    if not _features.has(feature_id):
        return false
    return bool(_features[feature_id]["enabled"])

func set_feature_enabled(feature_id: String, enabled: bool) -> void:
    if not _features.has(feature_id):
        _features[feature_id] = {"enabled": enabled, "default": enabled, "description": ""}
    _save_override(feature_id, enabled)
    _features[feature_id]["enabled"] = enabled

func list_features() -> Array:
    return _features.keys()

func _load_overrides() -> void:
    var overrides := _get_overrides()
    for feature_id in _features:
        if overrides.has(feature_id):
            _features[feature_id]["enabled"] = bool(overrides[feature_id])

func _get_overrides() -> Dictionary:
    if _settings != null and _settings.has_method("get_dict"):
        return _settings.get_dict("core.features", {})
    return {}

func _save_override(feature_id: String, enabled: bool) -> void:
    if _settings == null or not _settings.has_method("set_value"):
        return
    var overrides := _get_overrides()
    overrides[feature_id] = enabled
    _settings.set_value("core.features", overrides)
