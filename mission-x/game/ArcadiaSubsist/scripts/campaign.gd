extends RefCounted
class_name ArcadiaCampaign
## Five-act story progression for Arcadia Subsist.
## Owns the sol (day/night) clock, research points, build steps, scripted events and colony flags.
## main.gd owns the survival simulation, input and HUD and calls into this object.

const SOL_LENGTH: float = 240.0      # real seconds per Martian sol
const DAWN: float = 0.04
const MORNING: float = 0.12
const DUSK: float = 0.62
const NIGHT: float = 0.72
const START_TIME: float = 0.08
const SCAN_TIME: float = 6.0
const FARM_GROW_TIME: float = 50.0
const POINTS_EXPLORE: int = 5
const POINTS_DISCOVER: int = 10

const ACTS: Dictionary = {
	1: ["ACT I", "THE LANDING"],
	2: ["ACT II", "RENEWABLE POWER"],
	3: ["ACT III", "WATER, FOOD & FLARES"],
	4: ["ACT IV", "UNDERGROUND"],
	5: ["ACT V", "NEW ELEMENTS"]
}

const EVENTS: Dictionary = {
	"dust_storm": {"warning": 12.0, "duration": 45.0, "name": "DUST STORM"},
	"solar_flare": {"warning": 15.0, "duration": 40.0, "name": "SOLAR FLARE"}
}

const RESOURCE_NAMES: Dictionary = {
	"regolith": "REGOLITH", "ice": "ICE", "metal": "METAL", "electronics": "CONTROL BOARD",
	"water": "WATER", "food": "FOOD", "titanium": "TITANIUM", "arcadium": "ARCADIUM", "rubrium": "RUBRIUM"
}

