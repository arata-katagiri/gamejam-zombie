extends Node2D
class_name ZoneBase

@export var zone_name: String = "Zone"
var is_cleared: bool = false
var palette: Dictionary = {}
var zone_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func setup(_difficulty: int):
	_load_floor_and_roof_textures()
	palette = GameManager.get_current_palette()
	zone_rng.seed = GameManager.world_rng.randi()
	
	# Add huge city buildings as borders
	if house_textures.size() > 0:
		for x in range(0, 1280, 400):
			var bld_top = CityBuilding.new()
			bld_top.position = Vector2(x, -60)
			add_child(bld_top)
			bld_top.setup(house_textures, Vector2(400, 60))
			
			var bld_bot = CityBuilding.new()
			bld_bot.position = Vector2(x, 720)
			add_child(bld_bot)
			bld_bot.setup(house_textures, Vector2(400, 60))
	else:
		_add_static_box(Rect2(0, -40, 1280, 40))
		_add_static_box(Rect2(0, 720, 1280, 40))
	
	queue_redraw()

func mark_cleared():
	is_cleared = true
	SignalsBus.zone_cleared.emit()

## Draw the base ground and road that all zones share.
func _draw_base_ground():
	var ground_color: Color = palette.get("ground", Color(0.25, 0.42, 0.2)) as Color
	var ground_alt: Color = palette.get("ground_alt", Color(0.22, 0.38, 0.18)) as Color
	var road_color: Color = palette.get("road", Color(0.3, 0.3, 0.3)) as Color
	var line_color: Color = palette.get("road_line", Color(0.9, 0.85, 0.2)) as Color

	# Ground base
	draw_rect(Rect2(0, 0, 1280, 720), ground_color)
	
	# Detailed ground variation (realistic scattered patches)
	for _i: int in 40:
		var patch_x: float = zone_rng.randf_range(0, 1260)
		var patch_y: float = zone_rng.randf_range(0, 700)
		var patch_size: float = zone_rng.randf_range(10, 40)
		draw_circle(Vector2(patch_x, patch_y), patch_size, ground_alt.darkened(zone_rng.randf_range(0.0, 0.1)))

	# Road Base
	draw_rect(Rect2(0, 280, 1280, 160), road_color)
	# Road dirt margins
	draw_rect(Rect2(0, 275, 1280, 5), road_color.darkened(0.2))
	draw_rect(Rect2(0, 440, 1280, 5), road_color.darkened(0.2))
	
	# Road edge lines
	draw_rect(Rect2(0, 282, 1280, 2), line_color.darkened(0.3))
	draw_rect(Rect2(0, 436, 1280, 2), line_color.darkened(0.3))
	
	# Center dashed line
	var dash_offset: int = zone_rng.randi_range(0, 30)
	for i: int in range(dash_offset, 1280, 80):
		draw_rect(Rect2(i, 355, 40, 6), line_color)

