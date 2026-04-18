extends Area2D
class_name Collectible

enum Type { FOOD, DRINK, MEDKIT, FUEL, BATTERY, MELEE, GUN, AMMO }

var type: Type = Type.FOOD
var restore_amount: float = 25.0

var player_nearby: bool = false
var interaction_label: Label = null
var weapon_sprite: Sprite2D = null

func _ready():
	set_collision_layer(0)
	set_collision_mask(2)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if type == Type.GUN or type == Type.MELEE or type == Type.AMMO:
		weapon_sprite = Sprite2D.new()
		weapon_sprite.texture = load("res://Weapon.png")
		if weapon_sprite.texture:
			weapon_sprite.region_enabled = true
			if type == Type.GUN:
				weapon_sprite.region_rect = Rect2(0, 0, 32, 16)
			elif type == Type.MELEE:
				weapon_sprite.region_rect = Rect2(32, 0, 32, 16)
			elif type == Type.AMMO:
				weapon_sprite.region_rect = Rect2(0, 16, 16, 16) # Approximate ammo box in sheet
			add_child(weapon_sprite)

func _draw():
	if weapon_sprite != null: 
		return # Let the custom Sprite2D handle rendering!
		
	match type:
		Type.FOOD:
			draw_rect(Rect2(-7, -7, 14, 14), Color(0.9, 0.5, 0.1))
			draw_rect(Rect2(-4, -4, 8, 8), Color(1.0, 0.7, 0.3))
		Type.DRINK:
			draw_rect(Rect2(-5, -8, 10, 16), Color(0.2, 0.5, 0.9))
			draw_rect(Rect2(-3, -5, 6, 10), Color(0.4, 0.7, 1.0))
		Type.MEDKIT:
			draw_rect(Rect2(-8, -8, 16, 16), Color(0.9, 0.9, 0.9))
			draw_rect(Rect2(-2, -6, 4, 12), Color(0.85, 0.15, 0.15))
			draw_rect(Rect2(-6, -2, 12, 4), Color(0.85, 0.15, 0.15))
		Type.FUEL:
			draw_rect(Rect2(-6, -7, 12, 14), Color(0.75, 0.2, 0.15))
			draw_rect(Rect2(-3, -10, 6, 4), Color(0.6, 0.15, 0.1))
			draw_rect(Rect2(-4, -1, 8, 3), Color(0.6, 0.5, 0.1))
		Type.BATTERY:
			draw_rect(Rect2(-4, -8, 8, 16), Color(0.2, 0.2, 0.2))
			draw_rect(Rect2(-5, -6, 10, 4), Color(0.9, 0.9, 0.2))
			draw_rect(Rect2(-2, -10, 4, 2), Color(0.6, 0.6, 0.6))

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_nearby = true
		if not interaction_label:
			interaction_label = Label.new()
			interaction_label.text = "[E] Take"
			interaction_label.add_theme_font_size_override("font_size", 16)
			interaction_label.position = Vector2(-25, -30)
			interaction_label.z_index = 2000
			add_child(interaction_label)

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_nearby = false
		if is_instance_valid(interaction_label):
			interaction_label.queue_free()
			interaction_label = null

func _unhandled_input(event: InputEvent):
	if player_nearby and event.is_action_pressed("interact"):
		if type != Type.MELEE and type != Type.GUN and type != Type.AMMO:
			if GameManager.get_total_items() >= GameManager.max_inventory_capacity:
				SignalsBus.road_event_triggered.emit("BACKPACK FULL!")
				return

		get_viewport().set_input_as_handled()

		if type == Type.MELEE:
			GameManager.has_melee = true
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("auto_equip"):
				player.auto_equip(1) # Weapon.MELEE
			SignalsBus.road_event_triggered.emit("Found Melee Weapon!")
			queue_free()
			return
		elif type == Type.GUN:
			GameManager.has_gun = true
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("auto_equip"):
				player.auto_equip(2) # Weapon.GUN
			SignalsBus.road_event_triggered.emit("Found Handgun!")
			queue_free()
			return
		elif type == Type.AMMO:
			GameManager.pistol_ammo += 15
			SignalsBus.road_event_triggered.emit("Found Ammo Box! (+15)")
			queue_free()
			return

		var item_name: String
		match type:
			Type.FOOD: item_name = "food"
			Type.DRINK: item_name = "drink"
			Type.MEDKIT: item_name = "medkit"
			Type.FUEL: item_name = "fuel"
			Type.BATTERY: item_name = "battery"
			_: item_name = "unknown"

		GameManager.player_inventory.append(item_name)
		SignalsBus.road_event_triggered.emit("Collected: " + item_name.capitalize())
		SignalsBus.loot_collected.emit(item_name, 1)
		queue_free()
