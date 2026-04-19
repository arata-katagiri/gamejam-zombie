extends Node2D

## WorldManager — Handles zone spawning, biome transitions, and road events.

const ZONE_SPACING := 1280.0

# Preloaded zone scenes
var road_zone_scene: PackedScene = preload("res://scenes/zones/road_zone.tscn")
var house_zone_scene: PackedScene = preload("res://scenes/zones/house_zone.tscn")
var gas_station_scene: PackedScene = preload("res://scenes/zones/gas_station_zone.tscn")
var supermarket_scene: PackedScene = preload("res://scenes/zones/supermarket_zone.tscn")
var hospital_scene: PackedScene = preload("res://scenes/zones/hospital_zone.tscn")
var bridge_scene: PackedScene = preload("res://scenes/zones/bridge_zone.tscn")
var camp_scene: PackedScene = preload("res://scenes/zones/camp_zone.tscn")

# Zone scene lookup by type name
var zone_scene_map: Dictionary = {}

var active_zones: Array[Node2D] = []
var next_zone_position: float = 0.0
var zones_spawned: int = 0
var last_zone_type: String = ""

# Road event tracking
var pending_road_event: String = ""

var _day_night_mod: CanvasModulate

func _ready():
	# Build lookup map
	zone_scene_map = {
		"road": road_zone_scene,
		"house": house_zone_scene,
		"gas_station": gas_station_scene,
		"supermarket": supermarket_scene,
		"hospital": hospital_scene,
		"bridge": bridge_scene,
		"camp": camp_scene,
	}

	_spawn_initial_zones()
	_create_world_borders()
	_spawn_starter_shed()
	
	_day_night_mod = CanvasModulate.new()
	add_child(_day_night_mod)
	
	# AAA Post-Processing
	var we = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.3
	env.glow_strength = 1.1
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 1.1
	we.environment = env
	add_child(we)

	# Activate sound system for gameplay
	if has_node("/root/SoundManager"):
		SoundManager.enter_game()

	# Start tutorial after everything is loaded
	if has_node("/root/TutorialManager"):
		# Defer to next frame so all nodes are fully initialized
		call_deferred("_start_tutorial_deferred")

func _process(delta: float):
	# Calculate darkness based on time of day (8 -> daylight, 0/24 -> midnight)
	var t = GameManager.time_of_day
	var dark_factor = 0.0
	if t < 6.0 or t > 19.0:
		dark_factor = 1.0 # Pitch black
	elif t > 17.0 and t <= 19.0:
		dark_factor = lerp(0.0, 1.0, (t - 17.0) / 2.0)
	elif t >= 6.0 and t < 8.0:
		dark_factor = lerp(1.0, 0.0, (t - 6.0) / 2.0)
	
	# Interpolate lighting
	var color_light = Color(0.4, 0.4, 0.45) # Foggy daytime
	var color_dark = Color(0.01, 0.01, 0.03) # Deep pitch black
	_day_night_mod.color = color_light.lerp(color_dark, dark_factor)
	
	var target_x = 0.0
	
	var car = get_parent().get_node_or_null("Car")
	if car:
		target_x = max(target_x, car.global_position.x)
		
	var player = get_tree().get_first_node_in_group("player")
	if player:
		target_x = max(target_x, player.global_position.x)
		
	if target_x > next_zone_position - (ZONE_SPACING * 3):
		_trigger_next_zone()

func _spawn_initial_zones():
	# Start with a road zone, then location, then road, then location
	_spawn_zone("road")
	_spawn_next_location()
	_spawn_zone("road")
	_spawn_next_location()
	_spawn_zone("road")

func _trigger_next_zone():
	_cleanup_old_zones()

	# Check for biome transition
	if GameManager.should_change_biome():
		GameManager.advance_biome()

	# Roll a road event
	_roll_road_event()

	# Keep maintaining the buffer of zones ahead
	if last_zone_type == "road":
		_spawn_next_location()
	else:
		_spawn_zone("road")

## Spawns the next non-road location using weighted selection.
func _spawn_next_location():
	var weights: Dictionary = BiomeData.get_zone_weights(GameManager.current_biome)

	# Avoid repeating the same location type twice in a row
	if last_zone_type in weights and weights.size() > 1:
		var adjusted: Dictionary = weights.duplicate()
		# Halve the weight of the last type to reduce repeats
		adjusted[last_zone_type] = max(1, int(adjusted[last_zone_type] as float * 0.3))
		weights = adjusted

	var zone_type: String = ZoneGenerator.pick_weighted_zone(weights, GameManager.world_rng)
	_spawn_zone(zone_type)
	SignalsBus.zone_type_spawned.emit(zone_type)