## Draw a single prop based on its type.
func _draw_prop(prop: Dictionary):
	var pos: Vector2 = prop["pos"] as Vector2
	var sz: Vector2 = prop["size"] as Vector2
	var col: Color = prop["color"] as Color
	var prop_type: String = prop["type"] as String

	# Draw drop shadow for extreme realism
	if prop_type != "crater":
		draw_rect(Rect2(pos.x + 8, pos.y + 8, sz.x, sz.y), Color(0, 0, 0, 0.35))

	match prop_type:
		"tree", "tree_tall":
			# Detailed top-down tree canopy
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.8, col.darkened(0.2))
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.6, col)
			draw_circle(Vector2(pos.x + sz.x * 0.4, pos.y + sz.y * 0.4), sz.x * 0.3, col.lightened(0.1))
		"dead_tree":
			draw_circle(Vector2(pos.x + sz.x*0.5, pos.y + sz.y*0.5), sz.x * 0.4, col)
			draw_rect(Rect2(pos.x, pos.y + sz.y * 0.3, sz.x * 1.5, 4), col)
			draw_rect(Rect2(pos.x + sz.x * 0.3, pos.y, 4, sz.y * 1.2), col)
		"bush", "tumbleweed":
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.5, col.darkened(0.1))
			draw_circle(Vector2(pos.x + sz.x * 0.4, pos.y + sz.y * 0.4), sz.x * 0.3, col)
		"cactus":
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.4, col)
			draw_circle(Vector2(pos.x + sz.x * 0.2, pos.y + sz.y * 0.3), sz.x * 0.2, col)
			draw_circle(Vector2(pos.x + sz.x * 0.8, pos.y + sz.y * 0.7), sz.x * 0.2, col)
		"rock", "rubble":
			var points: PackedVector2Array = PackedVector2Array([
				Vector2(pos.x + sz.x * 0.1, pos.y + sz.y),
				Vector2(pos.x, pos.y + sz.y * 0.4),
				Vector2(pos.x + sz.x * 0.3, pos.y),
				Vector2(pos.x + sz.x * 0.7, pos.y + sz.y * 0.1),
				Vector2(pos.x + sz.x, pos.y + sz.y * 0.5),
				Vector2(pos.x + sz.x * 0.9, pos.y + sz.y),
			])
			draw_colored_polygon(points, col)
			draw_circle(Vector2(pos.x + sz.x * 0.4, pos.y + sz.y * 0.4), sz.x * 0.2, col.lightened(0.1))
		"streetlight":
			draw_rect(Rect2(pos.x, pos.y, 10, 10), col.darkened(0.2))
			draw_circle(Vector2(pos.x + 5, pos.y + 5), 18.0, Color(0.95, 0.9, 0.5, 0.4))
			draw_circle(Vector2(pos.x + 5, pos.y + 5), 6.0, Color(1.0, 1.0, 0.8, 0.8))
		"dumpster":
			draw_rect(Rect2(pos.x, pos.y, sz.x, sz.y), col)
			draw_rect(Rect2(pos.x + 2, pos.y + 2, sz.x - 4, sz.y - 4), col.darkened(0.2))
		"barrier":
			draw_rect(Rect2(pos.x, pos.y, sz.x, sz.y), col)
			for stripe_i: int in range(0, int(sz.x), 12):
				draw_rect(Rect2(pos.x + stripe_i, pos.y, 6, sz.y), col.darkened(0.3))
		"wreck":
			draw_rect(Rect2(pos.x, pos.y, sz.x, sz.y), col)
			draw_rect(Rect2(pos.x + sz.x * 0.2, pos.y + sz.y * 0.2, sz.x * 0.6, sz.y * 0.6), col.darkened(0.4)) # Broken windows area
		"barrel":
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.5, col)
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.4, col.darkened(0.3))
		"crater":
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.5, col)
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.3, col.darkened(0.2))
		"fence":
			draw_rect(Rect2(pos.x, pos.y, sz.x, 4), col)
			for fi: int in range(0, int(sz.x), 15):
				draw_rect(Rect2(pos.x + fi, pos.y - 2, 4, 8), col.lightened(0.2))
		"mailbox":
			draw_rect(Rect2(pos.x, pos.y, sz.x, sz.y), col)
			draw_rect(Rect2(pos.x + 2, pos.y + 2, sz.x - 4, sz.y * 0.5), col.lightened(0.2))
		"skull":
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.4, col)
		"stump":
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.5, col)
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.4, col.lightened(0.1))
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.2, col.lightened(0.2))
		"mushroom":
			draw_circle(Vector2(pos.x + sz.x * 0.5, pos.y + sz.y * 0.5), sz.x * 0.5, col)
			draw_circle(Vector2(pos.x + sz.x * 0.3, pos.y + sz.y * 0.3), sz.x * 0.15, col.lightened(0.4))
		"log":
			draw_rect(Rect2(pos.x, pos.y, sz.x, sz.y), col)
			draw_rect(Rect2(pos.x + 2, pos.y + 2, sz.x - 4, sz.y - 4), col.lightened(0.1))
		_:
			draw_rect(Rect2(pos.x, pos.y, sz.x, sz.y), col)

