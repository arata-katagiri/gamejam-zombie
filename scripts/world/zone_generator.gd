extends RefCounted
class_name ZoneGenerator

## Utility class for procedurally generating zone layouts.
## Used by zone scripts to randomize building positions, props, and spawn points.

# --- Building Generation ---

## Generates a random set of building definitions for a zone.
## Each building is a Dictionary with: pos, size, windows, has_door, door_side
static func generate_buildings(count_range: Vector2i, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	var count: int = rng.randi_range(count_range.x, count_range.y)

	# Define placement regions to avoid overlap
	var regions: Array[Rect2] = _get_building_regions(count)

	for i: int in count:
		if i >= regions.size():
			break
		var region: Rect2 = regions[i]
		var bld_w: float = rng.randf_range(region.size.x * 0.4, region.size.x * 0.95)
		var bld_h: float = rng.randf_range(region.size.y * 0.3, region.size.y * 0.9)
		
		# Organic overlap and offsets
		var x_offset = rng.randf_range(-15.0, 15.0)
		var y_offset = rng.randf_range(-15.0, 15.0)
		var bld_x: float = region.position.x + rng.randf_range(0, region.size.x - bld_w) + x_offset
		var bld_y: float = region.position.y + rng.randf_range(0, region.size.y - bld_h) + y_offset

		var window_count: int = rng.randi_range(1, max(1, int(bld_w / 45)))
		var has_door: bool = true
		var door_side: String = "front" if rng.randf() < 0.7 else "side"

		buildings.append({
			"pos": Vector2(bld_x, bld_y),
			"size": Vector2(bld_w, bld_h),
			"window_count": window_count,
			"has_door": has_door,
			"door_side": door_side,
		})
	return buildings


## Returns non-overlapping regions where buildings can be placed.
static func _get_building_regions(count: int) -> Array[Rect2]:
	var regions: Array[Rect2] = []
	# Top half and bottom half, split into columns
	var cols: int = max(1, ceili(count / 2.0))
	var col_width: float = 1280.0 / cols

	for i: int in count:
		var row: int = 0 if i < ceili(count / 2.0) else 1
		var col: int = i if row == 0 else i - ceili(count / 2.0)
		var x: float = col * col_width + 10.0
		var y: float = 20.0 if row == 0 else 460.0
		var w: float = col_width - 20.0
		var h: float = 220.0

		regions.append(Rect2(x, y, w, h))
	return regions


# --- Prop Generation ---

## Places props randomly along the road edges and open areas.
## Returns array of Dictionaries with: pos, size, color, type
static func generate_props(prop_pool: Array[Dictionary], count_range: Vector2i, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	if prop_pool.is_empty():
		return props

	var count: int = rng.randi_range(count_range.x, count_range.y)

	for _i: int in count:
		var prop_def: Dictionary = _weighted_pick(prop_pool, rng)
		# Place on either top grass (y: 20-260) or bottom grass (y: 460-680)
		var top: bool = rng.randf() < 0.5
		var pos_x: float = rng.randf_range(20.0, 1260.0)
		var pos_y: float
		if top:
			pos_y = rng.randf_range(20.0, 260.0)
		else:
			pos_y = rng.randf_range(460.0, 680.0)

		# Slight size variance
		var scale_factor: float = rng.randf_range(0.7, 1.3)
		var s: Vector2 = prop_def["size"] as Vector2
		var final_size := Vector2(s.x * scale_factor, s.y * scale_factor)

		props.append({
			"pos": Vector2(pos_x, pos_y),
			"size": final_size,
			"color": prop_def["color"] as Color,
			"type": prop_def["type"] as String,
		})
	return props


# --- Spawn Point Generation ---

## Generates random spawn positions within a zone, avoiding road area (y: 280-440).
static func generate_spawn_points(count: int, rng: RandomNumberGenerator, margin: float = 40.0) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for _i: int in count:
		var pos_x: float = rng.randf_range(margin, 1280.0 - margin)
		var pos_y: float
		if rng.randf() < 0.5:
			pos_y = rng.randf_range(margin, 260.0)
		else:
			pos_y = rng.randf_range(460.0, 720.0 - margin)
		points.append(Vector2(pos_x, pos_y))
	return points


# --- Item Spawn Points (can be inside buildings or near them) ---

static func generate_item_points(buildings: Array[Dictionary], extra_count: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	# One item per building
	for bld: Dictionary in buildings:
		var pos: Vector2 = bld["pos"] as Vector2
		var sz: Vector2 = bld["size"] as Vector2
		points.append(Vector2(
			pos.x + rng.randf_range(10, sz.x - 10),
			pos.y + rng.randf_range(10, sz.y - 10),
		))
	# Extra items in the open
	for _i: int in extra_count:
		points.append(Vector2(
			rng.randf_range(40, 1240),
			rng.randf_range(20, 260) if rng.randf() < 0.5 else rng.randf_range(460, 680),
		))
	return points


# --- Weighted Random Pick ---

static func _weighted_pick(pool: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var total_weight: float = 0.0
	for entry: Dictionary in pool:
		total_weight += entry.get("weight", 1.0) as float
	var roll: float = rng.randf() * total_weight
	var cumulative: float = 0.0
	for entry: Dictionary in pool:
		cumulative += entry.get("weight", 1.0) as float
		if roll <= cumulative:
			return entry
	return pool[pool.size() - 1]


## Picks a zone type string from a weighted dictionary.
static func pick_weighted_zone(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for key: String in weights:
		total += weights[key] as float
	var roll: float = rng.randf() * total
	var cumulative: float = 0.0
	for key: String in weights:
		cumulative += weights[key] as float
		if roll <= cumulative:
			return key
	return weights.keys()[0] as String
