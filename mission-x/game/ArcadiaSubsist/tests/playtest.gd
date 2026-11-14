extends SceneTree
# Headless playthrough: godot --headless --path . -s res://tests/playtest.gd

var main
var c
var failures: int = 0

func _initialize() -> void:
	_run()

func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func frames(n: int) -> void:
	for i in range(n):
		await process_frame

func wait(seconds: float) -> void:
	var end: float = Time.get_ticks_msec() / 1000.0 + seconds / Engine.time_scale
	while Time.get_ticks_msec() / 1000.0 < end:
		await process_frame

func goto(pos: Vector2) -> void:
	main.player.global_position = pos
	main.player.velocity = Vector2.ZERO
	await frames(3)

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(2)

func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await wait(seconds)
	Input.action_release(action)
	await frames(2)

func give(items: Dictionary) -> void:
	for k in items.keys():
		main.stats[k] = int(main.stats[k]) + int(items[k])

func sid() -> String:
	return str(c.step()["id"])

func keep_alive() -> void:
	main.stats["oxygen"] = 100.0
	main.stats["heat"] = 100.0
	main.stats["battery"] = maxf(60.0, float(main.stats["battery"]))
	main.stats["nutrition"] = 100.0

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await frames(5)
	c = main.campaign
	main._on_new_game_requested()
	await frames(5)
	main.intro_cutscene._finish_cutscene()
	await frames(20)
	Engine.time_scale = 6.0

	print("ACT I")
	check(sid() == "a1_salvage", "starts at salvage")
	await goto(Vector2(150, 488))
	await tap("interact")
	check(main.stats["metal"] == 4 and main.stats["electronics"] == 3, "lander salvage rewards")
	check(sid() == "a1_secure", "advanced to secure site")
	for p in main.world.STAKE_POSITIONS:
		await goto(p)
		await tap("interact")
	check(sid() == "a1_dome1", "3 beacons -> dome phase 1")

	# Real mining on the surface (cell 20,16 is regolith next to (640,490)).
	await goto(Vector2(640, 488))
	var before: int = int(main.stats["regolith"])
	main.world.mine_at(Vector2(20 * 32 + 16, 16 * 32 + 16), main.player.global_position)
	check(int(main.stats["regolith"]) == before + 1, "mining a regolith tile")
	check(c.points == 0, "no RP before act II")

	give({"regolith": 6})
	await goto(Vector2(430, 488))
	await hold("build", 4.0)
	check(sid() == "a1_dome2" and int(c.flags["dome_stage"]) == 1 and bool(c.flags["o2_gen"]), "dome phase 1 built (O2 generator ready)")
	give({"regolith": 10, "metal": 3})
	await hold("build", 4.0)
	check(sid() == "a1_dome2", "phase 2 blocked on the same sol")
	check(c.waiting_for_tomorrow(), "waiting for tomorrow")
	await goto(Vector2(150, 488))
	var sol_before: int = c.sol
	await tap("rest")
	check(c.sol == sol_before + 1, "rest in lander -> next sol")
	await goto(Vector2(430, 488))
	await hold("build", 4.0)
	check(sid() == "a1_dome3" and int(c.flags["dome_stage"]) == 2, "dome phase 2 built on sol 2")
	await goto(Vector2(150, 488))
	await tap("rest")
	give({"ice": 2, "metal": 2, "electronics": 1})
	await goto(Vector2(430, 488))
	await hold("build", 4.0)
	check(sid() == "a1_hide" and bool(c.flags["fuel_cell"]), "dome phase 3 (fuel cell) built on sol 3")
	await goto(Vector2(150, 488))
	await tap("rest")
	check(sid() == "a1_activate", "hid in ship -> landing survived")
	check(main.hud.banner_title.text == "LANDING SURVIVED", "landing banner shown")
	await goto(Vector2(430, 488))
	await tap("interact")
	check(bool(c.flags["dome_sealed"]) and sid() == "a1_shelter", "dome sealed")
	c.time_of_day = 0.3
	await tap("rest")
	check(sid() == "a1_shelter", "cannot finish first dome sol before dusk")
	c.time_of_day = 0.66
	await tap("rest")
	check(sid() == "a2_solar" and c.act() == 2, "first sol in dome survived -> ACT II")
	check(bool(c.flags["points_active"]), "research points online")

	print("ACT II")
	give({"metal": 4, "regolith": 4, "electronics": 1})
	await goto(Vector2(690, 488))
	await hold("build", 4.0)
	check(bool(c.flags["solar_built"]) and sid() == "a2_research", "solar array built")
	c.flags["solar_dust"] = 50.0
	await tap("interact")
	check(float(c.flags["solar_dust"]) < 1.0, "manual dust wipe")
	await goto(Vector2(1390, 486))
	await tap("interact")
	await wait(7.0)
	check(c.points == 5 and c.explored_count() == 1, "exploration scan +5")
	await goto(Vector2(1935, 486))
	await tap("interact")
	await wait(7.0)
	check(c.points == 10 and c.explored_count() == 2, "second exploration scan")
	await goto(Vector2(1720, 488))
	await tap("interact")
	check(c.points == 20, "discovery +10 (rover)")
	await goto(Vector2(640, 488))
	var rp_before: int = c.points
	main.world.mine_at(Vector2(21 * 32 + 16, 16 * 32 + 16), main.player.global_position)
	check(c.points == rp_before + 1, "mining regolith +1 RP")
	await goto(Vector2(1505, 494))
	await tap("interact")
	check(sid() == "a2_upgrade", "2 scans + 30 RP -> upgrade step")
	give({"metal": 2, "electronics": 1, "regolith": 3})
	await goto(Vector2(690, 488))
	await hold("build", 4.0)
	check(bool(c.flags["solar_autoclean"]) and sid() == "a2_storm", "auto-cleaning installed, storm incoming")
	await goto(Vector2(430, 488))
	await wait(13.0)
	check(c.storm_active(), "dust storm active")
	check(c.solar_efficiency() > 0.0 or c.daylight() == 0.0, "self-cleaning panels still produce in the storm")
	var storm_deaths_ok: bool = true
	await wait(46.0)
	check(sid() == "a3_water" and c.act() == 3, "storm survived -> ACT III")
	check(bool(c.flags["hunger_active"]) and int(main.stats["food"]) >= 2, "hunger active + 2 ration packs")

	print("ACT III")
	keep_alive()
	give({"ice": 6})
	await frames(3)
	check(sid() == "a3_purifier", "6 water crystals")
	give({"metal": 3, "electronics": 1, "regolith": 2})
	await hold("build", 4.0)
	check(bool(c.flags["purifier"]) and sid() == "a3_purify", "purifier built")
	await tap("interact")
	await tap("interact")
	check(int(main.stats["water"]) >= 4 and sid() == "a3_farm", "purified ice into water")
	give({"metal": 3, "regolith": 6})
	await hold("build", 4.0)
	check(bool(c.flags["farm"]) and sid() == "a3_grow", "hydroponics built")
	await tap("interact")
	check(str(c.flags["farm_state"]) == "growing", "planted")
	keep_alive()
	await wait(52.0)
	keep_alive()
	await tap("interact")
	check(c.harvests == 1 and sid() == "a3_shield", "harvested food")
	main.stats["nutrition"] = 30.0
	var food_before: int = int(main.stats["food"])
	await tap("eat")
	check(int(main.stats["food"]) == food_before - 1 and float(main.stats["nutrition"]) > 60.0, "eating restores nutrition")
	give({"regolith": 10, "metal": 2})
	await hold("build", 4.0)
	check(bool(c.flags["shield"]) and sid() == "a3_plan", "dome shield built")
	give({"metal": 2, "electronics": 1})
	c.points = maxi(c.points, 60)
	await goto(Vector2(690, 488))
	await hold("build", 4.0)
	check(bool(c.flags["flare_kit"]) and sid() == "a3_flare", "surge breakers built, flare inbound")
	await goto(Vector2(430, 488))
	keep_alive()
	main.stats["radiation"] = 0.0
	await wait(16.0)
	check(c.flare_active(), "flare active")
	await wait(10.0)
	check(float(main.stats["radiation"]) < 5.0, "shielded dome keeps radiation low (%.1f)" % float(main.stats["radiation"]))
	keep_alive()
	await wait(32.0)
	check(sid() == "a3_recover" and bool(c.flags["solar_damaged"]), "flare passed, array tripped")
	await goto(Vector2(690, 488))
	await hold("build", 5.0)
	check(not bool(c.flags["solar_damaged"]) and c.act() == 4, "array rebooted -> ACT IV")

	print("ACT IV")
	keep_alive()
	give({"regolith": 15, "metal": 6, "electronics": 2, "water": 3})
	await goto(Vector2(850, 840))
	await hold("build", 3.0)
	check(sid() == "a4_base", "base blocked until the cavern roof has been monitored a sol")
	await goto(Vector2(430, 488))
	c.time_of_day = 0.3
	await tap("rest")
	check(c.sol >= c.act_start_sol + 1, "rest allowed while waiting for tomorrow")
	await goto(Vector2(850, 840))
	await hold("build", 6.0)
	check(bool(c.flags["ug_base"]) and sid() == "a4_titanium", "underground base built")
	check(not main.world.tiles.has(Vector2i(36, 30)), "deep drill shaft opened")
	check(main.world.is_on_ladder(Vector2(1184, 1000)), "deep ladder active")
	check(c.shelter_at(Vector2(850, 840)) == "ug_base", "underground base is a shelter")
	# Real deep mining: find a titanium tile next to the shaft.
	var ti_cell := Vector2i(-1, -1)
	for cell in main.world.tiles.keys():
		if str(main.world.tiles[cell]) == "titanium" and cell.y < 39 and absf((cell.x + 0.5) * 32.0 - 1184.0) < 70.0:
			ti_cell = cell
			break
	if ti_cell.x >= 0:
		await goto(Vector2(1184, ti_cell.y * 32 + 16))
		var ti_before: int = int(main.stats["titanium"])
		main.world.mine_at(Vector2(ti_cell.x * 32 + 16, ti_cell.y * 32 + 16), main.player.global_position)
		check(int(main.stats["titanium"]) == ti_before + 1, "mined titanium in the deep strata")
	keep_alive()
	give({"titanium": 10})
	await frames(3)
	check(sid() == "a4_enhance", "stack of titanium collected")
	give({"metal": 4, "titanium": 10})
	await goto(Vector2(430, 488))
	await hold("build", 5.0)
	check(bool(c.flags["reinforced"]) and c.act() == 5, "titanium frame -> ACT V")

	print("ACT V")
	keep_alive()
	await goto(Vector2(560, 1350))
	var blocked: bool = not main.world.mine_at(Vector2(14 * 32 + 16, 43 * 32 + 16), main.player.global_position)
	check(blocked, "unknown crystal cannot be mined before analysis")
	await goto(Vector2(520, 1350))
	await tap("interact")
	await goto(Vector2(1555, 1350))
	await tap("interact")
	check(sid() == "a5_mine", "both new elements discovered")
	await goto(Vector2(500, 1354))
	var ar_before: int = int(main.stats["arcadium"])
	main.world.mine_at(Vector2(14 * 32 + 16, 43 * 32 + 16), main.player.global_position)
	check(int(main.stats["arcadium"]) == ar_before + 1, "mined arcadium after analysis")
	keep_alive()
	give({"arcadium": 5, "rubrium": 5})
	await frames(3)
	check(sid() == "a5_reactor", "elements collected")
	give({"arcadium": 5, "titanium": 3, "electronics": 2})
	c.points = maxi(c.points, 120)
	await goto(Vector2(850, 840))
	await hold("build", 6.0)
	check(bool(c.flags["reactor"]) and sid() == "a5_lattice", "arcadium reactor built")
	give({"rubrium": 5, "titanium": 3, "metal": 3})
	await goto(Vector2(430, 488))
	await hold("build", 6.0)
	check(c.victory and is_instance_valid(main.hud.overlay_panel), "rubrium lattice -> VICTORY")

	print("SAVE / LOAD")
	main.save_game()
	var saved_step: int = c.step_index
	var saved_points: int = c.points
	main._reset_expedition()
	check(c.step_index == 0, "reset clears campaign")
	check(main._load_game(), "load succeeds")
	check(c.step_index == saved_step and c.points == saved_points and bool(c.flags["reactor"]), "campaign restored")
	check(not main.world.tiles.has(Vector2i(36, 30)), "deep shaft open after load")
	check(main.world.colony == c.flags, "world sees restored colony flags")

	print("LADDER")
	main._close_overlay()
	Engine.time_scale = 1.0
	await goto(Vector2(1024, 820))
	Input.action_press("move_up")
	await wait(3.0)
	Input.action_release("move_up")
	check(main.player.global_position.y < 470.0, "climbed the shaft ladder (y=%.0f)" % main.player.global_position.y)
	Input.action_press("move_left")
	await wait(0.6)
	Input.action_release("move_left")
	await wait(0.8)
	check(main.player.global_position.y < 500.0 and main.player.global_position.x < 960.0, "stepped off onto the surface (%.0f, %.0f)" % [main.player.global_position.x, main.player.global_position.y])

	await goto(Vector2(1184, 1350))
	Input.action_press("move_up")
	await wait(4.0)
	Input.action_release("move_up")
	Input.action_press("move_right")
	await wait(0.5)
	Input.action_release("move_right")
	await wait(0.6)
	check(main.player.global_position.y < 850.0 and main.player.global_position.y > 780.0, "climbed out of the deep hollows into the cavern (y=%.0f)" % main.player.global_position.y)

	print("DEATH / RESPAWN")
	main.stats["oxygen"] = 0.0
	await frames(3)
	check(float(main.stats["oxygen"]) > 50.0, "respawned after oxygen death")

	print("\nRESULT: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
