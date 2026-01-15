extends "res://main.gd"

func _ready() -> void:
	super ()
	var core = Engine.get_meta("TajsCore", null)
	if core == null or core.trees == null:
		return
	if has_node("Main2D/Research"):
		var research_screen := $Main2D/Research
		var research_tree := $Main2D/Research/Tree
		core.trees.apply_research_tree(research_screen, research_tree)
	if has_node("Main2D/Ascension"):
		var ascension_screen := $Main2D/Ascension
		var ascension_tree := $Main2D/Ascension/Tree
		core.trees.apply_ascension_tree(ascension_screen, ascension_tree)
