extends "res://scenes/ui/MenuScreenScaffold.gd"


func _ready() -> void:
	var content := build_screen(
		"Growth",
		"Placeholder screen. Permanent growth systems are intentionally deferred."
	)
	add_label(content, "Growth trees and spending flows are not part of phase 1.", 24)
	add_spacer(content, 24)
	add_button(content, "Back", _on_back)


func _on_back() -> void:
	change_scene("res://scenes/ui/MainHub.tscn")
