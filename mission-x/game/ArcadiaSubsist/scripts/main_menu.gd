extends CanvasLayer

signal new_game_requested
signal continue_requested
signal resume_requested
signal save_and_menu_requested
signal quit_requested

const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/mars_surface_background.png")
const SETTINGS_PATH: String = "user://arcadia_settings.cfg"

var root_control: Control
var content: VBoxContainer
var frame: PanelContainer
var mission_panel: PanelContainer
var continue_available: bool = false
var current_page: String = "main"
var settings_return_page: String = "main"
var master_volume: float = 0.78
var fullscreen_enabled: bool = false
var title_label: Label
var menu_open: bool = false
var animation_time: float = 0.0

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_build_shell()
	visible = false

func _process(delta: float) -> void:
	animation_time += delta
	if is_instance_valid(title_label):
		var pulse: float = 0.5 + 0.5 * sin(animation_time * 1.4)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.72 + pulse * 0.06, 0.40 + pulse * 0.05))

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.physical_keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if current_page == "settings":
		current_page = settings_return_page
		_rebuild_page()
	elif current_page == "pause":
		resume_requested.emit()

func show_main_menu(can_continue: bool) -> void:
	continue_available = can_continue
	current_page = "main"
	_rebuild_page()
	menu_open = true
	visible = true

func show_pause_menu() -> void:
	current_page = "pause"
	_rebuild_page()
	menu_open = true
	visible = true

func close_menu() -> void:
	menu_open = false
	visible = false

func _build_shell() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var background := TextureRect.new()
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(background)

	var tint := ColorRect.new()
	tint.color = Color(0.035, 0.025, 0.035, 0.46)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(tint)

	# A second translucent band makes the left menu readable without hiding the landscape.
	var left_shade := ColorRect.new()
	left_shade.position = Vector2(0, 0)
	left_shade.size = Vector2(640, 720)
	left_shade.color = Color(0.035, 0.025, 0.035, 0.42)
	left_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(left_shade)

	frame = PanelContainer.new()
	frame.position = Vector2(64, 72)
	frame.size = Vector2(500, 576)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.035, 0.035, 0.045, 0.91)
	frame_style.border_color = Color("d18a51")
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(0)
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	frame_style.shadow_size = 14
	frame_style.content_margin_left = 28
	frame_style.content_margin_right = 28
	frame_style.content_margin_top = 25
	frame_style.content_margin_bottom = 22
	frame.add_theme_stylebox_override("panel", frame_style)
	root_control.add_child(frame)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	frame.add_child(content)

	_build_mission_panel()
	var footer := _make_label("ARCADIA EXPEDITION  //  BUILD 0.2.0  //  GODOT 4.7.2", 10, Color("c6aa8c"))
	footer.position = Vector2(820, 678)
	footer.size = Vector2(420, 20)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root_control.add_child(footer)

