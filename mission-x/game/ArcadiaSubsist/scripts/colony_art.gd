extends Node2D
class_name ColonyArt
## Draws every colony structure, marker and weather effect, and owns the scene's 2D lights.
## Two instances exist: layer "back" (behind the engineer) and layer "front" (dome glass + weather).

const W = preload("res://scripts/world.gd")

var world
var layer_name: String = "back"
var animation_time: float = 0.0
var light_scale: float = 1.0
var _lights: Dictionary = {}
static var _light_texture: GradientTexture2D

func setup(world_node, which: String) -> void:
	world = world_node
	layer_name = which
	z_index = 1 if which == "back" else 7
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if which == "back":
		_build_lights()

static func light_texture() -> GradientTexture2D:
	if _light_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.18, Color(1, 1, 1, 0.62))
		gradient.add_point(0.45, Color(1, 1, 1, 0.20))
		gradient.add_point(0.75, Color(1, 1, 1, 0.05))
		_light_texture = GradientTexture2D.new()
		_light_texture.gradient = gradient
		_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_light_texture.fill_from = Vector2(0.5, 0.5)
		_light_texture.fill_to = Vector2(1.0, 0.5)
		_light_texture.width = 256
		_light_texture.height = 256
	return _light_texture

func _add_light(id: String, pos: Vector2, color: Color, scale_value: float, energy: float) -> void:
	var light := PointLight2D.new()
	light.texture = light_texture()
	light.position = pos
	light.color = color
	light.texture_scale = scale_value
	light.energy = energy
	light.set_meta("base_energy", energy)
	add_child(light)
	_lights[id] = light

func _build_lights() -> void:
	_add_light("lander_window", Vector2(161, 413), Color(1.0, 0.72, 0.42), 1.2, 0.9)
	_add_light("lander_beacon", Vector2(140, 390), Color(1.0, 0.55, 0.25), 0.5, 0.9)
	_add_light("dome", Vector2(430, 470), Color(0.62, 0.95, 0.9), 1.9, 1.0)
	_add_light("fuel_cell", Vector2(365, 490), Color(1.0, 0.7, 0.35), 0.7, 0.9)
	_add_light("purifier", Vector2(307, 480), Color(0.55, 0.85, 1.0), 0.7, 0.7)
	_add_light("farm", Vector2(559, 488), Color(0.75, 1.0, 0.6), 0.9, 0.75)
	_add_light("solar", Vector2(690, 470), Color(0.6, 0.85, 1.0), 0.8, 0.45)
	_add_light("breakers", Vector2(787, 490), Color(1.0, 0.85, 0.4), 0.45, 0.8)
	_add_light("shaft_top", Vector2(1024, 500), Color(1.0, 0.75, 0.45), 0.8, 0.7)
	_add_light("shaft_mid", Vector2(1024, 640), Color(1.0, 0.75, 0.45), 0.8, 0.6)
	_add_light("cavern", Vector2(1110, 830), Color(0.4, 0.95, 0.9), 1.3, 0.6)
	_add_light("cavern_west", Vector2(840, 840), Color(0.4, 0.95, 0.9), 0.9, 0.5)
	_add_light("ug_base", Vector2(850, 820), Color(1.0, 0.82, 0.5), 1.5, 1.1)
	_add_light("drill", Vector2(1184, 830), Color(1.0, 0.6, 0.3), 0.8, 0.8)
	_add_light("deep_ladder_1", Vector2(1184, 1040), Color(1.0, 0.7, 0.4), 0.6, 0.8)
	_add_light("deep_ladder_2", Vector2(1184, 1250), Color(1.0, 0.7, 0.4), 0.7, 0.8)
	_add_light("arcadium", Vector2(420, 1340), Color(0.35, 1.0, 0.85), 1.5, 1.2)
	_add_light("rubrium", Vector2(1660, 1340), Color(1.0, 0.3, 0.28), 1.5, 1.2)
	_add_light("hollows", Vector2(1000, 1330), Color(0.55, 0.45, 0.8), 1.2, 0.25)
	_add_light("reactor", Vector2(850, 800), Color(0.4, 1.0, 0.85), 1.4, 1.0)
	for i in range(3):
		_add_light("stake_%d" % i, W.STAKE_POSITIONS[i] + Vector2(0, -26), Color(0.4, 1.0, 0.7), 0.35, 0.9)
	for discovery_id in W.DISCOVERIES.keys():
		var entry: Dictionary = W.DISCOVERIES[discovery_id]
		var tint := Color(1.0, 0.85, 0.5)
		if discovery_id == "arcadium":
			tint = Color(0.45, 1.0, 0.86)
		elif discovery_id == "rubrium":
			tint = Color(1.0, 0.35, 0.32)
		_add_light("disc_" + str(discovery_id), (entry["pos"] as Vector2) + Vector2(0, -20), tint, 0.6, 0.9)

func _set_light(id: String, on: bool, flicker: float = 1.0) -> void:
	var light: PointLight2D = _lights.get(id)
	if light == null:
		return
	light.enabled = on and light_scale > 0.02
	light.energy = float(light.get_meta("base_energy")) * light_scale * flicker