var house_textures: Array[Texture2D] = []
var roof_textures: Array[Texture2D] = []
var wall_textures: Array[Texture2D] = []
var floor_textures: Array[Texture2D] = []
var furniture_textures: Dictionary = {}

func _ready():
	_load_custom_textures()

func _load_floor_and_roof_textures():
	if floor_textures.size() > 0: return
	
	# Load Roofs dynamically
	var dir_roofs = DirAccess.open("res://Tiles/Roofs/")
	if dir_roofs:
		dir_roofs.list_dir_begin()
		var fn = dir_roofs.get_next()
		while fn != "":
			if fn.ends_with(".png") or fn.ends_with(".png.import"):
				var t = load("res://Tiles/Roofs/" + fn.replace(".import", ""))
				if t and t not in roof_textures: roof_textures.append(t)
			fn = dir_roofs.get_next()
			
	# Load Floors dynamically
	var dir_floors = DirAccess.open("res://Tiles/Floors/")
	if dir_floors:
		dir_floors.list_dir_begin()
		var fn = dir_floors.get_next()
		while fn != "":
			if fn.ends_with(".png") or fn.ends_with(".png.import"):
				var t = load("res://Tiles/Floors/" + fn.replace(".import", ""))
				if t and t not in floor_textures: floor_textures.append(t)
			fn = dir_floors.get_next()

func _load_custom_textures():
	if house_textures.size() > 0: return
	# Load Houses
	var dir1 = DirAccess.open("res://Objects/PNG/")
	if dir1:
		dir1.list_dir_begin()
		var fn = dir1.get_next()
		while fn != "":
			if fn.begins_with("objects_house_") and (fn.ends_with(".png") or fn.ends_with(".png.import")):
				var t = load("res://Objects/PNG/" + fn.replace(".import", ""))
				if t and t not in house_textures: house_textures.append(t)
			fn = dir1.get_next()
			
	# Load Roofs
	var dir2 = DirAccess.open("res://Tiles/PNG/Roof/")
	if dir2:
		dir2.list_dir_begin()
		var fn = dir2.get_next()
		while fn != "":
			if fn.begins_with("roof_") and (fn.ends_with(".png") or fn.ends_with(".png.import")):
				var t = load("res://Tiles/PNG/Roof/" + fn.replace(".import", ""))
				if t and t not in roof_textures: roof_textures.append(t)
			fn = dir2.get_next()
			
	# Load Walls
	var dir3 = DirAccess.open("res://Tiles/PNG/Walls/")
	if dir3:
		dir3.list_dir_begin()
		var fn = dir3.get_next()
		while fn != "":
			if fn.begins_with("walls_") and (fn.ends_with(".png") or fn.ends_with(".png.import")):
				var t = load("res://Tiles/PNG/Walls/" + fn.replace(".import", ""))
				if t and t not in wall_textures: wall_textures.append(t)
			fn = dir3.get_next()

func _load_furniture_textures():
	if furniture_textures.size() > 0: return
	furniture_textures = {"sofa": [], "armchair": [], "plant": [], "bed": [], "big_bed": [], "closet": []}
	
	# Load sofas and armchairs
	var dir_sofa = DirAccess.open("res://Objects/sofa/")
	if dir_sofa:
		dir_sofa.list_dir_begin()
		var fn = dir_sofa.get_next()
		while fn != "":
			if fn.ends_with(".png") or fn.ends_with(".png.import"):
				var clean = fn.replace(".import", "")
				var t = load("res://Objects/sofa/" + clean)
				if t:
					var key = "armchair" if clean.begins_with("armchair") else "sofa"
					if t not in furniture_textures[key]:
						furniture_textures[key].append(t)
			fn = dir_sofa.get_next()
	
	# Load plants
	var dir_plants = DirAccess.open("res://Objects/plants/")
	if dir_plants:
		dir_plants.list_dir_begin()
		var fn = dir_plants.get_next()
		while fn != "":
			if fn.ends_with(".png") or fn.ends_with(".png.import"):
				var t = load("res://Objects/plants/" + fn.replace(".import", ""))
				if t and t not in furniture_textures["plant"]:
					furniture_textures["plant"].append(t)
			fn = dir_plants.get_next()
	
	# Load beds
	var dir_beds = DirAccess.open("res://Objects/beds/")
	if dir_beds:
		dir_beds.list_dir_begin()
		var fn = dir_beds.get_next()
		while fn != "":
			if fn.ends_with(".png") or fn.ends_with(".png.import"):
				var clean = fn.replace(".import", "")
				var t = load("res://Objects/beds/" + clean)
				if t:
					var key = "big_bed" if clean.begins_with("big_bed") else "bed"
					if t not in furniture_textures[key]:
						furniture_textures[key].append(t)
			fn = dir_beds.get_next()
	
	# Load closets
	var dir_closets = DirAccess.open("res://Objects/closets/")
	if dir_closets:
		dir_closets.list_dir_begin()
		var fn = dir_closets.get_next()
		while fn != "":
			if fn.ends_with(".png") or fn.ends_with(".png.import"):
				var t = load("res://Objects/closets/" + fn.replace(".import", ""))
				if t and t not in furniture_textures["closet"]:
					furniture_textures["closet"].append(t)
			fn = dir_closets.get_next()

