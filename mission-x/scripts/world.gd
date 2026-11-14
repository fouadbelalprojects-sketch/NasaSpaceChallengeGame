extends Node2D
class_name MarsWorld

signal resource_mined(resource_name: String, amount: int, tile_type: String)
signal mine_blocked(reason: String)
signal tile_broken(world_position: Vector2, tile_type: String)

const TILE_SIZE: int = 32
const WORLD_WIDTH: int = 2048
const WORLD_BOTTOM: int = 1536
const SURFACE_Y: int = 512
const FIRST_ROW: int = 16
const LAST_ROW: int = 47
const DEEP_ROW: int = 32
const TILE_SHAPE_SIZE: Vector2 = Vector2(31, 31)
const TILESET_TEXTURE: Texture2D = preload("res://assets/mars_tileset.png")
const TERRAIN_TEXTURE: Texture2D = preload("res://assets/terrain_atlas.png")
const COLONY_ART_SCRIPT = preload("res://scripts/colony_art.gd")

# Water-crystal cells. Mined crystals slowly re-freeze from the cavern seep each dawn.
const ICE_CELLS: Array[Vector2i] = [
	Vector2i(43, 23), Vector2i(43, 24), Vector2i(43, 25), Vector2i(43, 26),
	Vector2i(23, 23), Vector2i(23, 24), Vector2i(23, 25), Vector2i(23, 26),
	Vector2i(44, 24), Vector2i(44, 25), Vector2i(33, 27), Vector2i(39, 27),
	Vector2i(41, 27), Vector2i(25, 22), Vector2i(38, 22), Vector2i(22, 43),
	Vector2i(40, 43), Vector2i(27, 38)
]

# Tile type -> [resource, amount, research points by rarity]
const TILE_YIELD: Dictionary = {
	"regolith": ["regolith", 1, 1],
	"basalt": ["regolith", 1, 1],
	"metal_scrap": ["metal", 2, 2],
	"salvage": ["electronics", 1, 3],
	"ice": ["ice", 1, 3],
	"titanium": ["titanium", 1, 4],
	"arcadium": ["arcadium", 1, 5],
	"rubrium": ["rubrium", 1, 5]
}

const WRECK_POSITION: Vector2 = Vector2(150, 470)
const DOME_POSITION: Vector2 = Vector2(430, 470)
const SOLAR_POSITION: Vector2 = Vector2(690, 478)
const UG_BASE_POSITION: Vector2 = Vector2(850, 832)
const STAKE_POSITIONS: Array[Vector2] = [Vector2(282, 490), Vector2(578, 490), Vector2(872, 490)]
const SHAFT_LADDER: Rect2 = Rect2(1004, 420, 40, 444)
const DEEP_LADDER: Rect2 = Rect2(1164, 826, 40, 550)

const EXPLORE_ZONES: Dictionary = {
	"east_ridge": {"name": "EASTERN RIDGE", "pos": Vector2(1390, 486), "radius": 120.0},
	"far_mesa": {"name": "FAR MESA", "pos": Vector2(1935, 486), "radius": 110.0},
	"ice_cavern": {"name": "ICE CAVERN", "pos": Vector2(1190, 838), "radius": 120.0},
	"deep_hollows": {"name": "DEEP HOLLOWS", "pos": Vector2(1000, 1352), "radius": 140.0}
}

const DISCOVERIES: Dictionary = {
	"meteorite": {"name": "IRON METEORITE", "pos": Vector2(1505, 494), "reward": {"metal": 3}},
	"rover": {"name": "ABANDONED SURVEY ROVER", "pos": Vector2(1720, 488), "reward": {"electronics": 2, "metal": 2}},
	"fossil": {"name": "FOSSILISED MICROBIAL MAT", "pos": Vector2(1300, 846), "reward": {}},
	"geode": {"name": "TITANIUM GEODE", "pos": Vector2(760, 1356), "reward": {"titanium": 2}},
	"arcadium": {"name": "GLOWING ANOMALY // NEW ELEMENT: ARCADIUM", "pos": Vector2(520, 1356), "reward": {}},
	"rubrium": {"name": "RED VEIN // NEW ELEMENT: RUBRIUM", "pos": Vector2(1555, 1356), "reward": {}}
}

