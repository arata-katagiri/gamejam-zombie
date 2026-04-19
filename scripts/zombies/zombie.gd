extends CharacterBody2D

enum State { IDLE, PATROL, HUNT, ATTACK, DEAD }

const PATROL_SPEED := 50.0
var base_hunt_speed := 85.0
var final_hunt_speed := 180.0
var base_damage := 10.0
var final_damage := 30.0
const ATTACK_COOLDOWN := 0.5 

var current_state: State = State.IDLE
var health: float = 50.0
var attack_timer: float = 0.0
var patrol_direction: Vector2 = Vector2.RIGHT
var patrol_timer: float = 0.0
var hunt_target: Node2D = null

var zombie_sprites := [
	"res://Wild Zombie/",
	"res://Zombie Man/",
	"res://Zombie Woman/"
]

var sprite: Sprite2D
var walk_texture: Texture2D
var idle_texture: Texture2D
var attack_texture: Texture2D
var dead_texture: Texture2D

var anim_timer: float = 0.0
var fps: float = 10.0

@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	add_to_group("zombie")
	set_collision_layer(4) # Layer 3 for zombies
	set_collision_mask(1)  # Only collide with Environment layer (1)
	
	# Instead of just relying on rigid Area2D masks, we will manually check radius in IDLE/PATROL
	# to seamlessly support targeting the Car without needing complex collision layers.
	# We still keep detection_area roughly configured if needed by other systems.
	detection_area.set_collision_layer(0)
	detection_area.set_collision_mask(2)
	attack_area.set_collision_layer(0)
	attack_area.set_collision_mask(2)
	z_index = 5 # Prevent newly generated road zones from visually burying the zombie
	patrol_timer = randf_range(2.0, 5.0)
	
	# Load random realistic sprite
	var type_path = zombie_sprites[GameManager.world_rng.randi_range(0, 2)]
	walk_texture = load(type_path + "Walk.png")
	idle_texture = load(type_path + "Idle.png")
	attack_texture = load(type_path + "Attack_1.png")
	dead_texture = load(type_path + "Dead.png")
	
	sprite = Sprite2D.new()
	sprite.texture = walk_texture
	if walk_texture:
		sprite.hframes = max(1, int(walk_texture.get_width() / walk_texture.get_height()))
	sprite.position = Vector2(0, -25) 
	add_child(sprite)
	
	# Scale the zombie down globally so it acts naturally smaller!
	scale = Vector2(0.55, 0.55)

func _physics_process(delta: float):
	if current_state == State.DEAD:
		_handle_animation(delta)
		return

	attack_timer -= delta

	match current_state:
		State.IDLE:
			_process_idle(delta)
			_check_aggro()
		State.PATROL:
			_process_patrol(delta)
			_check_aggro()
		State.HUNT:
			_process_hunt(delta)
		State.ATTACK:
			_process_attack(delta)

	move_and_slide()
	_handle_animation(delta)
	
func _handle_animation(delta: float):
	if not is_instance_valid(sprite): return

	var target_tex: Texture2D = idle_texture
	if current_state == State.DEAD:
		target_tex = dead_texture
	elif current_state == State.ATTACK:
		target_tex = attack_texture
	elif current_state == State.HUNT or current_state == State.PATROL:
		target_tex = walk_texture
		
	if sprite.texture != target_tex:
		sprite.texture = target_tex
		if target_tex:
			sprite.hframes = max(1, int(target_tex.get_width() / target_tex.get_height()))
		sprite.frame = 0
		anim_timer = 0.0

	anim_timer += delta
	var frame_duration = 1.0 / fps
	if anim_timer >= frame_duration:
		anim_timer -= frame_duration
		if target_tex and sprite.hframes > 0:
			if current_state == State.DEAD and sprite.frame == sprite.hframes - 1:
				pass # Freeze on last death frame permanently
			else:
				sprite.frame = (sprite.frame + 1) % sprite.hframes

	if current_state != State.DEAD:
		if velocity.x < -1.0:
			sprite.flip_h = true
		elif velocity.x > 1.0:
			sprite.flip_h = false

