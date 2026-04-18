extends StaticBody2D
class_name DestructibleObstacle

var hp: float = 75.0
var max_hp: float = 75.0

func _ready():
	add_to_group("destructible")
	set_collision_layer(5) # 1 (Environment) + 4 (Zombies/Destructibles)
	set_collision_mask(0)

func setup(type: String):
	pass

func take_damage(amount: float):
	hp -= amount
	# Visual flash
	modulate = Color(1.5, 1.0, 1.0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	if hp <= 0:
		_destroy()

func _destroy():
	# Drop loot or scrap?
	SignalsBus.loot_collected.emit("wood", 2)
	queue_free()