var tiles: Dictionary = {}
var colliders: Dictionary = {}
var mined_cells: Array[Vector2i] = []
var storm_active: bool = false
var flare_active: bool = false
var wreck_salvaged: bool = false
var mine_target_cell: Vector2i = Vector2i(-999, -999)
var animation_time: float = 0.0
# Shared with the campaign: the campaign writes colony flags, the world reads them to draw and gate.
var colony: Dictionary = {}

var colony_back
var colony_front

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_terrain()
	colony_back = COLONY_ART_SCRIPT.new()
	colony_back.setup(self, "back")
	add_child(colony_back)
	colony_front = COLONY_ART_SCRIPT.new()
	colony_front.setup(self, "front")
	add_child(colony_front)
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta

func flag(key: String, default_value: Variant = false) -> Variant:
	return colony.get(key, default_value)

func deep_unlocked() -> bool:
	return bool(flag("ug_base"))

func reset_world() -> void:
	for body_variant in colliders.values():
		var body: StaticBody2D = body_variant
		if is_instance_valid(body):
			body.queue_free()
	tiles.clear()
	colliders.clear()
	mined_cells.clear()
	storm_active = false
	flare_active = false
	wreck_salvaged = false
	mine_target_cell = Vector2i(-999, -999)
	_build_terrain()
	queue_redraw()

# ---------------------------------------------------------------- terrain

func _build_terrain() -> void:
	for x in range(64):
		for y in range(FIRST_ROW, LAST_ROW + 1):
			if _is_cave_open(x, y):
				continue
			_add_tile(Vector2i(x, y), _tile_type_for(x, y))

func _is_cave_open(x: int, y: int) -> bool:
	if x >= 30 and x <= 33 and y >= 16 and y <= 22:
		return true # access shaft
	if x >= 24 and x <= 42 and y >= 23 and y <= 26:
		return true # shallow ice cavern
	if x >= 14 and x <= 50 and y >= 39 and y <= 42:
		return true # deep hollows
	return false

func _tile_type_for(x: int, y: int) -> String:
	if y == LAST_ROW:
		return "bedrock"
	if x >= 36 and x <= 37 and y >= 27 and y <= 38:
		return "seal" # pre-surveyed drill column, opened by the underground base
	if ICE_CELLS.has(Vector2i(x, y)):
		return "ice"
	if x >= 11 and x <= 13 and y >= 38 and y <= 43 and (x + y) % 2 == 0:
		return "arcadium"
	if x >= 14 and x <= 16 and y == 43:
		return "arcadium"
	if x >= 51 and x <= 53 and y >= 38 and y <= 43 and (x + y) % 2 == 1:
		return "rubrium"
	if x >= 48 and x <= 50 and y == 43:
		return "rubrium"
	if y < DEEP_ROW:
		if (x * 7 + y * 13) % 53 == 0:
			return "metal_scrap"
		if y >= 17 and (x * 11 + y * 5) % 41 == 0:
			return "salvage"
		return "regolith"
	if (x * 5 + y * 3) % 13 == 0:
		return "titanium"
	if (x * 3 + y * 7) % 19 == 0:
		return "metal_scrap"
	if (x * 11 + y * 5) % 41 == 0:
		return "salvage"
	return "basalt"

func _add_tile(cell: Vector2i, tile_type: String) -> void:
	tiles[cell] = tile_type
	var body := StaticBody2D.new()
	body.position = _cell_center(cell)
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = TILE_SHAPE_SIZE
	collision.shape = rectangle
	body.add_child(collision)
	add_child(body)
	colliders[cell] = body
	queue_redraw()

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * TILE_SIZE, (float(cell.y) + 0.5) * TILE_SIZE)

func _remove_tile(cell: Vector2i, record_mined: bool) -> void:
	if not tiles.has(cell):
		return
	var body: StaticBody2D = colliders.get(cell)
	if is_instance_valid(body):
		body.queue_free()
	tiles.erase(cell)
	colliders.erase(cell)
	if record_mined and not mined_cells.has(cell):
		mined_cells.append(cell)
	queue_redraw()