func _draw_floor_area(rect: Rect2):
	if floor_textures.size() > 0:
		var tex_idx = abs(int(rect.position.x * 123 + rect.position.y)) % floor_textures.size()
		var tex = floor_textures[tex_idx]
		var tw = tex.get_width()
		var th = tex.get_height()
		if tw > 0 and th > 0:
			var cx: float = rect.position.x
			while cx < rect.position.x + rect.size.x:
				var cy: float = rect.position.y
				var draw_w: float = min(tw, rect.position.x + rect.size.x - cx)
				while cy < rect.position.y + rect.size.y:
					var draw_h: float = min(th, rect.position.y + rect.size.y - cy)
					draw_texture_rect_region(tex, Rect2(cx, cy, draw_w, draw_h), Rect2(0, 0, draw_w, draw_h))
					cy += draw_h
				cx += draw_w

## Draw a realistic top-down building showing floors and thick solid walls.
func _draw_building(bld: Dictionary, wall_color: Color, win_color: Color, door_color: Color):
	var pos: Vector2 = bld["pos"] as Vector2
	var sz: Vector2 = bld["size"] as Vector2
	var has_door: bool = bld["has_door"] as bool
	var door_side: String = bld.get("door_side", "front") as String
	
	var wall_thickness: float = 8.0
	
	# Drop Shadow for extreme realism
	draw_rect(Rect2(pos.x + 12, pos.y + 12, sz.x, sz.y), Color(0, 0, 0, 0.45))
	
	# (The dynamic roof is now spawned by _create_building_roofs in setup())

	# Interior Floor
	_draw_floor_area(Rect2(pos.x, pos.y, sz.x, sz.y))

	# Draw thick walls (Top, Left, Right, Bottom)
	# ... fallback manual thick walls ...
	draw_rect(Rect2(pos.x, pos.y, sz.x, wall_thickness), wall_color) # Top
	draw_rect(Rect2(pos.x, pos.y, wall_thickness, sz.y), wall_color) # Left
	draw_rect(Rect2(pos.x + sz.x - wall_thickness, pos.y, wall_thickness, sz.y), wall_color) # Right
	draw_rect(Rect2(pos.x, pos.y + sz.y - wall_thickness, sz.x, wall_thickness), wall_color)
	
	var door_w: float = 60.0
	if has_door:
		# Carve out the door from the wall and draw the open door panel
		if door_side == "front":
			var gap_x: float = pos.x + sz.x * 0.5 - door_w * 0.5
			_draw_floor_area(Rect2(gap_x, pos.y + sz.y - wall_thickness, door_w, wall_thickness))
			
			# Door swung fully open (180 degrees) flat against the exterior wall
			draw_rect(Rect2(gap_x - door_w, pos.y + sz.y, door_w, 12), door_color)
		else:
			var gap_y: float = pos.y + sz.y * 0.5 - door_w * 0.5
			var gap_x: float = pos.x + sz.x - wall_thickness
			_draw_floor_area(Rect2(gap_x, gap_y, wall_thickness, door_w))
			
			# Door swung fully open (180 degrees) flat against the right exterior wall
			draw_rect(Rect2(gap_x + wall_thickness, gap_y - door_w, 12, door_w), door_color)

