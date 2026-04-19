extends CanvasLayer

var health_bar: ProgressBar
var hunger_bar: ProgressBar
var energy_bar: ProgressBar
var distance_label: Label
var biome_label: Label
var event_label: Label
var player_stats: Node = null
var game_over_shown: bool = false
var event_display_timer: float = 0.0
var static_overlay: ColorRect

var fuel_bar: ProgressBar
var thirst_bar: ProgressBar
var time_label: Label
var ammo_label: Label
var coins_label: Label
var inventory_panel: PanelContainer
var inv_labels: Dictionary = {}
var inv_title_label: Label

var store_panel: PanelContainer
var store_status_label: Label

func _ready():
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_create_static_overlay()
	await get_tree().process_frame
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		player_stats = player.get_node("PlayerStats")
		player_stats.stats_changed.connect(_update_bars)
		_update_bars()
	SignalsBus.game_over.connect(_on_game_over)
	SignalsBus.biome_changed.connect(_on_biome_changed)
	SignalsBus.road_event_triggered.connect(_on_road_event)
	SignalsBus.zone_type_spawned.connect(_on_zone_spawned)

func _process(delta: float):
	if distance_label:
		distance_label.text = "Distance: %s" % _format_distance(GameManager.distance_traveled)

	if coins_label:
		coins_label.text = "Coins: %d" % GameManager.coins
	
	if time_label:
		var hours = int(GameManager.time_of_day)
		var minutes = int((GameManager.time_of_day - hours) * 60)
		var ampm = "AM"
		if hours >= 12:
			ampm = "PM"
			if hours > 12: hours -= 12
		if hours == 0: hours = 12
		time_label.text = "%02d:%02d %s" % [hours, minutes, ampm]
		if GameManager.is_night:
			time_label.add_theme_color_override("font_color", Color(0.3, 0.4, 0.8))
		else:
			time_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
			
	if fuel_bar:
		fuel_bar.value = (GameManager.car_fuel / GameManager.max_fuel) * 100.0
		
	if ammo_label:
		ammo_label.text = "Ammo: %d" % GameManager.pistol_ammo

	# Fade out event label
	if event_display_timer > 0.0:
		event_display_timer -= delta
		if event_display_timer <= 0.0 and event_label:
			event_label.text = ""
			
	# Update inventory UI slots
	if inventory_panel and inventory_panel.visible:
		if inv_title_label:
			inv_title_label.text = "BACKPACK [%d/%d]" % [GameManager.get_total_items(), GameManager.max_inventory_capacity]
		for i in range(GameManager.max_inventory_capacity):
			var data = inv_cells[i]
			if i < GameManager.player_inventory.size():
				var item_name = GameManager.player_inventory[i]
				data.label.text = item_name.capitalize()
				data.use.disabled = false
				data.drop.disabled = false
				_apply_inventory_icon(data, item_name)
			else:
				data.label.text = "Empty"
				data.use.disabled = true
				data.drop.disabled = true
				data.icon_tex.texture = null
				data.icon_bg.color = Color(0.2, 0.2, 0.2, 0.5)

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.is_pressed():
		if event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_I:
			inventory_panel.visible = !inventory_panel.visible
			get_viewport().set_input_as_handled()

	if game_over_shown and event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.physical_keycode == KEY_R and key_event.is_pressed():
			_restart_game()

