extends Node

## TutorialManager — Step-by-step onboarding for new players.
## Registered as an autoload. Builds its own UI and monitors game state
## to advance through tutorial steps automatically.
## 
## IMPORTANT: The tutorial does NOT activate until start_tutorial() is called
## (typically by the main game scene), so it stays dormant during the main menu.

signal tutorial_completed

# Tutorial is shown once per app launch (not persisted to disk).
# Autoloads survive scene reloads (retry via R), so this flag
# prevents re-showing on retry while still showing on fresh launch.

# ─── Tutorial State ───
var is_active: bool = false
var tutorial_already_done: bool = false
var current_step: int = 0
var step_timer: float = 0.0
var flash_timer: float = 0.0
var input_detected: bool = false
var waiting_for_dismiss: bool = false
var step_cooldown: float = 0.0  # Blocks input for a short period after step transition
var _is_advancing: bool = false  # Guard flag to prevent re-entrant advance from await
const STEP_COOLDOWN_DURATION: float = 0.8  # Seconds before input is accepted on a new step

# ─── UI Nodes ───
var canvas: CanvasLayer
var panel: PanelContainer
var title_label: Label
var body_label: Label
var hint_label: Label
var progress_container: HBoxContainer
var skip_button: Button
var backdrop: ColorRect
var dots: Array[ColorRect] = []

# ─── Step Definitions ───
# Each step: { title, body, hint, condition, auto_time }
#   condition: String checked in _check_condition()
#   auto_time: float — if > 0, auto-advances after N seconds (regardless of condition)
var steps: Array[Dictionary] = [
	{
		"title": "WELCOME TO THE ROAD",
		"body": "The world has fallen. Your only chance is to keep moving forward.\nScavenge. Fight. Survive.",
		"hint": "Press any key to continue...",
		"condition": "any_key",
		"auto_time": 0.0,
		"icon": "🌍"
	},
	{
		"title": "MOVEMENT",
		"body": "Use WASD or Arrow Keys to move around.\nExplore the area — supplies are everywhere.",
		"hint": "Move around to continue",
		"condition": "player_moved",
		"auto_time": 0.0,
		"icon": "🏃"
	},
	{
		"title": "SPRINT",
		"body": "Hold SHIFT while moving to sprint faster.\nSprinting drains your Energy bar.",
		"hint": "Sprint to continue",
		"condition": "player_sprinted",
		"auto_time": 0.0,
		"icon": "⚡"
	},
	{
		"title": "COMBAT",
		"body": "LEFT CLICK to attack enemies.\nYou start unarmed — find weapons for more damage!",
		"hint": "Attack to continue",
		"condition": "player_attacked",
		"auto_time": 0.0,
		"icon": "⚔️"
	},
	{
		"title": "SCAVENGING",
		"body": "Walk up to items on the ground and press E to pick them up.\nFood, water, medkits, fuel — everything matters.",
		"hint": "Pick up an item to continue  (or press SPACE)",
		"condition": "item_collected",
		"auto_time": 0.0,
		"icon": "🎒"
	},
	{
		"title": "BACKPACK",
		"body": "Press TAB or I to open your backpack.\nYou can Use or Drop items. Max 10 slots.",
		"hint": "Open your backpack to continue",
		"condition": "inventory_opened",
		"auto_time": 0.0,
		"icon": "📦"
	},
	{
		"title": "THE CAR",
		"body": "Walk to the red car and press E to enter it.\nDriving is faster but costs fuel.",
		"hint": "Enter the car to continue",
		"condition": "entered_car",
		"auto_time": 0.0,
		"icon": "🚗"
	},
	{
		"title": "DRIVING",
		"body": "Use WASD to steer the car.\nStay on the road for speed — off-road uses more fuel!\nPress E again to exit.",
		"hint": "Drive forward a bit to continue",
		"condition": "drove_car",
		"auto_time": 0.0,
		"icon": "🛣️"
	},
	{
		"title": "WEAPONS",
		"body": "When you find weapons, press Q to switch between them.\n• Melee — close range, no ammo\n• Gun — ranged, needs ammo clips",
		"hint": "Press any key to continue...",
		"condition": "any_key",
		"auto_time": 0.0,
		"icon": "🔫"
	},
	{
		"title": "BUILDINGS",
		"body": "Enter buildings through doors to explore inside.\nUse stairs to navigate between floors.\nWatch out for zombies lurking inside!",
		"hint": "Press any key to continue...",
		"condition": "any_key",
		"auto_time": 0.0,
		"icon": "🏠"
	},
	{
		"title": "SURVIVAL TIPS",
		"body": "• Hunger & Thirst drain over time — eat and drink!\n• Night is dangerous — zombies are faster and darkness closes in\n• Find batteries for a flashlight\n• Use scrap near the car to repair it",
		"hint": "Press any key to continue...",
		"condition": "any_key",
		"auto_time": 0.0,
		"icon": "💀"
	},
	{
		"title": "COINS & STORES",
		"body": "Every zombie you kill drops coins.\nA TRADER appears along the road every 500 meters.\nWalk up to the shop and press E to browse and buy supplies.",
		"hint": "Press any key to continue...",
		"condition": "any_key",
		"auto_time": 0.0,
		"icon": "🪙"
	},
	{
		"title": "GOOD LUCK",
		"body": "Keep moving forward. The road never ends.\nEvery zone brings new challenges and loot.\n\nSurvive as long as you can, traveler.",
		"hint": "",
		"condition": "auto",
		"auto_time": 4.0,
		"icon": "🔥"
	},
]

