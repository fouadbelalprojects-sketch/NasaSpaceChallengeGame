extends Node2D

const WORLD_SCRIPT = preload("res://scripts/world.gd")
const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const INTRO_SCRIPT = preload("res://scripts/intro_cutscene.gd")
const MENU_SCRIPT = preload("res://scripts/main_menu.gd")
const CAMPAIGN_SCRIPT = preload("res://scripts/campaign.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")
const SKY_SCRIPT = preload("res://scripts/sky.gd")
const SAVE_PATH: String = "user://arcadia_subsist_save.json"
const SAVE_VERSION: int = 2
const AUTOSAVE_INTERVAL: float = 30.0
const RECALL_COOLDOWN: float = 25.0
const DOME_SPAWN: Vector2 = Vector2(430, 490)
const LANDER_SPAWN: Vector2 = Vector2(165, 490)
const UG_SPAWN: Vector2 = Vector2(850, 840)

const COMMON_RESOURCES: Array[String] = ["regolith", "ice", "metal", "water"]
const DEFAULT_STATS: Dictionary = {
	"oxygen": 100.0, "battery": 100.0, "heat": 100.0, "radiation": 0.0, "pressure": 0.0, "nutrition": 100.0,
	"regolith": 0, "ice": 0, "metal": 0, "electronics": 0, "water": 0, "food": 0,
	"titanium": 0, "arcadium": 0, "rubrium": 0
}

var world
var player
var campaign
var day_tint: CanvasModulate
var heater_on: bool = true
var intro_active: bool = false
var menu_active: bool = true
var autosave_timer: float = 0.0
var menu_layer
var intro_resume_lock: float = 0.0
var intro_cutscene
var respawn_lock: float = 0.0
var recall_cooldown: float = 0.0
var fuel_warned: bool = false
var stats: Dictionary = DEFAULT_STATS.duplicate(true)

var hud
var hud_root: Control
var sky
var ambient_motes: CPUParticles2D
var storm_wind: CPUParticles2D
var camera: Camera2D

func _ready() -> void:
	_setup_input_map()
	_build_world()
	campaign = CAMPAIGN_SCRIPT.new(self, world)
	_build_hud()

	player.visible = false
	player.set_physics_process(false)
	world.set_process(false)
	hud_root.visible = false

	menu_layer = MENU_SCRIPT.new()
	menu_layer.new_game_requested.connect(_on_new_game_requested)
	menu_layer.continue_requested.connect(_on_continue_requested)
	menu_layer.resume_requested.connect(_on_resume_requested)
	menu_layer.save_and_menu_requested.connect(_on_save_and_menu_requested)
	menu_layer.quit_requested.connect(_on_quit_requested)
	add_child(menu_layer)
	menu_layer.show_main_menu(FileAccess.file_exists(SAVE_PATH))

# ---------------------------------------------------------------- flow

func _on_new_game_requested() -> void:
	_reset_expedition()
	menu_active = false
	world.set_process(true)
	menu_layer.close_menu()
	_start_intro()

func _start_intro() -> void:
	intro_active = true
	player.visible = false
	player.set_physics_process(false)
	hud_root.visible = false
	intro_cutscene = INTRO_SCRIPT.new()
	intro_cutscene.finished.connect(_on_intro_finished)
	add_child(intro_cutscene)

func _on_intro_finished() -> void:
	intro_active = false
	intro_resume_lock = 0.15
	if is_instance_valid(player):
		player.visible = true
		player.set_physics_process(false)
	if is_instance_valid(hud_root):
		hud_root.visible = true
	show_banner("ACT I // THE LANDING", "Secure the landing zone, then build the dome over three sols.")
	show_toast("SOL 1 // ARCADIA PLANITIA — SALVAGE THE LANDER AND SECURE THE SITE", 5.0)
	save_game()

func _on_continue_requested() -> void:
	var loaded: bool = _load_game()
	menu_active = false
	world.set_process(true)
	menu_layer.close_menu()
	if not loaded:
		_reset_expedition()
		_start_intro()
		return
	intro_active = false
	player.visible = true
	player.set_physics_process(true)
	hud_root.visible = true
	show_toast("EXPEDITION RESTORED // SOL %d — %s" % [campaign.sol, campaign.act_label()], 3.5)