func _draw_tiled_texture(tex: Texture2D, rect: Rect2):
	if not tex: return
	var tw = tex.get_width()
	var th = tex.get_height()
	if tw <= 0 or th <= 0: return

	# Draw drop shadow for extreme realism first
	draw_rect(Rect2(rect.position.x + 12, rect.position.y + 12, rect.size.x, rect.size.y), Color(0, 0, 0, 0.45))

	var x: float = rect.position.x
	while x < rect.position.x + rect.size.x:
		var y: float = rect.position.y
		var draw_w: float = min(tw, rect.position.x + rect.size.x - x)
		while y < rect.position.y + rect.size.y:
			var draw_h: float = min(th, rect.position.y + rect.size.y - y)
			draw_texture_rect_region(tex, Rect2(x, y, draw_w, draw_h), Rect2(0, 0, draw_w, draw_h))
			y += draw_h
		x += draw_w

## --- Collision Generation ---

func _create_building_collisions(bld: Dictionary):
	var pos: Vector2 = bld["pos"] as Vector2
	var sz: Vector2 = bld["size"] as Vector2
	var has_door: bool = bld["has_door"] as bool
	var door_side: String = bld.get("door_side", "front") as String
	var wall_thickness: float = 8.0
	
	var static_body := StaticBody2D.new()
	static_body.set_collision_layer(1)
	static_body.set_collision_mask(0)
	var rects_to_collide = []
	
	# Top and Left Wall
	rects_to_collide.append(Rect2(pos.x, pos.y, sz.x, wall_thickness))
	rects_to_collide.append(Rect2(pos.x, pos.y, wall_thickness, sz.y))
	
	# Right Wall Configuration
	if has_door and door_side == "side":
		var door_w: float = 60.0
		var h1: float = sz.y * 0.5 - door_w * 0.5
		rects_to_collide.append(Rect2(pos.x + sz.x - wall_thickness, pos.y, wall_thickness, h1))
		rects_to_collide.append(Rect2(pos.x + sz.x - wall_thickness, pos.y + h1 + door_w, wall_thickness, sz.y - (h1 + door_w)))
	else:
		rects_to_collide.append(Rect2(pos.x + sz.x - wall_thickness, pos.y, wall_thickness, sz.y))
		
	# Bottom Wall Configuration
	if has_door and door_side == "front":
		var door_w: float = 60.0
		var w1: float = sz.x * 0.5 - door_w * 0.5
		rects_to_collide.append(Rect2(pos.x, pos.y + sz.y - wall_thickness, w1, wall_thickness))
		rects_to_collide.append(Rect2(pos.x + w1 + door_w, pos.y + sz.y - wall_thickness, sz.x - (w1 + door_w), wall_thickness))
	else:
		rects_to_collide.append(Rect2(pos.x, pos.y + sz.y - wall_thickness, sz.x, wall_thickness))

	for rect in rects_to_collide:
		var coll = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = rect.size
		coll.shape = shape
		coll.position = rect.position + rect.size * 0.5
		static_body.add_child(coll)
		
	add_child(static_body)

