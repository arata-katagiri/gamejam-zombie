extends ZoneBase

## Abandoned camp zone — random loot cache with possible traps.

var zombie_scene: PackedScene = preload("res://scenes/zombies/zombie.tscn")
var collectible_scene: PackedScene = preload("res://scenes/collectibles/collectible.tscn")

var tent_positions: Array[Dictionary] = []
var campfire_pos: Vector2 = Vector2.ZERO
var has_trap: bool = false
var props: Array[Dictionary] = []

func _ready():
	zone_name = "Camp"

func setup(difficulty: int):
	super.setup(difficulty)
	_generate_layout()
	_create_prop_collisions(props)
	for tent in tent_positions:
		_add_static_box(Rect2(tent["pos"].x, tent["pos"].y, tent["size"].x, tent["size"].y))
	_add_static_box(Rect2(campfire_pos.x - 15, campfire_pos.y - 15, 30, 30))
	_spawn_zombies(difficulty)
	_spawn_collectibles()
	queue_redraw()

func _generate_layout():
	# 2-4 tents
	var tent_count: int = zone_rng.randi_range(2, 4)
	for i: int in tent_count:
		var tx: float
		var ty: float
		if i < 2:
			tx = zone_rng.randf_range(100, 600)
			ty = zone_rng.randf_range(40, 200)
		else:
			tx = zone_rng.randf_range(200, 800)
			ty = zone_rng.randf_range(480, 620)

		var tent_color: Color
		match zone_rng.randi_range(0, 3):
			0: tent_color = Color(0.3, 0.5, 0.25)
			1: tent_color = Color(0.6, 0.4, 0.2)
			2: tent_color = Color(0.4, 0.4, 0.55)
			_: tent_color = Color(0.55, 0.35, 0.25)

		tent_positions.append({
			"pos": Vector2(tx, ty),
			"size": Vector2(zone_rng.randf_range(60, 90), zone_rng.randf_range(40, 60)),
			"color": tent_color,
		})

	# Campfire in center area (top or bottom)
	if zone_rng.randf() < 0.5:
		campfire_pos = Vector2(zone_rng.randf_range(300, 700), zone_rng.randf_range(100, 200))
	else:
		campfire_pos = Vector2(zone_rng.randf_range(300, 700), zone_rng.randf_range(520, 620))

	# 30% chance of trap (extra zombies spawn when entering)
	has_trap = zone_rng.randf() < 0.3

	var prop_pool: Array[Dictionary] = BiomeData.get_road_prop_pool(GameManager.current_biome)
	props = ZoneGenerator.generate_props(prop_pool, Vector2i(4, 10), zone_rng)

func _draw():
	if palette.is_empty():
		palette = GameManager.get_current_palette()
	_draw_base_ground()

	# Draw props
	for prop: Dictionary in props:
		_draw_prop(prop)

	# Draw tents
	for tent: Dictionary in tent_positions:
		var pos: Vector2 = tent["pos"] as Vector2
		var sz: Vector2 = tent["size"] as Vector2
		var col: Color = tent["color"] as Color

		# Tent body (triangle-ish)
		var tent_points: PackedVector2Array = PackedVector2Array([
			Vector2(pos.x, pos.y + sz.y),
			Vector2(pos.x + sz.x * 0.5, pos.y),
			Vector2(pos.x + sz.x, pos.y + sz.y),
		])
		draw_colored_polygon(tent_points, col)
		# Tent opening
		draw_rect(Rect2(pos.x + sz.x * 0.35, pos.y + sz.y * 0.4, sz.x * 0.3, sz.y * 0.6), col.darkened(0.3))

	# Campfire
	# Stone ring
	for angle_step: int in range(0, 360, 45):
		var rad: float = deg_to_rad(float(angle_step))
		var stone_pos: Vector2 = campfire_pos + Vector2(cos(rad) * 18, sin(rad) * 18)
		draw_circle(stone_pos, 4, Color(0.4, 0.4, 0.4))

	# Fire (orange/red circles)
	draw_circle(campfire_pos, 8, Color(0.85, 0.35, 0.1))
	draw_circle(campfire_pos + Vector2(0, -3), 5, Color(0.95, 0.65, 0.15))
	draw_circle(campfire_pos + Vector2(0, -6), 3, Color(1.0, 0.9, 0.3))

	# Logs around campfire
	draw_rect(Rect2(campfire_pos.x - 30, campfire_pos.y + 20, 25, 6), Color(0.4, 0.28, 0.15))
	draw_rect(Rect2(campfire_pos.x + 10, campfire_pos.y + 18, 22, 6), Color(0.38, 0.26, 0.13))

	# Warning sign if trap
	if has_trap:
		draw_rect(Rect2(campfire_pos.x + 50, campfire_pos.y - 10, 4, 25), Color(0.5, 0.5, 0.5))
		var sign_points: PackedVector2Array = PackedVector2Array([
			Vector2(campfire_pos.x + 42, campfire_pos.y - 10),
			Vector2(campfire_pos.x + 52, campfire_pos.y - 25),
			Vector2(campfire_pos.x + 62, campfire_pos.y - 10),
		])
		draw_colored_polygon(sign_points, Color(0.9, 0.7, 0.1))

func _spawn_zombies(_difficulty: int):
	var base_count: int = max(1, GameManager.get_zombie_count_for_zone() - 1)
	# Trap camps have double zombies
	var count: int = base_count * 2 if has_trap else base_count
	var health_mod: float = GameManager.get_zombie_health_modifier()

	var spawn_points: Array[Vector2] = ZoneGenerator.generate_spawn_points(count, zone_rng)
	for point: Vector2 in spawn_points:
		var zombie: CharacterBody2D = zombie_scene.instantiate()
		zombie.position = point
		zombie.set_difficulty(health_mod)
		add_child(zombie)

func _spawn_collectibles():
	# Loot near tents
	for tent: Dictionary in tent_positions:
		if zone_rng.randf() < 0.65:
			var item: Collectible = collectible_scene.instantiate() as Collectible
			var pos: Vector2 = tent["pos"] as Vector2
			var sz: Vector2 = tent["size"] as Vector2
			item.position = pos + Vector2(zone_rng.randf_range(-10, sz.x + 10), sz.y + zone_rng.randf_range(5, 20))
			var roll: float = zone_rng.randf()
			if roll < 0.35:
				item.type = Collectible.Type.FOOD
			elif roll < 0.65:
				item.type = Collectible.Type.DRINK
			elif roll < 0.85:
				item.type = Collectible.Type.MEDKIT
			else:
				item.type = Collectible.Type.FUEL
			add_child(item)

	# Bonus loot near campfire
	if zone_rng.randf() < 0.5:
		var item: Collectible = collectible_scene.instantiate() as Collectible
		item.position = campfire_pos + Vector2(zone_rng.randf_range(-25, 25), zone_rng.randf_range(15, 30))
		item.type = Collectible.Type.FOOD
		add_child(item)