func _on_resume_requested() -> void:
	menu_active = false
	world.set_process(true)
	menu_layer.close_menu()
	hud_root.visible = true
	if not intro_active:
		player.visible = true
		player.set_physics_process(true)

func _on_save_and_menu_requested() -> void:
	save_game()
	menu_active = true
	world.set_process(false)
	player.visible = false
	player.set_physics_process(false)
	hud_root.visible = false
	menu_layer.show_main_menu(true)

func _on_quit_requested() -> void:
	if not intro_active and campaign.sol >= 1 and hud_root.visible:
		save_game()
	get_tree().quit()

func _open_pause_menu() -> void:
	menu_active = true
	world.set_process(false)
	player.set_physics_process(false)
	hud_root.visible = false
	menu_layer.show_pause_menu()

func _reset_expedition() -> void:
	heater_on = true
	intro_active = false
	intro_resume_lock = 0.0
	respawn_lock = 0.0
	recall_cooldown = 0.0
	autosave_timer = 0.0
	fuel_warned = false
	stats = DEFAULT_STATS.duplicate(true)
	world.reset_world()
	campaign.reset()
	player.position = Vector2(640, 490)
	player.velocity = Vector2.ZERO
	_close_overlay()

# ---------------------------------------------------------------- save / load

func save_game() -> void:
	if not is_instance_valid(world) or not is_instance_valid(player):
		return
	var save_data: Dictionary = {
		"save_version": SAVE_VERSION,
		"stats": stats.duplicate(true),
		"heater_on": heater_on,
		"player_position": [player.position.x, player.position.y],
		"campaign": campaign.get_save_state(),
		"world": world.get_save_state()
	}
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()
		autosave_timer = 0.0

func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return false
	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	if int(data.get("save_version", 1)) < SAVE_VERSION:
		return false # saves from the pre-campaign prototype are not compatible
	_reset_expedition()
	var saved_stats: Variant = data.get("stats", {})
	if saved_stats is Dictionary:
		for stat_name in stats.keys():
			if (saved_stats as Dictionary).has(stat_name):
				var value: Variant = saved_stats[stat_name]
				stats[stat_name] = int(value) if DEFAULT_STATS[stat_name] is int else float(value)
	heater_on = bool(data.get("heater_on", true))
	var saved_campaign: Variant = data.get("campaign", {})
	if saved_campaign is Dictionary:
		campaign.restore_save_state(saved_campaign)
	var saved_world: Variant = data.get("world", {})
	if saved_world is Dictionary:
		world.restore_save_state(saved_world)
	world.set_storm_active(campaign.storm_active())
	world.set_flare_active(campaign.flare_active())
	var saved_position: Variant = data.get("player_position", [640.0, 490.0])
	if saved_position is Array and (saved_position as Array).size() >= 2:
		player.position = Vector2(float(saved_position[0]), float(saved_position[1]))
		player.velocity = Vector2.ZERO
	fuel_warned = float(campaign.flags.get("fuel", 0.0)) <= 0.0
	return true

# ---------------------------------------------------------------- input & world

func _setup_input_map() -> void:
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_up", KEY_UP)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_down", KEY_DOWN)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("mine", KEY_F)
	_add_key_action("interact", KEY_E)
	_add_key_action("build", KEY_R)
	_add_key_action("heater", KEY_H)
	_add_key_action("rest", KEY_Z)
	_add_key_action("eat", KEY_Q)
	_add_key_action("recall", KEY_T)
	_add_key_action("pause", KEY_ESCAPE)

func _add_key_action(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)

func _build_world() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	sky_layer.follow_viewport_enabled = true
	add_child(sky_layer)
	sky = SKY_SCRIPT.new()
	sky_layer.add_child(sky)

	world = WORLD_SCRIPT.new()
	add_child(world)
	world.tile_broken.connect(_on_tile_broken)
	world.resource_mined.connect(_on_resource_mined)
	world.mine_blocked.connect(_on_mine_blocked)

	player = PLAYER_SCRIPT.new()
	player.world = world
	player.position = Vector2(640, 490)
	add_child(player)

	camera = Camera2D.new()
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.5
	camera.limit_left = 0
	camera.limit_right = world.WORLD_WIDTH
	camera.limit_top = 0
	camera.limit_bottom = world.WORLD_BOTTOM + 220
	player.add_child(camera)

	day_tint = CanvasModulate.new()
	add_child(day_tint)
	_build_ambient_particles()