const STEPS: Array = [
	# ---------------- ACT I — THE LANDING
	{"id": "a1_salvage", "act": 1, "type": "salvage", "title": "SALVAGE THE LANDER",
		"text": "Your lander is crippled but its cargo bay is intact. Walk to it (far left) and press E to strip metal and control boards."},
	{"id": "a1_secure", "act": 1, "type": "beacons", "title": "SECURE THE LANDING ZONE",
		"text": "Before building anything, confirm the ground is stable. Press E at the three orange survey stakes around the dome site."},
	{"id": "a1_dome1", "act": 1, "type": "build", "site": "dome", "effect": "dome1", "hold": 3.0, "min_sol": 1, "dome_phase": true,
		"cost": {"regolith": 6, "metal": 2, "electronics": 1},
		"title": "DOME 1/3 — FOUNDATION + OXYGEN GENERATOR",
		"text": "Lay the foundation ring and install the oxygen generator (it starts once the dome is sealed). Mine regolith with mouse + hold F, then hold R at the dome site."},
	{"id": "a1_dome2", "act": 1, "type": "build", "site": "dome", "effect": "dome2", "hold": 3.0, "min_sol": 2, "dome_phase": true,
		"cost": {"regolith": 10, "metal": 3},
		"title": "DOME 2/3 — FINISH THE STRUCTURE",
		"text": "Raise and weld the pressure shell. Grey metal-scrap tiles give 2 metal each. Hold R at the dome site."},
	{"id": "a1_dome3", "act": 1, "type": "build", "site": "dome", "effect": "dome3", "hold": 3.0, "min_sol": 3, "dome_phase": true,
		"cost": {"metal": 2, "electronics": 1, "ice": 2},
		"title": "DOME 3/3 — TEMPORARY ENERGY SOURCE",
		"text": "Install the emergency fuel cell. It runs on water ice: climb down the ladder in the shaft (W / S) to the ice cavern and mine 2 blue crystals."},
	{"id": "a1_hide", "act": 1, "type": "rest", "sites": ["lander"], "title": "HIDE IN YOUR SHIP",
		"banner": ["LANDING SURVIVED", "The dome stands. Tomorrow you move in."],
		"text": "The dome is built but untested. Get back inside the lander you came in and press Z to seal the hatch and ride out the night."},
	{"id": "a1_activate", "act": 1, "type": "activate", "site": "dome", "effect": "seal", "title": "MOVE INTO THE DOME",
		"text": "Walk to the dome and press E to seal it and start the oxygen generator. Inside, oxygen and heat recover."},
	{"id": "a1_shelter", "act": 1, "type": "rest", "sites": ["dome"], "evening_only": true, "title": "SURVIVE YOUR FIRST SOL IN THE DOME",
		"text": "Make it through the day, then shelter inside the sealed dome after dusk and press Z. The fuel cell keeps the lights on — but not forever."},
	# ---------------- ACT II — RENEWABLE POWER
	{"id": "a2_solar", "act": 2, "type": "build", "site": "solar", "effect": "solar", "hold": 3.0,
		"cost": {"metal": 4, "regolith": 4, "electronics": 1},
		"title": "SET UP THE SOLAR PANELS",
		"text": "The fuel cell is finite. Build the solar array on the marked frame east of the dome (hold R). Dust settles on bare panels — press E at the array to wipe them."},
	{"id": "a2_research", "act": 2, "type": "research", "explore": 2, "rp": 30, "title": "EXPLORE & RESEARCH",
		"text": "Earn research points (RP): exploration scan +5 (orange flags: press E and stay inside), discovery +10 (glowing beacons: press E), mining +1 to +5 by rarity. Complete 2 exploration scans and reach 30 RP."},
	{"id": "a2_upgrade", "act": 2, "type": "build", "site": "solar", "effect": "autoclean", "hold": 3.0, "rp": 30,
		"cost": {"metal": 2, "electronics": 1, "regolith": 3},
		"title": "UPGRADE: AUTO-CLEANING PANELS",
		"text": "Fit electrostatic dust-repelling coating and wipers so the panels clean themselves. Hold R at the solar array."},
	{"id": "a2_storm", "act": 2, "type": "event", "event": "dust_storm", "title": "SURVIVE THE DUST STORM",
		"text": "A regional dust storm is rolling in. Shelter in the dome — the self-cleaning array keeps charging through the haze."},
	# ---------------- ACT III — WATER, FOOD & FLARES
	{"id": "a3_water", "act": 3, "type": "collect", "need": {"ice": 6}, "title": "FIND WATER — MINE 6 WATER CRYSTALS",
		"text": "Ration packs are running out: hunger is now active (Q eats food). Mine blue water crystals in the ice cavern. Crystals slowly re-freeze every dawn."},
	{"id": "a3_purifier", "act": 3, "type": "build", "site": "dome", "effect": "purifier", "hold": 3.0,
		"cost": {"metal": 3, "electronics": 1, "regolith": 2},
		"title": "BUILD THE WATER PURIFIER",
		"text": "Raw ice is laced with perchlorates. Build a purifier beside the dome (hold R)."},
	{"id": "a3_purify", "act": 3, "type": "collect", "need": {"water": 4}, "title": "PURIFY WATER",
		"text": "Press E at the dome to melt and filter ice into clean water. Make 4 water."},
	{"id": "a3_farm", "act": 3, "type": "build", "site": "dome", "effect": "farm", "hold": 3.0,
		"cost": {"metal": 3, "regolith": 6, "water": 2},
		"title": "BUILD ARTIFICIAL AGRICULTURE",
		"text": "Build a pressurised hydroponics bay on the dome's east side (hold R)."},
	{"id": "a3_grow", "act": 3, "type": "harvest", "count": 1, "title": "GROW AND HARVEST FOOD",
		"text": "Press E at the dome to plant (1 water). Crops ripen in about 50 seconds or overnight. Press E again to harvest, then Q to eat."},
	{"id": "a3_shield", "act": 3, "type": "build", "site": "dome", "effect": "shield", "hold": 3.0,
		"cost": {"regolith": 10, "metal": 2},
		"title": "FLARE PLAN A: AVOID — SHIELD THE DOME",
		"text": "The Sun is getting active. Bank a thick regolith berm over the dome to keep flare radiation out (hold R at the dome)."},
	{"id": "a3_plan", "act": 3, "type": "build", "site": "solar", "effect": "flare_kit", "hold": 3.0, "rp": 60,
		"cost": {"metal": 2, "electronics": 1},
		"title": "FLARE PLAN B: RECOVER — SURGE BREAKERS",
		"text": "Install surge breakers and backup cells at the solar array so power can be restored after a flare (hold R). Needs 60 RP."},
	{"id": "a3_flare", "act": 3, "type": "event", "event": "solar_flare", "title": "SURVIVE THE SOLAR FLARE STORM",
		"text": "Proton storm incoming! Get inside the shielded dome or underground. Radiation on the open surface climbs fast."},
	{"id": "a3_recover", "act": 3, "type": "build", "site": "solar", "effect": "reboot", "hold": 4.0, "cost": {},
		"title": "RECOVER FROM THE FLARE",
		"text": "The flare tripped every breaker. Go to the solar array and hold R to reset it and bring power back."},
	# ---------------- ACT IV — UNDERGROUND
	{"id": "a4_base", "act": 4, "type": "build", "site": "ug_base", "effect": "ug_base", "hold": 5.0, "after_act_sols": 1,
		"cost": {"regolith": 15, "metal": 6, "electronics": 2, "water": 3},
		"title": "BUILD THE UNDERGROUND BASE",
		"text": "Stockpile surface materials while the cavern roof is monitored for a full sol, then hold R at the marked site in the ice cavern. Adds a pressurised shelter and a deep drill."},
	{"id": "a4_titanium", "act": 4, "type": "collect", "need": {"titanium": 10}, "title": "MINE A STACK OF TITANIUM",
		"text": "Climb down the drill-shaft ladder into the deep strata. Silver-veined titanium ore is worth 4 RP. Collect a stack of 10."},
	{"id": "a4_enhance", "act": 4, "type": "build", "site": "dome", "effect": "reinforced", "hold": 4.0,
		"cost": {"titanium": 10, "metal": 4},
		"title": "ENHANCE THE BASE — TITANIUM FRAME",
		"text": "Rebuild the dome frame in titanium: no pressure leaks, faster oxygen, extra heat. Hold R at the dome."},
	# ---------------- ACT V — NEW ELEMENTS
	{"id": "a5_discover", "act": 5, "type": "discover", "ids": ["arcadium", "rubrium"], "title": "FIND THE NEW ELEMENTS",
		"text": "Deep scans show two unknown signatures in the Deep Hollows. Find the glowing anomalies at the far west and far east and press E to analyse them."},
	{"id": "a5_mine", "act": 5, "type": "collect", "need": {"arcadium": 5, "rubrium": 5}, "title": "MINE ARCADIUM + RUBRIUM",
		"text": "Mine 5 Arcadium (cyan) and 5 Rubrium (red) crystals. +5 RP each."},
	{"id": "a5_reactor", "act": 5, "type": "build", "site": "ug_base", "effect": "reactor", "hold": 5.0, "rp": 120,
		"cost": {"arcadium": 5, "titanium": 3, "electronics": 2},
		"title": "ENHANCE WITH ARCADIUM — REACTOR",
		"text": "Arcadium has astonishing energy density. Build a reactor in the underground base (hold R). Needs 120 RP."},
	{"id": "a5_lattice", "act": 5, "type": "build", "site": "dome", "effect": "lattice", "hold": 5.0,
		"cost": {"rubrium": 5, "titanium": 3, "metal": 3},
		"title": "ENHANCE WITH RUBRIUM — ALLOY LATTICE",
		"text": "Weave Rubrium alloy through the dome: self-healing and radiation-proof. Hold R at the dome to complete the colony."},
	{"id": "victory", "act": 5, "type": "victory", "title": "ARCADIA SUBSISTS",
		"text": "The colony is self-sustaining. You succeeded. Keep exploring freely, or save and return to the menu."}
]

