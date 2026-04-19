extends CharacterBody2D

enum State { IDLE, WALKING, RUNNING, ATTACKING, HURT, DEAD, IN_CAR }

const WALK_SPEED := 150.0
const RUN_SPEED := 250.0
const ATTACK_DAMAGE := 25.0
const ATTACK_COOLDOWN := 0.5

var current_state: State = State.IDLE
var attack_timer: float = 0.0
var facing_right: bool = true
var is_dead: bool = false
var hurt_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var stats: Node = $PlayerStats

var sprite: Sprite2D
var tex_idle: Texture2D
var tex_walk: Texture2D
var tex_run: Texture2D
var tex_attack: Texture2D
var tex_dead: Texture2D
var tex_hurt: Texture2D
var tex_gun: Texture2D
var anim_timer: float = 0.0
var fps: float = 10.0

var vision_light: PointLight2D

enum Weapon { UNARMED, MELEE, GUN }
var equipped_weapon: Weapon = Weapon.UNARMED
var q_pressed_last: bool = false

var weapon_sprite: Sprite2D = null
var tex_weapon_sheet: Texture2D = null

var camera_shake_timer: float = 0.0
var camera_shake_intensity: float = 0.0
var jump_timer: float = 0.0
const JUMP_DURATION := 0.6

func _ready():
	SignalsBus.player_entered_car.connect(_on_entered_car)
	SignalsBus.player_exited_car.connect(_on_exited_car)

	set_collision_layer(2)
	set_collision_mask(1)
	attack_area.set_collision_layer(0)
	attack_area.set_collision_mask(4)

	var path = "res://City_men_1/"
	tex_idle = load(path + "Idle.png")
	tex_walk = load(path + "Walk.png")
	tex_run = load(path + "Run.png")
	tex_attack = load(path + "Attack.png")
	tex_dead = load(path + "Dead.png")
	tex_hurt = load(path + "Hurt.png")
	tex_gun = load(path + "Shoot.png")

	sprite = Sprite2D.new()
	sprite.texture = tex_idle
	if tex_idle:
		sprite.hframes = max(1, int(tex_idle.get_width() / tex_idle.get_height()))
	sprite.position = Vector2(0, -25)
	add_child(sprite)

	_setup_weapon_sprite()
	
	if GameManager.has_gun:
		equipped_weapon = Weapon.GUN
		_update_weapon_display()

	scale = Vector2(0.55, 0.55)

	vision_light = PointLight2D.new()
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 1200
	tex.height = 1200
	vision_light.texture = tex
	vision_light.color = Color(0.9, 0.9, 0.75)
	vision_light.energy = 1.0
	vision_light.shadow_enabled = true
	vision_light.blend_mode = Light2D.BLEND_MODE_ADD
	vision_light.z_index = 100
	add_child(vision_light)

func _setup_weapon_sprite():
	tex_weapon_sheet = load("res://Weapon.png")
	if not tex_weapon_sheet:
		return
	weapon_sprite = Sprite2D.new()
	weapon_sprite.visible = false
	weapon_sprite.z_index = 2
	weapon_sprite.position = Vector2(18, -12)
	add_child(weapon_sprite)

func _update_weapon_display():
	if not weapon_sprite or not tex_weapon_sheet:
		return
	if equipped_weapon == Weapon.UNARMED or current_state == State.ATTACKING or current_state == State.DEAD:
		weapon_sprite.visible = false
		return
	weapon_sprite.visible = true
	weapon_sprite.texture = tex_weapon_sheet
	weapon_sprite.region_enabled = true
	# Weapon.png is 64x80. Top rows = rifles, bottom rows = pistols/melee.
	if equipped_weapon == Weapon.GUN:
		weapon_sprite.region_rect = Rect2(0, 0, 32, 16)
	elif equipped_weapon == Weapon.MELEE:
		weapon_sprite.region_rect = Rect2(32, 0, 32, 16)
	var dir_x: float = 18.0 if facing_right else -18.0
	weapon_sprite.position = Vector2(dir_x, -12)
	weapon_sprite.flip_h = not facing_right