func _update_lights() -> void:
	var sealed: bool = bool(world.flag("dome_sealed"))
	var deep: bool = world.deep_unlocked()
	var pts: bool = bool(world.flag("points_active"))
	var t: float = animation_time
	_set_light("lander_window", true)
	_set_light("lander_beacon", int(t * 1.5) % 2 == 0)
	_set_light("dome", int(world.flag("dome_stage", 0)) >= 2, 1.0 if sealed else 0.35)
	_set_light("fuel_cell", bool(world.flag("fuel_cell")) and float(world.flag("fuel", 0.0)) > 0.0, 0.8 + 0.2 * sin(t * 2.0))
	_set_light("purifier", bool(world.flag("purifier")))
	_set_light("farm", bool(world.flag("farm")))
	_set_light("solar", bool(world.flag("solar_built")) and not bool(world.flag("solar_damaged")))
	_set_light("breakers", bool(world.flag("flare_kit")), 1.0 if not bool(world.flag("solar_damaged")) else (1.0 if int(t * 5.0) % 2 == 0 else 0.2))
	_set_light("shaft_top", true)
	_set_light("shaft_mid", true, 0.85 + 0.15 * sin(t * 7.0))
	_set_light("cavern", true, 0.9 + 0.1 * sin(t * 1.3))
	_set_light("cavern_west", not bool(world.flag("ug_base")))
	_set_light("ug_base", bool(world.flag("ug_base")))
	_set_light("drill", deep)
	_set_light("deep_ladder_1", deep)
	_set_light("deep_ladder_2", deep)
	_set_light("arcadium", deep, 0.85 + 0.15 * sin(t * 2.6))
	_set_light("rubrium", deep, 0.85 + 0.15 * sin(t * 2.1 + 1.0))
	_set_light("hollows", deep)
	_set_light("reactor", bool(world.flag("reactor")), 0.8 + 0.2 * sin(t * 3.0))
	var beacons: Variant = world.flag("beacons", [false, false, false])
	for i in range(3):
		var placed: bool = beacons is Array and bool((beacons as Array)[i])
		_set_light("stake_%d" % i, placed, 1.0 if int(t * 2.0 + i) % 2 == 0 else 0.3)
	for discovery_id in W.DISCOVERIES.keys():
		var visible_now: bool = pts and not world._discovered(str(discovery_id))
		if (discovery_id == "geode" or discovery_id == "arcadium" or discovery_id == "rubrium") and not deep:
			visible_now = false
		_set_light("disc_" + str(discovery_id), visible_now, 0.7 + 0.3 * sin(t * 3.0))

func _process(delta: float) -> void:
	animation_time += delta
	if layer_name == "back":
		_update_lights()
	queue_redraw()

func _draw() -> void:
	if world == null:
		return
	if layer_name == "front":
		_draw_dome_glass()
		if world.storm_active:
			_draw_dust_storm()
		if world.flare_active:
			_draw_solar_flare()
		return
	_draw_surface_decorations()
	_draw_ladders()
	_draw_stakes()
	_draw_lander()
	_draw_dome()
	_draw_solar_array()
	_draw_cave_crystals()
	_draw_underground_base()
	_draw_explore_zones()
	_draw_discoveries()
	_draw_mine_target()

func _draw_mine_target() -> void:
	var cell: Vector2i = world.mine_target_cell
	if cell.x < -100:
		return
	var rect := Rect2(Vector2(cell.x * 32, cell.y * 32), Vector2(32, 32))
	var pulse: float = 0.5 + 0.5 * sin(animation_time * 8.0)
	draw_rect(rect, Color(1.0, 0.82, 0.35, 0.10 + 0.08 * pulse))
	var c := Color(1.0, 0.88, 0.6, 0.65 + 0.35 * pulse)
	var l: float = 8.0
	for corner in [Vector2(0, 0), Vector2(32, 0), Vector2(0, 32), Vector2(32, 32)]:
		var p: Vector2 = rect.position + corner
		var sx: float = 1.0 if corner.x == 0 else -1.0
		var sy: float = 1.0 if corner.y == 0 else -1.0
		draw_line(p, p + Vector2(l * sx, 0), c, 2.0)
		draw_line(p, p + Vector2(0, l * sy), c, 2.0)


func _draw_surface_decorations() -> void:
	for i in range(26):
		var px: float = float((i * 157 + 31) % W.WORLD_WIDTH)
		if (px > 330.0 and px < 540.0) or (px > 950.0 and px < 1100.0):
			continue
		var variant: int = i % 4
		draw_texture_rect_region(W.TERRAIN_TEXTURE, Rect2(px, 482 + float(i % 3), 32, 32), Rect2(variant * 32, 12 * 32, 32, 32))
	for plant_index in range(9):
		var plant_x: float = 245.0 + float(plant_index) * 203.0
		if (plant_x > 880.0 and plant_x < 1120.0) or (plant_x > 330.0 and plant_x < 600.0):
			continue
		draw_texture_rect_region(W.TILESET_TEXTURE, Rect2(plant_x, 461, 32, 32), Rect2(96, 64, 32, 32), Color(0.85, 0.8, 0.75))

