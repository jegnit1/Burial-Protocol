extends "res://scenes/ui/MenuScreenScaffold.gd"


func _ready() -> void:
	var content := build_screen(
		Locale.ltr("itemlist_title"),
		Locale.ltr("itemlist_subtitle")
	)
	add_label(content, Locale.ltr("itemlist_note"), 24)
	add_spacer(content, 24)
	add_button(content, Locale.ltr("btn_back"), _on_back)


func _on_back() -> void:
	change_scene("res://scenes/ui/MainHub.tscn")