func _on_game_over():
	if game_over_shown: return
	game_over_shown = true

	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)

	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220, -200)
	panel.custom_minimum_size = Vector2(440, 400)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 14)
	add_child(panel)

	var title: Label = Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0))
	title.add_theme_constant_override("outline_size", 4)
	panel.add_child(title)

	var dist_label: Label = Label.new()
	dist_label.text = "Distance: %s" % _format_distance(GameManager.distance_traveled)
	dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dist_label.add_theme_font_size_override("font_size", 28)
	dist_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	panel.add_child(dist_label)

	var high_label: Label = Label.new()
	high_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	high_label.add_theme_font_size_override("font_size", 20)
	if GameManager.is_new_highscore:
		high_label.text = "★ NEW HIGH SCORE! ★"
		high_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		high_label.text = "Best: %s" % _format_distance(GameManager.highscore_distance)
		high_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	panel.add_child(high_label)

	var coin_label: Label = Label.new()
	coin_label.text = "Coins earned: %d" % GameManager.coins
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_label.add_theme_font_size_override("font_size", 20)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	panel.add_child(coin_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	panel.add_child(spacer)

	var retry_btn: Button = Button.new()
	retry_btn.text = "RETRY  (R)"
	retry_btn.custom_minimum_size = Vector2(260, 48)
	retry_btn.add_theme_font_size_override("font_size", 20)
	retry_btn.pressed.connect(_restart_game)
	panel.add_child(retry_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(260, 40)
	menu_btn.add_theme_font_size_override("font_size", 18)
	menu_btn.pressed.connect(_goto_main_menu)
	panel.add_child(menu_btn)

	get_tree().paused = true

func _restart_game():
	GameManager.reset_run()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _goto_main_menu():
	GameManager.reset_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _format_distance(meters: float) -> String:
	if meters >= 1000.0:
		return "%.2f km" % (meters / 1000.0)
	return "%d m" % int(meters)

func _on_biome_changed(biome_name: String):
	if biome_label:
		biome_label.text = "Biome: %s" % biome_name
	_show_event("Entering %s" % biome_name)

func _on_road_event(event_type: String):
	var display_name: String
	match event_type:
		"roadblock": display_name = "⚠ Roadblock ahead!"
		"ambush": display_name = "⚠ Ambush!"
		"abandoned_vehicle": display_name = "🚗 Abandoned vehicle found"
		"sandstorm": display_name = "🌪 Sandstorm!"
		"fallen_tree": display_name = "🌲 Fallen tree on road"
		"toxic_puddle": display_name = "☢ Toxic waste!"
		"bottleneck_horde": display_name = "❗ HORDE BLOCKADE AHEAD!"
		_: display_name = event_type
	_show_event(display_name)

func _on_zone_spawned(zone_type: String):
	pass

func _show_event(text: String):
	if event_label:
		event_label.text = text
		event_display_timer = 3.0

func _create_static_overlay():
	static_overlay = ColorRect.new()
	static_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	static_overlay.color = Color(1, 1, 1, 0)
	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity = 0.0;
void fragment() {
	float r = fract(sin(dot(UV.xy*TIME, vec2(12.9898,78.233))) * 43758.5453);
	COLOR = vec4(vec3(r), intensity);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	static_overlay.material = mat
	static_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(static_overlay)

func set_static_intensity(intensity: float):
	if static_overlay and static_overlay.material:
		var clamped_intensity = clamp(intensity, 0.0, 0.4) # Max 40% opacity
		static_overlay.material.set_shader_parameter("intensity", clamped_intensity)

var inv_cells: Array[Dictionary] = []

func _use_item(idx: int):
	if idx >= GameManager.player_inventory.size(): return
	var item_name = GameManager.player_inventory[idx]
	
	if item_name == "battery" and GameManager.has_flashlight: return # Prevent wasting battery
	
	if item_name == "scrap":
		var car = get_tree().get_first_node_in_group("car")
		if car and car.player_nearby and car.durability < car.max_durability:
			car.repair(100.0) # Repair 100 HP per scrap
			SignalsBus.road_event_triggered.emit("Repaired Car: HP at %d/%d" % [int(car.durability), int(car.max_durability)])
		else:
			return # Cannot consume scrap
			
	GameManager.player_inventory.remove_at(idx)
	
	var player = get_tree().get_first_node_in_group("player")
	var stats = player.get_node("PlayerStats") if player else null
	
	match item_name:
		"food":
			if stats: stats.feed(25.0)
		"drink":
			GameManager.player_thirst = min(GameManager.max_thirst, GameManager.player_thirst + 40.0)
			if stats: stats.stats_changed.emit()
		"medkit":
			if stats: stats.heal(40.0)
		"fuel":
			GameManager.car_fuel = min(GameManager.max_fuel, GameManager.car_fuel + 25.0)
		"battery":
			GameManager.has_flashlight = true
	
	SignalsBus.road_event_triggered.emit("Used: " + item_name.capitalize())

func _drop_item(idx: int):
	if idx >= GameManager.player_inventory.size(): return
	var item_name = GameManager.player_inventory[idx]
	GameManager.player_inventory.remove_at(idx)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var collect_scene = load("res://scenes/collectibles/collectible.tscn")
		if collect_scene:
			var item = collect_scene.instantiate()
			# Drop slightly offset so it doesn't instantly collide on frame 1
			item.global_position = player.global_position + Vector2(10, 40)
			if item_name == "food": item.type = Collectible.Type.FOOD
			elif item_name == "drink": item.type = Collectible.Type.DRINK
			elif item_name == "medkit": item.type = Collectible.Type.MEDKIT
			elif item_name == "fuel": item.type = Collectible.Type.FUEL
			elif item_name == "battery": item.type = Collectible.Type.BATTERY
			elif item_name == "scrap": item.type = Collectible.Type.SCRAP
			get_tree().current_scene.add_child(item)
			
	SignalsBus.road_event_triggered.emit("Dropped: " + item_name.capitalize())

func _build_ui():
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	health_bar = _create_bar(vbox, "HP", Color(0.8, 0.15, 0.15))
	hunger_bar = _create_bar(vbox, "Hunger", Color(0.85, 0.55, 0.1))
	energy_bar = _create_bar(vbox, "Energy", Color(0.2, 0.7, 0.85))
	fuel_bar = _create_bar(vbox, "Gas", Color(0.7, 0.7, 0.2))
	thirst_bar = _create_bar(vbox, "Thirst", Color(0.2, 0.4, 0.9))

	distance_label = Label.new()
	distance_label.text = "Distance: 0 m"
	distance_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(distance_label)

	time_label = Label.new()
	time_label.text = "12:00 PM"
	time_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(time_label)
	
	ammo_label = Label.new()
	ammo_label.text = "Ammo: 0"
	ammo_label.add_theme_font_size_override("font_size", 16)
	ammo_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(ammo_label)

	coins_label = Label.new()
	coins_label.text = "Coins: 0"
	coins_label.add_theme_font_size_override("font_size", 16)
	coins_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	vbox.add_child(coins_label)

	var store_hint = Label.new()
	store_hint.text = "Find a Store along the road (every 500 m)"
	store_hint.add_theme_font_size_override("font_size", 12)
	store_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	vbox.add_child(store_hint)

	biome_label = Label.new()
	biome_label.text = "Biome: Suburbs"
	biome_label.add_theme_font_size_override("font_size", 14)
	biome_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	vbox.add_child(biome_label)

	# Event notification (top center)
	var event_container: MarginContainer = MarginContainer.new()
	event_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	event_container.add_theme_constant_override("margin_top", 15)
	add_child(event_container)

	event_label = Label.new()
	event_label.text = ""
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.add_theme_font_size_override("font_size", 20)
	event_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	event_container.add_child(event_label)
	
	# --- Backpack UI ---
	inventory_panel = PanelContainer.new()
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	inventory_panel.visible = false
	add_child(inventory_panel)
	
	var inv_bg = ColorRect.new()
	inv_bg.color = Color(0.1, 0.1, 0.1, 0.9)
	inventory_panel.add_child(inv_bg)
	
	var inv_margin = MarginContainer.new()
	inv_margin.add_theme_constant_override("margin_left", 20)
	inv_margin.add_theme_constant_override("margin_top", 20)
	inv_margin.add_theme_constant_override("margin_right", 20)
	inv_margin.add_theme_constant_override("margin_bottom", 20)
	inventory_panel.add_child(inv_margin)
	
	var inv_vbox = VBoxContainer.new()
	inv_vbox.add_theme_constant_override("separation", 10)
	inv_margin.add_child(inv_vbox)
	
	inv_title_label = Label.new()
	inv_title_label.text = "BACKPACK [0/10]"
	inv_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_title_label.add_theme_font_size_override("font_size", 20)
	inv_vbox.add_child(inv_title_label)
	
	var inv_grid = GridContainer.new()
	inv_grid.columns = 5 # Changed to 5 columns so 10 items fit cleanly into 2 rows
	inv_grid.add_theme_constant_override("h_separation", 30)
	inv_grid.add_theme_constant_override("v_separation", 20)
	inv_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inv_vbox.add_child(inv_grid)
	
	for i in range(GameManager.max_inventory_capacity): # 10 exact slots
		var cell = VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 5)
		
		var icon_box = Control.new()
		icon_box.custom_minimum_size = Vector2(48, 48)
		icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(icon_box)

		var icon_bg = ColorRect.new()
		icon_bg.color = Color(0.2, 0.2, 0.2, 0.5)
		icon_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_box.add_child(icon_bg)

		var icon_tex = TextureRect.new()
		icon_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_box.add_child(icon_tex)
		
		var lbl = Label.new()
		lbl.text = "Empty"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		cell.add_child(lbl)
		
		var btn_use = Button.new()
		btn_use.text = "Use"
		btn_use.custom_minimum_size.x = 70
		btn_use.pressed.connect(func(): _use_item(i))
		cell.add_child(btn_use)
		
		var btn_drop = Button.new()
		btn_drop.text = "Drop"
		btn_drop.custom_minimum_size.x = 70
		btn_drop.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		btn_drop.pressed.connect(func(): _drop_item(i))
		cell.add_child(btn_drop)
		
		inv_grid.add_child(cell)
		inv_cells.append({ "cell": cell, "icon_bg": icon_bg, "icon_tex": icon_tex, "label": lbl, "use": btn_use, "drop": btn_drop })

	_build_store_ui()

const STORE_ITEMS := [
	{"id": "food",    "label": "Food",        "price": 10,  "desc": "+25 hunger"},
	{"id": "drink",   "label": "Water",       "price": 10,  "desc": "+40 thirst"},
	{"id": "medkit",  "label": "Medkit",      "price": 20,  "desc": "+40 HP"},
	{"id": "fuel",    "label": "Fuel",        "price": 15,  "desc": "+25 car fuel"},
	{"id": "scrap",   "label": "Scrap",       "price": 10,  "desc": "Repair the car"},
	{"id": "battery", "label": "Battery",     "price": 30,  "desc": "Flashlight power"},
	{"id": "ammo",    "label": "Ammo x3",     "price": 15,  "desc": "+3 pistol rounds"},
	{"id": "melee",   "label": "Melee Weapon","price": 40,  "desc": "Unlock melee"},
	{"id": "gun",     "label": "Pistol",      "price": 100, "desc": "Unlock firearm"},
]

func _build_store_ui():
	store_panel = PanelContainer.new()
	store_panel.set_anchors_preset(Control.PRESET_CENTER)
	store_panel.visible = false
	add_child(store_panel)

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 0.94)
	store_panel.add_child(bg)

	var store_margin = MarginContainer.new()
	store_margin.add_theme_constant_override("margin_left", 24)
	store_margin.add_theme_constant_override("margin_right", 24)
	store_margin.add_theme_constant_override("margin_top", 20)
	store_margin.add_theme_constant_override("margin_bottom", 20)
	store_panel.add_child(store_margin)

	var store_vbox = VBoxContainer.new()
	store_vbox.add_theme_constant_override("separation", 10)
	store_margin.add_child(store_vbox)

	var title = Label.new()
	title.text = "TRADER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	store_vbox.add_child(title)

	store_status_label = Label.new()
	store_status_label.text = "Spend coins earned from kills."
	store_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	store_status_label.add_theme_font_size_override("font_size", 14)
	store_status_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	store_vbox.add_child(store_status_label)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	store_vbox.add_child(grid)

	for entry in STORE_ITEMS:
		var cell = VBoxContainer.new()
		cell.custom_minimum_size = Vector2(180, 110)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 4)

		var name_lbl = Label.new()
		name_lbl.text = entry.label
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
		cell.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = entry.desc
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		cell.add_child(desc_lbl)

		var buy_btn = Button.new()
		buy_btn.text = "Buy — %d¢" % entry.price
		buy_btn.custom_minimum_size.x = 150
		var item_id: String = entry.id
		var price: int = entry.price
		buy_btn.pressed.connect(func(): _buy_item(item_id, price))
		cell.add_child(buy_btn)

		grid.add_child(cell)

	var close_btn = Button.new()
	close_btn.text = "Close (B)"
	close_btn.custom_minimum_size = Vector2(160, 36)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_toggle_store)
	store_vbox.add_child(close_btn)

