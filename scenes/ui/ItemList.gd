extends "res://scenes/ui/MenuScreenScaffold.gd"


func _ready() -> void:
	var content := build_screen(
		"Item List",
		"Placeholder screen. This phase only defines a reachable empty item list scene."
	)
	add_label(content, "Collection and ownership details are deferred to a later phase.", 24)
	add_spacer(content, 24)
	add_button(content, "Back", _on_back)


func _on_back() -> void:
	change_scene("res://scenes/ui/MainHub.tscn")
