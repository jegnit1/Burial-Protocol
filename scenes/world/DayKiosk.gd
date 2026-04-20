extends Node2D
class_name DayKiosk

const BODY_RECT := Rect2(Vector2(-34.0, -68.0), Vector2(68.0, 88.0))

var world_grid: WorldGrid
var sand_field: SandField
var blocks_root: Node2D
var fall_remainder := 0.0
var landed := false
var _title_label: Label
var _prompt_label: Label


func _ready() -> void:
	z_index = 50
	_build_ui()
	queue_redraw()


func setup(target_world: WorldGrid, target_sand: SandField, target_blocks: Node2D, spawn_position: Vector2) -> void:
	world_grid = target_world
	sand_field = target_sand
	blocks_root = target_blocks
	global_position = spawn_position
	fall_remainder = 0.0
	landed = false
	set_interaction_available(false)


func _physics_process(delta: float) -> void:
	if landed or world_grid == null or sand_field == null:
		return
	fall_remainder += GameConstants.DAY_KIOSK_FALL_SPEED * delta
	var step_pixels := int(floor(fall_remainder))
	fall_remainder -= step_pixels
	for _step in range(step_pixels):
		var next_rect := get_world_rect()
		next_rect.position.y += 1.0
		if _is_supporting_rect(next_rect):
			landed = true
			fall_remainder = 0.0
			set_interaction_available(false)
			return
		global_position.y += 1.0


func is_interactable() -> bool:
	return landed


func set_interaction_available(is_available: bool) -> void:
	if _prompt_label != null:
		_prompt_label.visible = landed and is_available


func get_world_rect() -> Rect2:
	return Rect2(global_position + BODY_RECT.position, BODY_RECT.size)


func _is_supporting_rect(target_rect: Rect2) -> bool:
	if world_grid.rect_collides_static(target_rect) or sand_field.rect_collides(target_rect):
		return true
	if blocks_root == null:
		return false
	for child in blocks_root.get_children():
		var block := child as FallingBlock
		if block != null and block.active and block.get_block_rect().intersects(target_rect):
			return true
	return false


func _build_ui() -> void:
	_title_label = Label.new()
	_title_label.text = "KIOSK"
	_title_label.position = Vector2(-56.0, -108.0)
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color("f0d984"))
	add_child(_title_label)

	_prompt_label = Label.new()
	_prompt_label.text = "E - SHOP"
	_prompt_label.position = Vector2(-58.0, -76.0)
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color("dfe8f2"))
	_prompt_label.visible = false
	add_child(_prompt_label)


func _draw() -> void:
	draw_rect(BODY_RECT, Color("2e3947"))
	draw_rect(BODY_RECT, Color("6e889f"), false, 3.0)
	draw_rect(Rect2(Vector2(-20.0, -52.0), Vector2(40.0, 24.0)), Color("7ed0c8"))
	draw_rect(Rect2(Vector2(-20.0, -52.0), Vector2(40.0, 24.0)), Color("10222c"), false, 2.0)