func _process_idle(delta: float):
	velocity = Vector2.ZERO
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		current_state = State.PATROL
		var angle: float = randf() * TAU
		patrol_direction = Vector2(cos(angle), sin(angle))
		patrol_timer = randf_range(2.0, 4.0)

func _process_patrol(delta: float):
	velocity = patrol_direction * PATROL_SPEED
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		current_state = State.IDLE
		patrol_timer = randf_range(1.0, 3.0)

func get_hunting_speed() -> float:
	var progress_factor = clamp(GameManager.distance_traveled / 20000.0, 0.0, 1.0)
	var current_base = lerp(base_hunt_speed, final_hunt_speed, progress_factor)
	var speed = current_base * GameManager.get_zombie_speed_modifier()
	# The Lunge mechanic
	if is_instance_valid(hunt_target) and global_position.distance_to(hunt_target.global_position) < 120.0:
		speed *= 2.0
	return speed

func get_attack_damage() -> float:
	var progress_factor = clamp(GameManager.distance_traveled / 20000.0, 0.0, 1.0)
	return lerp(base_damage, final_damage, progress_factor)

func _check_aggro():
	var car = get_tree().get_first_node_in_group("car")
	var player = get_tree().get_first_node_in_group("player")
	
	if car and car.is_traveling and not car.is_broken:
		if global_position.distance_to(car.global_position) < 400.0:
			start_hunt(car)
			return
			
	if player and not player.is_dead and player.current_state != 6: # State.IN_CAR is idx 6
		if global_position.distance_to(player.global_position) < 350.0:
			start_hunt(player)

func start_hunt(target: Node2D):
	if current_state == State.DEAD or current_state == State.HUNT or current_state == State.ATTACK:
		return
	hunt_target = target
	current_state = State.HUNT
	
	# Aggravator Chaining
	var zombies = get_tree().get_nodes_in_group("zombie")
	for z in zombies:
		if z != self and is_instance_valid(z) and not (z.current_state in [State.HUNT, State.ATTACK, State.DEAD]):
			if global_position.distance_to(z.global_position) < 400.0:
				if z.has_method("start_hunt"):
					z.start_hunt(target)

func _process_hunt(_delta: float):
	if not is_instance_valid(hunt_target):
		current_state = State.IDLE
		return
		
	# If the target is a car but no one is inside, give up chase
	if hunt_target.is_in_group("car") and not hunt_target.is_traveling:
		current_state = State.IDLE
		hunt_target = null
		return

	var direction: Vector2 = (hunt_target.global_position - global_position).normalized()
	velocity = direction * get_hunting_speed()

	var distance: float = global_position.distance_to(hunt_target.global_position)
	var attack_range = 75.0 if hunt_target.is_in_group("car") else 40.0
	if distance < attack_range:
		current_state = State.ATTACK

func _process_attack(_delta: float):
	velocity = Vector2.ZERO

	if not is_instance_valid(hunt_target):
		current_state = State.IDLE
		return
		
	if hunt_target.is_in_group("car") and not hunt_target.is_traveling:
		current_state = State.IDLE
		hunt_target = null
		return

	var distance: float = global_position.distance_to(hunt_target.global_position)
	var max_range = 80.0 if hunt_target.is_in_group("car") else 50.0
	if distance > max_range:
		current_state = State.HUNT
		return

	if attack_timer <= 0.0:
		attack_timer = ATTACK_COOLDOWN
		_deal_damage()

func _deal_damage():
	if is_instance_valid(hunt_target) and hunt_target.has_method("take_damage"):
		hunt_target.take_damage(get_attack_damage())

func take_damage(amount: float):
	if current_state == State.DEAD: return
	health -= amount
	if health <= 0.0:
		_die()

func _die():
	if current_state == State.DEAD: return
	
	current_state = State.DEAD
	velocity = Vector2.ZERO
	SignalsBus.loot_collected.emit("zombie_drop", 1)
	
	# Disable collisions so player can walk over the body
	collision_shape.set_deferred("disabled", true)
	detection_area.set_deferred("monitoring", false)
	attack_area.set_deferred("monitoring", false)
	
	# Immediately trigger the first frame of death
	_handle_animation(0.0)

func set_difficulty(modifier: float):
	health *= modifier
