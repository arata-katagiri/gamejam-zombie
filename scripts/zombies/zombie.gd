extends CharacterBody2D

enum State { IDLE, PATROL, CHASE, ATTACK, DEAD }

const PATROL_SPEED := 50.0
const CHASE_SPEED := 120.0
const ATTACK_DAMAGE := 10.0
const ATTACK_COOLDOWN := 1.0

var current_state: State = State.IDLE
var health: float = 50.0
var attack_timer: float = 0.0
var patrol_direction: Vector2 = Vector2.RIGHT
var patrol_timer: float = 0.0
var player_ref: CharacterBody2D = null

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
	set_collision_layer(4) # Layer 3 for zombies
	set_collision_mask(1)  # Only collide with Environment layer (1)
	
	detection_area.set_collision_layer(0)
	detection_area.set_collision_mask(2) # Detect Player (Layer 2)
	attack_area.set_collision_layer(0)
	attack_area.set_collision_mask(2)    # Detect Player (Layer 2)

	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
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
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
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
	elif current_state == State.CHASE or current_state == State.PATROL:
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

func _process_chase(_delta: float):
	if not is_instance_valid(player_ref):
		current_state = State.IDLE
		return

	var direction: Vector2 = (player_ref.global_position - global_position).normalized()
	velocity = direction * CHASE_SPEED

	var distance: float = global_position.distance_to(player_ref.global_position)
	if distance < 40.0:
		current_state = State.ATTACK

func _process_attack(_delta: float):
	velocity = Vector2.ZERO

	if not is_instance_valid(player_ref):
		current_state = State.IDLE
		return

	var distance: float = global_position.distance_to(player_ref.global_position)
	if distance > 50.0:
		current_state = State.CHASE
		return

	if attack_timer <= 0.0:
		attack_timer = ATTACK_COOLDOWN
		_deal_damage()

func _deal_damage():
	for body: Node2D in attack_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(ATTACK_DAMAGE)

func _on_detection_body_entered(body: Node2D):
	if current_state == State.DEAD: return
	if body.is_in_group("player"):
		player_ref = body as CharacterBody2D
		current_state = State.CHASE

func _on_detection_body_exited(body: Node2D):
	if current_state == State.DEAD: return
	if body.is_in_group("player"):
		player_ref = null
		if current_state == State.CHASE or current_state == State.ATTACK:
			current_state = State.IDLE

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
