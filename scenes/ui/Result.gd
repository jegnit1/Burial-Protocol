extends "res://scenes/ui/MenuScreenScaffold.gd"


func _ready() -> void:
	var content := build_screen(
		"Result",
		"Minimal run summary after game over or run end."
	)
	add_label(content, "Reason: %s" % GameState.latest_run_reason_label, 24)
	add_label(content, "Character: %s" % GameState.latest_run_character_name, 24)
	add_label(content, "Difficulty: %s" % GameState.latest_run_difficulty_name, 24)
	add_label(content, "Stage Reached: %d" % GameState.latest_run_stage_reached, 24)
	add_label(content, "Run Record: %s" % GameState.latest_run_record, 26)
	add_spacer(content, 24)
	add_button(content, "Exit", _on_exit)


func _on_exit() -> void:
	change_scene("res://scenes/ui/MainHub.tscn")
