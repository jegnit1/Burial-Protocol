extends Node2D
class_name AttackModuleVisual

const WEAPON_ASSET_BASE_PATH := "res://assets/attack_modules/%s.png"
const VISUAL_ALPHA := 0.7
const ANIMATION_TYPE_ONE_HAND_GUN: StringName = &"one_hand_gun"
const ANIMATION_TYPE_TWO_HAND_GUN: StringName = &"two_hand_gun"
const ANIMATION_TYPE_SWING: StringName = &"swing"
const ANIMATION_TYPE_STAB: StringName = &"stab"

@export var module_id: StringName
@export var shape_style: StringName = &"sword"
@export var fill_color := Color.WHITE
@export var accent_color := Color(0.1, 0.12, 0.14, 1.0)
@export var visual_scale := 1.0

var _slot_sprite: Sprite2D
var _weapon_pivot: Node2D
var _weapon_sprite: Sprite2D
var _trail_visual: Node2D
var _effect_spawn_point: Node2D
var _slot_texture: Texture2D
var _weapon_texture: Texture2D
var _configured_grade := "D"
var _configured_icon_path := ""
var _animation_type: StringName = ANIMATION_TYPE_SWING
var _warned_missing_weapon_paths: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_visual_alpha()
	_ensure_sprite_nodes()
	_apply_asset_visuals()
	queue_redraw()


func configure(module_entry: Dictionary, module_definition = null) -> void:
	_apply_visual_alpha()
	var entry_module_id := String(module_entry.get("module_id", ""))
	if not entry_module_id.is_empty():
		module_id = StringName(entry_module_id)
	_configured_grade = String(module_entry.get("grade", "D")).strip_edges().to_upper()
	if _configured_grade.is_empty():
		_configured_grade = "D"
	_configured_icon_path = ""
	if module_definition != null:
		_configured_icon_path = String(module_definition.icon_path)
	_apply_asset_visuals()
	queue_redraw()


func set_animation_type(animation_type: StringName) -> void:
	if animation_type == StringName():
		animation_type = ANIMATION_TYPE_SWING
	_animation_type = animation_type
	_apply_pivot_offset()
	queue_redraw()


func _apply_visual_alpha() -> void:
	modulate.a = VISUAL_ALPHA


func _ensure_sprite_nodes() -> void:
	if _slot_sprite == null:
		_slot_sprite = get_node_or_null("SlotSprite") as Sprite2D
	if _slot_sprite == null:
		_slot_sprite = Sprite2D.new()
		_slot_sprite.name = "SlotSprite"
		add_child(_slot_sprite)
	_slot_sprite.centered = true
	_slot_sprite.z_index = 0
	_slot_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_slot_sprite.visible = false
	if _weapon_pivot == null:
		_weapon_pivot = get_node_or_null("WeaponPivot") as Node2D
	if _weapon_pivot == null:
		_weapon_pivot = Node2D.new()
		_weapon_pivot.name = "WeaponPivot"
		add_child(_weapon_pivot)
	if _weapon_sprite == null:
		_weapon_sprite = _weapon_pivot.get_node_or_null("WeaponSprite") as Sprite2D
	if _weapon_sprite == null:
		_weapon_sprite = Sprite2D.new()
		_weapon_sprite.name = "WeaponSprite"
		_weapon_pivot.add_child(_weapon_sprite)
	_weapon_sprite.centered = true
	_weapon_sprite.z_index = 1
	_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _trail_visual == null:
		_trail_visual = get_node_or_null("TrailVisual") as Node2D
	if _trail_visual == null:
		_trail_visual = Node2D.new()
		_trail_visual.name = "TrailVisual"
		add_child(_trail_visual)
	_trail_visual.visible = false
	if _effect_spawn_point == null:
		_effect_spawn_point = get_node_or_null("EffectSpawnPoint") as Node2D
	if _effect_spawn_point == null:
		_effect_spawn_point = Node2D.new()
		_effect_spawn_point.name = "EffectSpawnPoint"
		add_child(_effect_spawn_point)


func _apply_asset_visuals() -> void:
	_ensure_sprite_nodes()
	_weapon_texture = _load_weapon_texture()
	_slot_texture = null
	_slot_sprite.texture = null
	_weapon_sprite.texture = _weapon_texture
	_slot_sprite.visible = false
	_weapon_sprite.visible = _weapon_texture != null
	_weapon_sprite.scale = Vector2.ONE
	_apply_pivot_offset()


func _load_weapon_texture() -> Texture2D:
	var candidate_paths := _get_weapon_texture_candidate_paths()
	for path in candidate_paths:
		if path.is_empty():
			continue
		var loaded_texture := _load_texture_if_available(path)
		if loaded_texture != null:
			return loaded_texture
	for path in candidate_paths:
		if path.is_empty() or _warned_missing_weapon_paths.has(path):
			continue
		_warned_missing_weapon_paths[path] = true
		push_warning("Attack module weapon texture missing, using fallback visual: %s" % path)
	return null


func _load_texture_if_available(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)


func _get_weapon_texture_candidate_paths() -> Array[String]:
	var paths: Array[String] = []
	if not _configured_icon_path.is_empty():
		paths.append(_configured_icon_path)
	var asset_key := _get_weapon_asset_key()
	if not asset_key.is_empty():
		paths.append(WEAPON_ASSET_BASE_PATH % asset_key)
	paths.append(WEAPON_ASSET_BASE_PATH % String(module_id))
	return paths


func _get_weapon_asset_key() -> String:
	var key := String(module_id)
	if key.ends_with("_attack_module"):
		key = key.replace("_attack_module", "")
	elif key.ends_with("_module"):
		key = key.replace("_module", "")
	match key:
		"drone":
			return ""
		_:
			return key