func _draw_ladder(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position.x + 5, rect.position.y, 3, rect.size.y), Color("5e5348"))
	draw_rect(Rect2(rect.position.x + rect.size.x - 8, rect.position.y, 3, rect.size.y), Color("5e5348"))
	var rung_y: float = rect.position.y + 6.0
	while rung_y < rect.end.y:
		draw_rect(Rect2(rect.position.x + 5, rung_y, rect.size.x - 10, 3), Color("a88d6a"))
		draw_rect(Rect2(rect.position.x + 5, rung_y + 3, rect.size.x - 10, 1), Color("3d352e"))
		rung_y += 14.0

func _draw_ladders() -> void:
	_draw_ladder(Rect2(W.SHAFT_LADDER.position.x, 470, W.SHAFT_LADDER.size.x, W.SHAFT_LADDER.end.y - 470))
	# Head frame over the access shaft.
	var lx: float = W.SHAFT_LADDER.position.x
	draw_line(Vector2(lx - 26, 512), Vector2(lx + 4, 452), Color("5b514c"), 4.0)
	draw_line(Vector2(lx + 66, 512), Vector2(lx + 36, 452), Color("5b514c"), 4.0)
	draw_rect(Rect2(lx - 4, 448, 48, 7), Color("e28a42"))
	draw_rect(Rect2(lx - 4, 448, 48, 2), Color("f5c074"))
	draw_rect(Rect2(lx + 16, 455, 8, 6), Color("2b2a2c"))
	draw_rect(Rect2(lx + 18, 457, 4, 3), Color(1.0, 0.75, 0.45))
	if world.deep_unlocked():
		_draw_ladder(Rect2(W.DEEP_LADDER.position.x, 846, W.DEEP_LADDER.size.x, W.DEEP_LADDER.end.y - 846))

func _draw_stakes() -> void:
	var beacons: Variant = world.flag("beacons", [false, false, false])
	for i in range(W.STAKE_POSITIONS.size()):
		var placed: bool = beacons is Array and i < (beacons as Array).size() and bool((beacons as Array)[i])
		var base := W.STAKE_POSITIONS[i]
		if placed:
			# Seismic survey beacon on a tripod.
			draw_line(base + Vector2(0, -20), base + Vector2(-9, 21), Color("6b6158"), 2.0)
			draw_line(base + Vector2(0, -20), base + Vector2(9, 21), Color("6b6158"), 2.0)
			draw_line(base + Vector2(0, -20), base + Vector2(0, 21), Color("8a7f72"), 2.0)
			draw_rect(Rect2(base.x - 6, base.y - 32, 12, 12), Color("2c3436"))
			draw_rect(Rect2(base.x - 6, base.y - 32, 12, 2), Color("8fa0a3"))
			var blink: float = 0.35 + 0.65 * float(int(animation_time * 2.0 + i) % 2)
			draw_rect(Rect2(base.x - 3, base.y - 28, 6, 5), Color(0.45, 1.0, 0.75, blink))
		else:
			draw_rect(Rect2(base.x - 2, base.y - 22, 4, 44), Color("8a7f72"))
			var wave: float = sin(animation_time * 4.0 + i) * 2.0
			draw_colored_polygon(PackedVector2Array([Vector2(base.x + 2, base.y - 22), Vector2(base.x + 16, base.y - 18 + wave), Vector2(base.x + 2, base.y - 13)]), Color("e28a42"))

func _draw_lander() -> void:
	draw_rect(Rect2(81, 493, 148, 8), Color(0.10, 0.06, 0.06, 0.34))
	draw_rect(Rect2(87, 433, 16, 28), Color("393c40"))
	draw_rect(Rect2(207, 426, 21, 30), Color("3b3b3d"))
	draw_rect(Rect2(92, 420, 124, 58), Color("34363b"))
	draw_rect(Rect2(96, 426, 116, 48), Color("686b67"))
	draw_rect(Rect2(111, 399, 83, 35), Color("514f50"))
	draw_rect(Rect2(115, 398, 75, 31), Color("a49a8b"))
	draw_rect(Rect2(120, 402, 63, 23), Color("788a88"))
	draw_rect(Rect2(126, 406, 50, 14), Color("314750"))
	draw_rect(Rect2(130, 408, 12, 4), Color("9dc7c7"))
	draw_rect(Rect2(100, 429, 108, 11), Color("85857e"))
	draw_rect(Rect2(103, 444, 102, 22), Color("77766f"))
	draw_rect(Rect2(105, 446, 17, 15), Color("4c4f51"))
	draw_rect(Rect2(128, 447, 44, 15), Color("b17d4d") if not world.wreck_salvaged else Color("4a3b30"))
	draw_rect(Rect2(133, 451, 34, 7), Color("393c40"))
	draw_rect(Rect2(177, 447, 22, 14), Color("58595a"))
	draw_rect(Rect2(91, 449, 18, 7), Color("e28a42"))
	draw_rect(Rect2(201, 435, 17, 6), Color("e28a42"))
	draw_rect(Rect2(115, 429, 81, 3), Color("d8c4a5"))
	draw_rect(Rect2(104, 472, 7, 27), Color("4e4c48"))
	draw_rect(Rect2(109, 493, 23, 5), Color("292b2f"))
	draw_rect(Rect2(188, 472, 7, 27), Color("4e4c48"))
	draw_rect(Rect2(181, 493, 23, 5), Color("292b2f"))
	draw_rect(Rect2(140, 396, 3, 13), Color("554e48"))
	draw_rect(Rect2(137, 391, 3, 9), Color("9a8b7a"))
	var beacon_on: bool = int(animation_time * 1.5) % 2 == 0
	draw_rect(Rect2(138, 388, 5, 4), Color("f0a05b") if beacon_on else Color("6a4a30"))
	# Cabin porthole glows warm while it is the crew's only shelter.
	draw_rect(Rect2(150, 408, 22, 10), Color(1.0, 0.82, 0.5, 0.95))
	draw_rect(Rect2(150, 408, 22, 2), Color(1.0, 0.95, 0.8, 1.0))
	draw_rect(Rect2(78, 482, 7, 3), Color("d87935"))
	draw_rect(Rect2(222, 478, 6, 3), Color("c36e39"))
	draw_rect(Rect2(219, 471, 3, 2), Color("f5c074"))

