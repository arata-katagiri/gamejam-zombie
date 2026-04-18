extends Node2D
class_name CityBuilding

var layers: Array[Texture2D] = []
var height_offset: float = 3.0 # pseudo-3D offset per layer

var base_area: Area2D
var blackout_rect: ColorRect
var player_inside: CharacterBody2D = null
var current_floor: int = 5

var stairs_area: Area2D
var stairs_visual: Node2D
var player_on_stairs: bool = false

func setup(textures: Array[Texture2D], box_size: Vector2):
	scale = Vector2(2.0, 2.0)
	layers = textures.duplicate()
	layers.sort_custom(func(a, b):
		return _get_layer_num(a.resource_path) < _get_layer_num(b.resource_path)
	)
	
	for i in range(layers.size()):
		var sprite = Sprite2D.new()
		sprite.texture = layers[i]
		sprite.position = Vector2(0, -i * height_offset)
		sprite.name = "Layer_%d" % i
		sprite.z_index = i
		sprite.z_as_relative = false
		add_child(sprite)
	
	# Massive blackout screen to hide outside world when inside
	blackout_rect = ColorRect.new()
	blackout_rect.color = Color(0, 0, 0, 1.0)
	blackout_rect.size = Vector2(50000, 50000)
	blackout_rect.position = Vector2(-25000, -25000)
	blackout_rect.z_index = 999
	blackout_rect.z_as_relative = false
	blackout_rect.visible = false
	add_child(blackout_rect)
	
	_create_colliders(box_size)

func _create_colliders(box_size: Vector2):
	var shape_size = box_size
	if layers.size() > 0 and layers[0] != null:
		shape_size = layers[0].get_size()
		
	# Physics wall to prevent walking through the building entirely without jumping
	var static_body = StaticBody2D.new()
	static_body.set_collision_layer(1)
	static_body.set_collision_mask(0)
	var st_shape = RectangleShape2D.new()
	# Cover the entire width and the bottom access area
	st_shape.size = Vector2(shape_size.x, shape_size.y * 0.95)
	var st_coll = CollisionShape2D.new()
	st_coll.shape = st_shape
	st_coll.position = Vector2(shape_size.x * 0.5, shape_size.y * 0.5)
	static_body.add_child(st_coll)
	add_child(static_body)

	# Visual Windows to indicate where the player should jump in
	var window_visuals = Node2D.new()
	window_visuals.position = Vector2(shape_size.x * 0.5 - 60, shape_size.y * 0.8)
	for i in range(3):
		var win = ColorRect.new()
		win.color = Color(0.4, 0.7, 0.9, 0.8)
		win.size = Vector2(30, 20)
		win.position = Vector2(i * 40, 0)
		window_visuals.add_child(win)
	add_child(window_visuals)

	# Block the Player's vision from seeing inside or outside using LightOccluder
	var occ = LightOccluder2D.new()
	var poly = OccluderPolygon2D.new()
	# Create a hollow U-shape wall (front side open for the window jump)
	var t = 5.0 # wall thickness
	var w = shape_size.x
	var h = shape_size.y
	poly.polygon = PackedVector2Array([
		Vector2(0, h), Vector2(0, 0), Vector2(w, 0), Vector2(w, h), # Outer edge
		Vector2(w - t, h), Vector2(w - t, t), Vector2(t, t), Vector2(t, h)  # Inner edge
	])
	poly.closed = false
	occ.occluder = poly
	add_child(occ)

	# Area for detecting entry
	base_area = Area2D.new()
	base_area.set_collision_layer(0)
	base_area.set_collision_mask(2)
	var coll = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = shape_size
	coll.shape = shape
	coll.position = shape_size * 0.5
	base_area.add_child(coll)
	add_child(base_area)
	
	base_area.body_entered.connect(_on_player_entered)
	base_area.body_exited.connect(_on_player_exited)

	# --- Stairs Area ---
	stairs_area = Area2D.new()
	stairs_area.set_collision_layer(0)
	stairs_area.set_collision_mask(2)
	
	var stair_size = Vector2(60, 60)
	var st_col2 = CollisionShape2D.new()
	var st_shp2 = RectangleShape2D.new()
	st_shp2.size = stair_size
	st_col2.shape = st_shp2
	st_col2.position = Vector2(shape_size.x * 0.5, shape_size.y * 0.5)
	stairs_area.add_child(st_col2)
	
	stairs_visual = Node2D.new()
	stairs_visual.position = Vector2(shape_size.x * 0.5 - stair_size.x * 0.5, shape_size.y * 0.5 - stair_size.y * 0.5)
	for i in range(4):
		var step = ColorRect.new()
		step.color = Color(0.2, 0.2, 0.2).lightened(i * 0.1)
		step.size = Vector2(60, 15)
		step.position = Vector2(0, i * 15)
		stairs_visual.add_child(step)
		
	var lbl = Label.new()
	lbl.text = "UP"
	lbl.position = Vector2(20, 15)
	stairs_visual.add_child(lbl)
	
	stairs_area.add_child(stairs_visual)
	add_child(stairs_area)
	
	stairs_area.body_entered.connect(func(b): if b.is_in_group("player"): player_on_stairs = true)
	stairs_area.body_exited.connect(func(b): if b.is_in_group("player"): player_on_stairs = false)

