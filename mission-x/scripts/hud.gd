extends CanvasLayer
## Arcadia Subsist HUD: vitals, sol clock, cargo, objective card, prompts, toasts, banners and screen effects.

const C_BG := Color(0.055, 0.048, 0.058, 0.88)
const C_BORDER := Color(0.94, 0.62, 0.38, 0.38)
const C_ACCENT := Color("f0a05b")
const C_TEXT := Color("efe4d2")
const C_MUTED := Color("a59c8e")
const C_GOOD := Color("8de0c8")
const C_BAD := Color("f08e6c")

const VITALS: Array = [
	["oxygen", "OXYGEN", "67c7cf", false],
	["battery", "POWER", "e5bc63", false],
	["heat", "HEAT", "e08a55", false],
	["radiation", "RADIATION", "b77ad0", true],
	["pressure", "DOME PRESSURE", "83c7a8", false],
	["nutrition", "NUTRITION", "9fcf6a", false]
]
const CARGO: Array = [
	["regolith", "Regolith", "c27a52", 1],
	["ice", "Ice crystals", "6cc0d4", 1],
	["metal", "Metal", "9aa2a8", 1],
	["electronics", "Control boards", "4fbf7a", 1],
	["water", "Water", "5aa8ff", 3],
	["food", "Food", "e7c35a", 3],
	["titanium", "Titanium", "cdd8e6", 4],
	["arcadium", "Arcadium", "5ff0d8", 5],
	["rubrium", "Rubrium", "ff5a50", 5]
]

const VIGNETTE_SHADER: String = """
shader_type canvas_item;
uniform float danger = 0.0;
uniform float time_s = 0.0;
uniform vec4 danger_color : source_color = vec4(0.9, 0.15, 0.1, 1.0);
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.0, 0.72));
	float v = smoothstep(0.32, 0.78, d);
	float pulse = 0.6 + 0.4 * sin(time_s * 5.0);
	vec3 col = mix(vec3(0.0), danger_color.rgb, clamp(danger * pulse, 0.0, 1.0));
	COLOR = vec4(col, v * (0.40 + danger * 0.55 * pulse));
}
"""

var main
var root: Control
var vignette: ColorRect
var vignette_mat: ShaderMaterial
var vital_bars: Dictionary = {}
var vital_values: Dictionary = {}
var vital_fills: Dictionary = {}
var heater_chip: Label
var status_line: Label
var sol_label: Label
var phase_label: Label
var timeline: Control
var cargo_rows: Dictionary = {}
var rp_label: Label
var objective_act: Label
var objective_body: RichTextLabel
var prompt_label: RichTextLabel
var prompt_panel: PanelContainer
var event_panel: PanelContainer
var event_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer: float = 0.0
var toast_text: String = ""
var banner: Control
var banner_title: Label
var banner_subtitle: Label
var banner_timer: float = 0.0
var action_bar: ProgressBar
var fade_rect: ColorRect
var overlay_panel: PanelContainer
var time_s: float = 0.0

func setup(main_node) -> void:
	main = main_node
	layer = 10
	_build()

# ---------------------------------------------------------------- public API

func show_toast(message: String, duration: float) -> void:
	toast_text = message
	toast_timer = duration
	if is_instance_valid(toast_label):
		toast_label.text = message
		toast_panel.visible = true
		toast_panel.modulate.a = 1.0

func show_banner(title: String, subtitle: String) -> void:
	banner_timer = 6.5
	banner_title.text = title
	banner_subtitle.text = subtitle
	banner.visible = true
	banner.modulate.a = 0.0

func fade_in_from_black() -> void:
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.visible = true
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 1.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: fade_rect.visible = false)

func close_overlay() -> void:
	if is_instance_valid(overlay_panel):
		overlay_panel.queue_free()
	overlay_panel = null

