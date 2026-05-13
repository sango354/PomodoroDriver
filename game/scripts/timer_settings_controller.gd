extends Node

signal focus_duration_delta_requested(delta_minutes: int)
signal break_duration_delta_requested(delta_minutes: int)
signal auto_restart_pressed
signal alarm_pressed

const TIMER_RAIL_LEFT := 0
const TIMER_RAIL_TOP := 58
const TIMER_RAIL_HEIGHT := 222
const TIMER_SETTINGS_GAP := 12
const TIMER_SETTINGS_HEIGHT := 238

var settings_panel: PanelContainer
var duration_value_label: Label
var break_duration_value_label: Label
var auto_restart_toggle: Button
var alarm_toggle: Button
var title_label: Label
var focus_label: Label
var break_label: Label
var auto_restart_label: Label
var alarm_label: Label
var localizer
var _auto_restart_enabled := false
var _alarm_enabled := false


func setup(
	parent: Control,
	timer_rail_width: int,
	panel_width: int,
	duration_minutes: int,
	break_duration_minutes: int,
	auto_restart_enabled: bool,
	alarm_enabled: bool,
	localization_service = null
) -> void:
	localizer = localization_service
	_build_settings_panel(parent, timer_rail_width, panel_width, auto_restart_enabled, alarm_enabled)
	refresh_durations(duration_minutes, break_duration_minutes)


func toggle_visible() -> void:
	settings_panel.visible = not settings_panel.visible


func hide() -> void:
	if settings_panel != null:
		settings_panel.visible = false


func refresh_durations(duration_minutes: int, break_duration_minutes: int) -> void:
	if duration_value_label != null:
		duration_value_label.text = "%d min" % duration_minutes
	if break_duration_value_label != null:
		break_duration_value_label.text = "%d min" % break_duration_minutes


func refresh_auto_restart(enabled: bool) -> void:
	_auto_restart_enabled = enabled
	_refresh_switch_button(auto_restart_toggle, enabled)


func refresh_alarm(enabled: bool) -> void:
	_alarm_enabled = enabled
	_refresh_switch_button(alarm_toggle, enabled)


func set_localizer(localization_service) -> void:
	localizer = localization_service
	refresh_text()


func refresh_text() -> void:
	if title_label != null:
		title_label.text = _tr("settings.title")
	if focus_label != null:
		focus_label.text = _tr("settings.focus_duration")
	if break_label != null:
		break_label.text = _tr("settings.break_duration")
	if auto_restart_label != null:
		auto_restart_label.text = _tr("settings.auto_restart")
	if alarm_label != null:
		alarm_label.text = _tr("settings.alarm")
	refresh_auto_restart(_auto_restart_enabled)
	refresh_alarm(_alarm_enabled)


func _build_settings_panel(
	parent: Control,
	timer_rail_width: int,
	panel_width: int,
	auto_restart_enabled: bool,
	alarm_enabled: bool
) -> void:
	_auto_restart_enabled = auto_restart_enabled
	_alarm_enabled = alarm_enabled
	settings_panel = _new_panel()
	settings_panel.name = "SettingsPanel"
	settings_panel.visible = false
	settings_panel.anchor_top = 0.0
	settings_panel.anchor_bottom = 0.0
	settings_panel.anchor_left = 0.0
	settings_panel.anchor_right = 0.0
	var settings_left := TIMER_RAIL_LEFT + timer_rail_width + TIMER_SETTINGS_GAP
	var settings_top := TIMER_RAIL_TOP
	settings_panel.offset_left = settings_left
	settings_panel.offset_top = settings_top
	settings_panel.offset_right = settings_left + panel_width
	settings_panel.offset_bottom = settings_top + TIMER_SETTINGS_HEIGHT
	parent.add_child(settings_panel)

	var box := _panel_box(settings_panel)
	title_label = _new_title(_tr("settings.title"))
	box.add_child(title_label)
	focus_label = _new_muted_label(_tr("settings.focus_duration"))
	box.add_child(focus_label)
	_build_duration_adjuster(box, true)
	break_label = _new_muted_label(_tr("settings.break_duration"))
	box.add_child(break_label)
	_build_duration_adjuster(box, false)

	auto_restart_toggle = _build_settings_toggle(box, _tr("settings.auto_restart"), auto_restart_enabled)
	auto_restart_toggle.pressed.connect(func(): auto_restart_pressed.emit())
	alarm_toggle = _build_settings_toggle(box, _tr("settings.alarm"), alarm_enabled)
	alarm_toggle.pressed.connect(func(): alarm_pressed.emit())