func _spawn_fading_roof(rect: Rect2, tex: Texture2D, is_tiled: bool = false, door_info: Dictionary = {}):
	if not tex: return
	
	var node = Node2D.new()
	node.position = rect.position
	node.z_index = 10 # Obscure the interior initially
	
	var sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	if is_tiled:
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, rect.size.x, rect.size.y)
	else:
		sprite.scale = rect.size / tex.get_size()
	
	var area = Area2D.new()
	area.set_collision_layer(0)
	area.set_collision_mask(2) # Detect player layer
	var coll = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = rect.size
	coll.shape = shape
	coll.position = rect.size * 0.5
	area.add_child(coll)
	
	area.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player"):
			var tween = node.create_tween()
			tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	)
	area.body_exited.connect(func(body: Node2D):
		if body.is_in_group("player"):
			var tween = node.create_tween()
			tween.tween_property(sprite, "modulate:a", 1.0, 0.25)
	)
	
	var drop_shadow = ColorRect.new()
	drop_shadow.color = Color(0, 0, 0, 0.45)
	drop_shadow.position = Vector2(12, 12)
	drop_shadow.size = rect.size
	drop_shadow.z_index = -1
	node.add_child(drop_shadow)
	
	if door_info.get("has_door", false):
		var shader = Shader.new()
		shader.code = """
shader_type canvas_item;

uniform bool has_door = false;
uniform vec2 door_center;
uniform float door_radius = 50.0;
uniform float fade_min = 0.2;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (has_door) {
		float dist = distance(local_pos, door_center);
		if (dist < door_radius) {
			float alpha_mult = mix(fade_min, 1.0, smoothstep(0.0, 1.0, dist / door_radius));
			c.a *= alpha_mult;
		}
	}
	COLOR = c;
}
"""
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("has_door", true)
		mat.set_shader_parameter("door_radius", 55.0)
		mat.set_shader_parameter("fade_min", 0.0)
		
		var door_side = door_info.get("door_side", "front")
		var door_center = Vector2.ZERO
		
		if door_info.has("custom_local_center"):
			door_center = door_info["custom_local_center"]
		elif door_side == "front":
			door_center = Vector2(rect.size.x * 0.5, rect.size.y)
		elif door_side == "side":
			door_center = Vector2(rect.size.x, rect.size.y * 0.5)
			
		mat.set_shader_parameter("door_center", door_center)
		sprite.material = mat

	node.add_child(sprite)
	node.add_child(area)
	add_child(node)

func _create_building_roof(bld: Dictionary):
	var pos: Vector2 = bld["pos"] as Vector2
	var sz: Vector2 = bld["size"] as Vector2
	
	if roof_textures.size() > 0:
		var tex_idx = abs(int(pos.x * 123 + pos.y)) % roof_textures.size()
		var tex = roof_textures[tex_idx]
		_spawn_fading_roof(Rect2(pos, sz), tex, true, bld)

func _create_prop_collisions(prop_arr: Array[Dictionary]):
	for prop in prop_arr:
		var prop_type: String = prop["type"] as String
		if prop_type in ["rock", "dumpster", "barrier", "wreck", "tree", "tree_tall", "barrel"]:
			var pos: Vector2 = prop["pos"] as Vector2
			var sz: Vector2 = prop["size"] as Vector2
			var static_body := StaticBody2D.new()
			static_body.set_collision_layer(1)
			static_body.set_collision_mask(0)
			
			var coll = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = sz
			coll.shape = shape
			coll.position = pos + sz * 0.5
			static_body.add_child(coll)
			add_child(static_body)