var host
var world
var flags: Dictionary = {}
var step_index: int = 0
var sol: int = 1
var time_of_day: float = START_TIME
var points: int = 0
var last_build_sol: int = 0
var act_start_sol: int = 1
var event_type: String = ""
var event_phase: String = ""
var event_timer: float = 0.0
var harvests: int = 0
var scan_zone: String = ""
var scan_progress: float = 0.0
var build_progress: float = 0.0
var victory: bool = false

func _init(host_node, world_node) -> void:
	host = host_node
	world = world_node
	reset()

func reset() -> void:
	flags = {
		"dome_stage": 0, "o2_gen": false, "fuel_cell": false, "fuel": 0.0, "dome_sealed": false,
		"beacons": [false, false, false],
		"solar_built": false, "solar_autoclean": false, "solar_dust": 0.0, "solar_damaged": false,
		"purifier": false, "farm": false, "farm_state": "idle", "farm_growth": 0.0,
		"shield": false, "flare_kit": false, "ug_base": false, "reinforced": false,
		"reactor": false, "lattice": false, "hunger_active": false, "points_active": false,
		"explored": {}, "discovered": {}
	}
	world.colony = flags
	step_index = 0
	sol = 1
	time_of_day = START_TIME
	points = 0
	last_build_sol = 0
	act_start_sol = 1
	event_type = ""
	event_phase = ""
	event_timer = 0.0
	harvests = 0
	scan_zone = ""
	scan_progress = 0.0
	build_progress = 0.0
	victory = false

# ---------------------------------------------------------------- queries

func step() -> Dictionary:
	return STEPS[clampi(step_index, 0, STEPS.size() - 1)]

func act() -> int:
	return int(step()["act"])

func act_label() -> String:
	var meta: Array = ACTS[act()]
	return "%s // %s" % [meta[0], meta[1]]

func f(key: String) -> bool:
	return bool(flags.get(key, false))

func res(name: String) -> int:
	return int(host.stats.get(name, 0))

func explored_count() -> int:
	var count: int = 0
	var done: Dictionary = flags["explored"]
	for value in done.values():
		if bool(value):
			count += 1
	return count

func is_discovered(discovery_id: String) -> bool:
	var found: Dictionary = flags["discovered"]
	return bool(found.get(discovery_id, false))

func daylight() -> float:
	if time_of_day < DAWN or time_of_day >= NIGHT:
		return 0.0
	if time_of_day < MORNING:
		return (time_of_day - DAWN) / (MORNING - DAWN)
	if time_of_day > DUSK:
		return 1.0 - (time_of_day - DUSK) / (NIGHT - DUSK)
	return 1.0

func is_night() -> bool:
	return time_of_day >= NIGHT or time_of_day < DAWN

func is_evening() -> bool:
	return time_of_day >= DUSK

func phase_name() -> String:
	if time_of_day < DAWN:
		return "PRE-DAWN"
	if time_of_day < MORNING:
		return "DAWN"
	if time_of_day < DUSK:
		return "DAYLIGHT"
	if time_of_day < NIGHT:
		return "DUSK"
	return "NIGHT"

func seconds_to_next_phase() -> int:
	var marks: Array = [DAWN, MORNING, DUSK, NIGHT, 1.0]
	for mark in marks:
		if time_of_day < float(mark):
			return int((float(mark) - time_of_day) * SOL_LENGTH)
	return 0

func event_active() -> bool:
	return event_phase == "active"

func storm_active() -> bool:
	return event_type == "dust_storm" and event_phase == "active"

func flare_active() -> bool:
	return event_type == "solar_flare" and event_phase == "active"

## Fraction (0..1) of rated solar output reaching the battery right now.
func solar_efficiency() -> float:
	if not f("solar_built") or f("solar_damaged"):
		return 0.0
	var eff: float = daylight() * (1.0 - clampf(float(flags["solar_dust"]), 0.0, 100.0) / 100.0)
	if storm_active():
		eff *= 0.40 if f("solar_autoclean") else 0.0
	if flare_active():
		eff *= 0.6
	return eff

func light_level() -> float:
	var light: float = 0.20 + 0.80 * daylight()
	if storm_active():
		light *= 0.78
	return light

# ---------------------------------------------------------------- frame update

func update(delta: float) -> void:
	time_of_day += delta / SOL_LENGTH
	if time_of_day >= 1.0:
		_new_sol(false)
	_update_events(delta)
	_update_scan(delta)
	_update_solar_dust(delta)
	_update_farm(delta)
	_check_passive_completion()