func _physics_process(delta: float):
	if current_state == State.IN_CAR:
		if is_instance_valid(vision_light):
			vision_light.visible = false
		return
	else:
		if is_instance_valid(vision_light):
			vision_light.visible = true

	if is_instance_valid(vision_light):
		var target_scale = 1.8
		if GameManager.is_night:
			if GameManager.has_flashlight:
				target_scale = 1.2
			else:
				target_scale = 0.35
		vision_light.scale = vision_light.scale.lerp(Vector2(target_scale, target_scale), delta * 4.0)

	if not is_dead:
		if hurt_timer > 0.0:
			hurt_timer -= delta

		if Input.is_action_just_pressed("jump") and jump_timer <= 0.0:
			jump_timer = JUMP_DURATION

		if jump_timer > 0.0:
			jump_timer -= delta
			sprite.position.y = -25 - sin((JUMP_DURATION - jump_timer) / JUMP_DURATION * PI) * 50.0
			set_collision_mask_value(1, false)
		else:
			sprite.position.y = -25
			set_collision_mask_value(1, true)

		_handle_weapon_switch()
		_handle_movement(delta)
		_handle_attack(delta)
		_update_state()
		move_and_slide()
		
		# Allow distance traveled progression while walking on foot entirely 
		if current_state != State.IN_CAR and velocity.x > 0:
			GameManager.distance_traveled += velocity.x * delta

		if camera_shake_timer > 0.0:
			camera_shake_timer -= delta
			var cam = get_viewport().get_camera_2d()
			if cam:
				var shake_str: float = camera_shake_intensity * (camera_shake_timer / 0.15)
				cam.offset = Vector2(randf_range(-shake_str, shake_str), randf_range(-shake_str, shake_str))
		elif get_viewport().get_camera_2d():
			get_viewport().get_camera_2d().offset = Vector2.ZERO

	_handle_animation(delta)
	_update_weapon_display()

func _handle_weapon_switch():
	var q_pressed: bool = Input.is_key_pressed(KEY_Q)
	if q_pressed and not q_pressed_last:
		_cycle_weapon()
	q_pressed_last = q_pressed

func _cycle_weapon():
	match equipped_weapon:
		Weapon.UNARMED:
			if GameManager.has_melee:
				equipped_weapon = Weapon.MELEE
				SignalsBus.road_event_triggered.emit("Equipped: Melee")
			elif GameManager.has_gun:
				equipped_weapon = Weapon.GUN
				SignalsBus.road_event_triggered.emit("Equipped: Gun")
		Weapon.MELEE:
			if GameManager.has_gun:
				equipped_weapon = Weapon.GUN
				SignalsBus.road_event_triggered.emit("Equipped: Gun")
			else:
				equipped_weapon = Weapon.UNARMED
				SignalsBus.road_event_triggered.emit("Unequipped weapon")
		Weapon.GUN:
			if GameManager.has_melee:
				equipped_weapon = Weapon.MELEE
				SignalsBus.road_event_triggered.emit("Equipped: Melee")
			else:
				equipped_weapon = Weapon.UNARMED
				SignalsBus.road_event_triggered.emit("Unequipped weapon")

func shake_camera(intensity: float, duration: float = 0.15):
	camera_shake_intensity = intensity
	camera_shake_timer = duration

func _handle_movement(delta: float):
	if current_state == State.ATTACKING or hurt_timer > 0.0:
		velocity = Vector2.ZERO
		return

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if input.length() > 0:
		var is_running = Input.is_key_pressed(KEY_SHIFT)
		if is_running:
			if not stats.use_energy(15.0 * delta):
				is_running = false
		
		velocity = input.normalized() * (RUN_SPEED if is_running else WALK_SPEED)
		if input.x != 0.0:
			facing_right = input.x > 0
	else:
		velocity = Vector2.ZERO