func show_victory(sols: int, points: int, on_keep: Callable, on_menu: Callable) -> void:
	close_overlay()
	overlay_panel = _panel(Color(0.04, 0.05, 0.06, 0.94), Color(0.55, 0.9, 0.8, 0.6))
	overlay_panel.custom_minimum_size = Vector2(520, 0)
	overlay_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	holder.add_child(overlay_panel)
	overlay_panel.tree_exited.connect(holder.queue_free)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	overlay_panel.add_child(box)
	var kicker := _label("MISSION COMPLETE", 12, C_ACCENT)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(kicker)
	var title := _label("ARCADIA SUBSISTS", 36, C_GOOD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var detail := _label("Two new elements. One living colony.", 15, C_TEXT)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail)
	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 30)
	box.add_child(stats_row)
	for pair in [["SOLS SURVIVED", str(sols)], ["RESEARCH", "%d RP" % points]]:
		var col := VBoxContainer.new()
		var v := _label(str(pair[1]), 24, C_TEXT)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var k := _label(str(pair[0]), 10, C_MUTED)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(v)
		col.add_child(k)
		stats_row.add_child(col)
	box.add_child(_spacer(6))
	var keep := _button("KEEP EXPLORING", true)
	keep.pressed.connect(on_keep)
	box.add_child(keep)
	var to_menu := _button("SAVE  /  RETURN TO MAIN MENU", false)
	to_menu.pressed.connect(on_menu)
	box.add_child(to_menu)

## progress < 0 hides the bar.
func set_action_progress(progress: float, world_position: Vector2) -> void:
	if progress < 0.0:
		action_bar.visible = false
		return
	action_bar.visible = true
	action_bar.value = clampf(progress, 0.0, 1.0) * 100.0
	var screen: Vector2 = main.get_viewport().get_canvas_transform() * world_position
	action_bar.position = screen + Vector2(-36, -58)

# ---------------------------------------------------------------- per-frame update