func _dome_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2(430 - radius, 510))
	for i in range(17):
		var angle: float = PI + (PI * float(i) / 16.0)
		points.append(Vector2(430 + cos(angle) * radius, 510 + sin(angle) * radius))
	points.append(Vector2(430 + radius, 510))
	return points

func _draw_dome() -> void:
	var stage: int = int(world.flag("dome_stage", 0))
	var sealed: bool = bool(world.flag("dome_sealed"))

	# Purifier tank (left) and hydroponics greenhouse (right) sit outside the shell.
	if bool(world.flag("purifier")):
		draw_rect(Rect2(288, 458, 38, 52), Color("252d33"))
		draw_rect(Rect2(291, 461, 32, 46), Color("4f7f93"))
		draw_rect(Rect2(291, 461, 32, 4), Color("8fc3d4"))
		var level: float = 18.0 + 6.0 * sin(animation_time * 0.8)
		draw_rect(Rect2(296, 505 - level - 6, 9, level), Color(0.55, 0.9, 1.0, 0.75))
		draw_rect(Rect2(296, 499 - level, 9, 2), Color(0.9, 1.0, 1.0, 0.9))
		draw_rect(Rect2(310, 468, 9, 5), Color("2b3438"))
		draw_rect(Rect2(312, 469, 3, 3), Color("8de0c8"))
		draw_rect(Rect2(278, 494, 12, 5), Color("8b8b84"))
	if bool(world.flag("farm")):
		var gx: float = 528.0
		draw_rect(Rect2(gx, 462, 62, 48), Color("2a3531"))
		draw_colored_polygon(PackedVector2Array([Vector2(gx, 466), Vector2(gx + 31, 452), Vector2(gx + 62, 466)]), Color("2a3531"))
		draw_rect(Rect2(gx + 3, 467, 56, 40), Color(0.55, 0.85, 0.72, 0.22))
		draw_colored_polygon(PackedVector2Array([Vector2(gx + 4, 466), Vector2(gx + 31, 455), Vector2(gx + 58, 466)]), Color(0.55, 0.85, 0.72, 0.22))
		var growth: float = float(world.flag("farm_growth", 0.0))
		var state: String = str(world.flag("farm_state", "idle"))
		draw_rect(Rect2(gx + 4, 500, 54, 7), Color("5a4634"))
		if state != "idle":
			for p in range(5):
				var h: float = 3.0 + 18.0 * growth
				var px: float = gx + 9 + p * 10
				draw_rect(Rect2(px, 500 - h, 2, h), Color("4f9a4d"))
				draw_rect(Rect2(px - 3, 500 - h * 0.6, 4, 3), Color("6fc46a"))
				draw_rect(Rect2(px + 1, 500 - h * 0.85, 4, 3), Color("86d77b"))
				if state == "ready":
					draw_rect(Rect2(px - 2, 497 - h, 6, 5), Color("e7c35a"))
					draw_rect(Rect2(px - 1, 497 - h, 2, 2), Color("fff0a8"))
		draw_rect(Rect2(gx + 3, 467, 2, 40), Color(1, 1, 1, 0.25))
		draw_rect(Rect2(gx, 505, 62, 5), Color("8b7c66"))

	if stage <= 0:
		var blink: float = 0.6 + 0.4 * sin(animation_time * 3.0)
		for i in range(9):
			draw_rect(Rect2(342 + i * 20, 506, 10, 3), Color(0.89, 0.54, 0.26, blink))
		draw_rect(Rect2(338, 488, 4, 22), Color("e28a42"))
		draw_rect(Rect2(518, 488, 4, 22), Color("e28a42"))
		draw_rect(Rect2(336, 486, 8, 3), Color(1.0, 0.8, 0.5, blink))
		draw_rect(Rect2(516, 486, 8, 3), Color(1.0, 0.8, 0.5, blink))
		return

	# Shield berm sits behind and over the shell.
	if bool(world.flag("shield")) and stage >= 2:
		draw_polyline(_dome_points(104.0), Color("6a3e2f"), 14.0)
		draw_polyline(_dome_points(104.0), Color("a8674a"), 5.0)
		for k in range(14):
			var a: float = PI + PI * (float(k) + 0.5) / 14.0
			var p: Vector2 = Vector2(430, 510) + Vector2(cos(a), sin(a)) * 106.0
			draw_rect(Rect2(p.x - 3, p.y - 2, 6, 4), Color("c27a52"))

	# Interior back wall (seen through the glass, behind the engineer).
	if stage >= 2:
		var interior := _dome_points(92.0)
		draw_colored_polygon(interior, Color(0.10, 0.16, 0.18, 0.55) if sealed else Color(0.08, 0.08, 0.09, 0.45))
		# Bunk, console and a little potted plant.
		draw_rect(Rect2(366, 488, 38, 8), Color("4c5658"))
		draw_rect(Rect2(366, 485, 12, 4), Color("c9c2b4"))
		draw_rect(Rect2(368, 496, 3, 10), Color("3a4143"))
		draw_rect(Rect2(399, 496, 3, 10), Color("3a4143"))
		draw_rect(Rect2(452, 470, 30, 22), Color("2c3436"))
		draw_rect(Rect2(455, 473, 24, 12), Color("8de0c8") if sealed else Color("324044"))
		if sealed:
			for row in range(3):
				var w: float = 6.0 + float(int(animation_time * 2.0 + row) % 3) * 5.0
				draw_rect(Rect2(457, 475 + row * 3, w, 1), Color("1e4d47"))
		draw_rect(Rect2(462, 492, 6, 14), Color("3a4143"))
		draw_rect(Rect2(492, 494, 8, 10), Color("8a5a3c"))
		draw_rect(Rect2(490, 486, 5, 8), Color("6fc46a"))
		draw_rect(Rect2(496, 484, 5, 9), Color("86d77b"))

	# Foundation ring.
	draw_rect(Rect2(332, 503, 196, 9), Color("6f6458"))
	draw_rect(Rect2(332, 503, 196, 3), Color("c9b89c"))
	for i in range(8):
		draw_rect(Rect2(340 + i * 24, 507, 10, 2), Color("4d453d"))

	if bool(world.flag("o2_gen")):
		var spin: float = animation_time * (6.0 if sealed else 1.2)
		var gx2: float = 404.0 if stage >= 2 else 454.0
		draw_rect(Rect2(gx2, 470, 34, 34), Color("2f383b"))
		draw_rect(Rect2(gx2 + 3, 473, 28, 28), Color("5f7374"))
		draw_circle(Vector2(gx2 + 17, 487), 11.0, Color("273032"))
		var cx := Vector2(gx2 + 17, 487)
		for k in range(4):
			var a: float = spin + float(k) * TAU / 4.0
			draw_line(cx, cx + Vector2(cos(a), sin(a)) * 9.0, Color("c9e6e0"), 3.0)
		draw_circle(cx, 2.5, Color("e8f4f0"))
		draw_rect(Rect2(gx2 + 26, 475, 4, 4), Color("8de0c8") if sealed else Color("e5a05b"))

	if stage >= 3 and bool(world.flag("fuel_cell")):
		draw_rect(Rect2(350, 476, 30, 28), Color("26282c"))
		draw_rect(Rect2(353, 479, 24, 22), Color("7b6a46"))
		draw_rect(Rect2(353, 479, 24, 3), Color("b49a62"))
		var fuel: float = float(world.flag("fuel", 0.0))
		var glow: float = 0.45 + 0.4 * absf(sin(animation_time * 2.0)) if fuel > 0.0 else 0.08
		draw_rect(Rect2(357, 486, 16, 8), Color(1.0, 0.75, 0.35, glow))
		draw_rect(Rect2(357, 496, 16 * clampf(fuel / 100.0, 0.0, 1.0), 2), Color("e5bc63"))

	if stage == 1:
		for rib_x in [358.0, 394.0, 430.0, 466.0, 502.0]:
			var half_width: float = absf(rib_x - 430.0)
			var height: float = sqrt(maxf(0.0, 94.0 * 94.0 - half_width * half_width)) * 0.55
			draw_line(Vector2(rib_x, 505), Vector2(rib_x, 505.0 - height), Color("3b3632"), 5.0)
			draw_line(Vector2(rib_x, 505), Vector2(rib_x, 505.0 - height), Color("a2927c"), 3.0)
			draw_rect(Rect2(rib_x - 3, 503.0 - height, 6, 3), Color("e28a42"))

	# Airlock hatch.
	if stage >= 2:
		draw_rect(Rect2(416, 470, 28, 40), Color("252d31"))
		draw_rect(Rect2(419, 473, 22, 34), Color("56706f" if sealed else "434f50"))
		draw_rect(Rect2(423, 478, 14, 18), Color("9bcfc7" if sealed else "56696a"))
		draw_rect(Rect2(423, 478, 14, 3), Color(1, 1, 1, 0.35))
		draw_rect(Rect2(437, 488, 3, 4), Color("e5a05b"))