func _process(delta: float) -> void:
	if menu_active or intro_active:
		return
	if intro_resume_lock > 0.0:
		intro_resume_lock = maxf(0.0, intro_resume_lock - delta)
		if intro_resume_lock <= 0.0 and is_instance_valid(player):
			player.set_physics_process(true)
		return

	if Input.is_action_just_pressed("pause"):
		_open_pause_menu()
		return

	autosave_timer += delta
	if autosave_timer >= AUTOSAVE_INTERVAL:
		save_game()
	respawn_lock = maxf(0.0, respawn_lock - delta)
	recall_cooldown = maxf(0.0, recall_cooldown - delta)
	campaign.update(delta)

	if Input.is_action_just_pressed("heater"):
		heater_on = not heater_on
		show_toast("SUIT HEATER " + ("ONLINE" if heater_on else "OFFLINE"), 2.0)
	if Input.is_action_just_pressed("interact"):
		if not campaign.interact(player.global_position):
			show_toast("NOTHING TO DO HERE // MOVE CLOSER TO A MODULE, STAKE OR BEACON", 2.0)
	if Input.is_action_just_pressed("rest"):
		var refusal: String = campaign.try_rest(player.global_position)
		if refusal != "":
			show_toast(refusal, 3.0)
	if Input.is_action_just_pressed("eat"):
		_eat()
	if Input.is_action_just_pressed("recall"):
		_recall()

	var building: bool = campaign.update_build(delta, Input.is_action_pressed("build"), player.global_position)
	_update_survival(delta)
	_update_day_tint(delta)
	_update_atmosphere()
	if building:
		hud.set_action_progress(campaign.build_progress / campaign.build_hold_time(), player.global_position)
	elif campaign.scan_zone != "":
		hud.set_action_progress(campaign.scan_progress / campaign.SCAN_TIME, player.global_position)
	else:
		hud.set_action_progress(-1.0, Vector2.ZERO)
	hud.update(delta)
	world.update_mining_target(get_global_mouse_position(), player.global_position)

# ---------------------------------------------------------------- survival

func _shelter() -> String:
	return campaign.shelter_at(player.global_position)

func _is_underground() -> bool:
	return player.global_position.y > 700.0