func _build_duration_adjuster(parent: VBoxContainer, focus: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var minus_button := Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(42, 32)
	if focus:
		minus_button.pressed.connect(func(): focus_duration_delta_requested.emit(-1))
	else:
		minus_button.pressed.connect(func(): break_duration_delta_requested.emit(-1))
	_add_hover_effect(minus_button)
	row.add_child(minus_button)

	var value_label := _new_muted_label("")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(92, 32)
	row.add_child(value_label)
	if focus:
		duration_value_label = value_label
	else:
		break_duration_value_label = value_label

	var plus_button := Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(42, 32)
	if focus:
		plus_button.pressed.connect(func(): focus_duration_delta_requested.emit(1))
	else:
		plus_button.pressed.connect(func(): break_duration_delta_requested.emit(1))
	_add_hover_effect(plus_button)
	row.add_child(plus_button)


func _build_settings_toggle(parent: VBoxContainer, label_text: String, enabled: bool) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := _new_muted_label(label_text)
	label.custom_minimum_size = Vector2(154, 0)
	row.add_child(label)
	if label_text == _tr("settings.auto_restart"):
		auto_restart_label = label
	elif label_text == _tr("settings.alarm"):
		alarm_label = label

	var toggle := Button.new()
	toggle.text = ""
	toggle.custom_minimum_size = Vector2(54, 30)
	toggle.focus_mode = Control.FOCUS_NONE
	_add_hover_effect(toggle)
	var knob := Panel.new()
	knob.name = "SwitchKnob"
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.add_theme_stylebox_override("panel", _new_switch_knob_style())
	toggle.add_child(knob)
	_refresh_switch_button(toggle, enabled)
	row.add_child(toggle)
	return toggle


func _new_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _new_panel_style(0.62))
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


func _panel_box(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return box


func _new_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	return label


func _new_muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.9, 0.92))
	return label


func _add_hover_effect(control: Control) -> void:
	control.mouse_entered.connect(_on_hover_scale.bind(control, true))
	control.mouse_exited.connect(_on_hover_scale.bind(control, false))


func _on_hover_scale(control: Control, hovered: bool) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * (1.1 if hovered else 1.0)


func _new_switch_style(enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.11, 0.24, 0.85) if enabled else Color(0.08, 0.1, 0.18, 0.78)
	style.border_color = Color(1, 1, 1, 0.82)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	return style


func _refresh_switch_button(button: Button, enabled: bool) -> void:
	if button == null:
		return
	button.tooltip_text = _tr("settings.on") if enabled else _tr("settings.off")
	button.add_theme_stylebox_override("normal", _new_switch_style(enabled))
	button.add_theme_stylebox_override("hover", _new_switch_style(enabled))
	button.add_theme_stylebox_override("pressed", _new_switch_style(enabled))
	var knob := button.get_node_or_null("SwitchKnob") as Control
	if knob == null:
		return
	knob.anchor_top = 0.5
	knob.anchor_bottom = 0.5
	knob.anchor_left = 1.0 if enabled else 0.0
	knob.anchor_right = 1.0 if enabled else 0.0
	knob.offset_left = -24 if enabled else 4
	knob.offset_right = -4 if enabled else 24
	knob.offset_top = -10
	knob.offset_bottom = 10


func _new_switch_knob_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.94, 0.98, 1.0)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _tr(key: String) -> String:
	if localizer != null:
		return localizer.translate(key)
	return key