func _spawn_building_furniture(bld: Dictionary, rng: RandomNumberGenerator):
	if furniture_textures.is_empty(): return
	
	var pos: Vector2 = bld["pos"] as Vector2
	var sz: Vector2 = bld["size"] as Vector2
	var has_door: bool = bld.get("has_door", false)
	var door_side: String = bld.get("door_side", "front")
	var wall_t: float = 8.0
	
	# Interior bounds
	var int_pos: Vector2 = pos + Vector2(wall_t, wall_t)
	var int_sz: Vector2 = sz - Vector2(wall_t * 2, wall_t * 2)
	if int_sz.x < 50 or int_sz.y < 50: return
	
	# Available walls (exclude door wall)
	var walls: Array[String] = ["top", "left", "right", "bottom"]
	if has_door:
		if door_side == "front": walls.erase("bottom")
		elif door_side == "side": walls.erase("right")
	
	# Collect all loaded furniture entries
	var all_furn: Array[Dictionary] = []
	for ftype in furniture_textures:
		for tex in furniture_textures[ftype]:
			all_furn.append({"type": ftype, "texture": tex})
	if all_furn.is_empty(): return
	
	var count: int = rng.randi_range(3, mini(4, walls.size()))
	
	for _i in range(count):
		if walls.is_empty(): break
		
		var furn: Dictionary = all_furn[rng.randi() % all_furn.size()]
		var tex: Texture2D = furn["texture"]
		var ftype: String = furn["type"]
		var tex_sz: Vector2 = tex.get_size()
		if tex_sz.x <= 0 or tex_sz.y <= 0: continue
		var aspect: float = tex_sz.y / tex_sz.x
		
		# Target width based on furniture type
		var tw: float
		match ftype:
			"sofa": tw = clampf(int_sz.x * 0.45, 40, 80)
			"armchair": tw = clampf(int_sz.x * 0.22, 20, 40)
			"plant":
				var ps = clampf(minf(int_sz.x, int_sz.y) * 0.2, 15, 28)
				tw = ps
			"bed": tw = clampf(int_sz.x * 0.22, 20, 35)
			"big_bed": tw = clampf(int_sz.x * 0.35, 35, 60)
			"closet": tw = clampf(int_sz.x * 0.2, 18, 35)
			_: tw = 30.0
		var th: float = tw * aspect
		
		# Clamp height to fit interior
		if th > int_sz.y * 0.6:
			th = int_sz.y * 0.6
			tw = th / aspect
		
		# Pick a wall and calculate position
		var wall: String = walls[rng.randi() % walls.size()]
		walls.erase(wall)
		
		var furn_pos: Vector2
		match wall:
			"top":
				furn_pos = Vector2(
					int_pos.x + rng.randf_range(0, maxf(0, int_sz.x - tw)),
					int_pos.y
				)
			"bottom":
				furn_pos = Vector2(
					int_pos.x + rng.randf_range(0, maxf(0, int_sz.x - tw)),
					int_pos.y + int_sz.y - th
				)
			"left":
				furn_pos = Vector2(
					int_pos.x,
					int_pos.y + rng.randf_range(0, maxf(0, int_sz.y - th))
				)
			"right":
				furn_pos = Vector2(
					int_pos.x + int_sz.x - tw,
					int_pos.y + rng.randf_range(0, maxf(0, int_sz.y - th))
				)
		
		# Create sprite
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.position = furn_pos
		sprite.scale = Vector2(tw / tex_sz.x, th / tex_sz.y)
		sprite.z_index = 1
		add_child(sprite)
		
		# Create collision
		var body = StaticBody2D.new()
		body.set_collision_layer(1)
		body.set_collision_mask(0)
		var coll = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(tw, th)
		coll.shape = shape
		coll.position = furn_pos + Vector2(tw, th) * 0.5
		body.add_child(coll)
		add_child(body)

func _add_static_box(rect: Rect2):
	var static_body := StaticBody2D.new()
	static_body.set_collision_layer(1)
	static_body.set_collision_mask(0)
	var coll = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = rect.size
	coll.shape = shape
	coll.position = rect.position + rect.size * 0.5
	static_body.add_child(coll)
	add_child(static_body)

func _add_static_walls(rect: Rect2, gap: Rect2 = Rect2()):
	var t: float = 8.0
	_add_static_box(Rect2(rect.position.x, rect.position.y, rect.size.x, t))
	_add_static_box(Rect2(rect.position.x, rect.position.y, t, rect.size.y))
	_add_static_box(Rect2(rect.position.x + rect.size.x - t, rect.position.y, t, rect.size.y))
	
	if gap.size != Vector2.ZERO:
		# Assume bottom wall gap for simplicity in our manual zones
		var w1 = gap.position.x - rect.position.x
		if w1 > 0:
			_add_static_box(Rect2(rect.position.x, rect.position.y + rect.size.y - t, w1, t))
		var w2 = (rect.position.x + rect.size.x) - (gap.position.x + gap.size.x)
		if w2 > 0:
			_add_static_box(Rect2(gap.position.x + gap.size.x, rect.position.y + rect.size.y - t, w2, t))
	else:
		_add_static_box(Rect2(rect.position.x, rect.position.y + rect.size.y - t, rect.size.x, t))
