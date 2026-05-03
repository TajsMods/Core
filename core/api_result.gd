class_name TajsCoreApiResult
extends RefCounted

## Helper for building stable Core wrapper API result dictionaries.
##
## Standard shape:
## - ok: bool
## - error: String (empty when ok=true)
## - any additional payload fields
static func ok(data: Dictionary = {}) -> Dictionary:
    var result: Dictionary = {"ok": true, "error": ""}
    for key: Variant in data.keys():
        result[key] = data[key]
    return result

static func fail(error_code: String, data: Dictionary = {}) -> Dictionary:
    var result: Dictionary = {"ok": false, "error": error_code}
    for key: Variant in data.keys():
        result[key] = data[key]
    return result