func _update_survival(delta: float) -> void:
	var shelter: String = _shelter()
	var underground: bool = _is_underground()
	var exposed: bool = shelter == "" and not underground
	var storm: bool = campaign.storm_active()
	var flare: bool = campaign.flare_active()
	var night: bool = campaign.is_night()
	var flags: Dictionary = campaign.flags
	var powered: bool = float(stats["battery"]) > 0.0

	# Oxygen
	match shelter:
		"dome":
			if powered and float(stats["pressure"]) > 12.0:
				var refill: float = 5.2 * (1.4 if bool(flags["reinforced"]) else 1.0)
				stats["oxygen"] = minf(100.0, float(stats["oxygen"]) + refill * delta)
			else:
				stats["oxygen"] = maxf(0.0, float(stats["oxygen"]) - 0.3 * delta)
		"ug_base":
			stats["oxygen"] = minf(100.0, float(stats["oxygen"]) + 5.2 * delta)
		"lander":
			stats["oxygen"] = minf(100.0, float(stats["oxygen"]) + 1.6 * delta)
		_:
			var oxygen_rate: float = 0.48
			if storm and exposed:
				oxygen_rate = 0.82
			stats["oxygen"] = maxf(0.0, float(stats["oxygen"]) - oxygen_rate * delta)

	# Power: one shared colony + suit battery.
	var drain: float = 0.035
	if heater_on and shelter == "":
		drain += 0.22
		if exposed and (night or storm):
			drain += 0.10
	var charge: float = 0.0
	var solar: float = campaign.solar_efficiency()
	if bool(flags["fuel_cell"]) and bool(flags["dome_sealed"]) and float(flags["fuel"]) > 0.0:
		flags["fuel"] = maxf(0.0, float(flags["fuel"]) - 0.06 * delta)
		if shelter == "dome" or shelter == "ug_base":
			charge += 0.55
		if float(flags["fuel"]) <= 0.0 and not fuel_warned:
			fuel_warned = true
			show_toast("FUEL CELL DEPLETED // ONLY RENEWABLE POWER REMAINS", 5.0)
	match shelter:
		"dome", "ug_base":
			charge += solar * 1.1
			if bool(flags["reactor"]):
				charge += 2.0
		"lander":
			charge += 0.35
		_:
			if not underground:
				charge += solar * 0.25
			if bool(flags["reactor"]):
				charge += 0.3
	stats["battery"] = clampf(float(stats["battery"]) - drain * delta + charge * delta, 0.0, 100.0)

	# Heat
	if shelter != "":
		var warm: float = 0.6 if shelter == "lander" else 1.0
		if bool(flags["reinforced"]) and shelter == "dome":
			warm = 1.5
		stats["heat"] = minf(100.0, float(stats["heat"]) + warm * delta)
	elif heater_on and float(stats["battery"]) > 0.0:
		var net: float = 0.12
		if exposed and night:
			net = -0.32
		if exposed and storm:
			net = minf(net, -0.28)
		stats["heat"] = clampf(float(stats["heat"]) + net * delta, 0.0, 100.0)
	else:
		var cooling: float = 0.70 if not storm else 1.15
		if exposed and night:
			cooling *= 1.4
		if underground:
			cooling *= 0.78
		stats["heat"] = maxf(0.0, float(stats["heat"]) - cooling * delta)

	# Radiation
	var radiation_change: float = -0.03
	if flare:
		match shelter:
			"dome":
				if bool(flags["lattice"]):
					radiation_change = -0.22
				else:
					radiation_change = 0.05 if bool(flags["shield"]) else 1.1
			"ug_base":
				radiation_change = -0.22
			"lander":
				radiation_change = 0.6
			_:
				radiation_change = -0.10 if underground else 2.6
	elif storm and exposed:
		radiation_change = 0.15
	elif shelter != "" or underground:
		radiation_change = -0.22
	stats["radiation"] = clampf(float(stats["radiation"]) + radiation_change * delta, 0.0, 100.0)

	# Dome pressure
	if bool(flags["dome_sealed"]):
		if powered and bool(flags["o2_gen"]):
			stats["pressure"] = minf(100.0, float(stats["pressure"]) + 0.5 * delta)
		elif not bool(flags["reinforced"]):
			stats["pressure"] = maxf(0.0, float(stats["pressure"]) - 0.15 * delta)
	else:
		stats["pressure"] = 0.0

	# Hunger (from Act III, when the ration packs run out)
	if bool(flags["hunger_active"]):
		stats["nutrition"] = maxf(0.0, float(stats["nutrition"]) - 0.17 * delta)

	if float(stats["oxygen"]) <= 0.0:
		_handle_death("OXYGEN DEPLETED")
	elif float(stats["heat"]) <= 0.0:
		_handle_death("THERMAL FAILURE")
	elif float(stats["radiation"]) >= 100.0:
		_handle_death("RADIATION OVERLOAD")
	elif float(stats["nutrition"]) <= 0.0:
		_handle_death("STARVATION")

func _respawn_point() -> Dictionary:
	var flags: Dictionary = campaign.flags
	if bool(flags["ug_base"]) and _is_underground():
		return {"pos": UG_SPAWN, "name": "UNDERGROUND BASE"}
	if bool(flags["dome_sealed"]):
		return {"pos": DOME_SPAWN, "name": "PRESSURISED DOME"}
	return {"pos": LANDER_SPAWN, "name": "LANDER"}

func _handle_death(reason: String) -> void:
	if respawn_lock > 0.0:
		return
	for resource_name in COMMON_RESOURCES:
		stats[resource_name] = floori(float(stats[resource_name]) * 0.75)
	stats["oxygen"] = 72.0
	stats["battery"] = maxf(40.0, float(stats["battery"]))
	stats["heat"] = 72.0
	stats["radiation"] = 0.0
	stats["nutrition"] = maxf(45.0, float(stats["nutrition"]))
	var spawn: Dictionary = _respawn_point()
	player.global_position = spawn["pos"]
	player.velocity = Vector2.ZERO
	respawn_lock = 4.0
	show_toast("%s // EMERGENCY RETURN TO %s // 25%% OF COMMON CARGO LOST" % [reason, spawn["name"]], 6.0)