func _build_mission_panel() -> void:
	mission_panel = PanelContainer.new()
	mission_panel.position = Vector2(850, 496)
	mission_panel.size = Vector2(360, 142)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.035, 0.045, 0.76)
	panel_style.border_color = Color(0.71, 0.43, 0.28, 0.82)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(0)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 13
	panel_style.content_margin_bottom = 11
	mission_panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(mission_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	mission_panel.add_child(box)
	box.add_child(_make_label("MISSION DOSSIER  /  742-A", 14, Color("e9a15e")))
	box.add_child(_make_label("LOCATION     ARCADIA PLANITIA", 11, Color("e8decc")))
	box.add_child(_make_label("CREW STATUS  01 SURVIVOR", 11, Color("e8decc")))
	box.add_child(_make_label("EARTH LINK    LOST // 26 MONTHS", 11, Color("f08e6c")))

func _rebuild_page() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

	if current_page == "settings":
		_build_settings_page()
	elif current_page == "pause":
		_build_pause_page()
	else:
		_build_main_page()

func _build_main_page() -> void:
	title_label = _make_label("ARCADIA SUBSIST", 34, Color("f2b46d"))
	title_label.add_theme_color_override("font_shadow_color", Color("2a1518"))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	content.add_child(title_label)
	content.add_child(_make_label("A LONE ENGINEER. A BROKEN HABITAT.\nA PLANET THAT DOES NOT FORGIVE.", 12, Color("d8c8b3")))
	_add_separator()
	content.add_child(_make_label("EXPEDITION CONTROL", 13, Color("d18a51")))

	var new_button := _make_button("NEW EXPEDITION")
	new_button.pressed.connect(func() -> void: new_game_requested.emit())
	content.add_child(new_button)

	var continue_button := _make_button("CONTINUE EXPEDITION")
	continue_button.disabled = not continue_available
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	content.add_child(continue_button)

	var settings_button := _make_button("SETTINGS")
	settings_button.pressed.connect(func() -> void: _open_settings("main"))
	content.add_child(settings_button)

	var quit_button := _make_button("QUIT TO DESKTOP")
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	content.add_child(quit_button)

	content.add_spacer(false)
	content.add_child(_make_label("TIP  //  SALVAGE THE LANDER BEFORE THE STORM ARRIVES.", 10, Color("c6aa8c")))

func _build_pause_page() -> void:
	title_label = _make_label("EXPEDITION PAUSED", 30, Color("f2b46d"))
	content.add_child(title_label)
	content.add_child(_make_label("LIFE SUPPORT IS WAITING. TAKE A BREATH.", 12, Color("d8c8b3")))
	_add_separator()

	var resume_button := _make_button("RESUME EXPEDITION")
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	content.add_child(resume_button)

	var save_button := _make_button("SAVE  /  RETURN TO MAIN MENU")
	save_button.pressed.connect(func() -> void: save_and_menu_requested.emit())
	content.add_child(save_button)

	var settings_button := _make_button("SETTINGS")
	settings_button.pressed.connect(func() -> void: _open_settings("pause"))
	content.add_child(settings_button)

	var quit_button := _make_button("QUIT TO DESKTOP")
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	content.add_child(quit_button)

	content.add_spacer(false)
	content.add_child(_make_label("PROGRESS AUTOSAVES PERIODICALLY.", 10, Color("c6aa8c")))

func _build_settings_page() -> void:
	title_label = _make_label("SETTINGS", 32, Color("f2b46d"))
	content.add_child(title_label)
	content.add_child(_make_label("DISPLAY AND AUDIO", 12, Color("d8c8b3")))
	_add_separator()

	var volume_title := _make_label("MASTER VOLUME", 13, Color("e7d5bc"))
	content.add_child(volume_title)
	var volume_value := _make_label("%d%%" % roundi(master_volume * 100.0), 12, Color("e9a15e"))
	content.add_child(volume_value)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = master_volume * 100.0
	volume_slider.custom_minimum_size = Vector2(0, 28)
	volume_slider.value_changed.connect(func(value: float) -> void:
		master_volume = value / 100.0
		volume_value.text = "%d%%" % roundi(value)
		_apply_volume()
		_save_settings()
	)
	content.add_child(volume_slider)

	var fullscreen_check := CheckButton.new()
	fullscreen_check.text = "FULLSCREEN"
	fullscreen_check.button_pressed = fullscreen_enabled
	fullscreen_check.add_theme_color_override("font_color", Color("e7d5bc"))
	fullscreen_check.toggled.connect(func(enabled: bool) -> void:
		fullscreen_enabled = enabled
		_apply_fullscreen()
		_save_settings()
	)
	content.add_child(fullscreen_check)

	content.add_spacer(false)
	var back_button := _make_button("BACK")
	back_button.pressed.connect(func() -> void:
		current_page = settings_return_page
		_rebuild_page()
	)
	content.add_child(back_button)

func _open_settings(from_page: String) -> void:
	settings_return_page = from_page
	current_page = "settings"
	_rebuild_page()

func _add_separator() -> void:
	var line := ColorRect.new()
	line.color = Color(0.76, 0.43, 0.25, 0.72)
	line.custom_minimum_size = Vector2(0, 2)
	content.add_child(line)

func _make_button(button_text: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("f0e1cb"))
	button.add_theme_color_override("font_hover_color", Color("fff2d9"))
	button.add_theme_color_override("font_pressed_color", Color("f0bd78"))
	button.add_theme_color_override("font_disabled_color", Color("77706b"))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("292326")
	normal.border_color = Color("98613f")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(0)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("493128")
	hover.border_color = Color("e3a15f")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("1c1a21")	
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("222126")
	disabled.border_color = Color("514b4a")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)
	return button

func _make_label(label_text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = float(config.get_value("audio", "master_volume", 0.78))
		fullscreen_enabled = bool(config.get_value("display", "fullscreen", false))
	_apply_volume()
	_apply_fullscreen()

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen_enabled)
	config.save(SETTINGS_PATH)

func _apply_volume() -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var volume_db: float = -80.0 if master_volume <= 0.001 else linear_to_db(master_volume)
		AudioServer.set_bus_volume_db(master_bus, volume_db)

func _apply_fullscreen() -> void:
	if fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
