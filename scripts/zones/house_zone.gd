extends ZoneBase

## House zone with procedurally generated building layouts and biome-aware visuals.

var zombie_scene: PackedScene = preload("res://scenes/zombies/zombie.tscn")
var collectible_scene: PackedScene = preload("res://scenes/collectibles/collectible.tscn")

var buildings: Array[Dictionary] = []
var props: Array[Dictionary] = []

func _ready():
	zone_name = "House"

func setup(difficulty: int):
	super.setup(difficulty)
	_generate_layout()

	for bld in buildings:
		if house_textures.size() > 0:
			var pos = bld["pos"] as Vector2
			var tex_idx = abs(int(pos.x * 123 + pos.y)) % house_textures.size()
			var tex = house_textures[tex_idx]
			if tex:
				var desired_aspect: float = tex.get_height() / float(tex.get_width())
				bld["size"].y = bld["size"].x * desired_aspect

	for bld in buildings:
		if house_textures.size() > 0 and (GameManager.current_biome == BiomeData.BiomeType.URBAN or zone_rng.randf() < 0.8):
			var tall = CityBuilding.new()
			var size = bld["size"] as Vector2
			tall.position = bld["pos"] as Vector2 + Vector2(size.x * 0.5, size.y * 0.5)
			add_child(tall)
			tall.setup(house_textures, size)
			bld["is_tall"] = true
		else:
			_create_building_collisions(bld)
			_create_building_roof(bld)
	_create_prop_collisions(props)
	
	# Spawn furniture in basic (non-tall) homes
	_load_furniture_textures()
	for bld in buildings:
		if not bld.get("is_tall", false):
			_spawn_building_furniture(bld, zone_rng)
	
	_spawn_zombies(difficulty)
	_spawn_collectibles()
	queue_redraw()

func _generate_layout():
	buildings = ZoneGenerator.generate_buildings(Vector2i(2, 5), zone_rng)
	var prop_pool: Array[Dictionary] = BiomeData.get_road_prop_pool(GameManager.current_biome)
	props = ZoneGenerator.generate_props(prop_pool, Vector2i(3, 7), zone_rng)

	for bld in buildings:
		var pos = bld["pos"] as Vector2
		var sz = bld["size"] as Vector2
		var indoor_pool = [
			{"type": "barrel", "color": Color(0.4, 0.4, 0.6), "size": Vector2(12, 18), "weight": 50},
			{"type": "dumpster", "color": Color(0.3, 0.35, 0.3), "size": Vector2(25, 15), "weight": 40},
			{"type": "rubble", "color": Color(0.3, 0.3, 0.3), "size": Vector2(20, 10), "weight": 30}
		]
		var indoor_count = zone_rng.randi_range(1, 3)
		for j in range(indoor_count):
			var chosen = indoor_pool[zone_rng.randi() % indoor_pool.size()].duplicate()
			chosen["pos"] = Vector2(
				pos.x + 15 + zone_rng.randf() * (sz.x - 30 - chosen["size"].x),
				pos.y + 15 + zone_rng.randf() * (sz.y - 30 - chosen["size"].y)
			)
			props.append(chosen)

func _draw():
	if palette.is_empty():
		palette = GameManager.get_current_palette()
	_draw_base_ground()

	var wall_color: Color = palette.get("building_wall", Color(0.5, 0.35, 0.2)) as Color
	var wall_alt: Color = palette.get("building_wall_alt", Color(0.45, 0.32, 0.2)) as Color
	var win_color: Color = palette.get("window", Color(0.4, 0.6, 0.8, 0.6)) as Color
	var door_color: Color = palette.get("door", Color(0.35, 0.25, 0.15)) as Color

	for prop: Dictionary in props:
		_draw_prop(prop)

	for i: int in buildings.size():
		if buildings[i].get("is_tall", false):
			continue
		var color: Color = wall_color if i % 2 == 0 else wall_alt
		_draw_building(buildings[i], color, win_color, door_color)

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
	var loot_mod: float = GameManager.get_loot_modifier()
	var extra: int = max(0, int(2 * loot_mod) - 1)
	var item_points: Array[Vector2] = ZoneGenerator.generate_item_points(buildings, extra, zone_rng)

	for point: Vector2 in item_points:
		if zone_rng.randf() > loot_mod * 0.8:
			continue
		var item: Collectible = collectible_scene.instantiate() as Collectible
		item.position = point
		item.type = _pick_item_type()
		add_child(item)

func _pick_item_type() -> Collectible.Type:
	var roll: float = zone_rng.randf()
	if roll < 0.16:
		return Collectible.Type.FOOD
	elif roll < 0.27:
		return Collectible.Type.DRINK
	elif roll < 0.38:
		return Collectible.Type.MEDKIT
	elif roll < 0.54:
		return Collectible.Type.FUEL
	elif roll < 0.68:
		return Collectible.Type.SCRAP
	elif roll < 0.72:
		return Collectible.Type.BATTERY
	elif roll < 0.88:
		# AMMO always — even before the player has a gun, so they have ammo waiting.
		return Collectible.Type.AMMO
	elif roll < 0.94:
		if not GameManager.has_melee:
			return Collectible.Type.MELEE
		return Collectible.Type.AMMO
	else:
		if not GameManager.has_gun:
			return Collectible.Type.GUN
		return Collectible.Type.AMMO
