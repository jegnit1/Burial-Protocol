extends "res://scenes/ui/MenuScreenScaffold.gd"


func _ready() -> void:
	var outcome := Locale.ltr("result_cleared") if GameState.run_cleared else Locale.ltr("result_failed")
	var content := build_screen(Locale.ltr("result_title"), outcome)
	add_label(content, Locale.ltr("result_reason") % GameState.latest_run_reason_label, 24)
	add_label(content, Locale.ltr("result_character") % GameState.latest_run_character_name, 24)
	add_label(content, Locale.ltr("result_difficulty") % GameState.latest_run_difficulty_name, 24)
	add_label(content, Locale.ltr("result_day_reached") % GameState.latest_run_stage_reached, 24)
	add_label(content, Locale.ltr("result_record") % GameState.latest_run_record, 26)
	add_spacer(content, 24)
	add_button(content, Locale.ltr("btn_exit"), _on_exit)


func _on_exit() -> void:
	change_scene("res://scenes/ui/MainHub.tscn")