func _update_solar_dust(delta: float) -> void:
	if not f("solar_built"):
		return
	if f("solar_autoclean"):
		flags["solar_dust"] = 0.0
		return
	var rate: float = 0.45 if not storm_active() else 6.0
	flags["solar_dust"] = minf(100.0, float(flags["solar_dust"]) + rate * delta)

func _update_farm(delta: float) -> void:
	if not f("farm") or str(flags["farm_state"]) != "growing":
		return
	flags["farm_growth"] = minf(1.0, float(flags["farm_growth"]) + delta / FARM_GROW_TIME)
	if float(flags["farm_growth"]) >= 1.0:
		flags["farm_state"] = "ready"
		host.show_toast("HYDROPONICS // CROP READY TO HARVEST (E AT DOME)", 3.5)

func _update_scan(delta: float) -> void:
	if scan_zone == "":
		return
	var zone: Dictionary = world.EXPLORE_ZONES[scan_zone]
	var zone_pos: Vector2 = zone["pos"]
	if host.player.global_position.distance_to(zone_pos) > float(zone["radius"]):
		host.show_toast("SCAN ABORTED // STAY INSIDE THE ZONE UNTIL IT COMPLETES", 3.0)
		scan_zone = ""
		scan_progress = 0.0
		return
	scan_progress += delta
	if scan_progress >= SCAN_TIME:
		var done: Dictionary = flags["explored"]
		done[scan_zone] = true
		add_points(POINTS_EXPLORE, "EXPLORATION: " + str(zone["name"]))
		scan_zone = ""
		scan_progress = 0.0

func _update_events(delta: float) -> void:
	if event_type == "":
		return
	event_timer -= delta
	if event_timer > 0.0:
		return
	var info: Dictionary = EVENTS[event_type]
	if event_phase == "warning":
		event_phase = "active"
		event_timer = float(info["duration"])
		if event_type == "dust_storm":
			world.set_storm_active(true)
			host.show_toast("DUST STORM HAS ARRIVED // OXYGEN AND HEAT DRAIN FASTER OUTSIDE", 5.0)
		else:
			world.set_flare_active(true)
			host.show_toast("SOLAR FLARE IMPACT // TAKE COVER: SHIELDED DOME OR UNDERGROUND", 5.0)
	else:
		var finished: String = event_type
		event_type = ""
		event_phase = ""
		event_timer = 0.0
		world.set_storm_active(false)
		world.set_flare_active(false)
		if finished == "solar_flare":
			flags["solar_damaged"] = true
			host.show_toast("FLARE PASSED // SOLAR ARRAY BREAKERS TRIPPED — RECOVER POWER", 5.0)
		else:
			host.show_toast("STORM FRONT PASSED // THE SELF-CLEANING ARRAY HELD", 5.0)
		if str(step()["type"]) == "event" and str(step()["event"]) == finished:
			_advance()

func start_event(kind: String) -> void:
	event_type = kind
	event_phase = "warning"
	event_timer = float(EVENTS[kind]["warning"])
	host.show_toast("WARNING // %s INBOUND IN %d SECONDS" % [EVENTS[kind]["name"], int(event_timer)], 5.0)

func _check_passive_completion() -> void:
	if victory:
		return
	var s: Dictionary = step()
	match str(s["type"]):
		"collect":
			var need: Dictionary = s["need"]
			for key in need.keys():
				if res(str(key)) < int(need[key]):
					return
			_advance()
		"research":
			if explored_count() >= int(s["explore"]) and points >= int(s["rp"]):
				_advance()
		"harvest":
			if harvests >= int(s["count"]):
				_advance()
		"discover":
			for discovery_id in s["ids"]:
				if not is_discovered(str(discovery_id)):
					return
			_advance()
		"beacons":
			if _beacons_done():
				_advance()
		"salvage":
			if world.wreck_salvaged:
				_advance()

func _beacons_done() -> bool:
	for placed in flags["beacons"]:
		if not bool(placed):
			return false
	return true

# ---------------------------------------------------------------- progression

func _advance() -> void:
	var finished: Dictionary = step()
	var old_act: int = act()
	if finished.has("banner"):
		var banner: Array = finished["banner"]
		host.show_banner(str(banner[0]), str(banner[1]))
	step_index = mini(step_index + 1, STEPS.size() - 1)
	build_progress = 0.0
	var next: Dictionary = step()
	if act() != old_act:
		_on_act_started(act())
	match str(next["type"]):
		"event":
			start_event(str(next["event"]))
		"victory":
			victory = true
			host.show_victory()
	host.save_game()

func _on_act_started(new_act: int) -> void:
	act_start_sol = sol
	var meta: Array = ACTS[new_act]
	var subtitle: String = ""
	match new_act:
		2:
			flags["points_active"] = true
			subtitle = "You survived the first sol under the dome. Research points are now online."
		3:
			flags["hunger_active"] = true
			host.stats["food"] = int(host.stats["food"]) + 2
			subtitle = "The dust storm is behind you. Rations are nearly gone — 2 packs left."
		4:
			subtitle = "The surface is secured. Time to dig deeper."
		5:
			subtitle = "Something new is glowing in the deep."
	host.show_banner(str(meta[0]) + " // " + str(meta[1]), subtitle)

