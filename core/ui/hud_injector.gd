# ==============================================================================
# Taj's Core - HUD Injector
# Author: TajemnikTV
# Description: Standard HUD injection zones for mods.
# ==============================================================================
class_name TajsCoreHudInjector
extends Node

enum HudZone {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
	OVERLAY_CENTER,
	TOOLBAR_LEFT,
	TOOLBAR_RIGHT,
	STATUS_BAR
}

var _hud: Node
var _zones: Dictionary = {}

func setup(hud: Node) -> void:
	_hud = hud
	_create_zones()

func inject_widget(zone: int, widget: Control, priority: int = 0) -> void:
	var container: Control = get_zone_container(zone)
	if container == null or widget == null:
		return
	widget.set_meta("priority", priority)
	container.add_child(widget)
	_sort_by_priority(container)

func remove_widget(widget: Control) -> void:
	if widget == null:
		return
	var parent := widget.get_parent()
	if parent != null:
		parent.remove_child(widget)

func get_zone_container(zone: int) -> Control:
	if _zones.has(zone):
		return _zones[zone]
	return null

func _create_zones() -> void:
	if _hud == null:
		return
	var overlay = _hud.get_node_or_null("Main/MainContainer/Overlay")
	if overlay == null:
		return
	if overlay.has_node("TajsCoreHudZones"):
		return
	var root := Control.new()
	root.name = "TajsCoreHudZones"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(root)

	_zones[HudZone.TOP_LEFT] = _make_zone(root, "TopLeft", Vector2(0, 0), Vector2(0, 0))
	_zones[HudZone.TOP_RIGHT] = _make_zone(root, "TopRight", Vector2(1, 0), Vector2(1, 0))
	_zones[HudZone.BOTTOM_LEFT] = _make_zone(root, "BottomLeft", Vector2(0, 1), Vector2(0, 1))
	_zones[HudZone.BOTTOM_RIGHT] = _make_zone(root, "BottomRight", Vector2(1, 1), Vector2(1, 1))
	_zones[HudZone.OVERLAY_CENTER] = _make_zone(root, "OverlayCenter", Vector2(0.5, 0.5), Vector2(0.5, 0.5))
	_zones[HudZone.TOOLBAR_LEFT] = _make_zone(root, "ToolbarLeft", Vector2(0, 0.5), Vector2(0, 0.5))
	_zones[HudZone.TOOLBAR_RIGHT] = _make_zone(root, "ToolbarRight", Vector2(1, 0.5), Vector2(1, 0.5))
	_zones[HudZone.STATUS_BAR] = _make_zone(root, "StatusBar", Vector2(0.5, 1), Vector2(0.5, 1))

func _make_zone(parent: Control, name: String, anchor: Vector2, pivot: Vector2) -> Control:
	var zone := VBoxContainer.new()
	zone.name = name
	zone.set_anchors_preset(Control.PRESET_TOP_LEFT)
	zone.anchor_left = anchor.x
	zone.anchor_right = anchor.x
	zone.anchor_top = anchor.y
	zone.anchor_bottom = anchor.y
	zone.pivot_offset = Vector2(0, 0)
	zone.position = Vector2(0, 0)
	zone.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	zone.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(zone)
	return zone

func _sort_by_priority(container: Control) -> void:
	var items := container.get_children()
	items.sort_custom(func(a, b):
		var pa = int(a.get_meta("priority", 0))
		var pb = int(b.get_meta("priority", 0))
		return pa < pb
	)
	for i in range(items.size()):
		container.move_child(items[i], i)