## Spawns a zone of the given type.
func _spawn_zone(zone_type: String) -> Node2D:
	var scene: PackedScene = zone_scene_map.get(zone_type, road_zone_scene) as PackedScene
	var zone: Node2D = scene.instantiate() as Node2D
	zone.position.x = next_zone_position
	add_child(zone)
	active_zones.append(zone)
	next_zone_position += ZONE_SPACING
	zones_spawned += 1
	last_zone_type = zone_type

	if zone.has_method("setup"):
		zone.setup(GameManager.difficulty_level)

	return zone

## Rolls a random road event based on current biome.
func _roll_road_event():
	var event_weights: Dictionary = BiomeData.get_road_event_weights(GameManager.current_biome)
	var event: String = ZoneGenerator.pick_weighted_zone(event_weights, GameManager.world_rng)

	# Inject Bottleneck Horde (rare event)
	if GameManager.world_rng.randf() < 0.12: # Lowered to 12% for less overwhelming gameplay
		event = "bottleneck_horde"

	if event != "nothing":
		pending_road_event = event
		SignalsBus.road_event_triggered.emit(event)
		_apply_road_event(event)

## Applies the effect of a road event.
func _apply_road_event(event: String):
	match event:
		"roadblock", "fallen_tree":
			var obs = DestructibleObstacle.new()
			var rect = ColorRect.new()
			if event == "fallen_tree":
				rect.color = Color(0.3, 0.2, 0.1)
				rect.size = Vector2(100, 30)
			else:
				rect.color = Color(0.7, 0.7, 0.7)
				rect.size = Vector2(80, 50)
				
			rect.position = -rect.size * 0.5
			obs.add_child(rect)
			
			var coll = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = rect.size
			coll.shape = shape
			obs.add_child(coll)
			
			obs.position = Vector2(next_zone_position - (ZONE_SPACING / 2.0), 370)
			obs.z_index = 5 # Fix drawing order against new road zones
			add_child(obs)
			
		"ambush":
			# Spawn extra zombies in the next zone
			pass
		"abandoned_vehicle":
			# Drop a couple of scrap pickups on the road for the player to grab.
			var collect_scene = load("res://scenes/collectibles/collectible.tscn")
			if collect_scene:
				for i in 2:
					var item = collect_scene.instantiate()
					item.type = Collectible.Type.SCRAP
					item.global_position = Vector2(next_zone_position - (ZONE_SPACING / 2.0) + (i * 30 - 15), 360)
					add_child(item)
		"sandstorm":
			pass
		"toxic_puddle":
			pass
		"bottleneck_horde":
			var horde_x = next_zone_position - (ZONE_SPACING * 1.5) # Spawns much closer to the player 
			var is_road = (GameManager.world_rng.randf() < 0.70)
			var zombie_scene = preload("res://scenes/zombies/zombie.tscn")
			var health_mod = GameManager.get_zombie_health_modifier()
			
			var count = GameManager.world_rng.randi_range(10, 15)
			if GameManager.distance_traveled > 5000.0:
				var scale_ratio = 1.0 + (GameManager.distance_traveled - 5000.0) / 10000.0
				count = int(count * min(3.5, scale_ratio)) # Up to 3.5x more zombies deep into the run
			
			var is_great_wall = is_road and GameManager.world_rng.randf() < 0.40 # 40% chance of a Wall
			
			for i in range(count):
				var z_x = horde_x + GameManager.world_rng.randf_range(-150, 150)
				var z_y = 0.0
				
				if is_great_wall:
					z_x = horde_x + GameManager.world_rng.randf_range(-20, 20)
					z_y = 280.0 + (160.0 * (float(i) / max(1.0, float(count - 1))))
				elif is_road:
					z_y = GameManager.world_rng.randf_range(280, 440)
				else: # Spawns in fields
					z_y = GameManager.world_rng.randf_range(100, 250) if GameManager.world_rng.randf() < 0.5 else GameManager.world_rng.randf_range(470, 600)
				
				var zombie = zombie_scene.instantiate()
				zombie.position = Vector2(z_x, z_y)
				if zombie.has_method("set_difficulty"):
					zombie.set_difficulty(health_mod)
				add_child(zombie)
	pending_road_event = ""

