extends ZoneBase

## Gas station zone — fuel and car upgrades, light zombie presence.

var zombie_scene: PackedScene = preload("res://scenes/zombies/zombie.tscn")
var collectible_scene: PackedScene = preload("res://scenes/collectibles/collectible.tscn")

var props: Array[Dictionary] = []
var pump_positions: Array[Vector2] = []
var station_x: float = 0.0

func _ready():
	zone_name = "Gas Station"

func setup(difficulty: int):
	super.setup(difficulty)
	_generate_layout()
	_create_prop_collisions(props)
	
	var rect_station = Rect2(station_x, 500, 280, 160)
	_add_static_walls(rect_station, Rect2(station_x + 200, 580, 40, 80))
	
	if roof_textures.size() > 0:
		var door_info_station = {"has_door": true, "custom_local_center": Vector2(220, 120)}
		_spawn_fading_roof(rect_station, roof_textures[4 % roof_textures.size()], true, door_info_station)
	
	for pump_pos in pump_positions:
		_add_static_box(Rect2(pump_pos.x - 12, pump_pos.y - 25, 24, 50))
	_spawn_zombies(difficulty)
	_spawn_collectibles()
	queue_redraw()

func _generate_layout():
	# Generate 2-4 fuel pumps
	var pump_count: int = zone_rng.randi_range(2, 4)
	for i: int in pump_count:
		var px: float = 200.0 + i * 250.0 + zone_rng.randf_range(-30, 30)
		var py: float = zone_rng.randf_range(100, 220)
		pump_positions.append(Vector2(px, py))

	var prop_pool: Array[Dictionary] = BiomeData.get_road_prop_pool(GameManager.current_biome)
	props = ZoneGenerator.generate_props(prop_pool, Vector2i(2, 5), zone_rng)
	station_x = zone_rng.randf_range(100, 300)

func _draw():
	if palette.is_empty():
		palette = GameManager.get_current_palette()
	_draw_base_ground()

	var wall_color: Color = palette.get("building_wall", Color(0.5, 0.35, 0.2)) as Color
	var floor_color: Color = palette.get("ground_alt", Color(0.2, 0.2, 0.2)).darkened(0.3)
	
	# Props
	for prop: Dictionary in props:
		_draw_prop(prop)

	# Main station building (bottom area)
	var rect_station = Rect2(station_x, 500, 280, 160)
	
	_draw_floor_area(rect_station)

	var t = 8.0
	draw_rect(Rect2(rect_station.position.x, rect_station.position.y, rect_station.size.x, t), wall_color)
	draw_rect(Rect2(rect_station.position.x, rect_station.position.y, t, rect_station.size.y), wall_color)
	draw_rect(Rect2(rect_station.position.x + rect_station.size.x - t, rect_station.position.y, t, rect_station.size.y), wall_color)
	draw_rect(Rect2(rect_station.position.x, rect_station.position.y + rect_station.size.y - t, rect_station.size.x, t), wall_color)

	# Station door threshold gap
	_draw_floor_area(Rect2(station_x + 200, 580, 40, 80))
	draw_rect(Rect2(station_x + 200, 656, 40, 4), Color(0.2, 0.2, 0.2, 0.6))

	# Canopy over pumps
	var canopy_color: Color = wall_color.lightened(0.2)
	draw_rect(Rect2(150, 80, 800, 8), canopy_color)
	# Support poles
	draw_rect(Rect2(160, 80, 6, 180), canopy_color.darkened(0.2))
	draw_rect(Rect2(940, 80, 6, 180), canopy_color.darkened(0.2))

	# Fuel pumps
	for pump_pos: Vector2 in pump_positions:
		# Pump body
		draw_rect(Rect2(pump_pos.x - 12, pump_pos.y - 25, 24, 50), Color(0.8, 0.2, 0.15))
		# Pump screen
		draw_rect(Rect2(pump_pos.x - 8, pump_pos.y - 18, 16, 10), Color(0.15, 0.15, 0.15))
		# Pump nozzle
		draw_rect(Rect2(pump_pos.x + 12, pump_pos.y - 5, 15, 4), Color(0.2, 0.2, 0.2))

	# Signage
	draw_rect(Rect2(50, 500, 40, 60), Color(0.6, 0.6, 0.6))
	draw_rect(Rect2(40, 490, 60, 15), Color(0.8, 0.2, 0.15))

func _spawn_zombies(_difficulty: int):
	# Light zombie presence at gas stations
	var count: int = max(1, GameManager.get_zombie_count_for_zone() - 1)
	var health_mod: float = GameManager.get_zombie_health_modifier()
	var spawn_points: Array[Vector2] = ZoneGenerator.generate_spawn_points(count, zone_rng)

	for point: Vector2 in spawn_points:
		var zombie: CharacterBody2D = zombie_scene.instantiate()
		zombie.position = point
		zombie.set_difficulty(health_mod)
		add_child(zombie)

func _spawn_collectibles():
	# Gas stations have guaranteed fuel items
	for pump_pos: Vector2 in pump_positions:
		var item: Collectible = collectible_scene.instantiate() as Collectible
		item.position = pump_pos + Vector2(zone_rng.randf_range(-20, 20), 30)
		item.type = Collectible.Type.FUEL
		add_child(item)

	# Plus some random items
	var extra_count: int = zone_rng.randi_range(1, 3)
	for _i: int in extra_count:
		var item: Collectible = collectible_scene.instantiate() as Collectible
		item.position = Vector2(
			zone_rng.randf_range(100, 1100),
			zone_rng.randf_range(500, 650),
		)
		item.type = Collectible.Type.FOOD if zone_rng.randf() < 0.6 else Collectible.Type.DRINK
		add_child(item)
