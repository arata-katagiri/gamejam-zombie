extends ZoneBase

## Road zone with procedural props that change based on the current biome.

var props: Array[Dictionary] = []

func _ready():
	zone_name = "Road"

func setup(difficulty: int):
	super.setup(difficulty)
	_generate_props()
	_create_prop_collisions(props)
	queue_redraw()

func _generate_props():
	var prop_pool: Array[Dictionary] = BiomeData.get_road_prop_pool(GameManager.current_biome)
	# More props at higher difficulty (road feels more cluttered/dangerous)
	var min_props: int = 4 + GameManager.difficulty_level
	var max_props: int = 8 + GameManager.difficulty_level * 2
	props = ZoneGenerator.generate_props(prop_pool, Vector2i(min_props, max_props), zone_rng)

func _draw():
	if palette.is_empty():
		palette = GameManager.get_current_palette()
	_draw_base_ground()

	# Road shoulder details
	var road_color: Color = palette.get("road", Color(0.3, 0.3, 0.3)) as Color
	draw_rect(Rect2(0, 275, 1280, 5), road_color.lightened(0.1))
	draw_rect(Rect2(0, 440, 1280, 5), road_color.lightened(0.1))

	# Draw all procedural props
	for prop: Dictionary in props:
		_draw_prop(prop)

	# Occasional road cracks for visual interest
	var crack_color: Color = road_color.darkened(0.15)
	for _i: int in zone_rng.randi_range(2, 6):
		var cx: float = zone_rng.randf_range(50, 1230)
		var cy: float = zone_rng.randf_range(290, 430)
		var cw: float = zone_rng.randf_range(15, 40)
		draw_rect(Rect2(cx, cy, cw, 2), crack_color)
		draw_rect(Rect2(cx + cw * 0.3, cy - 3, 2, 6), crack_color)
