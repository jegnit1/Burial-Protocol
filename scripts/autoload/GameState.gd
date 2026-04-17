extends Node

signal gold_changed(value: int)
signal health_changed(current: int, maximum: int)
signal status_text_changed(text: String)
signal selected_character_changed(character_id: String, character_name: String, best_record: String)

const SAVE_FILE_PATH := "user://profile.save"
const SAVE_VERSION := 1

const DEFAULT_CURRENCIES := {
	"gear": 0,
	"plywood": 0,
	"lubricant": 0,
	"iron_ore": 0,
	"power": 0,
}

const DEFAULT_SETTINGS := {
	"master_volume": 1.0,
	"fullscreen": false,
}

const DEFAULT_GROWTH := {
	"attack_level": 0,
	"mining_level": 0,
	"defense_level": 0,
	"mobility_level": 0,
}

const CHARACTER_SLOTS := [
	{
		"id": "default_worker",
		"display_name": "Default Worker",
		"default_unlocked": true,
		"unlock_text": "Available from the start.",
	},
	{
		"id": "locked_slot_01",
		"display_name": "Locked Slot 01",
		"default_unlocked": false,
		"unlock_text": "Unlock condition placeholder 01",
	},
	{
		"id": "locked_slot_02",
		"display_name": "Locked Slot 02",
		"default_unlocked": false,
		"unlock_text": "Unlock condition placeholder 02",
	},
	{
		"id": "locked_slot_03",
		"display_name": "Locked Slot 03",
		"default_unlocked": false,
		"unlock_text": "Unlock condition placeholder 03",
	},
	{
		"id": "locked_slot_04",
		"display_name": "Locked Slot 04",
		"default_unlocked": false,
		"unlock_text": "Unlock condition placeholder 04",
	},
	{
		"id": "locked_slot_05",
		"display_name": "Locked Slot 05",
		"default_unlocked": false,
		"unlock_text": "Unlock condition placeholder 05",
	},
	{
		"id": "locked_slot_06",
		"display_name": "Locked Slot 06",
		"default_unlocked": false,
		"unlock_text": "Unlock condition placeholder 06",
	},
	{
		"id": "locked_slot_07",
		"display_name": "Locked Slot 07",
		"default_unlocked": false,
		"unlock_text": "Unlock condition placeholder 07",
	},
	{
		"id": "locked_slot_08",
		"display_name": "Locked Slot 08",
		"default_unlocked": false,
		"unlock_text": "Unlock condition placeholder 08",
	},
	{
		"id": "locked_slot_09",
		"display_name": "Locked Slot 09",
		"default_unlocked": false,
		"unlock_text": "Unlock condition placeholder 09",
	},
]

const DIFFICULTY_OPTIONS := [
	{
		"id": "normal",
		"display_name": "Normal",
	},
	{
		"id": "hard",
		"display_name": "Hard",
	},
	{
		"id": "hell",
		"display_name": "Hell",
	},
	{
		"id": "extreme",
		"display_name": "Extreme",
	},
]

var gold := 0
var player_health := GameConstants.PLAYER_MAX_HEALTH
var status_text := "Phase 0 bootstrap complete."
var latest_run_record := "No run played yet."
var latest_run_reason_id := "none"
var latest_run_reason_label := "No result"
var latest_run_stage_reached := 0
var latest_run_difficulty_name := "Normal"
var latest_run_character_name := "Default Worker"
var selected_character_id := "default_worker"
var selected_character_name := "Default Worker"
var best_record_summary := "No record yet."
var last_selected_difficulty_id := "normal"
var last_selected_difficulty_name := "Normal"
var current_run_character_id := "default_worker"
var current_run_character_name := "Default Worker"
var current_run_difficulty_id := "normal"
var current_run_difficulty_name := "Normal"
var current_run_stage_reached := 1
var persistent_currencies: Dictionary = {}
var settings_data: Dictionary = {}
var growth_data: Dictionary = {}
var unlocked_character_ids: PackedStringArray = PackedStringArray()
var unlocked_achievement_ids: PackedStringArray = PackedStringArray()
var best_records_by_character: Dictionary = {}


func _ready() -> void:
	load_profile()
	_emit_initial_state()


func reset_run() -> void:
	gold = 0
	player_health = GameConstants.PLAYER_MAX_HEALTH
	current_run_stage_reached = 1
	status_text = "Run started. Character: %s | Difficulty: %s | Press R to end the run." % [
		current_run_character_name,
		current_run_difficulty_name,
	]
	gold_changed.emit(gold)
	health_changed.emit(player_health, GameConstants.PLAYER_MAX_HEALTH)
	status_text_changed.emit(status_text)