func _draw_dome_glass() -> void:
	var stage: int = int(world.flag("dome_stage", 0))
	if stage < 2:
		return
	var sealed: bool = bool(world.flag("dome_sealed"))
	var reinforced: bool = bool(world.flag("reinforced"))
	var shell_color := Color("9bd2cc") if sealed else Color("87918e")
	if reinforced:
		shell_color = Color("bfe0ea")
	var points := _dome_points(94.0)
	draw_colored_polygon(points, Color(shell_color.r, shell_color.g, shell_color.b, 0.16 if sealed else 0.10))
	# Glass sheen.
	var sheen := PackedVector2Array()
	for i in range(7):
		var a: float = PI * 1.12 + PI * 0.30 * float(i) / 6.0
		sheen.append(Vector2(430, 510) + Vector2(cos(a), sin(a)) * 80.0)
	draw_polyline(sheen, Color(1, 1, 1, 0.35), 3.0)
	var sheen2 := PackedVector2Array()
	for i in range(5):
		var a2: float = PI * 1.18 + PI * 0.18 * float(i) / 4.0
		sheen2.append(Vector2(430, 510) + Vector2(cos(a2), sin(a2)) * 70.0)
	draw_polyline(sheen2, Color(1, 1, 1, 0.18), 2.0)
	if bool(world.flag("lattice")):
		for k in range(1, 12):
			var a1: float = PI + PI * float(k) / 12.0
			var outer: Vector2 = Vector2(430, 510) + Vector2(cos(a1), sin(a1)) * 94.0
			var inner: Vector2 = Vector2(430, 510) + Vector2(cos(a1 + 0.26), sin(a1 + 0.26)) * 62.0
			draw_line(outer, inner, Color(1.0, 0.36, 0.32, 0.75), 2.0)
		var glow: float = 0.25 + 0.15 * sin(animation_time * 2.0)
		draw_polyline(_dome_points(62.0), Color(1.0, 0.4, 0.35, glow), 2.0)
	var rib_color := Color(0.85, 0.92, 0.98, 0.75) if reinforced else Color(0.72, 0.82, 0.78, 0.45)
	for rib_x in [358.0, 394.0, 430.0, 466.0, 502.0]:
		var half: float = absf(rib_x - 430.0)
		var h2: float = sqrt(maxf(0.0, 94.0 * 94.0 - half * half))
		draw_line(Vector2(rib_x, 510), Vector2(rib_x, 510.0 - h2), rib_color, 3.0 if reinforced else 2.0)
	draw_line(Vector2(345, 470), Vector2(515, 470), Color(rib_color.r, rib_color.g, rib_color.b, 0.3), 2.0)
	draw_polyline(points, Color("2e3639"), 7.0)
	draw_polyline(points, shell_color.lightened(0.25), 2.0)
	draw_circle(Vector2(430, 416), 5.0, Color("2e3639"))
	draw_circle(Vector2(430, 416), 3.0, Color("8de0c8") if sealed else Color("e5a05b"))
	if bool(world.flag("reactor")):
		var pulse: float = 0.5 + 0.5 * sin(animation_time * 3.0)
		draw_circle(Vector2(430, 416), 6.0 + pulse * 2.5, Color(0.45, 1.0, 0.86, 0.45))

