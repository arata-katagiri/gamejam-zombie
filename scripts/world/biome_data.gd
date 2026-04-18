extends RefCounted
class_name BiomeData

## Defines visual palettes and spawn rules for each biome.

enum BiomeType { SUBURBAN, DESERT, FOREST, URBAN, WASTELAND }

# --- Color Palettes ---
# Each biome returns a dictionary of colors used by zones to render themselves.

static func get_palette(biome: BiomeType) -> Dictionary:
	match biome:
		BiomeType.SUBURBAN:
			return {
				"ground": Color(0.2, 0.22, 0.18),
				"ground_alt": Color(0.18, 0.2, 0.16),
				"road": Color(0.25, 0.25, 0.25),
				"road_line": Color(0.6, 0.55, 0.2),
				"building_wall": Color(0.35, 0.35, 0.32),
				"building_wall_alt": Color(0.3, 0.3, 0.28),
				"building_roof": Color(0.3, 0.25, 0.2),
				"window": Color(0.3, 0.35, 0.4, 0.5),
				"door": Color(0.25, 0.2, 0.15),
				"prop_primary": Color(0.25, 0.3, 0.22),
				"prop_secondary": Color(0.3, 0.28, 0.25),
				"sky_tint": Color(0.4, 0.45, 0.5),
			}
		BiomeType.DESERT:
			return {
				"ground": Color(0.45, 0.4, 0.3),
				"ground_alt": Color(0.4, 0.35, 0.25),
				"road": Color(0.3, 0.28, 0.25),
				"road_line": Color(0.5, 0.45, 0.2),
				"building_wall": Color(0.45, 0.4, 0.35),
				"building_wall_alt": Color(0.4, 0.35, 0.3),
				"building_roof": Color(0.35, 0.3, 0.25),
				"window": Color(0.25, 0.3, 0.35, 0.5),
				"door": Color(0.3, 0.25, 0.2),
				"prop_primary": Color(0.35, 0.4, 0.25),
				"prop_secondary": Color(0.4, 0.35, 0.25),
				"sky_tint": Color(0.5, 0.45, 0.35),
			}
		BiomeType.FOREST:
			return {
				"ground": Color(0.15, 0.2, 0.12),
				"ground_alt": Color(0.12, 0.15, 0.1),
				"road": Color(0.25, 0.25, 0.22),
				"road_line": Color(0.45, 0.4, 0.2),
				"building_wall": Color(0.3, 0.25, 0.2),
				"building_wall_alt": Color(0.25, 0.2, 0.15),
				"building_roof": Color(0.2, 0.15, 0.1),
				"window": Color(0.25, 0.3, 0.35, 0.5),
				"door": Color(0.2, 0.15, 0.1),
				"prop_primary": Color(0.15, 0.25, 0.12),
				"prop_secondary": Color(0.25, 0.2, 0.15),
				"sky_tint": Color(0.3, 0.35, 0.3),
			}
		BiomeType.URBAN:
			return {
				"ground": Color(0.18, 0.18, 0.18),
				"ground_alt": Color(0.15, 0.15, 0.15),
				"road": Color(0.2, 0.2, 0.2),
				"road_line": Color(0.5, 0.5, 0.45),
				"building_wall": Color(0.3, 0.3, 0.32),
				"building_wall_alt": Color(0.25, 0.25, 0.28),
				"building_roof": Color(0.25, 0.25, 0.25),
				"window": Color(0.3, 0.35, 0.4, 0.6),
				"door": Color(0.2, 0.2, 0.22),
				"prop_primary": Color(0.35, 0.35, 0.35),
				"prop_secondary": Color(0.25, 0.25, 0.25),
				"sky_tint": Color(0.3, 0.3, 0.35),
			}
		BiomeType.WASTELAND:
			return {
				"ground": Color(0.25, 0.22, 0.18),
				"ground_alt": Color(0.2, 0.18, 0.15),
				"road": Color(0.2, 0.18, 0.15),
				"road_line": Color(0.4, 0.35, 0.2),
				"building_wall": Color(0.3, 0.25, 0.22),
				"building_wall_alt": Color(0.25, 0.2, 0.18),
				"building_roof": Color(0.2, 0.15, 0.12),
				"window": Color(0.25, 0.25, 0.28, 0.4),
				"door": Color(0.18, 0.15, 0.12),
				"prop_primary": Color(0.3, 0.25, 0.2),
				"prop_secondary": Color(0.2, 0.18, 0.15),
				"sky_tint": Color(0.35, 0.28, 0.22),
			}
	# Fallback
	return get_palette(BiomeType.SUBURBAN)


# --- Zone Weights per Biome ---
# Returns a dictionary of zone type string → spawn weight.
# Higher weight = more likely to appear.

static func get_zone_weights(biome: BiomeType) -> Dictionary:
	match biome:
		BiomeType.SUBURBAN:
			return {
				"house": 40,
				"gas_station": 15,
				"supermarket": 20,
				"hospital": 10,
				"camp": 15,
			}
		BiomeType.DESERT:
			return {
				"house": 20,
				"gas_station": 25,
				"camp": 30,
				"supermarket": 10,
				"hospital": 5,
				"bridge": 10,
			}
		BiomeType.FOREST:
			return {
				"house": 30,
				"camp": 35,
				"hospital": 5,
				"bridge": 15,
				"supermarket": 5,
				"gas_station": 10,
			}
		BiomeType.URBAN:
			return {
				"house": 15,
				"supermarket": 30,
				"hospital": 20,
				"gas_station": 15,
				"camp": 5,
				"bridge": 15,
			}
		BiomeType.WASTELAND:
			return {
				"house": 15,
				"camp": 35,
				"gas_station": 10,
				"bridge": 20,
				"hospital": 10,
				"supermarket": 10,
			}
	return get_zone_weights(BiomeType.SUBURBAN)


