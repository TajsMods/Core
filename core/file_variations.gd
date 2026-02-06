class_name TajsCoreFileVariations
extends RefCounted

const CUSTOM_START := 60
const MIN_CUSTOM_BIT := 32
const MAP_SETTING_KEY := "core.file_variations.map"

var _settings: Variant
var _logger: Variant
var _bit_map: Dictionary = {}
var _entries: Dictionary = {}
var _symbols: Dictionary = {}

func _init(settings: Variant = null, logger: Variant = null) -> void:
    _settings = settings
    _logger = logger
    _load_map()

func register_variations(mod_id: String, defs: Dictionary, symbols: Dictionary = {}, symbol_type: String = "file") -> Dictionary:
    var masks: Dictionary = {}
    if defs.is_empty():
        return masks
    for local_id: Variant in defs.keys():
        var full_id := _make_id(mod_id, str(local_id))
        var bit := _ensure_bit(full_id)
        if bit < 0:
            continue
        var mask := 1 << bit
        var config: Dictionary = {}
        if defs[local_id] is Dictionary:
            config = defs[local_id]
        _entries[full_id] = {
            "id": full_id,
            "bit": bit,
            "mask": mask,
            "config": config.duplicate(true)
        }
        masks[local_id] = mask
    if not symbols.is_empty():
        register_symbols(symbol_type, symbols, mod_id)
    return masks

func register_symbols(symbol_type: String, symbols: Dictionary, mod_id: String = "") -> void:
    if symbol_type == "" or symbols.is_empty():
        return
    if not _symbols.has(symbol_type):
        _symbols[symbol_type] = {}
    for local_id: Variant in symbols.keys():
        var full_id := _make_id(mod_id, str(local_id))
        _symbols[symbol_type][full_id] = symbols[local_id]

func get_mask(mod_id: String, local_id: String) -> int:
    return get_mask_by_id(_make_id(mod_id, local_id))

func get_mask_by_id(variation_id: String) -> int:
    if not _entries.has(variation_id):
        return 0
    return int(_entries[variation_id]["mask"])

func get_multiplier(variation: int, key: String) -> float:
    if key == "":
        return 1.0
    var multiplier := 1.0
    for entry: Variant in _entries.values():
        var mask := int(entry["mask"])
        if variation & mask:
            var config: Dictionary = entry["config"]
            if config.has(key):
                multiplier *= float(config[key])
    return multiplier

func get_symbols(symbol_type: String, variation: int) -> String:
    if symbol_type == "":
        return ""
    if not _symbols.has(symbol_type):
        return ""
    var output := ""
    var table: Dictionary = _symbols[symbol_type]
    for full_id: Variant in table.keys():
        var mask := get_mask_by_id(full_id)
        if mask != 0 and variation & mask:
            output += str(table[full_id])
    return output

func list_variations() -> Array:
    return _entries.keys()

func _make_id(mod_id: String, local_id: String) -> String:
    if mod_id == "":
        return local_id
    if local_id.begins_with(mod_id + "."):
        return local_id
    return "%s.%s" % [mod_id, local_id]

func _ensure_bit(full_id: String) -> int:
    if _bit_map.has(full_id):
        return int(_bit_map[full_id])
    var bit := _find_free_bit()
    if bit < 0:
        _log_warn("files", "No free bits for file variation '%s'." % full_id)
        return -1
    _bit_map[full_id] = bit
    _store_map()
    return bit

func _find_free_bit() -> int:
    var used: Dictionary = {}
    for full_id: Variant in _bit_map.keys():
        used[int(_bit_map[full_id])] = true
    for bit: Variant in range(CUSTOM_START, MIN_CUSTOM_BIT - 1, -1):
        if not used.has(bit):
            return bit
    return -1

func _load_map() -> void:
    if _settings == null or not _settings.has_method("get_dict"):
        return
    var stored: Variant = _settings.get_dict(MAP_SETTING_KEY, {})
    if stored is Dictionary:
        for key: Variant in stored.keys():
            _bit_map[str(key)] = int(stored[key])

func _store_map() -> void:
    if _settings == null or not _settings.has_method("set_value"):
        return
    _settings.set_value(MAP_SETTING_KEY, _bit_map.duplicate())

func _log_warn(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("warn"):
        _logger.warn(module_id, message)