func _handle_attack(delta: float):
	attack_timer -= delta

	var try_melee: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and (equipped_weapon == Weapon.MELEE or equipped_weapon == Weapon.UNARMED)
	var try_shoot: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and equipped_weapon == Weapon.GUN

	if (try_melee or try_shoot) and attack_timer <= 0.0 and hurt_timer <= 0.0:
		current_state = State.ATTACKING
		if try_melee:
			if GameManager.has_melee:
				equipped_weapon = Weapon.MELEE
			else:
				equipped_weapon = Weapon.UNARMED
				
			attack_timer = 0.5
			facing_right = get_global_mouse_position().x > global_position.x
			_perform_melee()
		elif try_shoot:
			facing_right = get_global_mouse_position().x > global_position.x
			if GameManager.pistol_ammo > 0:
				GameManager.pistol_ammo -= 1
				attack_timer = 0.4 # Give enough time to play the Shoot animation grid!
				_perform_shoot()
			else:
				SignalsBus.road_event_triggered.emit("OUT OF AMMO!")
				attack_timer = 0.5

func _perform_melee():
	shake_camera(4.0, 0.1)
	var dmg = ATTACK_DAMAGE * 1.5 if GameManager.has_melee else ATTACK_DAMAGE * 0.5
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(dmg)

func _perform_shoot():
	shake_camera(8.0, 0.1)

	var mpos = get_global_mouse_position()
	var dir = (mpos - global_position).normalized()
	dir = dir.rotated(randf_range(-0.05, 0.05))

	var muzzle_pos = global_position + Vector2(20 if facing_right else -20, -10)
	var end_pos = muzzle_pos + dir * 800.0

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(muzzle_pos, end_pos, 4)
	var result = space_state.intersect_ray(query)

	if result:
		end_pos = result.position
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(ATTACK_DAMAGE)

	var trail = Line2D.new()
	trail.add_point(muzzle_pos)
	trail.add_point(end_pos)
	trail.width = 1.5
	trail.default_color = Color(1.0, 0.9, 0.4, 0.8)
	trail.z_index = 1500
	get_tree().current_scene.add_child(trail)

	var tw = create_tween()
	tw.tween_property(trail, "modulate:a", 0.0, 0.08)
	tw.tween_callback(trail.queue_free)

func _update_state():
	if hurt_timer > 0.0:
		current_state = State.HURT
		return

	if current_state == State.ATTACKING and attack_timer <= 0.0:
		current_state = State.IDLE

	if current_state != State.ATTACKING:
		if velocity.length() > 0:
			if Input.is_key_pressed(KEY_SHIFT):
				current_state = State.RUNNING
			else:
				current_state = State.WALKING
		else:
			current_state = State.IDLE

func _handle_animation(delta: float):
	if not is_instance_valid(sprite):
		return

	var target_tex: Texture2D = tex_idle
	if is_dead:
		target_tex = tex_dead
	elif current_state == State.HURT:
		target_tex = tex_hurt
	elif current_state == State.ATTACKING:
		if equipped_weapon == Weapon.GUN and tex_gun:
			target_tex = tex_gun
		else:
			target_tex = tex_attack
	elif current_state == State.RUNNING:
		target_tex = tex_run
	elif current_state == State.WALKING:
		target_tex = tex_walk

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
			if is_dead and sprite.frame == sprite.hframes - 1:
				pass
			elif current_state == State.ATTACKING and sprite.frame == sprite.hframes - 1:
				pass
			else:
				sprite.frame = (sprite.frame + 1) % sprite.hframes

	sprite.flip_h = not facing_right

func _on_entered_car():
	current_state = State.IN_CAR
	visible = false
	collision_shape.set_deferred("disabled", true)

func _on_exited_car():
	current_state = State.IDLE
	visible = true
	collision_shape.set_deferred("disabled", false)

func take_damage(amount: float):
	if is_dead:
		return
	stats.take_damage(amount)
	hurt_timer = 0.3
	shake_camera(20.0, 0.3)
	SignalsBus.player_damaged.emit(amount) # Send damage to HUD
	
	if stats.health <= 0:
		is_dead = true
		current_state = State.DEAD
		velocity = Vector2.ZERO
		collision_shape.set_deferred("disabled", true)
		_handle_animation(0)

func auto_equip(weapon_type: Weapon):
	if equipped_weapon == Weapon.UNARMED:
		equipped_weapon = weapon_type