## Debug/test helper: jump straight to a step id, applying every earlier effect.
func debug_skip_to(step_id: String) -> void:
	while str(step()["id"]) != step_id and step_index < STEPS.size() - 1:
		var s: Dictionary = step()
		match str(s["type"]):
			"build", "activate":
				_apply_effect(str(s["effect"]))
			"salvage":
				world.wreck_salvaged = true
			"beacons":
				flags["beacons"] = [true, true, true]
			"event":
				event_type = ""
				event_phase = ""
				world.set_storm_active(false)
				world.set_flare_active(false)
		var old_act: int = act()
		step_index += 1
		if act() != old_act:
			act_start_sol = sol
			if act() >= 2:
				flags["points_active"] = true
			if act() >= 3:
				flags["hunger_active"] = true
	if str(step()["type"]) == "event":
		start_event(str(step()["event"]))

func _apply_effect(effect: String) -> void:
	match effect:
		"dome1":
			flags["dome_stage"] = 1
			flags["o2_gen"] = true
			last_build_sol = sol
		"dome2":
			flags["dome_stage"] = 2
			last_build_sol = sol
		"dome3":
			flags["dome_stage"] = 3
			flags["fuel_cell"] = true
			flags["fuel"] = 100.0
			last_build_sol = sol
		"seal":
			flags["dome_sealed"] = true
			host.stats["pressure"] = 100.0
		"solar":
			flags["solar_built"] = true
			flags["solar_dust"] = 0.0
		"autoclean":
			flags["solar_autoclean"] = true
			flags["solar_dust"] = 0.0
		"reboot":
			flags["solar_damaged"] = false
		"ug_base":
			flags["ug_base"] = true
			world.open_deep_shaft()
		_:
			flags[effect] = true

const EFFECT_MESSAGES: Dictionary = {
	"dome1": "DOME PHASE 1/3 COMPLETE // FOUNDATION LAID, OXYGEN GENERATOR READY. NEXT PHASE TOMORROW.",
	"dome2": "DOME PHASE 2/3 COMPLETE // PRESSURE SHELL WELDED. NEXT PHASE TOMORROW.",
	"dome3": "DOME PHASE 3/3 COMPLETE // FUEL CELL ONLINE. NOW HIDE IN THE LANDER.",
	"solar": "SOLAR ARRAY ONLINE // RENEWABLE POWER FLOWING",
	"autoclean": "AUTO-CLEANING COATING INSTALLED // PANELS WILL STAY CLEAR",
	"purifier": "WATER PURIFIER ONLINE // PRESS E AT THE DOME TO PURIFY ICE",
	"farm": "HYDROPONICS BAY PRESSURISED // PRESS E AT THE DOME TO PLANT",
	"shield": "REGOLITH BERM COMPLETE // DOME RADIATION SHIELDING ACTIVE",
	"flare_kit": "SURGE BREAKERS + BACKUP CELLS INSTALLED // RECOVERY PLAN READY",
	"reboot": "BREAKERS RESET // SOLAR POWER RESTORED",
	"ug_base": "UNDERGROUND BASE PRESSURISED // DEEP DRILL BORED THE SHAFT — LADDER DOWN",
	"reinforced": "TITANIUM FRAME INSTALLED // HABITAT ENHANCED",
	"reactor": "ARCADIUM REACTOR CRITICAL // UNLIMITED POWER",
	"lattice": "RUBRIUM LATTICE WOVEN // THE DOME IS COMPLETE"
}

# ---------------------------------------------------------------- building (hold R)

func current_build_site() -> String:
	var s: Dictionary = step()
	if str(s["type"]) == "build":
		return str(s["site"])
	return ""

func build_block_reason() -> String:
	var s: Dictionary = step()
	if str(s["type"]) != "build":
		return "NOTHING TO BUILD RIGHT NOW"
	if event_type != "":
		return "NO CONSTRUCTION DURING THE %s" % EVENTS[event_type]["name"]
	if s.has("min_sol") and sol < int(s["min_sol"]):
		return "AVAILABLE ON SOL %d // REST TONIGHT (Z IN A SHELTER)" % int(s["min_sol"])
	if bool(s.get("dome_phase", false)) and last_build_sol == sol:
		return "ONE DOME PHASE PER SOL // CREW FATIGUE — CONTINUE TOMORROW"
	if s.has("after_act_sols") and sol < act_start_sol + int(s["after_act_sols"]):
		return "CAVERN ROOF BEING MONITORED // CONSTRUCTION ALLOWED FROM SOL %d" % (act_start_sol + int(s["after_act_sols"]))
	if s.has("rp") and points < int(s["rp"]):
		return "NEEDS %d RESEARCH POINTS (YOU HAVE %d)" % [int(s["rp"]), points]
	var missing: Array = []
	var cost: Dictionary = s.get("cost", {})
	for key in cost.keys():
		var have: int = res(str(key))
		if have < int(cost[key]):
			missing.append("%d %s" % [int(cost[key]) - have, RESOURCE_NAMES.get(key, str(key).to_upper())])
	if not missing.is_empty():
		return "MISSING: " + ", ".join(missing)
	return ""

func waiting_for_tomorrow() -> bool:
	var s: Dictionary = step()
	if str(s["type"]) != "build":
		return false
	if s.has("min_sol") and sol < int(s["min_sol"]):
		return true
	if bool(s.get("dome_phase", false)) and last_build_sol == sol:
		return true
	return s.has("after_act_sols") and sol < act_start_sol + int(s["after_act_sols"])

func build_hold_time() -> float:
	return float(step().get("hold", 3.0))