# --- Zombie Modifiers per Biome ---

static func get_zombie_count_modifier(biome: BiomeType) -> float:
	match biome:
		BiomeType.SUBURBAN: return 1.0
		BiomeType.DESERT: return 0.7
		BiomeType.FOREST: return 1.2
		BiomeType.URBAN: return 1.5
		BiomeType.WASTELAND: return 1.3
	return 1.0

static func get_zombie_speed_modifier(biome: BiomeType) -> float:
	match biome:
		BiomeType.SUBURBAN: return 1.0
		BiomeType.DESERT: return 0.9
		BiomeType.FOREST: return 0.85
		BiomeType.URBAN: return 1.1
		BiomeType.WASTELAND: return 1.2
	return 1.0


# --- Loot Modifiers per Biome ---

static func get_loot_modifier(biome: BiomeType) -> float:
	match biome:
		BiomeType.SUBURBAN: return 1.0
		BiomeType.DESERT: return 0.6
		BiomeType.FOREST: return 0.8
		BiomeType.URBAN: return 1.3
		BiomeType.WASTELAND: return 0.5
	return 1.0


# --- Road Event Weights per Biome ---
# Returns weights for different road events during car travel.

static func get_road_event_weights(biome: BiomeType) -> Dictionary:
	match biome:
		BiomeType.SUBURBAN:
			return {"nothing": 50, "abandoned_vehicle": 20, "roadblock": 15, "ambush": 15}
		BiomeType.DESERT:
			return {"nothing": 40, "abandoned_vehicle": 15, "roadblock": 10, "ambush": 15, "sandstorm": 20}
		BiomeType.FOREST:
			return {"nothing": 35, "abandoned_vehicle": 10, "roadblock": 20, "ambush": 25, "fallen_tree": 10}
		BiomeType.URBAN:
			return {"nothing": 25, "abandoned_vehicle": 25, "roadblock": 25, "ambush": 25}
		BiomeType.WASTELAND:
			return {"nothing": 20, "abandoned_vehicle": 15, "roadblock": 20, "ambush": 30, "toxic_puddle": 15}
	return {"nothing": 60, "roadblock": 20, "ambush": 20}


# --- Prop Generation Rules per Biome ---
# Returns arrays of prop definitions that road/zone generators can place randomly.

static func get_road_prop_pool(biome: BiomeType) -> Array[Dictionary]:
	match biome:
		BiomeType.SUBURBAN:
			return [
				{"type": "tree", "color": Color(0.2, 0.5, 0.15), "size": Vector2(18, 40), "weight": 40},
				{"type": "bush", "color": Color(0.25, 0.45, 0.18), "size": Vector2(22, 14), "weight": 30},
				{"type": "mailbox", "color": Color(0.3, 0.3, 0.7), "size": Vector2(8, 16), "weight": 15},
				{"type": "fence", "color": Color(0.6, 0.55, 0.4), "size": Vector2(60, 8), "weight": 15},
			]
		BiomeType.DESERT:
			return [
				{"type": "cactus", "color": Color(0.35, 0.55, 0.25), "size": Vector2(12, 35), "weight": 40},
				{"type": "rock", "color": Color(0.6, 0.5, 0.35), "size": Vector2(25, 15), "weight": 35},
				{"type": "skull", "color": Color(0.85, 0.8, 0.7), "size": Vector2(10, 8), "weight": 10},
				{"type": "tumbleweed", "color": Color(0.6, 0.5, 0.3), "size": Vector2(16, 14), "weight": 15},
			]
		BiomeType.FOREST:
			return [
				{"type": "tree_tall", "color": Color(0.15, 0.35, 0.1), "size": Vector2(22, 55), "weight": 45},
				{"type": "stump", "color": Color(0.4, 0.28, 0.15), "size": Vector2(16, 10), "weight": 20},
				{"type": "mushroom", "color": Color(0.7, 0.25, 0.2), "size": Vector2(10, 12), "weight": 15},
				{"type": "log", "color": Color(0.45, 0.3, 0.15), "size": Vector2(50, 10), "weight": 20},
			]
		BiomeType.URBAN:
			return [
				{"type": "streetlight", "color": Color(0.5, 0.5, 0.5), "size": Vector2(6, 45), "weight": 30},
				{"type": "dumpster", "color": Color(0.3, 0.4, 0.3), "size": Vector2(28, 18), "weight": 25},
				{"type": "barrier", "color": Color(0.8, 0.4, 0.1), "size": Vector2(40, 10), "weight": 25},
				{"type": "wreck", "color": Color(0.4, 0.35, 0.3), "size": Vector2(45, 20), "weight": 20},
			]
		BiomeType.WASTELAND:
			return [
				{"type": "rubble", "color": Color(0.4, 0.32, 0.22), "size": Vector2(30, 12), "weight": 35},
				{"type": "barrel", "color": Color(0.5, 0.4, 0.15), "size": Vector2(12, 18), "weight": 25},
				{"type": "crater", "color": Color(0.2, 0.18, 0.12), "size": Vector2(35, 8), "weight": 20},
				{"type": "dead_tree", "color": Color(0.35, 0.25, 0.15), "size": Vector2(14, 40), "weight": 20},
			]
	return []


# --- Biome Display Name ---

static func get_biome_name(biome: BiomeType) -> String:
	match biome:
		BiomeType.SUBURBAN: return "Suburbs"
		BiomeType.DESERT: return "Desert"
		BiomeType.FOREST: return "Forest"
		BiomeType.URBAN: return "City"
		BiomeType.WASTELAND: return "Wasteland"
	return "Unknown"