func finish_temporary_run(reason_id: String = "run_end", reason_label: String = "Run Ended") -> void:
	latest_run_reason_id = reason_id
	latest_run_reason_label = reason_label
	latest_run_stage_reached = current_run_stage_reached
	latest_run_difficulty_name = current_run_difficulty_name
	latest_run_character_name = current_run_character_name
	_update_best_record(current_run_character_id, current_run_difficulty_id, current_run_stage_reached)
	latest_run_record = "%s | %s | Stage %d | Gold %d | Health %d/%d" % [
		current_run_character_name,
		current_run_difficulty_name,
		current_run_stage_reached,
		gold,
		player_health,
		GameConstants.PLAYER_MAX_HEALTH,
	]
	_refresh_selected_character_summary()
	save_profile()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func damage_player(amount: int) -> void:
	player_health = max(player_health - amount, 0)
	health_changed.emit(player_health, GameConstants.PLAYER_MAX_HEALTH)


func set_status_text(text: String) -> void:
	status_text = text
	status_text_changed.emit(status_text)


func get_character_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot_data in CHARACTER_SLOTS:
		var slot: Dictionary = slot_data.duplicate()
		var character_id := String(slot["id"])
		slot["unlocked"] = _is_character_unlocked(character_id)
		slot["best_record"] = _get_character_best_record_summary(character_id)
		slot["selected"] = character_id == selected_character_id
		slots.append(slot)
	return slots


func get_difficulty_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for option_data in DIFFICULTY_OPTIONS:
		var option: Dictionary = option_data.duplicate()
		option["selected"] = option["id"] == last_selected_difficulty_id
		options.append(option)
	return options


func select_character(character_id: String) -> bool:
	if not _is_character_unlocked(character_id):
		return false
	var display_name := _get_character_display_name(character_id)
	if display_name.is_empty():
		return false
	selected_character_id = character_id
	selected_character_name = display_name
	_refresh_selected_character_summary()
	selected_character_changed.emit(selected_character_id, selected_character_name, best_record_summary)
	save_profile()
	return true


func begin_run(difficulty_id: String) -> bool:
	for option_data in DIFFICULTY_OPTIONS:
		if option_data["id"] != difficulty_id:
			continue
		last_selected_difficulty_id = String(option_data["id"])
		last_selected_difficulty_name = String(option_data["display_name"])
		current_run_difficulty_id = last_selected_difficulty_id
		current_run_difficulty_name = last_selected_difficulty_name
		current_run_character_id = selected_character_id
		current_run_character_name = selected_character_name
		current_run_stage_reached = 1
		save_profile()
		return true
	return false


func apply_growth_change(changes: Dictionary) -> void:
	for key in changes.keys():
		growth_data[String(key)] = changes[key]
	save_profile()


func apply_setting_change(setting_name: String, value: Variant) -> void:
	settings_data[setting_name] = value
	save_profile()


func register_achievement_unlock(achievement_id: String) -> void:
	if unlocked_achievement_ids.has(achievement_id):
		return
	unlocked_achievement_ids.append(achievement_id)
	save_profile()


func unlock_character(character_id: String) -> void:
	if unlocked_character_ids.has(character_id):
		return
	unlocked_character_ids.append(character_id)
	save_profile()


func save_profile() -> void:
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: %s" % SAVE_FILE_PATH)
		return
	file.store_string(JSON.stringify(_build_save_data(), "\t"))


func load_profile() -> void:
	_apply_save_data(_default_save_data())
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		save_profile()
		return
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file for reading: %s" % SAVE_FILE_PATH)
		save_profile()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid save file format. Resetting to defaults.")
		_apply_save_data(_default_save_data())
		save_profile()
		return
	_apply_save_data(parsed)
	save_profile()


func _build_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"selected_character_id": selected_character_id,
		"last_selected_difficulty_id": last_selected_difficulty_id,
		"persistent_currencies": persistent_currencies.duplicate(true),
		"settings": settings_data.duplicate(true),
		"growth": growth_data.duplicate(true),
		"unlocked_character_ids": Array(unlocked_character_ids),
		"unlocked_achievement_ids": Array(unlocked_achievement_ids),
		"best_records_by_character": best_records_by_character.duplicate(true),
	}


func _default_save_data() -> Dictionary:
	var unlocked_ids: Array[String] = []
	var records: Dictionary = {}
	for slot_data in CHARACTER_SLOTS:
		var character_id := String(slot_data["id"])
		if bool(slot_data["default_unlocked"]):
			unlocked_ids.append(character_id)
		records[character_id] = _default_difficulty_record_map()
	return {
		"save_version": SAVE_VERSION,
		"selected_character_id": "default_worker",
		"last_selected_difficulty_id": "normal",
		"persistent_currencies": DEFAULT_CURRENCIES.duplicate(true),
		"settings": DEFAULT_SETTINGS.duplicate(true),
		"growth": DEFAULT_GROWTH.duplicate(true),
		"unlocked_character_ids": unlocked_ids,
		"unlocked_achievement_ids": [],
		"best_records_by_character": records,
	}


