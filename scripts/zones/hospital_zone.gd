extends ZoneBase

## Hospital zone — health items, moderate zombies, distinctive cross marking.

var zombie_scene: PackedScene = preload("res://scenes/zombies/zombie.tscn")
var collectible_scene: PackedScene = preload("res://scenes/collectibles/collectible.tscn")

var bed_positions: Array[Vector2] = []
var props: Array[Dictionary] = []

func _ready():
	zone_name = "Hospital"

func setup(difficulty: int):
	super.setup(difficulty)
	_generate_layout()
	_create_prop_collisions(props)
	
	var rect_top = Rect2(80, 15, 1100, 240)
	var rect_bot = Rect2(120, 470, 1000, 220)
	_add_static_walls(rect_top, Rect2(520, 200, 100, 55))
	_add_static_walls(rect_bot)
	
	if roof_textures.size() > 0:
		_spawn_fading_roof(rect_top, roof_textures[2 % roof_textures.size()], true)
		_spawn_fading_roof(rect_bot, roof_textures[3 % roof_textures.size()], true)
	
	for bed_pos in bed_positions:
		_add_static_box(Rect2(bed_pos.x, bed_pos.y, 50, 25))
	_spawn_zombies(difficulty)
	_spawn_collectibles()
	queue_redraw()

func _generate_layout():
	bed_positions.clear()
	for x: int in range(150, 1050, 200):
		for y: int in range(50, 180, 70):
			bed_positions.append(Vector2(x, y))

	var prop_pool: Array[Dictionary] = BiomeData.get_road_prop_pool(GameManager.current_biome)
	props = ZoneGenerator.generate_props(prop_pool, Vector2i(2, 4), zone_rng)

func _draw():
	if palette.is_empty():
		palette = GameManager.get_current_palette()
	_draw_base_ground()

	var wall_color: Color = palette.get("building_wall", Color(0.45, 0.45, 0.5)) as Color
	var floor_color: Color = palette.get("ground_alt", Color(0.2, 0.2, 0.2)).darkened(0.3)

	for prop: Dictionary in props:
		_draw_prop(prop)

	# Hospital building — top section
	var rect_top = Rect2(80, 15, 1100, 240)
	draw_rect(rect_top, floor_color)
	for fi_x in range(0, int(rect_top.size.x), 20): draw_rect(Rect2(rect_top.position.x + fi_x, rect_top.position.y, 2, rect_top.size.y), floor_color.darkened(0.2))
	for fi_y in range(0, int(rect_top.size.y), 20): draw_rect(Rect2(rect_top.position.x, rect_top.position.y + fi_y, rect_top.size.x, 2), floor_color.darkened(0.2))

	var t = 8.0
	draw_rect(Rect2(rect_top.position.x, rect_top.position.y, rect_top.size.x, t), wall_color)
	draw_rect(Rect2(rect_top.position.x, rect_top.position.y, t, rect_top.size.y), wall_color)
	draw_rect(Rect2(rect_top.position.x + rect_top.size.x - t, rect_top.position.y, t, rect_top.size.y), wall_color)
	draw_rect(Rect2(rect_top.position.x, rect_top.position.y + rect_top.size.y - t, rect_top.size.x, t), wall_color)

	# Entrance gap
	draw_rect(Rect2(520, 200, 100, 55), floor_color)
	draw_rect(Rect2(520, 235, 100, 4), Color(0.2, 0.2, 0.2, 0.6))
	
	# Hospital building — bottom section
	var rect_bot = Rect2(120, 470, 1000, 220)
	draw_rect(rect_bot, floor_color)
	for fi_x in range(0, int(rect_bot.size.x), 20): draw_rect(Rect2(rect_bot.position.x + fi_x, rect_bot.position.y, 2, rect_bot.size.y), floor_color.darkened(0.2))
	for fi_y in range(0, int(rect_bot.size.y), 20): draw_rect(Rect2(rect_bot.position.x, rect_bot.position.y + fi_y, rect_bot.size.x, 2), floor_color.darkened(0.2))
	
	draw_rect(Rect2(rect_bot.position.x, rect_bot.position.y, rect_bot.size.x, t), wall_color)
	draw_rect(Rect2(rect_bot.position.x, rect_bot.position.y, t, rect_bot.size.y), wall_color)
	draw_rect(Rect2(rect_bot.position.x + rect_bot.size.x - t, rect_bot.position.y, t, rect_bot.size.y), wall_color)
	draw_rect(Rect2(rect_bot.position.x, rect_bot.position.y + rect_bot.size.y - t, rect_bot.size.x, t), wall_color)

	# Beds
	for bed_pos: Vector2 in bed_positions:
		# Bed frame
		draw_rect(Rect2(bed_pos.x, bed_pos.y, 50, 25), Color(0.7, 0.7, 0.7))
		# Mattress
		draw_rect(Rect2(bed_pos.x + 2, bed_pos.y + 2, 46, 21), Color(0.85, 0.85, 0.9))
		# Pillow
		draw_rect(Rect2(bed_pos.x + 3, bed_pos.y + 4, 12, 17), Color(0.9, 0.9, 0.95))

	# Ambulance outside (on road)
	var amb_x: float = zone_rng.randf_range(200, 900)
	draw_rect(Rect2(amb_x, 310, 80, 40), Color(0.9, 0.9, 0.9))
	draw_rect(Rect2(amb_x + 55, 315, 20, 30), Color(0.4, 0.6, 0.85, 0.6))
	# Ambulance cross
	draw_rect(Rect2(amb_x + 18, 315, 6, 20), Color(0.85, 0.15, 0.15))
	draw_rect(Rect2(amb_x + 11, 322, 20, 6), Color(0.85, 0.15, 0.15))

func _spawn_zombies(_difficulty: int):
	var count: int = GameManager.get_zombie_count_for_zone()
	var health_mod: float = GameManager.get_zombie_health_modifier()
	var spawn_points: Array[Vector2] = ZoneGenerator.generate_spawn_points(count, zone_rng)

	for point: Vector2 in spawn_points:
		var zombie: CharacterBody2D = zombie_scene.instantiate()
		zombie.position = point
		zombie.set_difficulty(health_mod)
		add_child(zombie)

func _spawn_collectibles():
	# Hospitals primarily drop medkits
	for bed_pos: Vector2 in bed_positions:
		if zone_rng.randf() < 0.5:
			var item: Collectible = collectible_scene.instantiate() as Collectible
			item.position = bed_pos + Vector2(zone_rng.randf_range(-10, 60), zone_rng.randf_range(-10, 35))
			item.type = Collectible.Type.MEDKIT
			add_child(item)

	# A few food/drink items
	for _i: int in zone_rng.randi_range(1, 3):
		var item: Collectible = collectible_scene.instantiate() as Collectible
		item.position = Vector2(
			zone_rng.randf_range(150, 1100),
			zone_rng.randf_range(500, 650),
		)
		item.type = Collectible.Type.FOOD if zone_rng.randf() < 0.5 else Collectible.Type.DRINK
		add_child(item)
