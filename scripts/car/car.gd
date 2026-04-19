extends Node2D

signal travel_finished

const BASE_SPEED := 600.0
const TRAVEL_DISTANCE := 1280.0

var fuel_efficiency: float = 1.0
var storage_capacity: int = 10
var max_durability: float = 500.0
var durability: float = 500.0
var speed_modifier: float = 1.0
var is_traveling: bool = false
var is_broken: bool = false
var travel_progress: float = 0.0
var inventory: Array[String] = []
var player_ref: CharacterBody2D = null
var player_nearby: bool = false

var headlight: PointLight2D
var headlight_noise: FastNoiseLite
var car_velocity: Vector2 = Vector2.ZERO
var hp_label: Label

@onready var interaction_area: Area2D = $InteractionArea

const RAM_DAMAGE_TO_ZOMBIE := 200.0   # One-shot kill at any difficulty
const RAM_DAMAGE_TO_CAR := 8.0        # Hitting a body costs durability
const RAM_HALF_WIDTH := 60.0
const RAM_HALF_HEIGHT := 32.0

var _rammed_this_frame: Dictionary = {}  # track instance ids hit recently to avoid double-damage

func _ready():
	add_to_group("car")
	interaction_area.set_collision_layer(0)
	interaction_area.set_collision_mask(2)
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	hp_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	hp_label.add_theme_constant_override("outline_size", 4)
	hp_label.position = Vector2(-25, -55)
	hp_label.z_index = 50
	hp_label.visible = false
	add_child(hp_label)

	# Headlight creation
	headlight = PointLight2D.new()
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 800
	tex.height = 800
	headlight.texture = tex
	headlight.energy = 1.5
	headlight.color = Color(1.0, 0.95, 0.8)
	headlight.shadow_enabled = true
	headlight.position = Vector2(40, 0)
	headlight.texture_scale = 1.5
	headlight.scale = Vector2(1.5, 0.6)
	add_child(headlight)
	
	headlight_noise = FastNoiseLite.new()
	headlight_noise.noise_type = FastNoiseLite.TYPE_PERLIN

	_setup_car_sprite()

func _setup_car_sprite():
	var tex: Texture2D = load("res://sprites/car.png")
	if not tex:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	# The PNG is portrait-oriented (front pointing up); rotate so the front faces +X (right).
	sprite.rotation = -PI / 2.0
	# Mirror horizontally so the car image reads left-to-right correctly.
	sprite.flip_v = true
	# Bigger footprint — was 90×44, now 140×70.
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw > 0 and th > 0:
		var target_long: float = 140.0  # along driving axis
		var target_short: float = 70.0  # across
		# After rotation: visual width = th * scale.y, visual height = tw * scale.x
		sprite.scale = Vector2(target_short / tw, target_long / th)
	add_child(sprite)

func _process(delta: float):
	if headlight:
		var fuel_percent = GameManager.car_fuel / GameManager.max_fuel
		if fuel_percent <= 0.25:
			var time_ms = Time.get_ticks_msec() / 1000.0
			var noise_val = headlight_noise.get_noise_1d(time_ms * 100.0)
			headlight.energy = lerp(0.2, 1.5, (noise_val + 1.0) / 2.0)
		else:
			headlight.energy = 1.5
			
	if player_nearby:
		hp_label.visible = true
		hp_label.text = "HP: %d/%d" % [int(durability), int(max_durability)]
	else:
		if hp_label: hp_label.visible = false

	if not is_traveling or is_broken:
		return
		
	var input_vector = Vector2.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vector.x -= 0.5  # Reverse at half speed
	# Car only moves forward/backward — no vertical steering
		
	var fuel_consumption_rate = 5.0
		
	if input_vector != Vector2.ZERO:
		if GameManager.car_fuel > 0:
			GameManager.car_fuel -= fuel_consumption_rate * delta
		else:
			GameManager.car_fuel = 0
			_exit_car() # Ran out of fuel!
			SignalsBus.road_event_triggered.emit("OUT OF FUEL! Scavenge for supplies.")
			return

	var current_base_speed = BASE_SPEED * speed_modifier
		
	var target_velocity = Vector2(input_vector.x, 0.0).normalized() * current_base_speed
	var traction = 10.0
	car_velocity = car_velocity.lerp(target_velocity, delta * traction)
		
	var move_amount = car_velocity * delta
		
	# Detect Roadblocks directly in the immediate path vector
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(50, 40)
	query.shape = rect_shape
	query.transform = Transform2D(0, global_position + (Vector2(sign(input_vector.x), 0) * 50))
	query.collision_mask = 4 # Detect destructibles (Layer 3)
	
	var result = space_state.intersect_shape(query)
	for hit in result:
		if hit.collider.is_in_group("destructible"):
			_exit_car()
			SignalsBus.road_event_triggered.emit("CRASHED! Clear the path.")
			return
		
	# Apply Physical Movement (X axis only)
	travel_progress = max(0.0, travel_progress + move_amount.x)
	global_position.x += move_amount.x

	_ram_zombies_in_path()
	# Car Y position stays fixed — no vertical movement
	
	if player_ref:
		player_ref.global_position = global_position
		
	if global_position.x > GameManager.max_x_reached:
		var new_dist = global_position.x - GameManager.max_x_reached
		GameManager.distance_traveled += new_dist * GameManager.METERS_PER_PIXEL
		GameManager.max_x_reached = global_position.x
		
	# Proximity tension
	var cam = get_viewport().get_camera_2d()
	var hud = get_tree().get_first_node_in_group("hud")
	var tension_active = false
	
	if GameManager.is_night:
		var zombies = get_tree().get_nodes_in_group("zombie")
		var nearest_dist_sq = 1e9
		var threshold_dist = 200.0
		for z in zombies:
			var d_sq = global_position.distance_squared_to(z.global_position)
			if d_sq < nearest_dist_sq:
				nearest_dist_sq = d_sq
		
		if nearest_dist_sq < threshold_dist * threshold_dist:
			var nearest_dist = sqrt(nearest_dist_sq)
			var intensity = 1.0 - (nearest_dist / threshold_dist)
			tension_active = true
			if cam:
				var shake_str = intensity * 8.0
				cam.offset = Vector2(randf_range(-shake_str, shake_str), randf_range(-shake_str, shake_str))
			if hud and hud.has_method("set_static_intensity"):
				hud.set_static_intensity(intensity * 1.5)
				
	if not tension_active:
		if cam: cam.offset = Vector2.ZERO
		if hud and hud.has_method("set_static_intensity"): hud.set_static_intensity(0.0)

