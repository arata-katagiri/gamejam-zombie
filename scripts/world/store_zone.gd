extends Node2D

## StoreZone — A physical trader shop placed along the road every 1 km.
## Player walks near it, presses E to open the store UI.

const SIZE := Vector2(160, 110)
const WALL_T := 8.0

var player_nearby: bool = false
var _store_open: bool = false
var _hud: Node = null

func _ready():
	add_to_group("store_zone")
	_build_visuals()
	_build_walls()
	_build_sign()
	_build_interaction_area()

func _build_visuals():
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.25, 0.2, 0.3, 0.9)
	floor_rect.position = Vector2.ZERO
	floor_rect.size = SIZE
	add_child(floor_rect)

func _build_walls():
	var wall_color := Color(0.45, 0.3, 0.5)
	var door_w: float = 40.0
	var walls: Array = [
		Rect2(0, 0, SIZE.x, WALL_T),                                             # top
		Rect2(0, 0, WALL_T, SIZE.y),                                             # left
		Rect2(SIZE.x - WALL_T, 0, WALL_T, SIZE.y),                               # right
		Rect2(0, SIZE.y - WALL_T, SIZE.x * 0.5 - door_w * 0.5, WALL_T),          # bottom-left of door
		Rect2(SIZE.x * 0.5 + door_w * 0.5, SIZE.y - WALL_T,
			SIZE.x * 0.5 - door_w * 0.5, WALL_T),                                # bottom-right of door
	]
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for w: Rect2 in walls:
		var rect := ColorRect.new()
		rect.color = wall_color
		rect.position = w.position
		rect.size = w.size
		add_child(rect)

		var coll := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = w.size
		coll.shape = shape
		coll.position = w.position + w.size * 0.5
		body.add_child(coll)

func _build_sign():
	var label := Label.new()
	label.text = "STORE"
	label.position = Vector2(SIZE.x * 0.5 - 28, -22)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

	var hint := Label.new()
	hint.name = "ProximityHint"
	hint.text = "Press E to browse"
	hint.position = Vector2(SIZE.x * 0.5 - 52, SIZE.y + 8)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 3)
	hint.visible = false
	add_child(hint)

func _build_interaction_area():
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # Player layer
	var coll := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = SIZE + Vector2(40, 40)
	coll.shape = shape
	coll.position = SIZE * 0.5
	area.add_child(coll)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_nearby = true
		var hint := get_node_or_null("ProximityHint")
		if hint: hint.visible = true

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_nearby = false
		var hint := get_node_or_null("ProximityHint")
		if hint: hint.visible = false
		if _store_open:
			_close_store()

func _unhandled_input(event: InputEvent):
	if not player_nearby: return
	if event.is_action_pressed("interact"):
		if _store_open:
			_close_store()
		else:
			_open_store()
		get_viewport().set_input_as_handled()

func _open_store():
	_hud = get_tree().get_first_node_in_group("hud")
	if _hud and _hud.has_method("open_store"):
		_hud.open_store()
		_store_open = true

func _close_store():
	if _hud and _hud.has_method("close_store"):
		_hud.close_store()
	_store_open = false