func _apply_pivot_offset() -> void:
	_ensure_sprite_nodes()
	if _weapon_sprite == null:
		return
	var target_size := _get_weapon_visual_size()
	var pivot_ratio := _get_pivot_ratio()
	var pivot_position := Vector2(target_size.x * pivot_ratio.x, target_size.y * pivot_ratio.y)
	_weapon_sprite.position = target_size * 0.5 - pivot_position
	_weapon_pivot.position = Vector2.ZERO
	if _effect_spawn_point != null:
		_effect_spawn_point.position = Vector2(target_size.x - pivot_position.x, 0.0)


func _get_pivot_ratio() -> Vector2:
	match _animation_type:
		ANIMATION_TYPE_ONE_HAND_GUN:
			return Vector2(0.36, 0.55)
		ANIMATION_TYPE_TWO_HAND_GUN:
			return Vector2(0.42, 0.52)
		ANIMATION_TYPE_STAB:
			return Vector2(0.18, 0.50)
		_:
			return Vector2(0.20, 0.55)


func _get_weapon_visual_size() -> Vector2:
	if _weapon_sprite != null and _weapon_sprite.texture != null:
		return _weapon_sprite.texture.get_size()
	return Vector2(64.0, 64.0) * visual_scale


func _uses_asset_visual() -> bool:
	return _weapon_texture != null


func _draw() -> void:
	if _uses_asset_visual():
		return
	match shape_style:
		&"dagger":
			_draw_dagger()
		&"lance":
			_draw_lance()
		&"axe":
			_draw_axe()
		&"greatsword":
			_draw_greatsword()
		&"drone":
			_draw_drone()
		_:
			_draw_sword()


func _draw_sword() -> void:
	var hilt: Rect2 = _scaled_rect(Rect2(Vector2(-10.0, -3.0), Vector2(10.0, 6.0)))
	var blade: Rect2 = _scaled_rect(Rect2(Vector2(-1.0, -3.0), Vector2(26.0, 6.0)))
	draw_rect(hilt, accent_color)
	draw_rect(blade, fill_color)
	draw_line(_scaled_vector(Vector2(6.0, -6.0)), _scaled_vector(Vector2(6.0, 6.0)), accent_color, 2.0 * visual_scale)


func _draw_dagger() -> void:
	var hilt: Rect2 = _scaled_rect(Rect2(Vector2(-8.0, -2.5), Vector2(8.0, 5.0)))
	var blade_points: PackedVector2Array = _scaled_points([
		Vector2(-1.0, -4.0),
		Vector2(14.0, -2.0),
		Vector2(18.0, 0.0),
		Vector2(14.0, 2.0),
		Vector2(-1.0, 4.0),
	])
	draw_rect(hilt, accent_color)
	draw_colored_polygon(blade_points, fill_color)


func _draw_lance() -> void:
	var shaft: Rect2 = _scaled_rect(Rect2(Vector2(-14.0, -2.0), Vector2(28.0, 4.0)))
	var tip_points: PackedVector2Array = _scaled_points([
		Vector2(14.0, -5.0),
		Vector2(28.0, 0.0),
		Vector2(14.0, 5.0),
	])
	draw_rect(shaft, accent_color)
	draw_colored_polygon(tip_points, fill_color)


func _draw_axe() -> void:
	var handle: Rect2 = _scaled_rect(Rect2(Vector2(-12.0, -2.0), Vector2(18.0, 4.0)))
	var head_points: PackedVector2Array = _scaled_points([
		Vector2(4.0, -11.0),
		Vector2(16.0, -7.0),
		Vector2(18.0, 0.0),
		Vector2(16.0, 7.0),
		Vector2(4.0, 11.0),
		Vector2(8.0, 0.0),
	])
	draw_rect(handle, accent_color)
	draw_colored_polygon(head_points, fill_color)


func _draw_greatsword() -> void:
	var hilt: Rect2 = _scaled_rect(Rect2(Vector2(-12.0, -3.0), Vector2(12.0, 6.0)))
	var blade_points: PackedVector2Array = _scaled_points([
		Vector2(-1.0, -5.0),
		Vector2(20.0, -5.0),
		Vector2(27.0, 0.0),
		Vector2(20.0, 5.0),
		Vector2(-1.0, 5.0),
	])
	draw_rect(hilt, accent_color)
	draw_colored_polygon(blade_points, fill_color)
	draw_line(_scaled_vector(Vector2(5.0, -7.0)), _scaled_vector(Vector2(5.0, 7.0)), accent_color, 2.0 * visual_scale)


func _draw_drone() -> void:
	draw_circle(Vector2.ZERO, 9.0 * visual_scale, fill_color)
	draw_circle(Vector2.ZERO, 4.0 * visual_scale, accent_color)
	draw_line(_scaled_vector(Vector2(-14.0, 0.0)), _scaled_vector(Vector2(-6.0, 0.0)), accent_color, 2.0 * visual_scale)
	draw_line(_scaled_vector(Vector2(6.0, 0.0)), _scaled_vector(Vector2(14.0, 0.0)), accent_color, 2.0 * visual_scale)


func _scaled_rect(value: Rect2) -> Rect2:
	return Rect2(
		_scaled_vector(value.position),
		_scaled_vector(value.size)
	)


func _scaled_vector(value: Vector2) -> Vector2:
	return value * visual_scale


func _scaled_points(points: Array[Vector2]) -> PackedVector2Array:
	var scaled_points := PackedVector2Array()
	for point in points:
		scaled_points.append(_scaled_vector(point))
	return scaled_points
