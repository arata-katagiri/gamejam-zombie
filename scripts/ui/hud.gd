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

var fuel_bar: ProgressBar
var thirst_bar: ProgressBar
var time_label: Label
var ammo_label: Label
var inventory_panel: PanelContainer
var inv_labels: Dictionary = {}
var inv_title_label: Label

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
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
		distance_label.text = "Distance: %d m" % int(GameManager.distance_traveled)
	
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
				match item_name:
					"food": data.icon.color = Color(0.9, 0.5, 0.1)
					"drink": data.icon.color = Color(0.2, 0.5, 0.9)
					"medkit": data.icon.color = Color(0.85, 0.15, 0.15)
					"fuel": data.icon.color = Color(0.75, 0.2, 0.15)
					"battery": data.icon.color = Color(0.9, 0.9, 0.2)
					"scrap": data.icon.color = Color(0.6, 0.6, 0.6)
					_: data.icon.color = Color(1, 1, 1)
			else:
				data.label.text = "Empty"
				data.use.disabled = true
				data.drop.disabled = true
				data.icon.color = Color(0.2, 0.2, 0.2, 0.5)

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.is_pressed():
		if event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_I:
			inventory_panel.visible = !inventory_panel.visible
			get_viewport().set_input_as_handled()
			
	if game_over_shown and event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.physical_keycode == KEY_R and key_event.is_pressed():
			get_tree().paused = false
			get_tree().reload_current_scene()

func _on_game_over():
	game_over_shown = true

	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)

	var label: Label = Label.new()
	label.text = "GAME OVER\nPress R to restart"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(1280, 720)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.RED)
	add_child(label)

	get_tree().paused = true

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
		_: display_name = event_type
	_show_event(display_name)

func _on_zone_spawned(zone_type: String):
	pass

func _show_event(text: String):
	if event_label:
		event_label.text = text
		event_display_timer = 3.0

var inv_cells: Array[Dictionary] = []

func _use_item(idx: int):
	if idx >= GameManager.player_inventory.size(): return
	var item_name = GameManager.player_inventory[idx]
	
	if item_name == "battery" and GameManager.has_flashlight: return # Prevent wasting battery
	if item_name == "scrap": return # Cannot consume scrap
	
	GameManager.player_inventory.remove_at(idx)
	
	var player = get_tree().get_first_node_in_group("player")
	var stats = player.get_node("PlayerStats") if player else null
	
	match item_name:
		"food":
			if stats: stats.feed(25.0)
		"drink":
			if stats: stats.restore_energy(25.0)
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
			if item_name == "food": item.type = 0 # Type.FOOD
			elif item_name == "drink": item.type = 1
			elif item_name == "medkit": item.type = 2
			elif item_name == "fuel": item.type = 3
			elif item_name == "battery": item.type = 4
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
		
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.color = Color(0.2, 0.2, 0.2, 0.5)
		cell.add_child(icon)
		
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
		inv_cells.append({ "cell": cell, "icon": icon, "label": lbl, "use": btn_use, "drop": btn_drop })

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
	energy_bar.value = player_stats.get_energy_percent() * 100.0
