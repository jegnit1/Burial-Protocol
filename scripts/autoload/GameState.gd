extends Node

signal gold_changed(value: int)
signal health_changed(current: int, maximum: int)
signal status_text_changed(text: String)

var gold := 0
var player_health := GameConstants.PLAYER_MAX_HEALTH
var status_text := "Phase 0 bootstrap complete."


func reset_run() -> void:
	gold = 0
	player_health = GameConstants.PLAYER_MAX_HEALTH
	status_text = "Hold the center. Mine the walls if the sand rises."
	gold_changed.emit(gold)
	health_changed.emit(player_health, GameConstants.PLAYER_MAX_HEALTH)
	status_text_changed.emit(status_text)


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func damage_player(amount: int) -> void:
	player_health = max(player_health - amount, 0)
	health_changed.emit(player_health, GameConstants.PLAYER_MAX_HEALTH)


func set_status_text(text: String) -> void:
	status_text = text
	status_text_changed.emit(status_text)
