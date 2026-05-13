extends Node

signal primary_pressed
signal reset_pressed
signal settings_pressed

const ICON_RESET_PATH := "res://assets/Arts/UI/Button_reset.png"
const ICON_SETTINGS_PATH := "res://assets/Arts/UI/Button_config.png"
const PANEL_CLOCK_PATH := "res://assets/Arts/UI/Panel_clock.png"
const BUTTON_START_PATH := "res://assets/Arts/UI/Button_start.png"
const TIMER_RAIL_WIDTH := 260
const TIMER_RAIL_LEFT := 0
const TIMER_RAIL_TOP := 58
const TIMER_RAIL_HEIGHT := 325
const DEFAULT_FOCUS_MINUTES := 5
const DEFAULT_BREAK_MINUTES := 5
const TIMER_RUNNING_COLOR := Color(1, 1, 1, 1)
const TIMER_INACTIVE_COLOR := Color(0.5, 0.5, 0.5, 1)

var timer_label: Label
var timer_panel: Control
var break_time_label: Label
var phase_label: Label
var primary_timer_button: BaseButton
var primary_timer_label: Label
var reset_button: BaseButton
var settings_button: BaseButton
var localizer
var _last_app_state := "idle"
var _last_session_mode := "focus"
var _last_planned_duration_sec := DEFAULT_FOCUS_MINUTES * 60
var _last_elapsed_sec := 0.0
var _last_duration_minutes := DEFAULT_FOCUS_MINUTES
var _last_break_duration_minutes := DEFAULT_BREAK_MINUTES


func setup(parent: Control, localization_service = null) -> void:
	localizer = localization_service
	_build_timer_rail(parent)


func refresh_timer(
	app_state: String,
	session_mode: String,
	planned_duration_sec: int,
	elapsed_sec: float,
	duration_minutes: int,
	break_duration_minutes: int
) -> void:
	_last_app_state = app_state
	_last_session_mode = session_mode
	_last_planned_duration_sec = planned_duration_sec
	_last_elapsed_sec = elapsed_sec
	_last_duration_minutes = duration_minutes
	_last_break_duration_minutes = break_duration_minutes
	var active_remaining: int = max(planned_duration_sec - int(elapsed_sec), 0)
	var focus_remaining := duration_minutes * 60
	var break_remaining := break_duration_minutes * 60
	if session_mode == "focus":
		focus_remaining = active_remaining
	elif session_mode == "short_break":
		focus_remaining = 0
		break_remaining = active_remaining

	timer_label.text = _format_time(focus_remaining)
	timer_label.add_theme_color_override(
		"font_color",
		TIMER_RUNNING_COLOR if session_mode == "focus" and app_state == "running" else TIMER_INACTIVE_COLOR
	)
	break_time_label.text = _trf("timer.break_label", {"time": _format_time(break_remaining)})
	break_time_label.add_theme_color_override(
		"font_color",
		TIMER_RUNNING_COLOR if session_mode == "short_break" and app_state == "running" else TIMER_INACTIVE_COLOR
	)
	var mode_text := _tr("timer.focus") if session_mode == "focus" else _tr("timer.short_break")
	phase_label.text = "%s - %s" % [mode_text, _tr("timer.state_%s" % app_state)]


func refresh_controls(app_state: String) -> void:
	_last_app_state = app_state
	primary_timer_button.disabled = false
	if app_state == "running":
		primary_timer_label.text = _tr("timer.pause")
		primary_timer_button.tooltip_text = _tr("timer.pause")
	elif app_state == "paused":
		primary_timer_label.text = _tr("timer.resume")
		primary_timer_button.tooltip_text = _tr("timer.resume")
	else:
		primary_timer_label.text = _tr("timer.start")
		primary_timer_button.tooltip_text = _tr("timer.start")
	reset_button.disabled = false


func set_localizer(localization_service) -> void:
	localizer = localization_service
	refresh_timer(
		_last_app_state,
		_last_session_mode,
		_last_planned_duration_sec,
		_last_elapsed_sec,
		_last_duration_minutes,
		_last_break_duration_minutes
	)
	refresh_controls(_last_app_state)
	if settings_button != null:
		settings_button.tooltip_text = _tr("timer.settings")
	if reset_button != null:
		reset_button.tooltip_text = _tr("timer.reset")


