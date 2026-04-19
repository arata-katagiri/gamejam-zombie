extends Area2D

const DAMAGE := 8.0
const TICK_INTERVAL := 0.6
const LIFETIME := 10.0
const FADE_DURATION := 1.5

var _tick_timer: float = 0.0
var _life_timer: float = 0.0
var _player_inside: Node = null

func _ready():
	collision_layer = 0
	collision_mask = 2  # Player layer
	z_index = 1  # Above ground draws, beneath characters (zombies/player are at z=5)
	monitoring = true

	var sprite := Sprite2D.new()
	sprite.texture = load("res://sprites/spit_green.png")
	sprite.scale = Vector2(0.11, 0.11)
	sprite.modulate = Color(0.55, 0.7, 0.4)  # Darker, slightly desaturated green
	add_child(sprite)

	var coll := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	coll.shape = shape
	add_child(coll)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float):
	_life_timer += delta
	if _life_timer >= LIFETIME:
		queue_free()
		return

	if _life_timer >= LIFETIME - FADE_DURATION:
		var t = (LIFETIME - _life_timer) / FADE_DURATION
		modulate.a = clamp(t, 0.0, 1.0)

	if _player_inside and is_instance_valid(_player_inside):
		_tick_timer -= delta
		if _tick_timer <= 0.0:
			_tick_timer = TICK_INTERVAL
			if _player_inside.has_method("take_damage"):
				_player_inside.take_damage(DAMAGE)

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		_player_inside = body
		_tick_timer = 0.0  # Damage immediately on stepping in

func _on_body_exited(body: Node):
	if body == _player_inside:
		_player_inside = null
