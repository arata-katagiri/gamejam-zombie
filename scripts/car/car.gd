extends Node2D

signal travel_finished

const BASE_SPEED := 600.0
const TRAVEL_DISTANCE := 1280.0

var fuel_efficiency: float = 1.0
var storage_capacity: int = 10
var durability: float = 100.0
var speed_modifier: float = 1.0
var is_traveling: bool = false
var travel_progress: float = 0.0
var inventory: Array[String] = []
var player_ref: CharacterBody2D = null
var player_nearby: bool = false

@onready var interaction_area: Area2D = $InteractionArea

func _ready():
	interaction_area.set_collision_layer(0)
	interaction_area.set_collision_mask(2)
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _draw():
	draw_rect(Rect2(-35, -18, 70, 36), Color(0.6, 0.15, 0.1))
	draw_rect(Rect2(15, -14, 16, 28), Color(0.5, 0.7, 0.9, 0.7))
	draw_rect(Rect2(-30, -12, 12, 24), Color(0.5, 0.7, 0.9, 0.5))
	draw_rect(Rect2(-28, -22, 12, 6), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(-28, 16, 12, 6), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(16, -22, 12, 6), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(16, 16, 12, 6), Color(0.15, 0.15, 0.15))

func _process(delta: float):
	if not is_traveling:
		return
		
	var input_vector = Vector2.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vector.x -= 0.5 # Reverse is slower
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vector.y -= 0.7
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vector.y += 0.7
		
	if input_vector == Vector2.ZERO:
		return # Idle inside car
		
	# Consume fuel only when pushing the gas pedal
	var fuel_consumption_rate = 5.0 # percent per second of driving
	if GameManager.car_fuel > 0:
		pass # INFINITE FUEL CHEAT: GameManager.car_fuel -= fuel_consumption_rate * delta
	else:
		GameManager.car_fuel = 0
		_finish_travel() # Ran out of fuel!
		SignalsBus.road_event_triggered.emit("OUT OF FUEL! Scavenge for supplies.")
		return
		
	var target_velocity = input_vector * BASE_SPEED * speed_modifier
	var move_amount = target_velocity * delta
		
	# Detect Roadblocks directly in the immediate path vector
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(50, 40)
	query.shape = rect_shape
	query.transform = Transform2D(0, global_position + (input_vector.normalized() * 50))
	query.collision_mask = 4 # Detect destructibles (Layer 3)
	
	var result = space_state.intersect_shape(query)
	for hit in result:
		if hit.collider.is_in_group("destructible"):
			_finish_travel()
			SignalsBus.road_event_triggered.emit("CRASHED! Clear the path.")
			return
		
	# Apply Physical Movement
	travel_progress = max(0.0, travel_progress + move_amount.x)
	global_position += move_amount
	
	# Clamp Y axis so player doesn't drive off the asphalt fully into the void
	global_position.y = clamp(global_position.y, 150.0, 550.0)
	
	if player_ref:
		player_ref.global_position = global_position
		
	if move_amount.x > 0:
		GameManager.distance_traveled += move_amount.x
		
	if travel_progress >= TRAVEL_DISTANCE:
		_finish_travel()

func _unhandled_input(event: InputEvent):
	if is_traveling:
		return
	if event.is_action_pressed("interact"):
		if player_ref != null:
			_exit_car()
			get_viewport().set_input_as_handled()
		elif player_nearby:
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
	# If we previously fully finished travel, reset it. Otherwise, resume.
	if travel_progress >= TRAVEL_DISTANCE:
		travel_progress = 0.0
	SignalsBus.car_travel_started.emit()

func _finish_travel():
	is_traveling = false
	if travel_progress >= TRAVEL_DISTANCE:
		# We reached the zone marker properly
		SignalsBus.car_travel_ended.emit()
		travel_finished.emit()
	else:
		# Stopped midway for roadblock or fuel
		pass

func _exit_car():
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