func update(delta: float) -> void:
	time_s += delta
	var stats: Dictionary = main.stats
	var campaign = main.campaign
	var flags: Dictionary = campaign.flags

	# Vitals
	var danger: float = 0.0
	for v in VITALS:
		var key: String = v[0]
		var value: float = float(stats[key])
		var bar: ProgressBar = vital_bars[key]
		bar.value = clampf(value, 0.0, 100.0)
		(vital_values[key] as Label).text = "%d" % int(value)
		var critical: bool = (value >= 70.0) if bool(v[3]) else (value <= 25.0)
		if key == "pressure" and not bool(flags["dome_sealed"]):
			critical = false
			(vital_values[key] as Label).text = "--"
		if key == "nutrition" and not bool(flags["hunger_active"]):
			critical = false
		var fill: StyleBoxFlat = vital_fills[key]
		var base := Color(str(v[2]))
		if critical:
			var pulse: float = 0.5 + 0.5 * sin(time_s * 8.0)
			fill.bg_color = base.lerp(Color("ff4a3a"), 0.5 + 0.5 * pulse)
			(vital_values[key] as Label).add_theme_color_override("font_color", C_BAD)
			if key != "pressure":
				danger = maxf(danger, 0.6 if not bool(v[3]) else 0.5)
		else:
			fill.bg_color = base
			(vital_values[key] as Label).add_theme_color_override("font_color", C_TEXT)
	vignette_mat.set_shader_parameter("danger", danger)
	vignette_mat.set_shader_parameter("time_s", time_s)
	vignette_mat.set_shader_parameter("danger_color", Color(0.75, 0.25, 0.95) if float(stats["radiation"]) >= 70.0 else Color(0.9, 0.15, 0.1))

	heater_chip.text = "HEATER ON" if main.heater_on else "HEATER OFF"
	heater_chip.add_theme_color_override("font_color", C_ACCENT if main.heater_on else C_MUTED)
	var parts: Array = []
	if bool(flags["solar_built"]):
		parts.append("SOLAR %d%%" % int(campaign.solar_efficiency() * 100.0))
	if bool(flags["fuel_cell"]):
		parts.append("FUEL CELL %d%%" % int(flags["fuel"]))
	if bool(flags["reactor"]):
		parts.append("REACTOR ONLINE")
	status_line.text = "   ·   ".join(parts) if not parts.is_empty() else "NO COLONY POWER YET"

	# Sol clock
	sol_label.text = "SOL %d" % campaign.sol
	phase_label.text = "%s   ·   %ds" % [campaign.phase_name(), campaign.seconds_to_next_phase()]
	timeline.queue_redraw()

	# Cargo
	var act: int = campaign.act()
	for c in CARGO:
		var key2: String = c[0]
		var row: Control = cargo_rows[key2][0]
		var count: int = int(stats[key2])
		row.visible = act >= int(c[3]) or count > 0
		(cargo_rows[key2][1] as Label).text = str(count)
	rp_label.text = ("%d RP" % campaign.points) if bool(flags["points_active"]) else "RP OFFLINE"
	rp_label.add_theme_color_override("font_color", C_GOOD if bool(flags["points_active"]) else C_MUTED)

	# Objective card
	objective_act.text = campaign.step_counter()
	var obj: Dictionary = campaign.objective_parts()
	var bb: String = "[font_size=17][color=#%s]%s[/color][/font_size]\n" % [C_TEXT.to_html(false), _esc(str(obj["title"]))]
	bb += "[color=#%s]%s[/color]" % [Color("cfc5b5").to_html(false), _esc(str(obj["text"]))]
	var reqs: Array = obj["reqs"]
	if not reqs.is_empty():
		var chips: Array = []
		for r in reqs:
			var ok: bool = bool(r[1])
			var col: String = C_GOOD.to_html(false) if ok else C_BAD.to_html(false)
			chips.append("[color=#%s]%s %s[/color]" % [col, "●" if ok else "○", _esc(str(r[0]))])
		bb += "\n[font_size=12]" + "     ".join(chips) + "[/font_size]"
	if str(obj["note"]) != "":
		bb += "\n[color=#%s]▸ %s[/color]" % [C_ACCENT.to_html(false), _esc(str(obj["note"]))]
	objective_body.text = bb

	# Context prompt
	var prompt: String = campaign.context_prompt(main.player.global_position)
	if prompt == "":
		prompt = "[A/D] MOVE   [SPACE] JUMP   [F] MINE   [E] USE   [R] BUILD   [Z] REST   [Q] EAT   [T] RECALL"
	prompt_label.text = "[center]" + _keycaps(prompt) + "[/center]"

	# Event alert
	if campaign.event_type != "":
		var info: Dictionary = campaign.EVENTS[campaign.event_type]
		var flare: bool = campaign.event_type == "solar_flare"
		if campaign.event_phase == "warning":
			event_label.text = "⚠  %s INBOUND  ·  %ds" % [info["name"], int(ceilf(campaign.event_timer))]
		else:
			event_label.text = "%s  ·  %ds REMAINING" % [info["name"], int(ceilf(campaign.event_timer))]
		var pulse2: float = 0.6 + 0.4 * sin(time_s * 6.0)
		var tint := Color("c27aff") if flare else Color("ff7a4a")
		event_label.add_theme_color_override("font_color", tint.lerp(Color.WHITE, 0.3 * pulse2))
		event_panel.visible = true
	else:
		event_panel.visible = false

	# Toast
	if toast_timer > 0.0:
		toast_timer -= delta
		toast_panel.modulate.a = clampf(toast_timer / 0.35, 0.0, 1.0)
		if toast_timer <= 0.0:
			toast_panel.visible = false

	# Banner (fade in, hold, fade out)
	if banner_timer > 0.0:
		banner_timer -= delta
		var shown: float = 6.5 - banner_timer
		banner.modulate.a = clampf(minf(shown / 0.6, banner_timer / 1.2), 0.0, 1.0)
		if banner_timer <= 0.0:
			banner.visible = false

func _esc(text: String) -> String:
	return text.replace("[", "[lb]")