func on_slept(shelter: String) -> void:
	hud.fade_in_from_black()
	stats["heat"] = 100.0
	stats["oxygen"] = 100.0
	stats["radiation"] = maxf(0.0, float(stats["radiation"]) - 40.0)
	if shelter != "lander":
		stats["battery"] = minf(100.0, float(stats["battery"]) + 25.0)
	if bool(campaign.flags["hunger_active"]):
		stats["nutrition"] = maxf(8.0, float(stats["nutrition"]) - 12.0)
	save_game()

func _eat() -> void:
	if int(stats["food"]) <= 0:
		show_toast("NO FOOD // GROW CROPS IN THE HYDROPONICS BAY" if bool(campaign.flags["farm"]) else "NO FOOD IN YOUR PACK", 2.5)
		return
	if float(stats["nutrition"]) >= 95.0:
		show_toast("NOT HUNGRY // NUTRITION %d%%" % int(stats["nutrition"]), 2.0)
		return
	stats["food"] = int(stats["food"]) - 1
	stats["nutrition"] = minf(100.0, float(stats["nutrition"]) + 40.0)
	show_toast("ATE A MEAL // NUTRITION %d%%" % int(stats["nutrition"]), 2.5)

func _recall() -> void:
	if recall_cooldown > 0.0:
		show_toast("RECALL BEACON RECHARGING // %d s" % int(ceilf(recall_cooldown)), 2.0)
		return
	var flags: Dictionary = campaign.flags
	var target: Vector2 = LANDER_SPAWN
	var target_name: String = "LANDER"
	if bool(flags["ug_base"]) and _is_underground():
		target = UG_SPAWN
		target_name = "UNDERGROUND BASE"
	elif int(flags["dome_stage"]) >= 2:
		target = DOME_SPAWN
		target_name = "DOME"
	player.global_position = target
	player.velocity = Vector2.ZERO
	stats["battery"] = maxf(0.0, float(stats["battery"]) - 8.0)
	recall_cooldown = RECALL_COOLDOWN
	show_toast("RECALL BEACON // RETURNED TO THE %s (-8 POWER)" % target_name, 3.0)

func _on_resource_mined(resource_name: String, amount: int, tile_type: String) -> void:
	if not stats.has(resource_name):
		return
	stats[resource_name] = int(stats[resource_name]) + amount
	var line: String = "+%d %s" % [amount, str(campaign.RESOURCE_NAMES.get(resource_name, resource_name.to_upper()))]
	if bool(campaign.flags["points_active"]):
		var rp: int = world.rarity_points(tile_type)
		campaign.points += rp
		line += "   +%d RP" % rp
	show_toast(line, 1.4)

func _on_mine_blocked(reason: String) -> void:
	if hud.toast_timer > 0.0 and hud.toast_text == reason:
		return
	show_toast(reason, 2.5)

func _update_day_tint(delta: float) -> void:
	var light: float = campaign.light_level()
	var target := Color(1, 1, 1).lerp(Color(0.13, 0.15, 0.30), clampf((1.0 - light) / 0.8, 0.0, 1.0))
	if _is_underground():
		var depth: float = clampf((player.global_position.y - 700.0) / 500.0, 0.0, 1.0)
		target = Color(0.20, 0.19, 0.25).lerp(Color(0.10, 0.10, 0.15), depth)
	if campaign.flare_active() and not _is_underground():
		target = target.lerp(Color(1.0, 0.82, 1.0), 0.3 + 0.1 * sin(Time.get_ticks_msec() * 0.02))
	if campaign.storm_active() and not _is_underground():
		target = target.lerp(Color(0.78, 0.48, 0.34), 0.5)
	day_tint.color = day_tint.color.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	var darkness: float = clampf(1.0 - day_tint.color.v, 0.0, 1.0)
	player.darkness = darkness
	world.colony_back.light_scale = clampf(darkness * 1.3, 0.0, 1.0)