func _apply_save_data(data: Dictionary) -> void:
	var default_data := _default_save_data()
	persistent_currencies = _merge_simple_dict(
		default_data["persistent_currencies"],
		data.get("persistent_currencies", {})
	)
	settings_data = _merge_simple_dict(
		default_data["settings"],
		data.get("settings", {})
	)
	growth_data = _merge_simple_dict(
		default_data["growth"],
		data.get("growth", {})
	)
	unlocked_character_ids = PackedStringArray(_normalize_string_array(
		data.get("unlocked_character_ids", default_data["unlocked_character_ids"])
	))
	if unlocked_character_ids.is_empty():
		unlocked_character_ids.append("default_worker")
	unlocked_achievement_ids = PackedStringArray(_normalize_string_array(
		data.get("unlocked_achievement_ids", [])
	))
	best_records_by_character = _normalize_best_records(
		data.get("best_records_by_character", default_data["best_records_by_character"])
	)
	selected_character_id = String(data.get("selected_character_id", "default_worker"))
	if not _is_character_unlocked(selected_character_id):
		selected_character_id = "default_worker"
	last_selected_difficulty_id = String(data.get("last_selected_difficulty_id", "normal"))
	last_selected_difficulty_name = _get_difficulty_display_name(last_selected_difficulty_id)
	selected_character_name = _get_character_display_name(selected_character_id)
	current_run_character_id = selected_character_id
	current_run_character_name = selected_character_name
	current_run_difficulty_id = last_selected_difficulty_id
	current_run_difficulty_name = last_selected_difficulty_name
	_refresh_selected_character_summary()


func _emit_initial_state() -> void:
	gold_changed.emit(gold)
	health_changed.emit(player_health, GameConstants.PLAYER_MAX_HEALTH)
	status_text_changed.emit(status_text)
	selected_character_changed.emit(selected_character_id, selected_character_name, best_record_summary)


func _merge_simple_dict(defaults: Dictionary, overrides: Variant) -> Dictionary:
	var merged := defaults.duplicate(true)
	if typeof(overrides) != TYPE_DICTIONARY:
		return merged
	for key in overrides.keys():
		merged[String(key)] = overrides[key]
	return merged


func _normalize_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(String(item))
	return result


func _normalize_best_records(value: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	for slot_data in CHARACTER_SLOTS:
		var character_id := String(slot_data["id"])
		normalized[character_id] = _default_difficulty_record_map()
	if typeof(value) != TYPE_DICTIONARY:
		return normalized
	for character_id_variant in value.keys():
		var character_id := String(character_id_variant)
		if not normalized.has(character_id):
			normalized[character_id] = _default_difficulty_record_map()
		var source_records: Dictionary = value[character_id_variant]
		if typeof(source_records) != TYPE_DICTIONARY:
			continue
		for difficulty in DIFFICULTY_OPTIONS:
			var difficulty_id := String(difficulty["id"])
			normalized[character_id][difficulty_id] = int(source_records.get(difficulty_id, 0))
	return normalized


func _default_difficulty_record_map() -> Dictionary:
	var records: Dictionary = {}
	for difficulty in DIFFICULTY_OPTIONS:
		records[String(difficulty["id"])] = 0
	return records


func _is_character_unlocked(character_id: String) -> bool:
	return unlocked_character_ids.has(character_id)


func _get_character_display_name(character_id: String) -> String:
	for slot_data in CHARACTER_SLOTS:
		if String(slot_data["id"]) == character_id:
			return String(slot_data["display_name"])
	return ""


func _get_difficulty_display_name(difficulty_id: String) -> String:
	for option_data in DIFFICULTY_OPTIONS:
		if String(option_data["id"]) == difficulty_id:
			return String(option_data["display_name"])
	return "Normal"


func _get_character_best_record_summary(character_id: String) -> String:
	if not best_records_by_character.has(character_id):
		return "No record yet."
	var record_map := best_records_by_character[character_id] as Dictionary
	var best_stage := 0
	var best_difficulty_name := ""
	for option_data in DIFFICULTY_OPTIONS:
		var difficulty_id := String(option_data["id"])
		var stage_value := int(record_map.get(difficulty_id, 0))
		if stage_value > best_stage:
			best_stage = stage_value
			best_difficulty_name = String(option_data["display_name"])
	if best_stage <= 0:
		return "No record yet."
	return "%s - Stage %d" % [best_difficulty_name, best_stage]


func _refresh_selected_character_summary() -> void:
	best_record_summary = _get_character_best_record_summary(selected_character_id)


func _update_best_record(character_id: String, difficulty_id: String, stage_reached: int) -> void:
	if not best_records_by_character.has(character_id):
		best_records_by_character[character_id] = _default_difficulty_record_map()
	var record_map := best_records_by_character[character_id] as Dictionary
	record_map[difficulty_id] = maxi(int(record_map.get(difficulty_id, 0)), stage_reached)
	best_records_by_character[character_id] = record_map
