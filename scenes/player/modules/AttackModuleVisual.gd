extends Node2D
class_name AttackModuleVisual

const SLOT_TEXTURE_PATHS := {
	"D": "res://assets/attack_modules/module_d.png",
	"C": "res://assets/attack_modules/module_c.png",
	"B": "res://assets/attack_modules/module_b.png",
	"A": "res://assets/attack_modules/module_a.png",
	"S": "res://assets/attack_modules/module_s.png",
}
const WEAPON_ASSET_BASE_PATH := "res://assets/attack_modules/%s.png"
const SLOT_TARGET_SIZE := Vector2(64.0, 64.0)
const WEAPON_TARGET_SIZE := Vector2(56.0, 56.0)
const VISUAL_ALPHA := 0.7

@export var module_id: StringName
@export var shape_style: StringName = &"sword"
@export var fill_color := Color.WHITE
@export var accent_color := Color(0.1, 0.12, 0.14, 1.0)
@export var visual_scale := 1.0

var _slot_sprite: Sprite2D
var _weapon_sprite: Sprite2D
var _slot_texture: Texture2D
var _weapon_texture: Texture2D
var _configured_grade := "D"
var _configured_icon_path := ""
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
	if _weapon_sprite == null:
		_weapon_sprite = get_node_or_null("WeaponSprite") as Sprite2D
	if _weapon_sprite == null:
		_weapon_sprite = Sprite2D.new()
		_weapon_sprite.name = "WeaponSprite"
		add_child(_weapon_sprite)
	_weapon_sprite.centered = true
	_weapon_sprite.z_index = 1
	_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _apply_asset_visuals() -> void:
	_ensure_sprite_nodes()
	_slot_texture = _get_slot_texture_for_grade(_configured_grade)
	_weapon_texture = _load_weapon_texture()
	_slot_sprite.texture = _slot_texture
	_weapon_sprite.texture = _weapon_texture
	_slot_sprite.visible = _slot_texture != null
	_weapon_sprite.visible = _weapon_texture != null
	_fit_sprite_to_target(_slot_sprite, SLOT_TARGET_SIZE, false)
	_fit_sprite_to_target(_weapon_sprite, _get_weapon_target_size(), true)


func _get_slot_texture_for_grade(grade: String) -> Texture2D:
	var normalized_grade := grade.strip_edges().to_upper()
	var path := String(SLOT_TEXTURE_PATHS.get(normalized_grade, SLOT_TEXTURE_PATHS["D"]))
	return _load_texture_if_available(path)


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


func _get_weapon_target_size() -> Vector2:
	match _get_weapon_asset_key():
		"greatsword", "lance":
			return Vector2(64.0, 64.0)
		"dagger", "pistol", "revolver":
			return Vector2(48.0, 48.0)
		_:
			return WEAPON_TARGET_SIZE


func _fit_sprite_to_target(sprite: Sprite2D, target_size: Vector2, apply_visual_scale: bool) -> void:
	if sprite == null or sprite.texture == null:
		return
	var texture_size := sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var fit_scale := minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	var final_scale := fit_scale
	if apply_visual_scale:
		final_scale *= visual_scale
	sprite.scale = Vector2.ONE * final_scale


func _uses_asset_visual() -> bool:
	return _slot_texture != null and _weapon_texture != null


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