func _toggle_store():
	if not store_panel: return
	store_panel.visible = not store_panel.visible

func open_store():
	if store_panel:
		store_panel.visible = true

func close_store():
	if store_panel:
		store_panel.visible = false

func _buy_item(item_id: String, price: int):
	if GameManager.coins < price:
		_store_status("Not enough coins.", Color(0.9, 0.4, 0.4))
		return

	var ok: bool = _apply_purchase(item_id)
	if not ok:
		_store_status("Can't buy right now.", Color(0.9, 0.6, 0.3))
		return

	GameManager.spend_coins(price)
	SignalsBus.store_purchase.emit(item_id)
	_store_status("Purchased: %s" % item_id.capitalize(), Color(0.4, 0.9, 0.5))

func _apply_purchase(item_id: String) -> bool:
	match item_id:
		"gun":
			if GameManager.has_gun: return false
			GameManager.has_gun = true
			GameManager.pistol_ammo += 6
			return true
		"melee":
			if GameManager.has_melee: return false
			GameManager.has_melee = true
			return true
		"ammo":
			GameManager.pistol_ammo += 3
			return true
		"fuel":
			if GameManager.car_fuel >= GameManager.max_fuel: return false
			GameManager.car_fuel = min(GameManager.max_fuel, GameManager.car_fuel + 25.0)
			return true
		_:
			# Consumable added to backpack
			if GameManager.get_total_items() >= GameManager.max_inventory_capacity:
				return false
			GameManager.player_inventory.append(item_id)
			return true

