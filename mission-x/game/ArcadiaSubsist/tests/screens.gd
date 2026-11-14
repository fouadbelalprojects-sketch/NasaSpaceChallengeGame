extends SceneTree
var main
var c
var out_dir: String = "/tmp"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	_run()
func frames(n: int) -> void:
	for i in range(n):
		await process_frame
func shot(name: String, pos: Vector2, hide_toast: bool = true, mining: bool = false) -> void:
	main.player.global_position = pos
	main.player.velocity = Vector2.ZERO
	await frames(2)
	main.camera.reset_smoothing()
	main.stats["oxygen"] = 88.0
	main.stats["heat"] = 92.0
	main.stats["battery"] = 76.0
	if hide_toast:
		main.hud.toast_timer = 0.01
	if mining:
		var target_world := Vector2(26 * 32 + 16, 18 * 32 + 16)
		var mm := InputEventMouseMotion.new()
		mm.position = main.get_viewport().get_canvas_transform() * target_world
		mm.global_position = mm.position
		Input.parse_input_event(mm)
		main.get_viewport().warp_mouse(mm.position)
		await frames(3)
		Input.action_press("mine")
	for i in range(60):
		if mining:
			var mm2 := InputEventMouseMotion.new()
			mm2.position = main.get_viewport().get_canvas_transform() * Vector2(26 * 32 + 16, 18 * 32 + 16)
			Input.parse_input_event(mm2)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	Input.action_release("mine")
	print("saved ", name)
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(5)
	c = main.campaign
	main._on_new_game_requested()
	await frames(5)
	main.intro_cutscene._finish_cutscene()
	await frames(30)
	await shot("01_landing_banner", Vector2(300, 488), false)
	main.hud.banner_timer = 0.01
	main.world.wreck_salvaged = true
	c.flags["beacons"] = [true, true, false]
	c.debug_skip_to("a1_dome2")
	main.stats["regolith"] = 7
	main.stats["metal"] = 2
	c.time_of_day = 0.85
	await shot("02_night_phase1", Vector2(470, 488))
	c.time_of_day = 0.45
	c.debug_skip_to("a1_hide")
	await frames(5)
	# cut a mining hole for a nice shot
	for cell in [Vector2i(24,17), Vector2i(25,17)]:
		main.world._remove_tile(cell, true)
	await shot("03_day_mining", Vector2(790, 488), true, true)
	c.debug_skip_to("a2_research")
	c.time_of_day = 0.3
	c.points = 17
	c.flags["solar_dust"] = 55.0
	await shot("04_act2_day", Vector2(640, 488))
	c.time_of_day = 0.66
	await shot("05_blue_sunset", Vector2(1300, 488))
	c.debug_skip_to("a2_storm")
	c.time_of_day = 0.3
	c.event_timer = 0.01
	await frames(10)
	await shot("06_dust_storm", Vector2(560, 488))
	c.debug_skip_to("a3_flare")
	c.flags["farm_state"] = "growing"
	c.flags["farm_growth"] = 0.7
	main.stats["water"] = 3
	main.stats["food"] = 4
	c.time_of_day = 0.85
	await shot("07_act3_night_colony", Vector2(430, 488))
	c.time_of_day = 0.4
	c.event_timer = 0.01
	await frames(10)
	await shot("08_flare", Vector2(430, 488))
	c.debug_skip_to("a4_titanium")
	c.time_of_day = 0.3
	main.stats["titanium"] = 4
	await shot("09_cavern_base", Vector2(980, 840))
	c.debug_skip_to("a5_mine")
	c.flags["discovered"] = {"rover": true, "meteorite": true}
	await shot("10_deep_hollows", Vector2(600, 1350))
	c.debug_skip_to("a5_lattice")
	main.stats["rubrium"] = 5
	main.stats["titanium"] = 3
	main.stats["metal"] = 3
	c.flags["reactor"] = true
	c._complete_build()
	await shot("11_victory", Vector2(470, 488))
	quit()