func _get_layer_num(path: String) -> int:
	var parts = path.split("Layer-")
	if parts.size() > 1:
		return int(parts[1].split(".")[0])
	return 0

func _on_player_entered(body: Node2D):
	if body.is_in_group("player"):
		player_inside = body as CharacterBody2D
		current_floor = 5 # Start on ground level visually
		_update_interior_view()
		
		# Generate the first floor content immediately!
		if interior_nodes.size() == 0:
			_spawn_interior_content(current_floor)

func _on_player_exited(body: Node2D):
	if body == player_inside:
		_restore_exterior_view()
		player_inside = null

func _unhandled_input(event: InputEvent):
	if player_inside != null and player_on_stairs and event.is_action_pressed("interact"):
		current_floor += 5
		if current_floor >= layers.size():
			current_floor = 5 # Loop back
		_update_interior_view()
		_spawn_interior_content(current_floor)
		SignalsBus.road_event_triggered.emit("Floor %d" % (current_floor / 5))
		get_viewport().set_input_as_handled()

var interior_nodes: Array[Node2D] = []

func _spawn_interior_content(floor_z: int):
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var shape_size = Vector2(100, 100)
	if layers.size() > 0 and layers[0] != null:
		shape_size = layers[0].get_size()
		
	# 70% chance to spawn a Zombie
	if rng.randf() < 0.7:
		var zombie_scene = load("res://scenes/zombies/zombie.tscn")
		if zombie_scene:
			var z = zombie_scene.instantiate()
			z.position = Vector2(rng.randf_range(30, shape_size.x - 30), rng.randf_range(30, shape_size.y - 30))
			z.z_index = 1000 + floor_z
			z.z_as_relative = false
			z.scale /= self.scale # Counteract CityBuilding 2.0x scaling
			add_child(z)
			interior_nodes.append(z)
			
	# 80% chance to spawn Loot
	if rng.randf() < 0.8:
		var item_scene = load("res://scenes/collectibles/collectible.tscn")
		if item_scene:
			var item = item_scene.instantiate()
			item.position = Vector2(rng.randf_range(30, shape_size.x - 30), rng.randf_range(30, shape_size.y - 30))
			item.z_index = 1000 + floor_z
			item.z_as_relative = false
			item.scale /= self.scale
			
			# Extreme Weapon Loot Distribution
			var roll = rng.randf()
			if roll < 0.50:
				item.type = 7 # AMMO (50%)
			elif roll < 0.70:
				item.type = 6 # GUN (20%)
			elif roll < 0.90:
				item.type = 5 # MELEE (20%)
			else:
				item.type = rng.randi() % 5 # Survival (10%)
				
			add_child(item)
			interior_nodes.append(item)

func _update_interior_view():
	if not is_instance_valid(player_inside): return
	
	blackout_rect.visible = true
	player_inside.z_as_relative = false
	player_inside.z_index = 1000 + current_floor
	
	if stairs_visual:
		stairs_visual.visible = true
		stairs_visual.z_as_relative = false
		stairs_visual.z_index = 1000 + current_floor - 2 # Place slightly below player but above floor
	
	# Show interior nodes
	var valid_nodes: Array[Node2D] = []
	for node in interior_nodes:
		if is_instance_valid(node):
			node.visible = true
			valid_nodes.append(node)
	interior_nodes = valid_nodes
	
	for i in range(layers.size()):
		var sprite = get_node_or_null("Layer_%d" % i)
		if sprite:
			sprite.z_index = 1000 + i
			if i > current_floor:
				sprite.modulate.a = 0.0
			else:
				sprite.modulate.a = 1.0

func _restore_exterior_view():
	if is_instance_valid(player_inside):
		player_inside.z_index = 0
		player_inside.z_as_relative = true
	
	if stairs_visual:
		stairs_visual.visible = false
		stairs_visual.z_as_relative = true
		stairs_visual.z_index = 0
		
	# Hide interior nodes so they don't visually clip out over the 2D roof
	for node in interior_nodes:
		if is_instance_valid(node):
			node.visible = false
	
	blackout_rect.visible = false
	for i in range(layers.size()):
		var sprite = get_node_or_null("Layer_%d" % i)
		if sprite:
			sprite.z_index = i
			sprite.modulate.a = 1.0