func _unhandled_input(event: InputEvent):
	if is_traveling:
		if event.is_action_pressed("interact"):
			_exit_car()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		if player_ref != null:
			_exit_car()
			get_viewport().set_input_as_handled()
		elif player_nearby and not is_broken:
			_try_enter()
			get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player") and not is_traveling:
		player_nearby = true

func _on_body_exited(body: Node2D):
	if body.is_in_group("player") and not is_traveling:
		player_nearby = false

func _try_enter():
	for body: Node2D in interaction_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			_enter_car(body as CharacterBody2D)
			return

func _enter_car(player: CharacterBody2D):
	player_ref = player
	player_nearby = false
	SignalsBus.player_entered_car.emit()
	is_traveling = true
	SignalsBus.car_travel_started.emit()

func _exit_car():
	is_traveling = false
	if player_ref:
		player_ref.global_position = global_position + Vector2(0, 60)
		player_ref = null
	SignalsBus.player_exited_car.emit()

func add_to_storage(item: String) -> bool:
	if inventory.size() < storage_capacity:
		inventory.append(item)
		return true
	return false

func upgrade_speed(amount: float):
	speed_modifier += amount

func upgrade_storage(amount: int):
	storage_capacity += amount

func take_damage(amount: float):
	if is_broken: return
	durability -= amount
	if durability <= 0.0:
		durability = 0.0
		is_broken = true
		if is_traveling:
			_exit_car()
		SignalsBus.road_event_triggered.emit("CAR BROKEN! Use scrap to repair.")

func repair(amount: float):
	durability = min(max_durability, durability + amount)
	if is_broken and durability > 0.0:
		is_broken = false

## Each frame while traveling, kill any zombie inside the car footprint and
## chip durability for each one we hit. Tracked by instance id so a single
## zombie isn't hit twice as it ragdolls under the wheels.
func _ram_zombies_in_path():
	var zombies = get_tree().get_nodes_in_group("zombie")
	for z in zombies:
		if not is_instance_valid(z):
			continue
		# Skip already-dead zombies (DEAD = enum index 4 in zombie.gd)
		if "current_state" in z and z.current_state == 4:
			continue
		var dx: float = abs(z.global_position.x - global_position.x)
		var dy: float = abs(z.global_position.y - global_position.y)
		if dx <= RAM_HALF_WIDTH and dy <= RAM_HALF_HEIGHT:
			var id := z.get_instance_id()
			if _rammed_this_frame.has(id):
				continue
			_rammed_this_frame[id] = true
			if z.has_method("take_damage"):
				z.take_damage(RAM_DAMAGE_TO_ZOMBIE)
			take_damage(RAM_DAMAGE_TO_CAR)
			SignalsBus.road_event_triggered.emit("RAMMED a zombie!")
	# Compact the dedupe map: drop ids that are no longer in range so later
	# passes re-arm correctly if a different zombie reuses an id slot.
	if _rammed_this_frame.size() > 32:
		_rammed_this_frame.clear()