# ─── Tracking Flags ───
var _has_moved: bool = false
var _has_sprinted: bool = false
var _has_attacked: bool = false
var _has_collected: bool = false
var _has_opened_inv: bool = false
var _has_entered_car: bool = false
var _has_driven: float = 0.0
var _drive_start_dist: float = 0.0
var _inv_was_open: bool = false

## Resets ALL tracking flags so actions from a previous step don't bleed into the next.
func _reset_tracking_flags():
	_has_moved = false
	_has_sprinted = false
	_has_attacked = false
	_has_collected = false
	_has_opened_inv = false
	_has_entered_car = false
	_has_driven = 0.0
	_drive_start_dist = GameManager.distance_traveled
	input_detected = false

## Spawns a fuel canister in front of the player for the scavenging tutorial step.
func _spawn_tutorial_fuel():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var collectible_scene = load("res://scenes/collectibles/collectible.tscn")
	if not collectible_scene:
		return

	var fuel = collectible_scene.instantiate()
	fuel.type = Collectible.Type.FUEL
	# Place 120px in front (right) of the player, same Y level
	fuel.position = player.global_position + Vector2(120, 0)

	# Add to the main scene tree so it persists properly
	get_tree().current_scene.add_child(fuel)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Do NOT build UI or activate here — wait for start_tutorial() call
	# This prevents the tutorial from blocking the main menu.

## Called by the game scene (main.tscn or world_manager) to actually start the tutorial.
func start_tutorial():
	if tutorial_already_done:
		is_active = false
		return

	is_active = true
	current_step = 0
	_build_ui()
	_show_step(0)

	# Connect to signals for tracking
	if not SignalsBus.loot_collected.is_connected(_on_loot_collected):
		SignalsBus.loot_collected.connect(_on_loot_collected)
	if not SignalsBus.player_entered_car.is_connected(_on_entered_car):
		SignalsBus.player_entered_car.connect(_on_entered_car)
	if not SignalsBus.car_travel_started.is_connected(_on_car_travel_started):
		SignalsBus.car_travel_started.connect(_on_car_travel_started)
	if not SignalsBus.game_over.is_connected(_on_game_over):
		SignalsBus.game_over.connect(_on_game_over)

func _on_loot_collected(_item: String, _qty: int):
	_has_collected = true

func _on_entered_car():
	_has_entered_car = true

func _on_car_travel_started():
	_drive_start_dist = GameManager.distance_traveled