## Returns true while the build bar should be visible.
func update_build(delta: float, holding: bool, position: Vector2) -> bool:
	var site: String = current_build_site()
	if site == "" or not world.is_near_site(site, position):
		build_progress = 0.0
		return false
	if not holding:
		build_progress = maxf(0.0, build_progress - delta * 2.0)
		return build_progress > 0.0
	var reason: String = build_block_reason()
	if reason != "":
		build_progress = 0.0
		host.show_toast(reason, 2.5)
		return false
	build_progress += delta
	if build_progress >= build_hold_time():
		_complete_build()
	return true

func _complete_build() -> void:
	var s: Dictionary = step()
	var cost: Dictionary = s.get("cost", {})
	for key in cost.keys():
		host.stats[key] = res(str(key)) - int(cost[key])
	var effect: String = str(s["effect"])
	_apply_effect(effect)
	host.show_toast(str(EFFECT_MESSAGES.get(effect, "CONSTRUCTION COMPLETE")), 5.0)
	_advance()

# ---------------------------------------------------------------- interaction (E)

func interact(position: Vector2) -> bool:
	# Discoveries (once the research network is online).
	if f("points_active"):
		var discovery_id: String = world.discovery_at(position)
		if discovery_id != "" and not is_discovered(discovery_id):
			var entry: Dictionary = world.DISCOVERIES[discovery_id]
			var found: Dictionary = flags["discovered"]
			found[discovery_id] = true
			var reward: Dictionary = entry["reward"]
			var reward_text: Array = []
			for key in reward.keys():
				host.stats[key] = res(str(key)) + int(reward[key])
				reward_text.append("+%d %s" % [int(reward[key]), RESOURCE_NAMES.get(key, str(key))])
			add_points(POINTS_DISCOVER, "DISCOVERY: " + str(entry["name"]) + ("" if reward_text.is_empty() else "  " + "  ".join(reward_text)))
			return true

	if world.is_near_wreck(position) and not world.wreck_salvaged:
		world.wreck_salvaged = true
		host.stats["metal"] = res("metal") + 4
		host.stats["electronics"] = res("electronics") + 3
		host.show_toast("SALVAGED: 4 METAL // 3 CONTROL BOARDS", 3.5)
		return true

	var stake: int = world.nearest_stake(position)
	if stake >= 0:
		var beacons: Array = flags["beacons"]
		if not bool(beacons[stake]):
			beacons[stake] = true
			var placed: int = 0
			for b in beacons:
				if bool(b):
					placed += 1
			if placed >= beacons.size():
				host.show_toast("GROUND STABLE AT ALL 3 STAKES // LANDING ZONE SECURED — DOME CONSTRUCTION AUTHORISED", 5.0)
			else:
				host.show_toast("SURVEY BEACON %d/3 PLANTED // GROUND STABLE" % placed, 3.0)
			return true

	if f("points_active"):
		var zone_id: String = world.zone_at(position)
		if zone_id != "" and not bool((flags["explored"] as Dictionary).get(zone_id, false)):
			if zone_id == "deep_hollows" and not world.deep_unlocked():
				pass
			elif scan_zone != zone_id:
				scan_zone = zone_id
				scan_progress = 0.0
				host.show_toast("SCANNING %s // STAY INSIDE THE ZONE" % str(world.EXPLORE_ZONES[zone_id]["name"]), 3.0)
				return true

	if world.is_near_dome(position):
		var s: Dictionary = step()
		if str(s["type"]) == "activate":
			_apply_effect(str(s["effect"]))
			host.show_toast("DOME SEALED // OXYGEN GENERATOR SPINNING UP — PRESSURE 100%", 5.0)
			_advance()
			return true
		if f("farm"):
			var state: String = str(flags["farm_state"])
			if state == "ready":
				flags["farm_state"] = "idle"
				flags["farm_growth"] = 0.0
				host.stats["food"] = res("food") + 3
				harvests += 1
				host.show_toast("HARVESTED +3 FOOD // PRESS Q TO EAT", 3.5)
				return true
			if state == "idle" and res("water") >= 1:
				host.stats["water"] = res("water") - 1
				flags["farm_state"] = "growing"
				flags["farm_growth"] = 0.0
				host.show_toast("SEEDS PLANTED (-1 WATER) // READY IN ~%d SECONDS" % int(FARM_GROW_TIME), 3.5)
				return true
		if f("purifier") and res("ice") >= 1:
			var batch: int = mini(3, res("ice"))
			host.stats["ice"] = res("ice") - batch
			host.stats["water"] = res("water") + batch
			host.show_toast("PURIFIED %d ICE INTO %d WATER" % [batch, batch], 3.0)
			return true

	if world.is_near_solar(position) and f("solar_built") and not f("solar_autoclean"):
		if float(flags["solar_dust"]) > 3.0:
			flags["solar_dust"] = 0.0
			host.show_toast("PANELS WIPED CLEAN // FULL OUTPUT RESTORED", 2.5)
			return true

	return false

func add_points(amount: int, reason: String) -> void:
	if not f("points_active"):
		return
	points += amount
	host.show_toast("%s  // +%d RP" % [reason, amount], 3.0)

# ---------------------------------------------------------------- sleeping (Z)

func shelter_at(position: Vector2) -> String:
	if world.is_inside_ug_base(position):
		return "ug_base"
	if f("dome_sealed") and world.is_inside_dome(position):
		return "dome"
	if world.is_inside_lander(position):
		return "lander"
	return ""