func open_deep_shaft() -> void:
	for x in range(36, 38):
		for y in range(27, 39):
			var cell := Vector2i(x, y)
			if tiles.has(cell) and str(tiles[cell]) == "seal":
				_remove_tile(cell, false)
	queue_redraw()

func regrow_ice(player_position: Vector2) -> int:
	var regrown: int = 0
	for cell in ICE_CELLS:
		if tiles.has(cell) or not mined_cells.has(cell):
			continue
		if player_position.distance_to(_cell_center(cell)) < 40.0:
			continue
		mined_cells.erase(cell)
		_add_tile(cell, "ice")
		regrown += 1
	if regrown > 0:
		queue_redraw()
	return regrown

func mine_at(world_position: Vector2, player_position: Vector2) -> bool:
	var cell := Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))
	if not tiles.has(cell):
		return false
	if player_position.distance_to(_cell_center(cell)) > 88.0:
		return false
	var tile_type: String = str(tiles[cell])
	if tile_type == "bedrock":
		mine_blocked.emit("MANTLE BEDROCK // TOO DENSE FOR ANY DRILL")
		return false
	if tile_type == "seal":
		mine_blocked.emit("SURVEYED DRILL COLUMN // THE UNDERGROUND BASE WILL BORE THIS SHAFT")
		return false
	if cell.y >= DEEP_ROW and not deep_unlocked():
		mine_blocked.emit("DEEP STRATA TOO DENSE // BUILD THE UNDERGROUND BASE DRILL FIRST")
		return false
	if (tile_type == "arcadium" or tile_type == "rubrium") and not bool(_discovered(tile_type)):
		mine_blocked.emit("UNKNOWN CRYSTAL // ANALYSE THE NEARBY ANOMALY WITH [E] FIRST")
		return false
	_remove_tile(cell, true)
	tile_broken.emit(_cell_center(cell), tile_type)
	var yield_data: Array = TILE_YIELD.get(tile_type, ["regolith", 1, 1])
	resource_mined.emit(str(yield_data[0]), int(yield_data[1]), tile_type)
	queue_redraw()
	return true

static func rarity_points(tile_type: String) -> int:
	var yield_data: Array = TILE_YIELD.get(tile_type, ["regolith", 1, 1])
	return int(yield_data[2])

func update_mining_target(mouse_world_position: Vector2, player_position: Vector2) -> void:
	var cell := Vector2i(floori(mouse_world_position.x / TILE_SIZE), floori(mouse_world_position.y / TILE_SIZE))
	var next_target := Vector2i(-999, -999)
	if tiles.has(cell) and player_position.distance_to(_cell_center(cell)) <= 88.0:
		next_target = cell
	if next_target != mine_target_cell:
		mine_target_cell = next_target

# ---------------------------------------------------------------- sites & queries

func is_near_wreck(position: Vector2) -> bool:
	return position.distance_to(WRECK_POSITION) <= 94.0

func is_inside_lander(position: Vector2) -> bool:
	return absf(position.x - WRECK_POSITION.x) <= 70.0 and position.y >= 400.0 and position.y <= 515.0

func is_near_dome(position: Vector2) -> bool:
	return absf(position.x - DOME_POSITION.x) <= 115.0 and position.y >= 405.0 and position.y <= 545.0

func is_inside_dome(position: Vector2) -> bool:
	return absf(position.x - DOME_POSITION.x) <= 82.0 and position.y >= 405.0 and position.y <= 535.0

func is_near_solar(position: Vector2) -> bool:
	return position.distance_to(SOLAR_POSITION) <= 95.0

func is_near_ug_base(position: Vector2) -> bool:
	return position.distance_to(UG_BASE_POSITION) <= 110.0

func is_inside_ug_base(position: Vector2) -> bool:
	return bool(flag("ug_base")) and absf(position.x - UG_BASE_POSITION.x) <= 85.0 and position.y >= 740.0 and position.y <= 868.0