func _process(delta: float):
	if not is_active:
		return

	# Tick step cooldown
	if step_cooldown > 0.0:
		step_cooldown -= delta

	# Flash the hint label
	flash_timer += delta
	if hint_label and hint_label.text != "":
		hint_label.modulate.a = 0.5 + 0.5 * abs(sin(flash_timer * 2.5))

	# Animate panel subtle breathing
	if panel:
		var breath = 1.0 + sin(flash_timer * 1.8) * 0.003
		panel.scale = Vector2(breath, breath)

	# Don't process conditions or poll state while cooldown is active
	# This prevents tracking flags from being set before the player
	# has even had a chance to read the new step.
	if step_cooldown > 0.0:
		return

	# Guard: if we're already in the middle of advancing (awaiting), bail out.
	# This prevents the await-in-_process bug where multiple parallel
	# _advance_step() calls fire because _process keeps running during await.
	if _is_advancing:
		return

	# Only poll player state AFTER cooldown expires so flags don't
	# accumulate from actions taken before the step was readable.
	_poll_player_state(delta)

	# Check auto-advance timer
	var step_data: Dictionary = steps[current_step]
	if step_data["auto_time"] > 0.0:
		step_timer += delta
		if step_timer >= step_data["auto_time"]:
			_advance_step()
			return

	# Check condition
	if _check_condition(step_data["condition"]):
		# Set guard to prevent re-entrant calls during the await
		_is_advancing = true
		# Small delay so the player sees the checkmark
		await get_tree().create_timer(0.3).timeout
		_is_advancing = false
		if is_active:
			_advance_step()

func _poll_player_state(_delta: float):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Movement detection
	if player.velocity.length() > 10.0:
		_has_moved = true

	# Sprint detection
	if Input.is_key_pressed(KEY_SHIFT) and player.velocity.length() > 200.0:
		_has_sprinted = true

	# Attack detection
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_has_attacked = true

	# Inventory open detection
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.get("inventory_panel"):
		if hud.inventory_panel.visible:
			_has_opened_inv = true

	# Driving distance
	if GameManager.current_state == GameManager.GameState.DRIVING:
		_has_driven = GameManager.distance_traveled - _drive_start_dist

func _unhandled_input(event: InputEvent):
	if not is_active:
		return

	# Block all input during step cooldown or while advancing
	if step_cooldown > 0.0 or _is_advancing:
		return

	var step_data: Dictionary = steps[current_step]

	# "any_key" condition — only accept fresh presses (not held keys)
	if step_data["condition"] == "any_key":
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			input_detected = true
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.is_pressed():
			input_detected = true
			get_viewport().set_input_as_handled()

	# Allow spacebar to skip certain waiting steps
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key = event as InputEventKey
		if key.physical_keycode == KEY_SPACE:
			if step_data["condition"] in ["item_collected"]:
				input_detected = true

func _check_condition(condition: String) -> bool:
	match condition:
		"any_key":
			if input_detected:
				input_detected = false
				return true
		"player_moved":
			return _has_moved
		"player_sprinted":
			return _has_sprinted
		"player_attacked":
			return _has_attacked
		"item_collected":
			if input_detected:
				input_detected = false
				return true
			return _has_collected
		"inventory_opened":
			return _has_opened_inv
		"entered_car":
			return _has_entered_car
		"drove_car":
			return _has_driven > 4.0
		"auto":
			return false  # Handled by auto_time
	return false

func _advance_step():
	current_step += 1
	if current_step >= steps.size():
		_finish_tutorial()
		return
	_show_step(current_step)

func _finish_tutorial():
	is_active = false
	tutorial_already_done = true
	tutorial_completed.emit()

	# Animate out
	if panel:
		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(panel, "modulate:a", 0.0, 0.6)
		tw.tween_property(backdrop, "color:a", 0.0, 0.6)
		tw.set_parallel(false)
		tw.tween_callback(func():
			if is_instance_valid(canvas):
				canvas.queue_free()
			canvas = null
		)

func _skip_tutorial():
	is_active = false
	tutorial_already_done = true
	tutorial_completed.emit()
	if canvas and is_instance_valid(canvas):
		canvas.queue_free()
		canvas = null

func _on_game_over():
	# When the game ends, just hide the tutorial panel if still active
	if is_active:
		_skip_tutorial()

## Resets the tutorial so it shows again (e.g. from a settings menu).
func reset_tutorial():
	tutorial_already_done = false

# ─── UI Construction ───