func _store_status(text: String, color: Color):
	if store_status_label:
		store_status_label.text = text
		store_status_label.add_theme_color_override("font_color", color)

const INVENTORY_ICONS := {
	"food": "res://collectible_sprites/food1.png",
	"drink": "res://collectible_sprites/bottle_of_water.png",
	"medkit": "res://collectible_sprites/medkit.png",
	"fuel": "res://collectible_sprites/fuel.png",
}

const INVENTORY_FALLBACK_COLORS := {
	"battery": Color(0.9, 0.9, 0.2),
	"scrap": Color(0.6, 0.6, 0.6),
}

func _apply_inventory_icon(data: Dictionary, item_name: String):
	if INVENTORY_ICONS.has(item_name):
		var path: String = INVENTORY_ICONS[item_name]
		data.icon_tex.texture = load(path) if ResourceLoader.exists(path) else null
		data.icon_bg.color = Color(0.15, 0.15, 0.15, 0.7)
	else:
		data.icon_tex.texture = null
		data.icon_bg.color = INVENTORY_FALLBACK_COLORS.get(item_name, Color(1, 1, 1, 0.6))

func _create_bar(parent: Control, label_text: String, color: Color) -> ProgressBar:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 60
	label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(label)

	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(180, 18)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", bg_style)

	hbox.add_child(bar)
	return bar

func _update_bars():
	if not player_stats:
		return
	health_bar.value = player_stats.get_health_percent() * 100.0
	hunger_bar.value = player_stats.get_hunger_percent() * 100.0
	thirst_bar.value = player_stats.get_thirst_percent() * 100.0
	energy_bar.value = player_stats.get_energy_percent() * 100.0