func _draw_solar_array() -> void:
	if not bool(world.flag("solar_built")):
		# Ghost outline of the planned array.
		draw_rect(Rect2(592, 438, 180, 37), Color(0.85, 0.55, 0.30, 0.35), false, 2.0)
		draw_rect(Rect2(615, 475, 4, 27), Color("e28a42"))
		draw_rect(Rect2(749, 475, 4, 27), Color("e28a42"))
		return
	var damaged: bool = bool(world.flag("solar_damaged"))
	var panel_color := Color("356d80") if not damaged else Color("2b2f36")
	draw_rect(Rect2(615, 467, 7, 35), Color("5b514c"))
	draw_rect(Rect2(747, 467, 7, 35), Color("5b514c"))
	draw_line(Vector2(620, 467), Vector2(683, 489), Color("a2957e"), 3.0)
	draw_line(Vector2(751, 467), Vector2(686, 489), Color("a2957e"), 3.0)
	draw_rect(Rect2(592, 438, 180, 37), Color("202d39"))
	draw_rect(Rect2(596, 442, 172, 29), panel_color)
	draw_rect(Rect2(598, 444, 168, 2), Color("91c1bd"))
	for i in range(1, 7):
		draw_rect(Rect2(596 + i * 24, 443, 2, 27), Color("86acb0"))
	draw_rect(Rect2(596, 455, 172, 2), Color("789fa5"))
	var dust: float = float(world.flag("solar_dust", 0.0))
	if dust > 1.0:
		draw_rect(Rect2(596, 442, 172, 29), Color(0.62, 0.36, 0.22, clampf(dust / 100.0, 0.0, 1.0) * 0.85))
	if bool(world.flag("solar_autoclean")):
		var wiper_x: float = 596.0 + fmod(animation_time * 40.0, 166.0)
		draw_rect(Rect2(wiper_x, 440, 4, 33), Color("e8d9b6"))
	draw_rect(Rect2(676, 479, 18, 14), Color("615850"))
	if bool(world.flag("flare_kit")):
		draw_rect(Rect2(776, 482, 22, 20), Color("3a3d40"))
		draw_rect(Rect2(779, 485, 16, 6), Color("e7c35a"))
	if damaged:
		if int(animation_time * 6.0) % 3 == 0:
			draw_rect(Rect2(660 + float(int(animation_time * 37.0) % 60), 446, 4, 4), Color("ffd27a"))
	else:
		draw_rect(Rect2(608, 447, 10, 4), Color("b9e0d6"))