func _build_ui():
	canvas = CanvasLayer.new()
	canvas.layer = 200  # Above everything
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	# Semi-transparent backdrop (top + bottom strips only, not full screen)
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(backdrop)

	# Main panel — bottom-center
	var anchor = Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.position = Vector2(0, 0)
	canvas.add_child(anchor)

	panel = PanelContainer.new()
	panel.position = Vector2(-300, -220)
	panel.custom_minimum_size = Vector2(600, 190)

	# Panel style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.12, 0.92)
	style.border_color = Color(0.45, 0.55, 0.8, 0.6)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.2, 0.3, 0.6, 0.3)
	style.shadow_size = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	anchor.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Title row (icon + title)
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	vbox.add_child(title_row)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	title_row.add_child(title_label)

	# Body text
	body_label = Label.new()
	body_label.add_theme_font_size_override("font_size", 15)
	body_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size.x = 550
	vbox.add_child(body_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 4
	vbox.add_child(spacer)

	# Bottom row: hint + progress dots + skip
	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	vbox.add_child(bottom_row)

	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(hint_label)

	# Progress dots
	progress_container = HBoxContainer.new()
	progress_container.add_theme_constant_override("separation", 5)
	progress_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	bottom_row.add_child(progress_container)

	dots.clear()
	for i in range(steps.size()):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = Color(0.3, 0.35, 0.5, 0.5)
		progress_container.add_child(dot)
		dots.append(dot)

	# Skip button
	skip_button = Button.new()
	skip_button.text = "SKIP ✕"
	skip_button.add_theme_font_size_override("font_size", 12)
	skip_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

	var skip_style_normal = StyleBoxFlat.new()
	skip_style_normal.bg_color = Color(0.15, 0.15, 0.2, 0.7)
	skip_style_normal.corner_radius_top_left = 6
	skip_style_normal.corner_radius_top_right = 6
	skip_style_normal.corner_radius_bottom_left = 6
	skip_style_normal.corner_radius_bottom_right = 6
	skip_style_normal.content_margin_left = 10
	skip_style_normal.content_margin_right = 10
	skip_style_normal.content_margin_top = 4
	skip_style_normal.content_margin_bottom = 4
	skip_button.add_theme_stylebox_override("normal", skip_style_normal)

	var skip_style_hover = skip_style_normal.duplicate()
	skip_style_hover.bg_color = Color(0.25, 0.15, 0.15, 0.8)
	skip_button.add_theme_stylebox_override("hover", skip_style_hover)

	skip_button.pressed.connect(_skip_tutorial)
	bottom_row.add_child(skip_button)

func _show_step(index: int):
	if index >= steps.size():
		return

	var step: Dictionary = steps[index]
	step_timer = 0.0
	step_cooldown = STEP_COOLDOWN_DURATION  # Block input briefly on new step
	_is_advancing = false  # Reset guard flag

	# Reset ALL tracking flags so prior-step actions don't instantly satisfy this step
	_reset_tracking_flags()

	# Spawn a fuel canister in front of the player for the scavenging step
	if step["condition"] == "item_collected":
		_spawn_tutorial_fuel()

	# Update content
	title_label.text = "%s  %s" % [step["icon"], step["title"]]
	body_label.text = step["body"]
	hint_label.text = step["hint"]

	# Update progress dots
	for i in range(dots.size()):
		if i < index:
			dots[i].color = Color(0.4, 0.7, 1.0, 0.9)  # Completed — bright blue
		elif i == index:
			dots[i].color = Color(0.9, 0.85, 0.3, 1.0)  # Current — gold
		else:
			dots[i].color = Color(0.3, 0.35, 0.5, 0.4)  # Upcoming — dim

	# Subtle backdrop for first step
	if index == 0:
		backdrop.color = Color(0, 0, 0, 0.35)
	elif index == steps.size() - 1:
		backdrop.color = Color(0, 0, 0, 0.0)
	else:
		var bg_tween = create_tween()
		bg_tween.tween_property(backdrop, "color:a", 0.0, 0.3)

	# Slide-in animation
	if panel:
		panel.modulate.a = 0.0
		panel.position.y = -200
		var slide_tween = create_tween()
		slide_tween.set_ease(Tween.EASE_OUT)
		slide_tween.set_trans(Tween.TRANS_BACK)
		slide_tween.set_parallel(true)
		slide_tween.tween_property(panel, "modulate:a", 1.0, 0.4)
		slide_tween.tween_property(panel, "position:y", -220, 0.5)
