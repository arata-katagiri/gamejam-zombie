extends Node

enum GameState { EXPLORING, DRIVING, PAUSED, GAME_OVER }

var current_state: GameState = GameState.EXPLORING
var distance_traveled: float = 0.0
var difficulty_level: int = 1
var zones_cleared: int = 0

# Biome tracking
var current_biome: BiomeData.BiomeType = BiomeData.BiomeType.SUBURBAN
var zones_in_current_biome: int = 0
var biomes_visited: Array[BiomeData.BiomeType] = []

# World seed for reproducible runs (set to 0 for random)
var world_seed: int = 0
var world_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Day & Night Cycle
var time_of_day: float = 8.0 # Starts at 8 AM (0.0 to 24.0)
var time_multiplier: float = 3.0 # real time minutes -> game hours logic
var is_night: bool = false
var has_flashlight: bool = false # Tracks if player found a flashlight

# Fuel System
var car_fuel: float = 100.0
var max_fuel: float = 100.0

# Weapons and Ammo
var has_melee: bool = false
var has_gun: bool = false
var pistol_ammo: int = 0

# Survival Metrics
var player_thirst: float = 100.0
var max_thirst: float = 100.0

# Backpack Inventory
var max_inventory_capacity: int = 10
var player_inventory: Array[String] = []

func get_total_items() -> int:
	return player_inventory.size()

func reset_run():
	current_state = GameState.EXPLORING
	distance_traveled = 0.0
	difficulty_level = 1
	zones_cleared = 0
	
	current_biome = BiomeData.BiomeType.SUBURBAN
	zones_in_current_biome = 0
	biomes_visited.clear()
	
	time_of_day = 8.0
	is_night = false
	has_flashlight = false
	
	car_fuel = max_fuel
	
	has_melee = false
	has_gun = false
	pistol_ammo = 0
	
	player_thirst = max_thirst
	player_inventory.clear()

func _ready():
	SignalsBus.zone_cleared.connect(_on_zone_cleared)
	SignalsBus.car_travel_started.connect(_on_car_travel_started)
	SignalsBus.car_travel_ended.connect(_on_car_travel_ended)
	SignalsBus.player_died.connect(_on_player_died)
	_init_world_seed()

func _init_world_seed():
	if world_seed == 0:
		world_rng.randomize()
		world_seed = world_rng.seed
	else:
		world_rng.seed = world_seed

func _on_zone_cleared():
	zones_cleared += 1
	if zones_cleared % 3 == 0:
		difficulty_level += 1

func _on_car_travel_started():
	current_state = GameState.DRIVING

func _on_car_travel_ended():
	current_state = GameState.EXPLORING

func _on_player_died():
	current_state = GameState.GAME_OVER
	SignalsBus.game_over.emit()

func _process(delta: float):
	if current_state != GameState.PAUSED:
		time_of_day += (delta * time_multiplier) / 60.0
		if time_of_day >= 24.0:
			time_of_day -= 24.0
		is_night = (time_of_day > 19.0 or time_of_day < 6.0)

func get_zombie_count_for_zone() -> int:
	var base: int = 2 + difficulty_level
	var biome_mod: float = BiomeData.get_zombie_count_modifier(current_biome)
	var time_mod: float = 2.0 if is_night else 1.0
	return max(1, int(base * biome_mod * time_mod))

func get_zombie_health_modifier() -> float:
	return 1.0 + (difficulty_level - 1) * 0.2

func get_zombie_speed_modifier() -> float:
	var time_mod: float = 1.35 if is_night else 1.0
	return BiomeData.get_zombie_speed_modifier(current_biome) * time_mod

func get_loot_modifier() -> float:
	return BiomeData.get_loot_modifier(current_biome)

## Called by WorldManager when it's time to consider a biome change.
func should_change_biome() -> bool:
	zones_in_current_biome += 1
	# Change biome every 1-2 zones for much faster generation cycle
	var threshold: int = world_rng.randi_range(1, 2)
	return zones_in_current_biome >= threshold

## Transitions to a new biome, avoiding the current one.
func advance_biome():
	var all_biomes: Array[BiomeData.BiomeType] = [
		BiomeData.BiomeType.SUBURBAN,
		BiomeData.BiomeType.DESERT,
		BiomeData.BiomeType.FOREST,
		BiomeData.BiomeType.URBAN,
		BiomeData.BiomeType.URBAN,
		BiomeData.BiomeType.URBAN,
		BiomeData.BiomeType.URBAN,
		BiomeData.BiomeType.URBAN,
		BiomeData.BiomeType.WASTELAND,
	]
	# Remove current to avoid repeats
	var candidates: Array[BiomeData.BiomeType] = []
	for b: BiomeData.BiomeType in all_biomes:
		if b != current_biome:
			candidates.append(b)

	var idx: int = world_rng.randi_range(0, candidates.size() - 1)
	current_biome = candidates[idx]
	zones_in_current_biome = 0

	if current_biome not in biomes_visited:
		biomes_visited.append(current_biome)

	SignalsBus.biome_changed.emit(BiomeData.get_biome_name(current_biome))

## Returns the current biome's color palette.
func get_current_palette() -> Dictionary:
	return BiomeData.get_palette(current_biome)
