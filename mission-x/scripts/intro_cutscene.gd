extends CanvasLayer

signal finished

const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/intro_mars_background.png")
const DESCENT_SHIP_SCRIPT: Script = preload("res://scripts/descent_ship.gd")
const CUTSCENE_DURATION: float = 12.75

var elapsed: float = 0.0
var completed: bool = false

var ship: Node2D
var information_panel: PanelContainer
var header_label: Label
var message_label: Label
var title_label: Label
var time_jump_label: Label
var time_jump_subtitle: Label
var skip_label: Label
var emergency_overlay: ColorRect
var fade_overlay: ColorRect

func _ready() -> void:
	layer = 100
	_build_cutscene()
	_update_cutscene(0.0)

func _process(delta: float) -> void:
	if completed:
		return

	elapsed += delta
	_update_cutscene(elapsed)

	if elapsed >= CUTSCENE_DURATION:
		_finish_cutscene()

func _input(event: InputEvent) -> void:
	if completed or elapsed < 0.8:
		return

	var pressed: bool = false
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		pressed = key_event.pressed and not key_event.echo
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		pressed = mouse_event.pressed
	elif event is InputEventJoypadButton:
		var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
		pressed = joy_event.pressed

	if pressed:
		get_viewport().set_input_as_handled()
		_finish_cutscene()

func _build_cutscene() -> void:
	var background := TextureRect.new()
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.z_index = -10
	add_child(background)

	# Keep the ship as a separate animated object so the background stays lightweight.
	ship = Node2D.new()
	ship.set_script(DESCENT_SHIP_SCRIPT)
	ship.z_index = 0
	add_child(ship)

	emergency_overlay = ColorRect.new()
	emergency_overlay.color = Color(0.85, 0.08, 0.04, 0.0)
	emergency_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	emergency_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emergency_overlay.z_index = 1
	add_child(emergency_overlay)

	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.z_index = 2
	add_child(fade_overlay)

	_build_title()
	_build_information_panel()
	_build_time_jump_text()
	_build_skip_hint()

func _build_title() -> void:
	title_label = _make_label("ARCADIA SUBSIST", 28, Color("f1b66d"))
	title_label.position = Vector2(0, 28)
	title_label.size = Vector2(1280, 44)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_shadow_color", Color("311b1b"))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_label.z_index = 3
	add_child(title_label)

func _build_information_panel() -> void:
	information_panel = PanelContainer.new()
	information_panel.position = Vector2(32, 514)
	information_panel.size = Vector2(710, 166)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.045, 0.055, 0.90)
	panel_style.border_color = Color("c17a4a")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(0)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 13
	panel_style.content_margin_bottom = 12
	information_panel.add_theme_stylebox_override("panel", panel_style)
	information_panel.z_index = 3
	add_child(information_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	information_panel.add_child(content)

	header_label = _make_label("FLIGHT RECORDER // 2042", 17, Color("e9a45e"))
	content.add_child(header_label)

	message_label = _make_label("Arcadia Planitia on visual. Beginning controlled descent.", 15, Color("eee0ca"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(message_label)

func _build_time_jump_text() -> void:
	time_jump_label = _make_label("26 MONTHS LATER", 36, Color("f0b66f"))
	time_jump_label.position = Vector2(0, 292)
	time_jump_label.size = Vector2(1280, 58)
	time_jump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_jump_label.visible = false
	time_jump_label.z_index = 3
	add_child(time_jump_label)

	time_jump_subtitle = _make_label("EARTH REMAINS SILENT. THE HABITAT IS FAILING.", 16, Color("e8d7c3"))
	time_jump_subtitle.position = Vector2(0, 356)
	time_jump_subtitle.size = Vector2(1280, 32)
	time_jump_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_jump_subtitle.visible = false
	time_jump_subtitle.z_index = 3
	add_child(time_jump_subtitle)

func _build_skip_hint() -> void:
	skip_label = _make_label("PRESS ANY KEY OR CLICK TO SKIP", 12, Color("e6c9a6"))
	skip_label.position = Vector2(910, 674)
	skip_label.size = Vector2(340, 24)
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.z_index = 3
	add_child(skip_label)

func _update_cutscene(time_value: float) -> void:
	var descent_progress: float = clampf(time_value / 7.8, 0.0, 1.0)
	var eased_progress: float = descent_progress * descent_progress * (3.0 - 2.0 * descent_progress)
	ship.position = Vector2(930.0 - 300.0 * eased_progress, -110.0 + 590.0 * eased_progress)
	ship.rotation = sin(time_value * 1.2) * 0.018 if time_value < 8.0 else 0.0
	ship.call("set_landed", time_value >= 7.8)

	if time_value < 2.7:
		header_label.text = "FLIGHT RECORDER // 2042"
		message_label.text = "Arcadia Planitia on visual. Beginning controlled descent."
	elif time_value < 5.5:
		header_label.text = "ATMOSPHERIC ENTRY"
		message_label.text = "The red horizon is filling the viewport. Heat shields holding. Guidance is stable."
	elif time_value < 8.2:
		header_label.text = "LANDING SEQUENCE"
		message_label.text = "Touchdown confirmed. Surface contact established. Starting habitat and power checks."
	elif time_value < 9.7:
		header_label.text = "CRITICAL WARNING // SOLAR PARTICLE STORM"
		header_label.add_theme_color_override("font_color", Color("ff8063"))
		message_label.text = "Radiation spike detected. Secondary lander power bus offline. Emergency shelter protocols engaged."
	else:
		information_panel.visible = false

	time_jump_label.visible = time_value >= 10.45
	time_jump_subtitle.visible = time_value >= 10.45
	skip_label.visible = time_value < 10.25

	var emergency_alpha: float = 0.0
	if time_value >= 8.2 and time_value < 9.8:
		emergency_alpha = 0.07 + 0.10 * absf(sin(time_value * 22.0))
	emergency_overlay.color = Color(0.86, 0.10, 0.055, emergency_alpha)

	var black_alpha: float = 0.0
	if time_value < 1.0:
		black_alpha = 1.0 - time_value
	elif time_value < 9.7:
		black_alpha = 0.0
	elif time_value < 10.45:
		black_alpha = (time_value - 9.7) / 0.75
	elif time_value < 11.9:
		black_alpha = 1.0
	else:
		black_alpha = 1.0 - clampf((time_value - 11.9) / 0.85, 0.0, 1.0)
	fade_overlay.color = Color(0.0, 0.0, 0.0, clampf(black_alpha, 0.0, 1.0))

func _make_label(label_text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _finish_cutscene() -> void:
	if completed:
		return
	completed = true
	finished.emit()
	queue_free()
