extends "res://scenes/ui/MenuScreenScaffold.gd"


func _ready() -> void:
	var content := build_screen(
		"Achievements",
		"Placeholder screen. This phase only guarantees scene entry and return flow."
	)
	add_label(content, "Real achievement logic is intentionally not implemented in phase 1.", 24)
	add_spacer(content, 24)
	add_button(content, "Back", _on_back)


func _on_back() -> void:
	change_scene("res://scenes/ui/MainHub.tscn")
