extends ZoneBase

## Supermarket zone — high loot density, high zombie count.

var zombie_scene: PackedScene = preload("res://scenes/zombies/zombie.tscn")
var collectible_scene: PackedScene = preload("res://scenes/collectibles/collectible.tscn")

var shelf_positions: Array[Rect2] = []
var props: Array[Dictionary] = []

func _ready():
	zone_name = "Supermarket"

func setup(difficulty: int):
	super.setup(difficulty)
	_generate_layout()
	_create_prop_collisions(props)
	var rect_top = Rect2(100, 20, 1000, 230)
	var rect_bot = Rect2(150, 480, 900, 200)
	_add_static_walls(rect_top, Rect2(540, 200, 80, 50))
	_add_static_walls(rect_bot)
	for shelf in shelf_positions:
		_add_static_box(shelf)
	
	if roof_textures.size() > 0:
		_spawn_fading_roof(rect_top, roof_textures[0 % roof_textures.size()], true)
		_spawn_fading_roof(rect_bot, roof_textures[1 % roof_textures.size()], true)
	_spawn_zombies(difficulty)
	_spawn_collectibles()
	queue_redraw()

func _generate_layout():
	# Big building with interior shelves
	shelf_positions.clear()
	for x: int in range(150, 950, 180):
		for y: int in range(80, 200, 60):
			shelf_positions.append(Rect2(x, y, 120, 30))

	var prop_pool: Array[Dictionary] = BiomeData.get_road_prop_pool(GameManager.current_biome)
	props = ZoneGenerator.generate_props(prop_pool, Vector2i(2, 6), zone_rng)

func _draw():
	if palette.is_empty():
		palette = GameManager.get_current_palette()
	_draw_base_ground()

	var wall_color: Color = palette.get("building_wall", Color(0.45, 0.45, 0.5)) as Color
	var win_color: Color = palette.get("window", Color(0.5, 0.65, 0.85, 0.7)) as Color
	var floor_color: Color = palette.get("ground_alt", Color(0.2, 0.2, 0.2)).darkened(0.3)

	for prop: Dictionary in props:
		_draw_prop(prop)

	# Main building — large footprint top area
	var rect_top = Rect2(100, 20, 1000, 230)
	_draw_floor_area(rect_top)

	var t = 8.0
	draw_rect(Rect2(rect_top.position.x, rect_top.position.y, rect_top.size.x, t), wall_color)
	draw_rect(Rect2(rect_top.position.x, rect_top.position.y, t, rect_top.size.y), wall_color)
	draw_rect(Rect2(rect_top.position.x + rect_top.size.x - t, rect_top.position.y, t, rect_top.size.y), wall_color)
	draw_rect(Rect2(rect_top.position.x, rect_top.position.y + rect_top.size.y - t, rect_top.size.x, t), wall_color)

	# Entrance gap
	_draw_floor_area(Rect2(540, 200, 80, 50))
	draw_rect(Rect2(540, 230, 80, 4), Color(0.2, 0.2, 0.2, 0.6)) # Glass Door Threshold

	# Bottom building
	var rect_bot = Rect2(150, 480, 900, 200)
	_draw_floor_area(rect_bot)
	
	draw_rect(Rect2(rect_bot.position.x, rect_bot.position.y, rect_bot.size.x, t), wall_color)
	draw_rect(Rect2(rect_bot.position.x, rect_bot.position.y, t, rect_bot.size.y), wall_color)
	draw_rect(Rect2(rect_bot.position.x + rect_bot.size.x - t, rect_bot.position.y, t, rect_bot.size.y), wall_color)
	draw_rect(Rect2(rect_bot.position.x, rect_bot.position.y + rect_bot.size.y - t, rect_bot.size.x, t), wall_color)

	# Shelves (inside buildings)
	var shelf_color: Color = Color(0.5, 0.45, 0.35)
	for shelf: Rect2 in shelf_positions:
		draw_rect(shelf, shelf_color)
		draw_rect(Rect2(shelf.position.x + 2, shelf.position.y + 2, shelf.size.x - 4, shelf.size.y - 4), shelf_color.darkened(0.2))

	# Shopping carts outside
	for _i: int in zone_rng.randi_range(1, 3):
		var cart_x: float = zone_rng.randf_range(110, 500)
		var cart_y: float = zone_rng.randf_range(250, 270)
		draw_rect(Rect2(cart_x, cart_y, 18, 14), Color(0.6, 0.6, 0.6))
		draw_rect(Rect2(cart_x + 2, cart_y - 8, 14, 8), Color(0.55, 0.55, 0.55))

func _spawn_zombies(_difficulty: int):
	# High zombie density in supermarkets
	var count: int = GameManager.get_zombie_count_for_zone() + 2
	var health_mod: float = GameManager.get_zombie_health_modifier()
	var spawn_points: Array[Vector2] = ZoneGenerator.generate_spawn_points(count, zone_rng)

	for point: Vector2 in spawn_points:
		var zombie: CharacterBody2D = zombie_scene.instantiate()
		zombie.position = point
		zombie.set_difficulty(health_mod)
		add_child(zombie)

func _spawn_collectibles():
	# Lots of food and drink near shelves
	for shelf: Rect2 in shelf_positions:
		if zone_rng.randf() < 0.7:
			var item: Collectible = collectible_scene.instantiate() as Collectible
			item.position = Vector2(
				shelf.position.x + zone_rng.randf_range(-15, shelf.size.x + 15),
				shelf.position.y + zone_rng.randf_range(0, shelf.size.y),
			)
			var roll: float = zone_rng.randf()
			if roll < 0.45:
				item.type = Collectible.Type.FOOD
			elif roll < 0.85:
				item.type = Collectible.Type.DRINK
			else:
				item.type = Collectible.Type.MEDKIT
			add_child(item)
