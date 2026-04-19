extends ZoneBase

## Bridge zone — narrow passage, ambush potential, tension zone.

var zombie_scene: PackedScene = preload("res://scenes/zombies/zombie.tscn")
var collectible_scene: PackedScene = preload("res://scenes/collectibles/collectible.tscn")

var bridge_style: int = 0  # 0 = wooden, 1 = concrete, 2 = suspension
var wreck_positions: Array[Vector2] = []

func _ready():
	zone_name = "Bridge"

func setup(difficulty: int):
	super.setup(difficulty)
	bridge_style = zone_rng.randi_range(0, 2)
	_generate_wrecks()
	for wreck_pos in wreck_positions:
		_add_static_box(Rect2(wreck_pos.x, wreck_pos.y, 45, 22))
	# Boundaries for bridge ends
	_add_static_box(Rect2(0, 0, 1280, 260))
	_add_static_box(Rect2(0, 460, 1280, 260))
	_spawn_zombies(difficulty)
	_spawn_collectibles()
	queue_redraw()

func _generate_wrecks():
	var wreck_count: int = zone_rng.randi_range(0, 3)
	for _i: int in wreck_count:
		wreck_positions.append(Vector2(
			zone_rng.randf_range(100, 1100),
			zone_rng.randf_range(300, 420),
		))

func _draw():
	if palette.is_empty():
		palette = GameManager.get_current_palette()

	# Water/chasm below
	var water_color: Color
	match GameManager.current_biome:
		BiomeData.BiomeType.DESERT:
			water_color = Color(0.7, 0.55, 0.3)  # Sandy canyon
		BiomeData.BiomeType.WASTELAND:
			water_color = Color(0.3, 0.35, 0.2)  # Toxic
		_:
			water_color = Color(0.15, 0.3, 0.55)  # Normal water

	# Fill with water/chasm
	draw_rect(Rect2(0, 0, 1280, 720), water_color)

	# Water wave lines
	for wi: int in range(0, 720, 40):
		var wave_y: float = float(wi) + zone_rng.randf_range(-5, 5)
		draw_rect(Rect2(0, wave_y, 1280, 2), water_color.lightened(0.15))

	# Bridge structure
	var road_color: Color = palette.get("road", Color(0.3, 0.3, 0.3)) as Color
	var line_color: Color = palette.get("road_line", Color(0.9, 0.85, 0.2)) as Color

	match bridge_style:
		0:  # Wooden bridge
			var plank_color := Color(0.5, 0.35, 0.18)
			draw_rect(Rect2(0, 260, 1280, 200), plank_color)
			# Plank lines
			for pi: int in range(0, 1280, 30):
				draw_rect(Rect2(pi, 260, 2, 200), plank_color.darkened(0.2))
			# Railing
			draw_rect(Rect2(0, 255, 1280, 8), plank_color.darkened(0.1))
			draw_rect(Rect2(0, 457, 1280, 8), plank_color.darkened(0.1))
			# Posts
			for pp: int in range(0, 1280, 100):
				draw_rect(Rect2(pp, 240, 6, 20), plank_color.darkened(0.2))
				draw_rect(Rect2(pp, 460, 6, 20), plank_color.darkened(0.2))

		1:  # Concrete bridge
			draw_rect(Rect2(0, 270, 1280, 180), Color(0.55, 0.55, 0.55))
			draw_rect(Rect2(0, 265, 1280, 8), Color(0.45, 0.45, 0.45))
			draw_rect(Rect2(0, 447, 1280, 8), Color(0.45, 0.45, 0.45))
			# Road surface
			draw_rect(Rect2(0, 280, 1280, 160), road_color)
			# Center line
			for di: int in range(0, 1280, 80):
				draw_rect(Rect2(di, 355, 40, 10), line_color)
			# Concrete pillars visible below
			for cp: int in range(200, 1280, 400):
				draw_rect(Rect2(cp, 455, 30, 265), Color(0.5, 0.5, 0.5))

		2:  # Suspension bridge
			draw_rect(Rect2(0, 280, 1280, 160), road_color)
			# Center line
			for di: int in range(0, 1280, 80):
				draw_rect(Rect2(di, 355, 40, 10), line_color)
			# Side barriers
			draw_rect(Rect2(0, 275, 1280, 8), Color(0.6, 0.2, 0.15))
			draw_rect(Rect2(0, 437, 1280, 8), Color(0.6, 0.2, 0.15))
			# Towers
			draw_rect(Rect2(100, 100, 15, 340), Color(0.6, 0.2, 0.15))
			draw_rect(Rect2(1165, 100, 15, 340), Color(0.6, 0.2, 0.15))
			# Cables
			for cable_x: int in range(100, 1180, 60):
				var cable_sag: float = sin(float(cable_x - 100) / 1080.0 * PI) * 80.0
				draw_rect(Rect2(cable_x, 120 + cable_sag, 3, 160 - cable_sag), Color(0.4, 0.4, 0.4))

	# Wrecked vehicles on bridge
	for wreck_pos: Vector2 in wreck_positions:
		draw_rect(Rect2(wreck_pos.x, wreck_pos.y, 45, 22), Color(0.4, 0.35, 0.3))
		draw_rect(Rect2(wreck_pos.x + 10, wreck_pos.y - 8, 25, 12), Color(0.35, 0.3, 0.28))

func _spawn_zombies(_difficulty: int):
	# Ambush — zombies concentrated on the bridge
	var count: int = GameManager.get_zombie_count_for_zone() + 1
	var health_mod: float = GameManager.get_zombie_health_modifier()

	for _i: int in count:
		var zombie: CharacterBody2D = zombie_scene.instantiate()
		zombie.position = Vector2(
			zone_rng.randf_range(80, 1200),
			zone_rng.randf_range(290, 430),
		)
		zombie.set_difficulty(health_mod)
		add_child(zombie)

func _spawn_collectibles():
	# Sparse loot — mostly from wrecked cars
	for wreck_pos: Vector2 in wreck_positions:
		if zone_rng.randf() < 0.85:
			var item: Collectible = collectible_scene.instantiate() as Collectible
			item.position = wreck_pos + Vector2(zone_rng.randf_range(-10, 50), zone_rng.randf_range(-5, 25))
			# Wrecks favour scrap and fuel — they're literally crashed cars.
			var roll = zone_rng.randf()
			if roll < 0.45:
				item.type = Collectible.Type.SCRAP
			elif roll < 0.80:
				item.type = Collectible.Type.FUEL
			else:
				item.type = Collectible.Type.FOOD
			add_child(item)