func _draw_cave_crystals() -> void:
	for i in range(8):
		var x: float = 820.0 + float(i) * 72.0
		var y: float = 841.0 + float((i * 13) % 11)
		if x < 960.0 and bool(world.flag("ug_base")):
			continue
		draw_texture_rect_region(W.TILESET_TEXTURE, Rect2(x, y - 27.0, 24, 27), Rect2(64, 64, 32, 32))
		draw_rect(Rect2(x + 7.0, y - 4.0, 3, 4), Color(0.47, 0.95, 0.91, 0.55))

func _draw_underground_base() -> void:
	var base := W.UG_BASE_POSITION
	if not bool(world.flag("ug_base")):
		var blink: float = 0.55 + 0.45 * sin(animation_time * 3.0)
		for i in range(7):
			draw_rect(Rect2(base.x - 70 + i * 21, 859, 12, 3), Color(0.89, 0.54, 0.26, blink))
		draw_rect(Rect2(base.x - 72, 832, 4, 30), Color("e28a42"))
		draw_rect(Rect2(base.x + 68, 832, 4, 30), Color("e28a42"))
		return
	# Pressurised module with a curved roof.
	draw_rect(Rect2(base.x - 84, 794, 168, 70), Color("1d2226"))
	draw_rect(Rect2(base.x - 80, 798, 160, 64), Color("48545a"))
	draw_rect(Rect2(base.x - 80, 798, 160, 4), Color("7d8c92"))
	draw_colored_polygon(PackedVector2Array([Vector2(base.x - 84, 796), Vector2(base.x - 60, 782), Vector2(base.x + 60, 782), Vector2(base.x + 84, 796)]), Color("5c6a70"))
	draw_rect(Rect2(base.x - 60, 782, 120, 3), Color("9fb0b5"))
	for wx in [-68.0, 30.0]:
		draw_rect(Rect2(base.x + wx, 806, 38, 20), Color("22282b"))
		draw_rect(Rect2(base.x + wx + 2, 808, 34, 16), Color(1.0, 0.82, 0.5, 0.85))
		draw_rect(Rect2(base.x + wx + 2, 808, 34, 3), Color(1.0, 0.95, 0.8, 0.9))
	draw_rect(Rect2(base.x - 13, 818, 26, 44), Color("252d31"))
	draw_rect(Rect2(base.x - 10, 821, 20, 39), Color("6f9c97"))
	draw_rect(Rect2(base.x - 10, 821, 20, 3), Color(1, 1, 1, 0.3))
	for i in range(8):
		draw_rect(Rect2(base.x - 80 + i * 20, 840, 12, 2), Color("e28a42"))
	if bool(world.flag("reactor")):
		var pulse: float = 0.5 + 0.5 * sin(animation_time * 3.0)
		draw_rect(Rect2(base.x - 5, 786, 10, 12), Color("2b3438"))
		draw_circle(Vector2(base.x, 790), 7.0 + pulse * 3.0, Color(0.45, 1.0, 0.86, 0.35))
		draw_circle(Vector2(base.x, 790), 4.0, Color(0.75, 1.0, 0.95, 0.95))
	# Drill rig over the deep column.
	draw_rect(Rect2(1142, 834, 84, 8), Color("4d453d"))
	draw_rect(Rect2(1142, 834, 84, 2), Color("8b7c66"))
	draw_line(Vector2(1146, 834), Vector2(1172, 790), Color("6b6158"), 4.0)
	draw_line(Vector2(1222, 834), Vector2(1196, 790), Color("6b6158"), 4.0)
	draw_rect(Rect2(1166, 784, 36, 8), Color("e28a42"))
	var spin: float = animation_time * 4.0
	draw_line(Vector2(1184, 792), Vector2(1184, 792) + Vector2(cos(spin), sin(spin) * 0.3) * 10.0, Color("c9c2b4"), 2.0)

func _draw_explore_zones() -> void:
	if not bool(world.flag("points_active")):
		return
	for zone_id in W.EXPLORE_ZONES.keys():
		var zone: Dictionary = W.EXPLORE_ZONES[zone_id]
		var zone_pos: Vector2 = zone["pos"]
		if zone_id == "deep_hollows" and not world.deep_unlocked():
			continue
		var done: bool = world._explored(str(zone_id))
		var flag_color := Color("6fd39a") if done else Color("f0a05b")
		if not done:
			# Faint scan radius on the ground.
			var r: float = float(zone["radius"])
			var pulse: float = fmod(animation_time * 0.6, 1.0)
			draw_line(zone_pos + Vector2(-r * pulse, 24), zone_pos + Vector2(r * pulse, 24), Color(flag_color.r, flag_color.g, flag_color.b, 0.5 * (1.0 - pulse)), 2.0)
		draw_rect(Rect2(zone_pos.x - 2, zone_pos.y - 34, 3, 58), Color("8a7f72"))
		var wave: float = sin(animation_time * 4.0) * 2.0
		draw_colored_polygon(PackedVector2Array([zone_pos + Vector2(1, -34), zone_pos + Vector2(24, -29 + wave), zone_pos + Vector2(1, -21)]), flag_color)
		draw_rect(Rect2(zone_pos.x - 4, zone_pos.y - 37, 7, 3), Color("c9c2b4"))