func is_near_site(site: String, position: Vector2) -> bool:
	match site:
		"lander":
			return is_near_wreck(position)
		"dome":
			return is_near_dome(position)
		"solar":
			return is_near_solar(position)
		"ug_base":
			return is_near_ug_base(position)
	return false

func nearest_stake(position: Vector2) -> int:
	for i in range(STAKE_POSITIONS.size()):
		if position.distance_to(STAKE_POSITIONS[i]) <= 60.0:
			return i
	return -1

func zone_at(position: Vector2) -> String:
	for zone_id in EXPLORE_ZONES.keys():
		var zone: Dictionary = EXPLORE_ZONES[zone_id]
		var zone_pos: Vector2 = zone["pos"]
		if position.distance_to(zone_pos) <= float(zone["radius"]):
			return str(zone_id)
	return ""

func discovery_at(position: Vector2) -> String:
	for discovery_id in DISCOVERIES.keys():
		var entry: Dictionary = DISCOVERIES[discovery_id]
		var entry_pos: Vector2 = entry["pos"]
		if position.distance_to(entry_pos) <= 70.0:
			return str(discovery_id)
	return ""

func _discovered(discovery_id: String) -> bool:
	var found: Variant = flag("discovered", {})
	return found is Dictionary and bool((found as Dictionary).get(discovery_id, false))

func _explored(zone_id: String) -> bool:
	var done: Variant = flag("explored", {})
	return done is Dictionary and bool((done as Dictionary).get(zone_id, false))

func is_on_ladder(position: Vector2) -> bool:
	if SHAFT_LADDER.has_point(position):
		return true
	return deep_unlocked() and DEEP_LADDER.has_point(position)

func set_storm_active(active: bool) -> void:
	storm_active = active
	queue_redraw()

func set_flare_active(active: bool) -> void:
	flare_active = active
	queue_redraw()

# ---------------------------------------------------------------- save

func get_save_state() -> Dictionary:
	var saved_mined: Array = []
	for cell in mined_cells:
		saved_mined.append([cell.x, cell.y])
	return {
		"wreck_salvaged": wreck_salvaged,
		"mined_cells": saved_mined
	}

func restore_save_state(state: Dictionary) -> void:
	reset_world()
	wreck_salvaged = bool(state.get("wreck_salvaged", false))
	var saved_mined: Variant = state.get("mined_cells", [])
	if saved_mined is Array:
		for raw_cell in saved_mined:
			if raw_cell is Array and raw_cell.size() >= 2:
				var cell := Vector2i(int(raw_cell[0]), int(raw_cell[1]))
				_remove_tile(cell, true)
	if deep_unlocked():
		open_deep_shaft()
	queue_redraw()

# ---------------------------------------------------------------- terrain drawing (static: redrawn only when tiles change)

const ATLAS_ROW: Dictionary = {
	"surface": 0, "regolith": 1, "rock": 2, "basalt": 3, "bedrock": 4, "seal": 4,
	"metal_scrap": 5, "salvage": 6, "ice": 7, "titanium": 8, "arcadium": 9, "rubrium": 9,
	"backwall_rock": 10, "backwall_deep": 11
}

static func _hash(x: int, y: int) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

func _atlas_rect(tile_type: String, cell: Vector2i) -> Rect2:
	var h: int = _hash(cell.x, cell.y)
	var material: String = tile_type
	var col: int = h % 4
	match tile_type:
		"regolith":
			var jitter: int = roundi(sin(float(cell.x) * 0.45) * 1.2 + sin(float(cell.x) * 0.17 + 1.3) * 0.9)
			if cell.y == FIRST_ROW:
				material = "surface"
			elif cell.y + jitter >= 22:
				material = "rock"
		"bedrock":
			col = h % 2
		"seal":
			col = 2 + h % 2
		"metal_scrap", "salvage":
			col = (h % 2) + (2 if cell.y >= DEEP_ROW else 0)
		"arcadium":
			col = h % 2
		"rubrium":
			col = 2 + h % 2
	return Rect2(col * TILE_SIZE, int(ATLAS_ROW[material]) * TILE_SIZE, TILE_SIZE, TILE_SIZE)