func try_rest(position: Vector2) -> String:
	var shelter: String = shelter_at(position)
	if shelter == "":
		return "REST ONLY INSIDE A SHELTER // LANDER, SEALED DOME OR UNDERGROUND BASE"
	if event_type != "":
		return "STAY ALERT UNTIL THE %s PASSES" % EVENTS[event_type]["name"]
	var s: Dictionary = step()
	var rest_step: bool = str(s["type"]) == "rest" and (s["sites"] as Array).has(shelter)
	if rest_step and bool(s.get("evening_only", false)) and not is_evening():
		return "SURVIVE THE DAY FIRST // YOU CAN REST AFTER DUSK (IN %d s)" % int((DUSK - time_of_day) * SOL_LENGTH)
	if not (rest_step or is_evening() or waiting_for_tomorrow()):
		return "TOO EARLY TO SLEEP // REST AFTER DUSK, OR WHEN WORK MUST WAIT FOR TOMORROW"
	_new_sol(true)
	host.on_slept(shelter)
	if rest_step:
		_advance()
	return ""

func _new_sol(slept: bool) -> void:
	sol += 1
	time_of_day = DAWN if slept else 0.0
	if f("farm") and str(flags["farm_state"]) == "growing" and slept:
		flags["farm_state"] = "ready"
		flags["farm_growth"] = 1.0
	var regrown: int = world.regrow_ice(host.player.global_position)
	var message: String = "SOL %d // A NEW DAY AT ARCADIA PLANITIA" % sol
	if regrown > 0 and act() >= 3:
		message += "  —  %d WATER CRYSTALS RE-FROZE" % regrown
	host.show_toast(message, 4.0)

# ---------------------------------------------------------------- HUD text

func objective_text() -> String:
	var s: Dictionary = step()
	var lines: Array = []
	lines.append(str(s["title"]))
	lines.append(str(s["text"]))
	match str(s["type"]):
		"build":
			var parts: Array = []
			var cost: Dictionary = s.get("cost", {})
			for key in cost.keys():
				var have: int = res(str(key))
				var need: int = int(cost[key])
				parts.append("%s %d/%d%s" % [RESOURCE_NAMES.get(key, str(key)), mini(have, need), need, " [OK]" if have >= need else ""])
			if s.has("rp"):
				parts.append("RP %d/%d%s" % [mini(points, int(s["rp"])), int(s["rp"]), " [OK]" if points >= int(s["rp"]) else ""])
			if not parts.is_empty():
				lines.append("NEEDS: " + "   ".join(parts))
			var reason: String = build_block_reason()
			if waiting_for_tomorrow():
				lines.append(">> " + reason)
		"collect":
			var parts2: Array = []
			var need2: Dictionary = s["need"]
			for key in need2.keys():
				parts2.append("%s %d/%d" % [RESOURCE_NAMES.get(key, str(key)), mini(res(str(key)), int(need2[key])), int(need2[key])])
			lines.append("PROGRESS: " + "   ".join(parts2))
		"research":
			lines.append("PROGRESS: EXPLORATION SCANS %d/%d   RP %d/%d" % [mini(explored_count(), int(s["explore"])), int(s["explore"]), mini(points, int(s["rp"])), int(s["rp"])])
		"beacons":
			var placed: int = 0
			for b in flags["beacons"]:
				if bool(b):
					placed += 1
			lines.append("PROGRESS: BEACONS %d/3" % placed)
		"discover":
			var parts3: Array = []
			for discovery_id in s["ids"]:
				parts3.append("%s %s" % [str(discovery_id).to_upper(), "[FOUND]" if is_discovered(str(discovery_id)) else "?"])
			lines.append("PROGRESS: " + "   ".join(parts3))
		"event":
			if event_phase == "warning":
				lines.append("ARRIVES IN %d s" % int(ceilf(event_timer)))
			elif event_phase == "active":
				lines.append("ENDS IN %d s" % int(ceilf(event_timer)))
	return "\n".join(lines)

## Structured objective for the HUD card: requirements come back as [label, met] pairs.
func objective_parts() -> Dictionary:
	var s: Dictionary = step()
	var reqs: Array = []
	var note: String = ""
	match str(s["type"]):
		"build":
			var cost: Dictionary = s.get("cost", {})
			for key in cost.keys():
				var have: int = res(str(key))
				var need: int = int(cost[key])
				reqs.append(["%s %d/%d" % [RESOURCE_NAMES.get(key, str(key)), mini(have, need), need], have >= need])
			if s.has("rp"):
				reqs.append(["RP %d/%d" % [mini(points, int(s["rp"])), int(s["rp"])], points >= int(s["rp"])])
			if waiting_for_tomorrow():
				note = build_block_reason()
		"collect":
			var need2: Dictionary = s["need"]
			for key in need2.keys():
				var have2: int = res(str(key))
				reqs.append(["%s %d/%d" % [RESOURCE_NAMES.get(key, str(key)), mini(have2, int(need2[key])), int(need2[key])], have2 >= int(need2[key])])
		"research":
			reqs.append(["SCANS %d/%d" % [mini(explored_count(), int(s["explore"])), int(s["explore"])], explored_count() >= int(s["explore"])])
			reqs.append(["RP %d/%d" % [mini(points, int(s["rp"])), int(s["rp"])], points >= int(s["rp"])])
		"beacons":
			var placed: int = 0
			for b in flags["beacons"]:
				if bool(b):
					placed += 1
			reqs.append(["BEACONS %d/3" % placed, placed >= 3])
		"discover":
			for discovery_id in s["ids"]:
				reqs.append([str(discovery_id).to_upper(), is_discovered(str(discovery_id))])
		"event":
			if event_phase == "warning":
				note = "ARRIVES IN %d s" % int(ceilf(event_timer))
			elif event_phase == "active":
				note = "ENDS IN %d s" % int(ceilf(event_timer))
		"harvest":
			reqs.append(["HARVESTS %d/%d" % [mini(harvests, int(s["count"])), int(s["count"])], harvests >= int(s["count"])])
	return {"title": str(s["title"]), "text": str(s["text"]), "reqs": reqs, "note": note}