func _update_atmosphere() -> void:
	sky.time_of_day = campaign.time_of_day
	sky.daylight = campaign.daylight()
	sky.storm = lerpf(sky.storm, 1.0 if campaign.storm_active() else 0.0, 0.03)
	storm_wind.emitting = campaign.storm_active() and not _is_underground()
	ambient_motes.color = Color(0.6, 0.85, 0.9, 0.35) if _is_underground() else Color(1.0, 0.75, 0.55, 0.35)

func _build_ambient_particles() -> void:
	ambient_motes = CPUParticles2D.new()
	ambient_motes.amount = 60
	ambient_motes.lifetime = 7.0
	ambient_motes.preprocess = 7.0
	ambient_motes.local_coords = false
	ambient_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ambient_motes.emission_rect_extents = Vector2(700, 400)
	ambient_motes.direction = Vector2(1, -0.2)
	ambient_motes.spread = 40.0
	ambient_motes.gravity = Vector2.ZERO
	ambient_motes.initial_velocity_min = 4.0
	ambient_motes.initial_velocity_max = 14.0
	ambient_motes.scale_amount_min = 1.0
	ambient_motes.scale_amount_max = 2.0
	var mote_ramp := Gradient.new()
	mote_ramp.set_color(0, Color(1, 1, 1, 0))
	mote_ramp.add_point(0.3, Color(1, 1, 1, 1))
	mote_ramp.add_point(0.7, Color(1, 1, 1, 1))
	mote_ramp.set_color(mote_ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	ambient_motes.color_ramp = mote_ramp
	ambient_motes.z_index = 6
	camera.add_child(ambient_motes)

	storm_wind = CPUParticles2D.new()
	storm_wind.amount = 220
	storm_wind.lifetime = 1.6
	storm_wind.local_coords = false
	storm_wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	storm_wind.emission_rect_extents = Vector2(40, 420)
	storm_wind.position = Vector2(-720, 0)
	storm_wind.direction = Vector2(1, 0.08)
	storm_wind.spread = 6.0
	storm_wind.gravity = Vector2(0, 30)
	storm_wind.initial_velocity_min = 700.0
	storm_wind.initial_velocity_max = 1100.0
	storm_wind.scale_amount_min = 1.5
	storm_wind.scale_amount_max = 5.0
	storm_wind.color = Color(0.98, 0.70, 0.48, 0.75)
	storm_wind.emitting = false
	storm_wind.z_index = 8
	camera.add_child(storm_wind)

const BURST_COLORS: Dictionary = {
	"regolith": Color("c27a52"), "basalt": Color("4b485e"), "metal_scrap": Color("aab2b8"),
	"salvage": Color("4fbf7a"), "ice": Color("9be0ea"), "titanium": Color("e6eef8"),
	"arcadium": Color("5ff0d8"), "rubrium": Color("ff5a50")
}

func _on_tile_broken(world_position: Vector2, tile_type: String) -> void:
	var burst := CPUParticles2D.new()
	burst.position = world_position
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.amount = 16
	burst.lifetime = 0.7
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	burst.emission_rect_extents = Vector2(12, 12)
	burst.direction = Vector2(0, -1)
	burst.spread = 75.0
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 170.0
	burst.gravity = Vector2(0, 520)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	var col: Color = BURST_COLORS.get(tile_type, Color("c27a52"))
	if tile_type == "regolith" and world_position.y > 704:
		col = Color("6b4c48")
	var ramp := Gradient.new()
	ramp.set_color(0, col.lightened(0.25))
	ramp.set_color(1, Color(col, 0.0))
	burst.color_ramp = ramp
	burst.z_index = 6
	world.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)

# ---------------------------------------------------------------- HUD API used by the campaign

func show_toast(message: String, duration: float) -> void:
	if hud != null:
		hud.show_toast(message, duration)

func show_banner(title: String, subtitle: String) -> void:
	if hud != null:
		hud.show_banner(title, subtitle)

func show_victory() -> void:
	hud.show_victory(campaign.sol, campaign.points, _close_overlay, func() -> void:
		_close_overlay()
		_on_save_and_menu_requested())

func _close_overlay() -> void:
	if hud != null:
		hud.close_overlay()

func _build_hud() -> void:
	hud = HUD_SCRIPT.new()
	hud.setup(self)
	add_child(hud)
	hud_root = hud.root