func _is_solid(x: int, y: int) -> bool:
	if y < FIRST_ROW:
		return false
	if x < 0 or x > 63 or y > LAST_ROW:
		return true
	return tiles.has(Vector2i(x, y))

func _draw() -> void:
	# Below-ground fill (the sky is drawn on its own layer behind this node).
	draw_rect(Rect2(0, (LAST_ROW + 1) * TILE_SIZE, WORLD_WIDTH, 260), Color("0b0a0e"))

	# Back walls behind every open or mined cell, with soft ambient occlusion at the rock edges.
	for x in range(64):
		for y in range(FIRST_ROW, LAST_ROW + 1):
			if tiles.has(Vector2i(x, y)):
				continue
			var cell := Vector2i(x, y)
			var row: String = "backwall_deep" if y >= DEEP_ROW else "backwall_rock"
			var rect := Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			draw_texture_rect_region(TERRAIN_TEXTURE, rect, Rect2((_hash(x, y) % 4) * TILE_SIZE, int(ATLAS_ROW[row]) * TILE_SIZE, TILE_SIZE, TILE_SIZE))
			_draw_occlusion(cell, rect)

	for cell_variant in tiles.keys():
		var cell: Vector2i = cell_variant
		var tile_type: String = str(tiles[cell])
		var rect := Rect2(Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
		draw_texture_rect_region(TERRAIN_TEXTURE, rect, _atlas_rect(tile_type, cell))
		_draw_tile_edges(cell, rect)

func _draw_occlusion(cell: Vector2i, rect: Rect2) -> void:
	var shade := Color(0.0, 0.0, 0.0, 1.0)
	var steps: Array = [[0.0, 0.42], [3.0, 0.24], [6.0, 0.11]]
	if _is_solid(cell.x, cell.y - 1):
		for s in steps:
			draw_rect(Rect2(rect.position.x, rect.position.y + float(s[0]), TILE_SIZE, 3), Color(shade, float(s[1])))
	if _is_solid(cell.x - 1, cell.y):
		for s in steps:
			draw_rect(Rect2(rect.position.x + float(s[0]), rect.position.y, 3, TILE_SIZE), Color(shade, float(s[1]) * 0.8))
	if _is_solid(cell.x + 1, cell.y):
		for s in steps:
			draw_rect(Rect2(rect.end.x - 3.0 - float(s[0]), rect.position.y, 3, TILE_SIZE), Color(shade, float(s[1]) * 0.8))
	if _is_solid(cell.x, cell.y + 1):
		draw_rect(Rect2(rect.position.x, rect.end.y - 2, TILE_SIZE, 2), Color(shade, 0.25))

func _draw_tile_edges(cell: Vector2i, rect: Rect2) -> void:
	var open_up: bool = not _is_solid(cell.x, cell.y - 1)
	var open_down: bool = not _is_solid(cell.x, cell.y + 1)
	var open_left: bool = not _is_solid(cell.x - 1, cell.y)
	var open_right: bool = not _is_solid(cell.x + 1, cell.y)
	if open_up and cell.y > FIRST_ROW:
		draw_rect(Rect2(rect.position.x, rect.position.y, TILE_SIZE, 2), Color(1.0, 0.86, 0.7, 0.30))
		draw_rect(Rect2(rect.position.x, rect.position.y + 2, TILE_SIZE, 2), Color(1.0, 0.86, 0.7, 0.10))
	if open_down:
		draw_rect(Rect2(rect.position.x, rect.end.y - 3, TILE_SIZE, 3), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(rect.position.x, rect.end.y - 6, TILE_SIZE, 3), Color(0, 0, 0, 0.18))
	if open_left:
		draw_rect(Rect2(rect.position.x, rect.position.y, 2, TILE_SIZE), Color(1.0, 0.86, 0.7, 0.14))
	if open_right:
		draw_rect(Rect2(rect.end.x - 2, rect.position.y, 2, TILE_SIZE), Color(0, 0, 0, 0.30))
	if cell.y == FIRST_ROW and open_left:
		draw_rect(Rect2(rect.position.x, rect.position.y + 6, 3, TILE_SIZE - 6), Color(0, 0, 0, 0.25))