func step_counter() -> String:
	var a: int = act()
	var total: int = 0
	var index_in_act: int = 0
	for i in range(STEPS.size()):
		if int(STEPS[i]["act"]) == a and str(STEPS[i]["type"]) != "victory":
			total += 1
			if i <= step_index:
				index_in_act = total
	return "%s   ·   STEP %d/%d" % [act_label(), index_in_act, maxi(total, 1)]

func context_prompt(position: Vector2) -> String:
	if f("points_active"):
		var discovery_id: String = world.discovery_at(position)
		if discovery_id != "" and not is_discovered(discovery_id):
			return "[E] ANALYSE DISCOVERY  (+10 RP)"
		var zone_id: String = world.zone_at(position)
		if zone_id != "" and not bool((flags["explored"] as Dictionary).get(zone_id, false)):
			if scan_zone == zone_id:
				return "SCANNING %s ... %d%%" % [str(world.EXPLORE_ZONES[zone_id]["name"]), int(scan_progress / SCAN_TIME * 100.0)]
			if zone_id != "deep_hollows" or world.deep_unlocked():
				return "[E] START EXPLORATION SCAN — %s  (+5 RP)" % str(world.EXPLORE_ZONES[zone_id]["name"])
	if world.is_near_wreck(position) and not world.wreck_salvaged:
		return "[E] SALVAGE LANDER"
	var stake: int = world.nearest_stake(position)
	if stake >= 0 and not bool((flags["beacons"] as Array)[stake]):
		return "[E] PLANT SURVEY BEACON"
	var site: String = current_build_site()
	if site != "" and world.is_near_site(site, position):
		var reason: String = build_block_reason()
		if reason == "":
			return "[HOLD R] BUILD: " + str(step()["title"])
		return reason
	var shelter: String = shelter_at(position)
	if world.is_near_dome(position):
		var s: Dictionary = step()
		if str(s["type"]) == "activate":
			return "[E] SEAL THE DOME + START OXYGEN GENERATOR"
		var options: Array = []
		if f("farm"):
			var state: String = str(flags["farm_state"])
			if state == "ready":
				options.append("[E] HARVEST")
			elif state == "growing":
				options.append("CROP %d%%" % int(float(flags["farm_growth"]) * 100.0))
			elif res("water") >= 1:
				options.append("[E] PLANT (1 WATER)")
		if f("purifier") and res("ice") >= 1 and not options.has("[E] HARVEST") and not options.has("[E] PLANT (1 WATER)"):
			options.append("[E] PURIFY ICE")
		if shelter != "":
			options.append("[Z] REST")
		if not options.is_empty():
			return "   ".join(options)
	if world.is_near_solar(position) and f("solar_built"):
		if f("solar_damaged"):
			return "SOLAR ARRAY OFFLINE // BREAKERS TRIPPED"
		if not f("solar_autoclean") and float(flags["solar_dust"]) > 3.0:
			return "[E] WIPE DUST OFF PANELS  (DUST %d%%)" % int(flags["solar_dust"])
		return "SOLAR OUTPUT %d%%" % int(solar_efficiency() * 100.0)
	if shelter != "":
		return "[Z] REST UNTIL DAWN   (SHELTER: %s)" % shelter.to_upper().replace("_", " ")
	if world.is_on_ladder(position):
		return "[W / S] CLIMB"
	return ""

# ---------------------------------------------------------------- save

func get_save_state() -> Dictionary:
	return {
		"step_index": step_index, "sol": sol, "time_of_day": time_of_day, "points": points,
		"last_build_sol": last_build_sol, "act_start_sol": act_start_sol,
		"event_type": event_type, "event_phase": event_phase, "event_timer": event_timer,
		"harvests": harvests, "victory": victory, "flags": flags.duplicate(true)
	}

func restore_save_state(state: Dictionary) -> void:
	reset()
	step_index = clampi(int(state.get("step_index", 0)), 0, STEPS.size() - 1)
	sol = maxi(1, int(state.get("sol", 1)))
	time_of_day = clampf(float(state.get("time_of_day", START_TIME)), 0.0, 0.999)
	points = int(state.get("points", 0))
	last_build_sol = int(state.get("last_build_sol", 0))
	act_start_sol = int(state.get("act_start_sol", 1))
	event_type = str(state.get("event_type", ""))
	event_phase = str(state.get("event_phase", ""))
	event_timer = float(state.get("event_timer", 0.0))
	harvests = int(state.get("harvests", 0))
	victory = bool(state.get("victory", false))
	var saved_flags: Variant = state.get("flags", {})
	if saved_flags is Dictionary:
		for key in (saved_flags as Dictionary).keys():
			flags[key] = saved_flags[key]
	flags["dome_stage"] = int(flags["dome_stage"])
	world.colony = flags
	if event_type != "" and not EVENTS.has(event_type):
		event_type = ""
		event_phase = ""
	world.set_storm_active(storm_active())
	world.set_flare_active(flare_active())