func set_panel_visible(is_visible: bool) -> void:
	if timer_panel != null:
		timer_panel.visible = is_visible


func _build_timer_rail(parent: Control) -> void:
	var panel := _new_panel()
	timer_panel = panel
	panel.name = "TimerRail"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = TIMER_RAIL_LEFT
	panel.offset_top = TIMER_RAIL_TOP
	panel.offset_right = TIMER_RAIL_LEFT + TIMER_RAIL_WIDTH
	panel.offset_bottom = TIMER_RAIL_TOP + TIMER_RAIL_HEIGHT
	panel.custom_minimum_size = Vector2(TIMER_RAIL_WIDTH, 0)
	parent.add_child(panel)
	var box := _panel_box(panel)

	phase_label = _new_muted_label("")
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(phase_label)

	timer_label = Label.new()
	timer_label.text = _format_time(DEFAULT_FOCUS_MINUTES * 60)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 44)
	timer_label.add_theme_color_override("font_color", Color(0.28, 0.16, 0.1, 1.0))
	box.add_child(timer_label)

	break_time_label = _new_muted_label(_trf("timer.break_label", {"time": _format_time(DEFAULT_BREAK_MINUTES * 60)}))
	break_time_label.name = "BreakLabel"
	break_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(break_time_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(controls)

	settings_button = _new_icon_asset_button(ICON_SETTINGS_PATH, _tr("timer.settings"), Vector2(38, 38))
	settings_button.pressed.connect(func(): settings_pressed.emit())
	controls.add_child(settings_button)

	primary_timer_button = _new_timer_action_button(_tr("timer.start"), _tr("timer.start"))
	primary_timer_button.pressed.connect(func(): primary_pressed.emit())
	controls.add_child(primary_timer_button)

	reset_button = _new_icon_asset_button(ICON_RESET_PATH, _tr("timer.reset"), Vector2(38, 38))
	reset_button.pressed.connect(func(): reset_pressed.emit())
	controls.add_child(reset_button)


func _new_panel() -> Control:
	var panel := Control.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var background := TextureRect.new()
	background.texture = _load_icon_texture(PANEL_CLOCK_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(background)
	return panel


func _new_panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.068, alpha)
	style.border_color = Color(1, 1, 1, 0.14)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _panel_box(panel: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 68)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	return box


func _new_muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.38, 0.24, 0.16, 0.92))
	return label


func _new_icon_asset_button(icon_path: String, tip: String, size: Vector2) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _load_icon_texture(icon_path)
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.texture_disabled = button.texture_normal
	button.tooltip_text = tip
	button.custom_minimum_size = size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.mouse_entered.connect(_on_hover_scale.bind(button, true))
	button.mouse_exited.connect(_on_hover_scale.bind(button, false))
	return button


func _load_icon_texture(icon_path: String) -> Texture2D:
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
	if FileAccess.file_exists(icon_path):
		var image := Image.new()
		if image.load(icon_path) == OK:
			return ImageTexture.create_from_image(image)
	return null


func _new_timer_action_button(text: String, tip: String) -> BaseButton:
	var button := TextureButton.new()
	button.texture_normal = _load_icon_texture(BUTTON_START_PATH)
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.texture_disabled = button.texture_normal
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(112, 36)
	button.focus_mode = Control.FOCUS_NONE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	primary_timer_label = Label.new()
	primary_timer_label.text = text
	primary_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	primary_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	primary_timer_label.add_theme_color_override("font_color", Color(0.34, 0.18, 0.1, 1.0))
	primary_timer_label.add_theme_font_size_override("font_size", 16)
	primary_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	primary_timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(primary_timer_label)
	button.mouse_entered.connect(_on_hover_scale.bind(button, true))
	button.mouse_exited.connect(_on_hover_scale.bind(button, false))
	return button


func _apply_timer_button_style(button: Button) -> void:
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.add_theme_stylebox_override("disabled", empty_style)


func _on_hover_scale(button: Control, hovered: bool) -> void:
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE * (1.1 if hovered else 1.0)


func _format_time(seconds: int) -> String:
	var minutes := seconds / 60
	var secs := seconds % 60
	return "%02d:%02d" % [minutes, secs]


func _tr(key: String) -> String:
	if localizer != null:
		return localizer.translate(key)
	return key


func _trf(key: String, values: Dictionary) -> String:
	if localizer != null:
		return localizer.trf(key, values)
	return key