## Cleans up old zones behind the player.
func _cleanup_old_zones():
	while active_zones.size() > 8:
		var old_zone: Node2D = active_zones.pop_front()
		if is_instance_valid(old_zone):
			old_zone.queue_free()

func _start_tutorial_deferred():
	TutorialManager.start_tutorial()

## Creates invisible collision walls at the top and bottom of the play area.
func _create_world_borders():
	var wall_width: float = 100000.0  # Very wide to cover all generated zones
	var wall_thickness: float = 40.0

	# Top border at y = 30
	_add_border_wall(Vector2(wall_width * 0.5, 30.0 - wall_thickness * 0.5), Vector2(wall_width, wall_thickness))
	# Bottom border at y = 690
	_add_border_wall(Vector2(wall_width * 0.5, 690.0 + wall_thickness * 0.5), Vector2(wall_width, wall_thickness))

## Spawns a small starter shed near the player's spawn (~200,360) with a gun,
## ammo, fuel, and basic supplies inside, so the run starts equipped.
func _spawn_starter_shed():
	var collect_scene = load("res://scenes/collectibles/collectible.tscn")
	if not collect_scene:
		return

	var shed_pos := Vector2(80, 80)
	var shed_size := Vector2(180, 140)
	var wall_t := 8.0

	var node := Node2D.new()
	node.position = shed_pos
	node.z_index = 2
	add_child(node)

	# Floor
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.4, 0.32, 0.22, 0.9)
	floor_rect.position = Vector2.ZERO
	floor_rect.size = shed_size
	node.add_child(floor_rect)

	# Wall draws + collisions (open south, facing the road)
	var wall_color := Color(0.55, 0.4, 0.25)
	var door_w: float = 50.0
	var walls: Array = [
		Rect2(0, 0, shed_size.x, wall_t),                                    # top
		Rect2(0, 0, wall_t, shed_size.y),                                    # left
		Rect2(shed_size.x - wall_t, 0, wall_t, shed_size.y),                 # right
		Rect2(0, shed_size.y - wall_t, shed_size.x * 0.5 - door_w * 0.5, wall_t),  # bottom-left of door
		Rect2(shed_size.x * 0.5 + door_w * 0.5, shed_size.y - wall_t,
			shed_size.x * 0.5 - door_w * 0.5, wall_t),                       # bottom-right of door
	]
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	node.add_child(body)
	for w: Rect2 in walls:
		var rect := ColorRect.new()
		rect.color = wall_color
		rect.position = w.position
		rect.size = w.size
		node.add_child(rect)

		var coll := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = w.size
		coll.shape = shape
		coll.position = w.position + w.size * 0.5
		body.add_child(coll)

	# Sign label
	var label := Label.new()
	label.text = "SUPPLIES"
	label.position = Vector2(shed_size.x * 0.5 - 35, -22)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.5))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	node.add_child(label)

	# Spawn supplies inside (positions are world coords).
	var origin := shed_pos + Vector2(wall_t + 15, wall_t + 15)
	var item_layout: Array = [
		[Collectible.Type.GUN, Vector2(0, 0)],
		[Collectible.Type.AMMO, Vector2(35, 0)],
		[Collectible.Type.AMMO, Vector2(70, 0)],
		[Collectible.Type.FUEL, Vector2(0, 35)],
		[Collectible.Type.MEDKIT, Vector2(35, 35)],
		[Collectible.Type.FOOD, Vector2(70, 35)],
		[Collectible.Type.DRINK, Vector2(105, 35)],
		[Collectible.Type.MELEE, Vector2(0, 70)],
		[Collectible.Type.SCRAP, Vector2(35, 70)],
		[Collectible.Type.BATTERY, Vector2(70, 70)],
	]
	for entry in item_layout:
		var item: Collectible = collect_scene.instantiate() as Collectible
		item.type = entry[0]
		item.global_position = origin + entry[1]
		add_child(item)

func _add_border_wall(pos: Vector2, size: Vector2):
	var wall = StaticBody2D.new()
	wall.position = pos
	wall.collision_layer = 1  # Environment layer
	wall.collision_mask = 0

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)

	add_child(wall)
