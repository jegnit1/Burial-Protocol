extends RefCounted
class_name DamagePopupManager

const DAMAGE_POPUP_SCRIPT := preload("res://scenes/ui/DamagePopup.gd")
const SLOT_REUSE_WINDOW := 0.35
const SLOT_JITTER_X := 3.0
const SLOT_JITTER_Y := 2.0

const BASE_SLOT_OFFSETS := [
	Vector2(0.0, -8.0),
	Vector2(-18.0, -10.0),
	Vector2(18.0, -10.0),
	Vector2(-10.0, -24.0),
	Vector2(10.0, -24.0),
	Vector2(0.0, -36.0),
]

const OVERFLOW_X_OFFSETS := [0.0, -12.0, 12.0]

var _target_slot_records: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func request_popup(
	parent: Node,
	target_id: int,
	anchor_position: Vector2,
	amount: int,
	text_color: Color = GameConstants.DAMAGE_POPUP_TEXT_COLOR,
	shadow_color: Color = GameConstants.DAMAGE_POPUP_SHADOW_COLOR,
	prefix: String = "",
	suffix: String = ""
) -> void:
	if parent == null or amount <= 0:
		return
	var now := Time.get_ticks_msec() * 0.001
	var slot_index := _allocate_slot(target_id, now)
	var slot_offset := _get_slot_offset(slot_index)
	var jitter := Vector2(
		_rng.randf_range(-SLOT_JITTER_X, SLOT_JITTER_X),
		_rng.randf_range(-SLOT_JITTER_Y, SLOT_JITTER_Y)
	)
	var popup := DAMAGE_POPUP_SCRIPT.new() as Node2D
	parent.add_child(popup)
	popup.global_position = anchor_position + slot_offset + jitter
	popup.call("setup", amount, text_color, shadow_color, prefix, suffix)
	if popup.has_method("set_motion"):
		popup.call("set_motion", _get_slot_drift(slot_offset))


func _allocate_slot(target_id: int, now: float) -> int:
	_cleanup_target_records(target_id, now)
	var records: Array = _target_slot_records.get(target_id, [])
	var used_slots: Dictionary = {}
	for raw_record in records:
		var record: Dictionary = raw_record
		used_slots[int(record.get("slot", -1))] = true
	for index in range(BASE_SLOT_OFFSETS.size()):
		if not used_slots.has(index):
			records.append({"slot": index, "time": now})
			_target_slot_records[target_id] = records
			return index
	var overflow_index := BASE_SLOT_OFFSETS.size()
	while used_slots.has(overflow_index):
		overflow_index += 1
	records.append({"slot": overflow_index, "time": now})
	_target_slot_records[target_id] = records
	return overflow_index


func _cleanup_target_records(target_id: int, now: float) -> void:
	if not _target_slot_records.has(target_id):
		return
	var fresh_records: Array = []
	for raw_record in (_target_slot_records[target_id] as Array):
		var record: Dictionary = raw_record
		if now - float(record.get("time", 0.0)) <= SLOT_REUSE_WINDOW:
			fresh_records.append(record)
	if fresh_records.is_empty():
		_target_slot_records.erase(target_id)
	else:
		_target_slot_records[target_id] = fresh_records


func _get_slot_offset(slot_index: int) -> Vector2:
	if slot_index < BASE_SLOT_OFFSETS.size():
		return BASE_SLOT_OFFSETS[slot_index]
	var extra_index := slot_index - BASE_SLOT_OFFSETS.size()
	var row := int(floor(float(extra_index) / float(OVERFLOW_X_OFFSETS.size())))
	var column := extra_index % OVERFLOW_X_OFFSETS.size()
	return Vector2(OVERFLOW_X_OFFSETS[column], -48.0 - float(row) * 16.0)


func _get_slot_drift(slot_offset: Vector2) -> Vector2:
	var side_push := clampf(slot_offset.x / 36.0, -1.0, 1.0)
	return Vector2(side_push * 18.0, -GameConstants.DAMAGE_POPUP_RISE_SPEED)