func _draw_discoveries() -> void:
	if not bool(world.flag("points_active")):
		return
	for discovery_id in W.DISCOVERIES.keys():
		if world._discovered(str(discovery_id)):
			continue
		var entry: Dictionary = W.DISCOVERIES[discovery_id]
		var pos: Vector2 = entry["pos"]
		var pulse: float = 0.5 + 0.5 * sin(animation_time * 3.0 + pos.x * 0.01)
		var tint := Color(1.0, 0.85, 0.45)
		if discovery_id == "arcadium":
			tint = Color(0.45, 1.0, 0.86)
		elif discovery_id == "rubrium":
			tint = Color(1.0, 0.35, 0.32)
		match str(discovery_id):
			"rover":
				draw_rect(Rect2(pos.x - 28, pos.y + 6, 56, 4), Color(0, 0, 0, 0.3))
				draw_rect(Rect2(pos.x - 26, pos.y - 6, 52, 14), Color("5d5a55"))
				draw_rect(Rect2(pos.x - 26, pos.y - 6, 52, 3), Color("9a958a"))
				draw_rect(Rect2(pos.x - 20, pos.y - 18, 24, 12), Color("7b776d"))
				draw_rect(Rect2(pos.x - 16, pos.y - 15, 10, 5), Color("2f4650"))
				draw_rect(Rect2(pos.x + 8, pos.y - 26, 2, 20), Color("6b6158"))
				draw_rect(Rect2(pos.x + 4, pos.y - 28, 10, 3), Color("9a958a"))
				for wx in [-18.0, 0.0, 18.0]:
					draw_circle(Vector2(pos.x + wx, pos.y + 10), 5.5, Color("232325"))
					draw_circle(Vector2(pos.x + wx, pos.y + 10), 2.0, Color("6d6a64"))
			"meteorite":
				draw_circle(pos + Vector2(0, 10), 12.0, Color("3c3433"))
				draw_circle(pos + Vector2(-3, 7), 8.0, Color("554a47"))
				draw_rect(Rect2(pos.x - 6, pos.y + 2, 6, 3), Color("b9b2a7"))
				draw_rect(Rect2(pos.x + 3, pos.y + 9, 3, 2), Color("8d867c"))
			"fossil":
				draw_rect(Rect2(pos.x - 14, pos.y + 2, 28, 12), Color("4a3f3a"))
				for k in range(4):
					draw_arc(pos + Vector2(-6 + k * 4, 9), 3.0 + k, PI, TAU, 6, Color("c9b89c"), 1.0)
			_:
				draw_rect(Rect2(pos.x - 9, pos.y - 2, 18, 18), Color("2b2530"))
				draw_rect(Rect2(pos.x - 5, pos.y - 8, 4, 10), tint.darkened(0.3))
				draw_rect(Rect2(pos.x + 1, pos.y - 12, 5, 14), tint)
		# Holographic scan marker.
		var bob: float = sin(animation_time * 2.4 + pos.x) * 3.0
		var m := pos + Vector2(0, -36 + bob)
		draw_colored_polygon(PackedVector2Array([m + Vector2(0, -7), m + Vector2(6, 0), m + Vector2(0, 7), m + Vector2(-6, 0)]), Color(tint.r, tint.g, tint.b, 0.55 + 0.35 * pulse))
		draw_polyline(PackedVector2Array([m + Vector2(0, -10), m + Vector2(9, 0), m + Vector2(0, 10), m + Vector2(-9, 0), m + Vector2(0, -10)]), Color(tint.r, tint.g, tint.b, 0.35 * pulse), 1.0)
		draw_line(m + Vector2(0, 10), pos + Vector2(0, -4), Color(tint.r, tint.g, tint.b, 0.18), 1.0)

func _draw_dust_storm() -> void:
	draw_rect(Rect2(0, -200, W.WORLD_WIDTH, W.SURFACE_Y + 202), Color(0.74, 0.40, 0.22, 0.38))
	for i in range(48):
		var sx: float = float((i * 137 + 53) % W.WORLD_WIDTH)
		var sy: float = float((i * 47 + 24) % 500)
		var drift: float = fmod(animation_time * (85.0 + float(i % 5) * 18.0), 140.0)
		draw_rect(Rect2(sx + drift - 60.0, sy, 34.0 + float(i % 4) * 9.0, 2.0), Color(0.98, 0.62, 0.40, 0.45))
		if i % 4 == 0:
			draw_rect(Rect2(sx + drift - 18.0, sy + 4.0, 5, 2), Color(1.0, 0.78, 0.53, 0.40))

func _draw_solar_flare() -> void:
	var flicker: float = 0.12 + 0.10 * absf(sin(animation_time * 9.0))
	draw_rect(Rect2(0, -200, W.WORLD_WIDTH, W.SURFACE_Y + 202), Color(0.85, 0.55, 1.0, flicker))
	for i in range(14):
		var x: float = float((i * 211 + 90) % W.WORLD_WIDTH)
		var seg_len: float = 80.0 + float((i * 37) % 120)
		var y0: float = fmod(animation_time * 300.0 + float(i) * 70.0, 600.0) - 200.0
		draw_line(Vector2(x, y0), Vector2(x - 20.0, y0 + seg_len), Color(0.95, 0.85, 1.0, 0.35), 2.0)