func _keycaps(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[([A-Z0-9 /+]+)\\]")
	var out: String = ""
	var last: int = 0
	for m in regex.search_all(text):
		out += _esc(text.substr(last, m.get_start() - last))
		out += "[bgcolor=#%s][color=#1b1210] %s [/color][/bgcolor] " % [C_ACCENT.to_html(false), m.get_string(1)]
		last = m.get_end()
	out += _esc(text.substr(last))
	return out

# ---------------------------------------------------------------- construction

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	vignette_mat = ShaderMaterial.new()
	vignette_mat.shader = shader
	vignette.material = vignette_mat
	root.add_child(vignette)

	_build_vitals()
	_build_sol_clock()
	_build_cargo()
	_build_objective()
	_build_prompt()
	_build_alerts()
	_build_banner()

	action_bar = ProgressBar.new()
	action_bar.size = Vector2(72, 8)
	action_bar.show_percentage = false
	action_bar.add_theme_stylebox_override("background", _flat(Color(0.05, 0.05, 0.06, 0.85), 3, Color(0, 0, 0, 0)))
	action_bar.add_theme_stylebox_override("fill", _flat(C_ACCENT, 3, Color(0, 0, 0, 0)))
	action_bar.visible = false
	action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(action_bar)

	fade_rect = ColorRect.new()
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.visible = false
	root.add_child(fade_rect)

func _build_vitals() -> void:
	var panel := _panel()
	panel.position = Vector2(16, 14)
	panel.custom_minimum_size = Vector2(292, 0)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_child(_label("VITALS", 12, C_ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	heater_chip = _label("HEATER ON", 10, C_ACCENT)
	head.add_child(heater_chip)
	box.add_child(head)
	for v in VITALS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := _label(str(v[1]), 10, C_MUTED)
		name_label.custom_minimum_size = Vector2(92, 0)
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(120, 8)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", _flat(Color(1, 1, 1, 0.07), 4, Color(0, 0, 0, 0)))
		var fill := _flat(Color(str(v[2])), 4, Color(0, 0, 0, 0))
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		var value := _label("100", 11, C_TEXT)
		value.custom_minimum_size = Vector2(28, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		box.add_child(row)
		vital_bars[v[0]] = bar
		vital_values[v[0]] = value
		vital_fills[v[0]] = fill
	status_line = _label("", 10, C_MUTED)
	box.add_child(status_line)

func _build_sol_clock() -> void:
	var panel := _panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 14
	panel.custom_minimum_size = Vector2(360, 0)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := HBoxContainer.new()
	sol_label = _label("SOL 1", 18, C_TEXT)
	head.add_child(sol_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	phase_label = _label("DAYLIGHT", 11, C_MUTED)
	phase_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(phase_label)
	box.add_child(head)
	timeline = Control.new()
	timeline.custom_minimum_size = Vector2(336, 14)
	timeline.draw.connect(_draw_timeline)
	box.add_child(timeline)

func _draw_timeline() -> void:
	var w: float = timeline.size.x
	var h: float = 8.0
	var y: float = 3.0
	var segs: Array = [
		[0.0, 0.04, Color("1b2040")], [0.04, 0.12, Color("d9824f")], [0.12, 0.62, Color("efc596")],
		[0.62, 0.72, Color("6c86d4")], [0.72, 1.0, Color("1b2040")]
	]
	for s in segs:
		timeline.draw_rect(Rect2(float(s[0]) * w, y, (float(s[1]) - float(s[0])) * w, h), s[2])
	timeline.draw_rect(Rect2(0, y, w, h), Color(1, 1, 1, 0.12), false, 1.0)
	var t: float = main.campaign.time_of_day
	var x: float = t * w
	timeline.draw_rect(Rect2(0, y, x, h), Color(0, 0, 0, 0.35))
	timeline.draw_rect(Rect2(x - 1, 0, 3, h + 6), Color.WHITE)
	var is_day: bool = main.campaign.daylight() > 0.0
	timeline.draw_circle(Vector2(x, y + h * 0.5), 4.0, Color("fff2cc") if is_day else Color("c9d3ff"))

func _build_cargo() -> void:
	var panel := _panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -16
	panel.offset_top = 14
	panel.custom_minimum_size = Vector2(220, 0)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_child(_label("CARGO", 12, C_ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	rp_label = _label("RP OFFLINE", 12, C_MUTED)
	head.add_child(rp_label)
	box.add_child(head)
	for c in CARGO:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(9, 9)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_theme_stylebox_override("panel", _flat(Color(str(c[2])), 2, Color(0, 0, 0, 0)))
		row.add_child(chip)
		var name_label := _label(str(c[1]), 12, Color("d8cdbb"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var count := _label("0", 13, C_TEXT)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(count)
		box.add_child(row)
		cargo_rows[c[0]] = [row, count]

func _build_objective() -> void:
	var panel := _panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 16
	panel.offset_bottom = -14
	panel.custom_minimum_size = Vector2(560, 0)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	objective_act = _label("ACT I", 11, C_ACCENT)
	box.add_child(objective_act)
	objective_body = RichTextLabel.new()
	objective_body.bbcode_enabled = true
	objective_body.fit_content = true
	objective_body.scroll_active = false
	objective_body.custom_minimum_size = Vector2(536, 0)
	objective_body.add_theme_font_size_override("normal_font_size", 13)
	objective_body.add_theme_constant_override("line_separation", 2)
	objective_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(objective_body)

func _build_prompt() -> void:
	prompt_panel = _panel()
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_panel.offset_right = -16
	prompt_panel.offset_bottom = -14
	prompt_panel.custom_minimum_size = Vector2(640, 0)
	root.add_child(prompt_panel)
	prompt_label = RichTextLabel.new()
	prompt_label.bbcode_enabled = true
	prompt_label.fit_content = true
	prompt_label.scroll_active = false
	prompt_label.custom_minimum_size = Vector2(616, 0)
	prompt_label.add_theme_font_size_override("normal_font_size", 12)
	prompt_label.add_theme_color_override("default_color", Color("e6d6bd"))
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.add_child(prompt_label)

func _build_alerts() -> void:
	event_panel = _panel(Color(0.08, 0.03, 0.05, 0.9), Color(1.0, 0.45, 0.35, 0.6))
	_top_holder(84).add_child(event_panel)
	event_label = _label("", 15, C_BAD)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_panel.add_child(event_label)
	event_panel.visible = false

	toast_panel = _panel(Color(0.07, 0.06, 0.07, 0.92), Color(0.94, 0.62, 0.38, 0.55))
	_top_holder(132).add_child(toast_panel)
	toast_label = _label("", 14, Color("ffe6bf"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)
	toast_panel.visible = false

func _top_holder(top: float) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = top
	holder.offset_bottom = top + 40
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	return holder

func _build_banner() -> void:
	banner = Control.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 196
	banner.offset_bottom = 316
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	var band := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.5, Color(0.03, 0.02, 0.03, 0.82))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	band.texture = gt
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.add_child(band)
	var line_top := ColorRect.new()
	line_top.color = Color(C_ACCENT, 0.7)
	line_top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	line_top.offset_left = -220
	line_top.offset_right = 220
	line_top.offset_top = 14
	line_top.offset_bottom = 15
	banner.add_child(line_top)
	var line_bottom := line_top.duplicate()
	line_bottom.offset_top = 105
	line_bottom.offset_bottom = 106
	banner.add_child(line_bottom)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	banner.add_child(box)
	banner_title = _label("", 38, Color("ffd49a"))
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	banner_title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(banner_title)
	banner_subtitle = _label("", 15, Color("e8dccb"))
	banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(banner_subtitle)
	banner.visible = false

# ---------------------------------------------------------------- helpers

func _flat(color: Color, radius: int, border: Color, border_width: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_width)
	s.anti_aliasing = true
	return s

func _panel(bg: Color = C_BG, border: Color = C_BORDER) -> PanelContainer:
	var panel := PanelContainer.new()
	var s := _flat(bg, 8, border, 1)
	s.border_width_top = 2
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", s)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _button(text_value: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 14)
	var base := C_ACCENT if primary else Color(1, 1, 1, 0.08)
	var normal := _flat(base, 6, Color(0, 0, 0, 0))
	var hover := _flat(base.lightened(0.15) if primary else Color(1, 1, 1, 0.16), 6, Color(0, 0, 0, 0))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0), 6, C_ACCENT, 1))
	b.add_theme_color_override("font_color", Color("1b1210") if primary else C_TEXT)
	b.add_theme_color_override("font_hover_color", Color("1b1210") if primary else Color.WHITE)
	return b
