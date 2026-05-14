extends Node

const SaveDataService = preload("res://scripts/save_data_service.gd")
const ProgressionService = preload("res://scripts/progression_service.gd")
const TaxiDriveController = preload("res://scripts/taxi_drive_controller.gd")
const MusicPlayerController = preload("res://scripts/music_player_controller.gd")
const CompanionPanelController = preload("res://scripts/companion_panel_controller.gd")
const TimerRailController = preload("res://scripts/timer_rail_controller.gd")
const TimerSettingsController = preload("res://scripts/timer_settings_controller.gd")
const TimerSessionService = preload("res://scripts/timer_session_service.gd")
const LocalizationService = preload("res://scripts/localization_service.gd")
const OptionPanelController = preload("res://scripts/option_panel_controller.gd")
const TaskPanelController = preload("res://scripts/task_panel_controller.gd")
const ResultPanelController = preload("res://scripts/result_panel_controller.gd")
const SessionRewardCoordinator = preload("res://scripts/session_reward_coordinator.gd")
const BreakMediaController = preload("res://scripts/break_media_controller.gd")
const ContentUnlockService = preload("res://scripts/content_unlock_service.gd")
const StorePanelController = preload("res://scripts/store_panel_controller.gd")
const AVGDialogueService = preload("res://scripts/avg_dialogue_service.gd")
const AVGDialogueController = preload("res://scripts/avg_dialogue_controller.gd")
const AVGGalleryController = preload("res://scripts/avg_gallery_controller.gd")
const PassengerFlowService = preload("res://scripts/passenger_flow_service.gd")
const PassengerQuizController = preload("res://scripts/passenger_quiz_controller.gd")

const SAVE_PATH := "user://save.json"
const ALARM_SOUND_PATH := "res://assets/sfx/alarm_placeholder.wav"
const DEFAULT_BREAK_MEDIA_PATH := "res://assets/videos/break/video.mp4"
const SETTINGS_PANEL_WIDTH := 264
const TIMER_RAIL_WIDTH := 260
const DEFAULT_FOCUS_MINUTES := 5
const DEFAULT_BREAK_MINUTES := 5
const MIN_REWARDABLE_SESSION_SEC := 300
const BASE_FOCUS_POINTS := 20
const BASE_BOND := 10
const BASE_XP := 30
const TASK_BONUS_FOCUS_POINTS := 8
const TASK_BONUS_XP := 10
const AMBIENT_PROMPT_LOW := "low"
const AMBIENT_PROMPT_NORMAL := "normal"
const AMBIENT_PROMPT_OFF := "off"
const AMBIENT_PROMPT_INITIAL_IDLE_SEC := 20
const AMBIENT_PROMPT_LOW_IDLE_INTERVAL_SEC := 90
const AMBIENT_PROMPT_NORMAL_IDLE_INTERVAL_SEC := 3 * 60
const AMBIENT_PROMPT_FOCUS_INTERVAL_SEC := 8 * 60
const AMBIENT_PROMPT_VISIBLE_SEC := 8.0
const BACKGROUND_LOFI_AUTO := "lofi_auto"
const FIRST_ENTRY_DIALOGUE_ID := "first_entry_welcome"
const H_EVENT_PREVIEW_DIALOGUE_ID := "h_event_preview"
const H_EVENT_DIALOGUE_COUNT := 2
const PASSENGER_QUIZ_ROUNDS := 10
const PASSENGER_MIN_REWARDABLE_SESSION_SEC := 300
const QUIT_VIEWPORT_SHUTDOWN_FRAMES := 2
const ICON_TUTORIAL_PATH := "res://assets/Arts/UI/ICON_tutorial.png"
const ICON_MEMORY_PATH := "res://assets/Arts/UI/ICON_memory.png"
const ICON_STATISTICS_PATH := "res://assets/Arts/UI/ICON_statistics.png"
const ICON_FOCUS_POINT_PATH := "res://assets/Arts/UI/Icon_FocusPoint.png"
const ICON_TOKEN_PATH := "res://assets/Arts/UI/Icon_Token.png"
const ICON_TOKEN_BAR_PATH := "res://assets/Arts/UI/Icon_Tokenbar.png"
const PANEL_BOND_LEVEL_PATH := "res://assets/Arts/UI/Panel_Bondlevel.png"
const ICON_SIMPLE_MODE_PATH := "res://assets/Arts/UI/Icon_simplemode.png"
const ICON_MISSION_PATH := "res://assets/Arts/UI/ICON_mission.png"
const ICON_HIDE_MISSION_PATH := "res://assets/Arts/UI/ICON_hidemission.png"
const ICON_HIDE_CLOCK_PATH := "res://assets/Arts/UI/Icon_hideclock.png"

var app_state := "idle"
var session_mode := "focus"
var result_dismissed := false
var planned_duration_sec := DEFAULT_FOCUS_MINUTES * 60
var elapsed_sec := 0.0
var session_started_at := ""
var active_task_id := ""
var selected_context := {
	"mood": "normal",
	"time": "day",
	"weather": "clear"
}

var tasks: Array = []
var sessions: Array = []
var currencies := {
	"focus_points": 0,
	"bond_points_total": 0,
	"gold_tokens": 0
}
var level_progress := {
	"focus_level": 1,
	"focus_xp": 0,
	"focus_xp_lifetime": 0
}
var bond_progress := {
	"character_id": "companion_01",
	"bond_level": 1,
	"bond_points_current": 0,
	"bond_points_lifetime": 0
}
var daily_stats := {
	"focus_minutes_completed": 0,
	"focus_minutes_partial": 0,
	"completed_sessions": 0,
	"partial_sessions": 0,
	"tasks_completed": 0
}

var drive_scene: Node
var timer_rail: Node
var localizer
var option_controller: Node
var task_controller: Node
var result_controller: Node
var break_media_controller: Node
var store_controller: Node
var avg_dialogue_controller: Node
var avg_gallery_controller: Node
var passenger_quiz_controller: Node

var root_2d: Node2D
var ui_layer: CanvasLayer
var app_container: Control
var message_label: Label
var top_bar: Control
var bottom_mode_controls: Control
var background_menu_panel: PanelContainer
var tutorial_button: BaseButton
var tutorial_panel: PanelContainer
var simple_mode_button: BaseButton
var tasks_toggle_button: BaseButton
var timer_toggle_button: BaseButton
var ambience_toggle_button: Control
var fullscreen_toggle_button: Button
var focus_progress_hud: Control
var fp_label: Control
var focus_points_value_label: Label
var bond_level_label: Label
var level_label: Control
var focus_level_badge_label: Label
var focus_level_progress: ProgressBar
var bond_label: Button
var stats_panel: PanelContainer
var stats_label: Label
var duration_minutes := DEFAULT_FOCUS_MINUTES
var break_duration_minutes := DEFAULT_BREAK_MINUTES
var auto_restart_enabled := false
var alarm_enabled := false
var timer_settings: Node
var saved_music_path := ""
var music_loop := false
var music_volume := 0.7
var music_controller: Node
var companion_controller: Node
var alarm_player: AudioStreamPlayer
var language_code := "en"
var break_media_enabled := false
var break_media_path := DEFAULT_BREAK_MEDIA_PATH
var ambient_prompt_frequency := AMBIENT_PROMPT_NORMAL
var interaction_history: Array = []
var background_defs: Array = []
var unlocked_content: Array = []
var ambient_prompt_elapsed_sec := 0.0
var ambient_prompt_visible_sec := 0.0
var ambient_prompt_has_shown := false
var unlocks_label: Button
var store_button: Button
var avg_gallery_button: BaseButton
var stats_button: BaseButton
var simple_mode_enabled := false
var tasks_ui_visible := true
var timer_ui_visible := true
var manual_time_state := "day"
var selected_background_id := BACKGROUND_LOFI_AUTO
var h_event_active := false
var h_event_queue: Array = []
var h_event_pending_unlock := {}
var h_event_music_state := {}
var avg_dialogue_music_state := {}
var avg_dialogue_music_suspended := false
var passenger_quiz_active := false
var passenger_quiz_music_state := {}
var passenger_defs: Array = []
var passenger_questions: Array = []
var passenger_progress := {}
var current_passenger_id := ""
var current_passenger := {}
var current_passenger_complete_bonus := false
var threshold_warning_dialog: ConfirmationDialog
var completed_passenger_dialog: ConfirmationDialog
var gallery_unlock_confirm_dialog: ConfirmationDialog
var pending_gallery_unlock := {}
var pending_passenger_success_event := {}
var quiz_state := {}
var quit_requested := false
var previous_window_mode := DisplayServer.WINDOW_MODE_WINDOWED
var has_previous_window_mode := false


func _ready() -> void:
	randomize()
	get_tree().auto_accept_quit = false
	_load_save()
	_ensure_currency_defaults()
	background_defs = ContentUnlockService.load_background_defs()
	passenger_defs = PassengerFlowService.load_passengers()
	passenger_questions = PassengerFlowService.load_questions()
	passenger_progress = PassengerFlowService.normalize_progress(passenger_progress, passenger_defs)
	localizer = LocalizationService.new(language_code)
	_apply_time_context()
	manual_time_state = _time_state_from_context()
	_build_scene()
	drive_scene.load_selected_background()
	_refresh_all()
	call_deferred("_begin_next_passenger")


func _process(delta: float) -> void:
	_update_ambient_prompt(delta)
	if app_state != "running":
		return

	var tick := TimerSessionService.advance(elapsed_sec, delta, planned_duration_sec)
	elapsed_sec = float(tick.elapsed_sec)
	if tick.finished:
		if session_mode == "focus":
			_finish_session("completed", true)
		else:
			_finish_break()
		return

	_refresh_timer_ui()


func _input(event: InputEvent) -> void:
	if _handle_top_bar_popup_pointer(event):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		currencies.focus_points = int(currencies.get("focus_points", 0)) + 100
		_save_game()
		_refresh_progress_ui()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		currencies.gold_tokens = int(currencies.get("gold_tokens", 0)) + 1
		_save_game()
		_refresh_progress_ui()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		if drive_scene != null and drive_scene.has_method("trigger_sky_transition"):
			drive_scene.trigger_sky_transition()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		_reset_debug_data()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		_debug_start_passenger_quiz()


func _handle_top_bar_popup_pointer(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return false
	if not _has_top_bar_popup_open():
		return false
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_hide_top_bar_popups()
		get_viewport().set_input_as_handled()
		return true
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if top_bar != null and top_bar.get_global_rect().has_point(mouse_event.position):
		return false
	if not _top_bar_popup_contains_point(mouse_event.position):
		_hide_top_bar_popups()
		get_viewport().set_input_as_handled()
		return true
	return false


func _has_top_bar_popup_open() -> bool:
	if stats_panel != null and stats_panel.visible:
		return true
	if tutorial_panel != null and tutorial_panel.visible:
		return true
	if option_controller != null and option_controller.has_method("is_visible") and option_controller.is_visible():
		return true
	if avg_gallery_controller != null and avg_gallery_controller.has_method("is_gallery_visible") and avg_gallery_controller.is_gallery_visible():
		return true
	return false


func _top_bar_popup_contains_point(point: Vector2) -> bool:
	if stats_panel != null and stats_panel.visible and stats_panel.get_global_rect().has_point(point):
		return true
	if tutorial_panel != null and tutorial_panel.visible and tutorial_panel.get_global_rect().has_point(point):
		return true
	if option_controller != null and option_controller.has_method("contains_global_point") and option_controller.contains_global_point(point):
		return true
	if avg_gallery_controller != null and avg_gallery_controller.has_method("contains_global_point") and avg_gallery_controller.contains_global_point(point):
		return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()


func _request_quit() -> void:
	if quit_requested:
		return
	quit_requested = true
	set_process(false)
	_save_game()
	if drive_scene != null and drive_scene.has_method("prepare_for_quit"):
		drive_scene.prepare_for_quit()
	call_deferred("_quit_after_viewport_shutdown")


func _quit_after_viewport_shutdown() -> void:
	for _i in range(QUIT_VIEWPORT_SHUTDOWN_FRAMES):
		await get_tree().process_frame
	get_tree().quit()


func _build_scene() -> void:
	root_2d = Node2D.new()
	root_2d.name = "World"
	add_child(root_2d)

	drive_scene = TaxiDriveController.new()
	add_child(drive_scene)
	drive_scene.setup(root_2d, selected_context, background_defs, unlocked_content, selected_background_id)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)

	app_container = Control.new()
	app_container.name = "App"
	app_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(app_container)

	var overlay := ColorRect.new()
	overlay.name = "ReadabilityOverlay"
	overlay.color = Color(0.04, 0.045, 0.05, 0.16)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	app_container.add_child(overlay)

	var margins := MarginContainer.new()
	margins.name = "LayoutMargins"
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 28)
	margins.add_theme_constant_override("margin_top", 24)
	margins.add_theme_constant_override("margin_right", 28)
	margins.add_theme_constant_override("margin_bottom", 22)
	app_container.add_child(margins)

	var layers := Control.new()
	layers.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.add_child(layers)

	message_label = Label.new()
	message_label.visible = false
	layers.add_child(message_label)

	option_controller = OptionPanelController.new()
	add_child(option_controller)
	option_controller.setup(layers, localizer, break_media_enabled, ambient_prompt_frequency)
	option_controller.language_previous_pressed.connect(_on_previous_language_pressed)
	option_controller.language_next_pressed.connect(_on_next_language_pressed)
	option_controller.break_media_pressed.connect(_on_break_media_toggled)
	option_controller.ambient_prompt_pressed.connect(_on_ambient_prompt_frequency_pressed)
	option_controller.panel_opened.connect(_on_option_panel_opened)

	_build_top_bar(layers)
	store_controller = StorePanelController.new()
	add_child(store_controller)
	store_controller.setup(layers, localizer)
	store_controller.purchase_requested.connect(_on_store_purchase_requested)
	avg_dialogue_controller = AVGDialogueController.new()
	add_child(avg_dialogue_controller)
	avg_dialogue_controller.setup(app_container, localizer)
	avg_dialogue_controller.dialogue_finished.connect(_on_avg_dialogue_finished)
	avg_gallery_controller = AVGGalleryController.new()
	add_child(avg_gallery_controller)
	avg_gallery_controller.setup(layers, localizer)
	avg_gallery_controller.dialogue_selected.connect(_on_avg_gallery_dialogue_selected)
	avg_gallery_controller.unlock_requested.connect(_on_avg_gallery_unlock_requested)
	passenger_quiz_controller = PassengerQuizController.new()
	add_child(passenger_quiz_controller)
	passenger_quiz_controller.setup(layers, localizer)
	passenger_quiz_controller.answer_selected.connect(_on_passenger_quiz_answer_selected)
	passenger_quiz_controller.answer_response_finished.connect(_on_passenger_quiz_answer_response_finished)
	passenger_quiz_controller.quiz_dismissed.connect(_on_passenger_quiz_dismissed)
	task_controller = TaskPanelController.new()
	add_child(task_controller)
	task_controller.setup(layers, tasks, localizer)
	task_controller.tasks_changed.connect(_on_tasks_changed)
	task_controller.task_renamed.connect(_on_task_renamed)
	task_controller.task_completed.connect(_on_task_completed)
	_build_focus_progress_hud(layers)
	timer_rail = TimerRailController.new()
	add_child(timer_rail)
	timer_rail.setup(layers, localizer)
	timer_rail.primary_pressed.connect(_on_primary_timer_pressed)
	timer_rail.reset_pressed.connect(_on_reset_pressed)
	timer_rail.settings_pressed.connect(_toggle_settings_panel)
	timer_settings = TimerSettingsController.new()
	add_child(timer_settings)
	timer_settings.setup(
		layers,
		TIMER_RAIL_WIDTH,
		SETTINGS_PANEL_WIDTH,
		duration_minutes,
		break_duration_minutes,
		auto_restart_enabled,
		alarm_enabled,
		localizer
	)
	timer_settings.focus_duration_delta_requested.connect(_adjust_duration_minutes)
	timer_settings.break_duration_delta_requested.connect(_adjust_break_duration_minutes)
	timer_settings.auto_restart_pressed.connect(_on_auto_restart_toggled)
	timer_settings.alarm_pressed.connect(_on_alarm_toggled)
	result_controller = ResultPanelController.new()
	add_child(result_controller)
	result_controller.setup(layers, localizer)
	result_controller.mark_task_done_pressed.connect(_on_mark_bound_task_done)
	result_controller.break_pressed.connect(_on_break_pressed)
	companion_controller = CompanionPanelController.new()
	add_child(companion_controller)
	companion_controller.setup(layers, localizer)
	companion_controller.break_interaction_viewed.connect(_on_break_interaction_viewed)
	companion_controller.break_interaction_skipped.connect(_on_break_interaction_skipped)
	companion_controller.break_interaction_advanced.connect(_on_break_interaction_advanced)
	companion_controller.ambient_prompt_shown.connect(_on_ambient_prompt_shown)
	companion_controller.ambient_prompt_dismissed.connect(_on_ambient_prompt_dismissed)
	break_media_controller = BreakMediaController.new()
	add_child(break_media_controller)
	break_media_controller.setup(layers, break_media_enabled, break_media_path)
	break_media_controller.playback_failed.connect(_on_break_media_failed)
	_build_stats_overlay(layers)
	_build_tutorial_overlay(layers)
	music_controller = MusicPlayerController.new()
	add_child(music_controller)
	music_controller.state_changed.connect(_save_game)
	music_controller.setup(layers, saved_music_path, music_loop, music_volume, localizer)
	_build_bottom_mode_controls(layers)
	_build_alarm_player()
	_build_flow_dialogs()


func _build_top_bar(parent: Control) -> void:
	var bar := Control.new()
	top_bar = bar
	bar.name = "TopBar"
	bar.z_index = 90
	bar.anchor_left = 0.0
	bar.anchor_top = 0.0
	bar.anchor_right = 0.0
	bar.anchor_bottom = 0.0
	bar.offset_left = 0
	bar.offset_top = 0
	bar.offset_right = 240
	bar.offset_bottom = 58
	parent.add_child(bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var unlocks := _new_icon_button("UL", "Unlocks")
	unlocks_label = unlocks
	unlocks.text = ""
	unlocks.tooltip_text = ""
	unlocks.visible = false
	row.add_child(unlocks)

	var shop := _new_icon_button("SH", "Store")
	store_button = shop
	shop.text = ""
	shop.tooltip_text = ""
	shop.visible = false
	shop.pressed.connect(_toggle_store_panel)
	row.add_child(shop)

	var tutorial := _new_top_bar_icon_button(ICON_TUTORIAL_PATH, "Tutorial")
	tutorial_button = tutorial
	tutorial.pressed.connect(_toggle_tutorial_panel)
	row.add_child(tutorial)

	var gallery := _new_top_bar_icon_button(ICON_MEMORY_PATH, "Dialogue Gallery")
	avg_gallery_button = gallery
	gallery.pressed.connect(_toggle_avg_gallery)
	row.add_child(gallery)

	var stats := _new_top_bar_icon_button(ICON_STATISTICS_PATH, "Stats")
	stats_button = stats
	stats.pressed.connect(_toggle_stats_message)
	row.add_child(stats)

	var option_button: BaseButton = option_controller.create_top_bar_button() as BaseButton
	row.add_child(option_button)
	option_controller.refresh_text()


func _build_bottom_mode_controls(parent: Control) -> void:
	var panel := Control.new()
	bottom_mode_controls = panel
	panel.name = "BottomModeControls"
	panel.z_index = 150
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -270
	panel.offset_top = -50
	panel.offset_right = 0
	panel.offset_bottom = 0
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var simple_button := _new_icon_asset_button(ICON_SIMPLE_MODE_PATH, "Simple Mode", Vector2(42, 36))
	simple_mode_button = simple_button
	simple_button.pressed.connect(_toggle_simple_mode)
	row.add_child(simple_button)

	var tasks_button := _new_icon_asset_button(ICON_MISSION_PATH, "Tasks", Vector2(42, 36))
	tasks_toggle_button = tasks_button
	tasks_button.pressed.connect(_toggle_tasks_ui)
	row.add_child(tasks_button)

	var timer_button := _new_icon_asset_button(ICON_HIDE_CLOCK_PATH, "Pomodoro", Vector2(42, 36))
	timer_toggle_button = timer_button
	timer_button.pressed.connect(_toggle_timer_ui)
	row.add_child(timer_button)

	var time_button := _new_icon_button("時間", "Time")
	time_button.custom_minimum_size = Vector2(58, 32)
	time_button.pressed.connect(_cycle_time_context)
	row.add_child(time_button)

	var background_button := _new_icon_button("BG", "Background")
	background_button.custom_minimum_size = Vector2(46, 32)
	background_button.pressed.connect(_toggle_background_menu)
	row.add_child(background_button)

	time_button.visible = false
	background_button.visible = false
	if music_controller != null and music_controller.has_method("create_ambience_button"):
		var ambience_button: Control = music_controller.create_ambience_button()
		ambience_toggle_button = ambience_button
		row.add_child(ambience_button)
		row.move_child(ambience_button, 0)
	var fullscreen_button := _new_icon_button("FS", localizer.translate("music.fullscreen_enter"))
	fullscreen_toggle_button = fullscreen_button
	fullscreen_button.pressed.connect(_toggle_borderless_fullscreen)
	row.add_child(fullscreen_button)
	row.move_child(fullscreen_button, 1)
	row.move_child(tasks_button, 2)
	row.move_child(timer_button, 3)
	row.move_child(simple_button, row.get_child_count() - 1)
	_refresh_bottom_mode_icons()

	_build_background_menu(parent)


func _build_focus_progress_hud(parent: Control) -> void:
	var hud := HBoxContainer.new()
	focus_progress_hud = hud
	hud.name = "FocusProgressHud"
	hud.z_index = 40
	hud.anchor_left = 1.0
	hud.anchor_top = 0.0
	hud.anchor_right = 1.0
	hud.anchor_bottom = 0.0
	hud.offset_left = -430
	hud.offset_top = 1
	hud.offset_right = 0
	hud.offset_bottom = 35
	hud.add_theme_constant_override("separation", 6)
	parent.add_child(hud)

	var points := HBoxContainer.new()
	fp_label = points
	points.custom_minimum_size = Vector2(108, 32)
	points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	points.add_theme_constant_override("separation", 5)
	hud.add_child(points)

	var focus_icon := TextureRect.new()
	focus_icon.texture = _load_texture(ICON_FOCUS_POINT_PATH)
	focus_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_icon.custom_minimum_size = Vector2(30, 32)
	focus_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	focus_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	points.add_child(focus_icon)

	focus_points_value_label = Label.new()
	focus_points_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_points_value_label.custom_minimum_size = Vector2(76, 32)
	focus_points_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	focus_points_value_label.add_theme_font_size_override("font_size", 22)
	focus_points_value_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	focus_points_value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.86))
	focus_points_value_label.add_theme_constant_override("shadow_offset_x", 2)
	focus_points_value_label.add_theme_constant_override("shadow_offset_y", 2)
	points.add_child(focus_points_value_label)

	var bond_panel := Control.new()
	bond_panel.custom_minimum_size = Vector2(88, 34)
	bond_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud.add_child(bond_panel)

	var bond_background := TextureRect.new()
	bond_background.texture = _load_texture(PANEL_BOND_LEVEL_PATH)
	bond_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bond_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	bond_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bond_background.stretch_mode = TextureRect.STRETCH_SCALE
	bond_panel.add_child(bond_background)

	bond_level_label = Label.new()
	bond_level_label.mouse_filter = Control.MOUSE_FILTER_STOP
	bond_level_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	bond_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bond_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bond_level_label.add_theme_font_size_override("font_size", 22)
	bond_level_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.38, 1.0))
	bond_level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.86))
	bond_level_label.add_theme_constant_override("shadow_offset_x", 2)
	bond_level_label.add_theme_constant_override("shadow_offset_y", 2)
	bond_panel.add_child(bond_level_label)

	var level := Control.new()
	level_label = level
	level.custom_minimum_size = Vector2(126, 34)
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level.mouse_filter = Control.MOUSE_FILTER_STOP
	level.gui_input.connect(_on_gold_token_gui_input)
	_add_hover_effect(level)
	hud.add_child(level)

	var token_bar := TextureRect.new()
	token_bar.texture = _load_texture(ICON_TOKEN_BAR_PATH)
	token_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	token_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	token_bar.stretch_mode = TextureRect.STRETCH_SCALE
	level.add_child(token_bar)

	var bar := ProgressBar.new()
	focus_level_progress = bar
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = 1
	bar.value = 0
	bar.anchor_left = 0.0
	bar.anchor_top = 0.5
	bar.anchor_right = 1.0
	bar.anchor_bottom = 0.5
	bar.offset_left = 18
	bar.offset_top = -8
	bar.offset_right = 0
	bar.offset_bottom = 8
	bar.add_theme_stylebox_override("background", _new_progress_background_style())
	bar.add_theme_stylebox_override("fill", _new_progress_fill_style())
	level.add_child(bar)

	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(34, 34)
	badge.anchor_left = 0.0
	badge.anchor_top = 0.5
	badge.anchor_right = 0.0
	badge.anchor_bottom = 0.5
	badge.offset_left = 0
	badge.offset_top = -17
	badge.offset_right = 34
	badge.offset_bottom = 17
	level.add_child(badge)

	var token_icon := TextureRect.new()
	token_icon.texture = _load_texture(ICON_TOKEN_PATH)
	token_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	token_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	token_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.add_child(token_icon)

	var badge_center := CenterContainer.new()
	badge_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.add_child(badge_center)

	focus_level_badge_label = Label.new()
	focus_level_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_level_badge_label.add_theme_font_size_override("font_size", 15)
	focus_level_badge_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36, 1.0))
	focus_level_badge_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.86))
	focus_level_badge_label.add_theme_constant_override("shadow_offset_x", 1)
	focus_level_badge_label.add_theme_constant_override("shadow_offset_y", 1)
	badge_center.add_child(focus_level_badge_label)


func _build_background_menu(parent: Control) -> void:
	background_menu_panel = _new_panel()
	background_menu_panel.name = "BackgroundMenu"
	background_menu_panel.visible = false
	background_menu_panel.z_index = 170
	background_menu_panel.anchor_left = 1.0
	background_menu_panel.anchor_top = 1.0
	background_menu_panel.anchor_right = 1.0
	background_menu_panel.anchor_bottom = 1.0
	background_menu_panel.offset_left = -250
	background_menu_panel.offset_top = -206
	background_menu_panel.offset_right = -64
	background_menu_panel.offset_bottom = -58
	parent.add_child(background_menu_panel)
	_refresh_background_menu()


func _refresh_background_menu() -> void:
	if background_menu_panel == null:
		return
	var box: VBoxContainer
	if background_menu_panel.get_child_count() == 0:
		box = _panel_box(background_menu_panel)
	else:
		var margin := background_menu_panel.get_child(0)
		box = margin.get_child(0) as VBoxContainer
	for child in box.get_children():
		child.queue_free()

	var title := _new_title(localizer.translate("background_menu.title") if localizer != null else "Background")
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	for item in _background_menu_items():
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 30)
		button.text = str(item.get("name", ""))
		button.disabled = bool(item.get("locked", false))
		button.tooltip_text = str(item.get("tooltip", ""))
		button.pressed.connect(_select_background.bind(str(item.get("id", BACKGROUND_LOFI_AUTO))))
		_add_hover_effect(button)
		box.add_child(button)


func _background_menu_items() -> Array:
	var items := [
		{
			"id": BACKGROUND_LOFI_AUTO,
			"name": _selected_prefix(BACKGROUND_LOFI_AUTO) + localizer.translate("background_menu.lofi"),
			"locked": false,
			"tooltip": localizer.translate("background_menu.lofi")
		}
	]
	for entry in [
		{"id": "room_bg_01", "key": "background_menu.room_01"},
		{"id": "room_bg_02", "key": "background_menu.room_02"}
	]:
		var content_id: String = str(entry.id)
		var definition := ContentUnlockService.find_by_content_id(background_defs, content_id)
		var locked: bool = definition.is_empty() or not ContentUnlockService.is_unlocked(definition, unlocked_content)
		var label: String = localizer.translate(str(entry.key))
		if locked:
			label = "%s  -  %s" % [label, localizer.translate("background_menu.locked")]
		items.append({
			"id": content_id,
			"name": _selected_prefix(content_id) + label,
			"locked": locked,
			"tooltip": label
		})
	return items


func _selected_prefix(background_id: String) -> String:
	return "✓ " if selected_background_id == background_id else ""


func _build_stats_overlay(parent: Control) -> void:
	stats_panel = _new_panel()
	stats_panel.name = "StatsPanel"
	stats_panel.visible = false
	stats_panel.z_index = 100
	stats_panel.anchor_left = 0.0
	stats_panel.anchor_top = 0.0
	stats_panel.anchor_right = 0.0
	stats_panel.anchor_bottom = 0.0
	stats_panel.offset_left = 342
	stats_panel.offset_top = 54
	stats_panel.offset_right = 672
	stats_panel.offset_bottom = 246
	parent.add_child(stats_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	stats_panel.add_child(margin)

	stats_label = _new_muted_label("")
	margin.add_child(stats_label)


func _build_tutorial_overlay(parent: Control) -> void:
	tutorial_panel = _new_panel()
	tutorial_panel.name = "TutorialPanel"
	tutorial_panel.visible = false
	tutorial_panel.z_index = 100
	tutorial_panel.anchor_left = 0.0
	tutorial_panel.anchor_top = 0.0
	tutorial_panel.anchor_right = 0.0
	tutorial_panel.anchor_bottom = 0.0
	tutorial_panel.offset_left = 342
	tutorial_panel.offset_top = 54
	tutorial_panel.offset_right = 862
	tutorial_panel.offset_bottom = 438
	parent.add_child(tutorial_panel)

	var box := _panel_box(tutorial_panel)
	var title := _new_title("簡易教學")
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470, 300)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var body := _new_muted_label(
		"目前流程\n" +
		"- 乘客上車後會先播放問候，接著由玩家選擇專注時間並開始。\n" +
		"- 少於 5 分鐘會跳提醒；繼續開始也不會取得專注點數，且會跳過停車休息與問答。\n" +
		"- 達 5 分鐘以上完成車程後，會進入停車對話，再進入 10 回合問答小遊戲。\n\n" +
		"問答小遊戲\n" +
		"- 回答會改變 Emotion 與 Alert。\n" +
		"- Emotion 滿 100 會直接進入目前乘客的下一個 H 事件，播放完後解鎖圖鑑。\n" +
		"- Alert 滿 100 則小遊戲失敗；10 回合結束仍未達成則普通結束。\n\n" +
		"圖鑑與專注點數\n" +
		"- 圖鑑依乘客 A-D 分組，所有項目預設上鎖。\n" +
		"- 每位乘客只能解鎖目前最前面尚未解鎖的項目。\n" +
		"- 可用專注點數直接解鎖，會先跳確認視窗，並播放事件後才解鎖。\n\n" +
		"金手指按鈕\n" +
		"- F1：增加 100 專注點數。\n" +
		"- F3：立即切換下一段天色漸變。\n" +
		"- F4：清空所有遊戲進度並回到預設值。\n" +
		"- F5：直接進入目前乘客的問答小遊戲。"
	)
	body.custom_minimum_size = Vector2(440, 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 15)
	scroll.add_child(body)


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


func _new_level_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.36, 0.13, 0.48, 1.0)
	style.border_color = Color(1.0, 0.73, 0.26, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 17
	style.corner_radius_top_right = 17
	style.corner_radius_bottom_left = 17
	style.corner_radius_bottom_right = 17
	return style


func _new_progress_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.08, 0.24, 0.72)
	style.border_color = Color(0.95, 0.73, 0.36, 0.96)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style


func _new_progress_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.66, 0.28, 0.88, 0.96)
	style.border_color = Color(1.0, 0.73, 0.26, 0.0)
	style.set_border_width_all(0)
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


func _new_icon_button(text: String, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(42, 32)
	button.focus_mode = Control.FOCUS_NONE
	_add_hover_effect(button)
	return button


func _new_icon_asset_button(icon_path: String, tip: String, size: Vector2) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _load_texture(icon_path)
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.texture_disabled = button.texture_normal
	button.tooltip_text = tip
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_add_hover_effect(button)
	return button


func _new_top_bar_icon_button(icon_path: String, tip: String) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _load_texture(icon_path)
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.texture_disabled = button.texture_normal
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(42, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_add_hover_effect(button)
	return button


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null


func _set_texture_button_icon(button: BaseButton, icon_path: String) -> void:
	var texture_button := button as TextureButton
	if texture_button == null:
		return
	var texture := _load_texture(icon_path)
	texture_button.texture_normal = texture
	texture_button.texture_hover = texture
	texture_button.texture_pressed = texture
	texture_button.texture_disabled = texture


func _add_hover_effect(control: Control) -> void:
	control.mouse_entered.connect(_on_hover_scale.bind(control, true))
	control.mouse_exited.connect(_on_hover_scale.bind(control, false))


func _on_hover_scale(control: Control, hovered: bool) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * (1.1 if hovered else 1.0)


func _toggle_borderless_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		var restore_mode := previous_window_mode if has_previous_window_mode else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(restore_mode)
		has_previous_window_mode = false
	else:
		previous_window_mode = current_mode
		has_previous_window_mode = true
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_fullscreen_button()


func _refresh_fullscreen_button() -> void:
	if fullscreen_toggle_button == null:
		return
	var is_fullscreen := DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_toggle_button.tooltip_text = localizer.translate("music.fullscreen_exit") if is_fullscreen else localizer.translate("music.fullscreen_enter")


func _new_muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.9, 0.92))
	return label


func _build_alarm_player() -> void:
	if DisplayServer.get_name() == "headless":
		return
	alarm_player = AudioStreamPlayer.new()
	alarm_player.name = "AlarmPlayer"
	if ResourceLoader.exists(ALARM_SOUND_PATH):
		alarm_player.stream = load(ALARM_SOUND_PATH)
	if alarm_player.stream == null:
		alarm_player.stream = _new_silent_alarm_stream()
	add_child(alarm_player)


func _build_flow_dialogs() -> void:
	threshold_warning_dialog = ConfirmationDialog.new()
	threshold_warning_dialog.title = "No Reward"
	threshold_warning_dialog.dialog_text = "This ride is shorter than the reward threshold. Continue without rewards?"
	threshold_warning_dialog.ok_button_text = "Continue"
	threshold_warning_dialog.cancel_button_text = "Adjust"
	threshold_warning_dialog.confirmed.connect(_start_focus_session_after_warning)
	ui_layer.add_child(threshold_warning_dialog)

	completed_passenger_dialog = ConfirmationDialog.new()
	completed_passenger_dialog.title = "Passenger Complete"
	completed_passenger_dialog.dialog_text = "This passenger has no locked gallery events left. Continue for double Focus Points?"
	completed_passenger_dialog.ok_button_text = "Continue"
	completed_passenger_dialog.cancel_button_text = "Change Passenger"
	completed_passenger_dialog.confirmed.connect(_continue_completed_passenger)
	completed_passenger_dialog.canceled.connect(_change_completed_passenger)
	ui_layer.add_child(completed_passenger_dialog)

	gallery_unlock_confirm_dialog = ConfirmationDialog.new()
	gallery_unlock_confirm_dialog.title = "Unlock Gallery"
	gallery_unlock_confirm_dialog.dialog_text = "Spend Focus Points to unlock this gallery event?"
	gallery_unlock_confirm_dialog.ok_button_text = "Unlock"
	gallery_unlock_confirm_dialog.cancel_button_text = "Cancel"
	gallery_unlock_confirm_dialog.confirmed.connect(_confirm_gallery_unlock)
	gallery_unlock_confirm_dialog.canceled.connect(func(): pending_gallery_unlock = {})
	ui_layer.add_child(gallery_unlock_confirm_dialog)


func _new_silent_alarm_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	stream.data = PackedByteArray()
	return stream


func _on_primary_timer_pressed() -> void:
	match TimerSessionService.primary_action(app_state):
		"resume":
			_apply_timer_state(TimerSessionService.resume())
			_refresh_all()
		"pause":
			_apply_timer_state(TimerSessionService.pause())
			_refresh_all()
		_:
			_start_focus_session()


func _start_focus_session() -> void:
	if duration_minutes * 60 < PASSENGER_MIN_REWARDABLE_SESSION_SEC:
		if threshold_warning_dialog != null:
			threshold_warning_dialog.popup_centered()
		return
	_start_focus_session_after_warning()


func _start_focus_session_after_warning() -> void:
	if app_state == "running":
		return
	_dismiss_result_panel()
	_hide_break_interaction()
	_hide_ambient_prompt()
	_stop_break_media()
	if timer_settings != null and timer_settings.has_method("hide"):
		timer_settings.hide()
	var next_state := TimerSessionService.start_focus(duration_minutes, _selected_task_id())
	_apply_timer_state(next_state)
	if active_task_id != "":
		_set_task_status(active_task_id, "in_progress")
	drive_scene.load_selected_background()
	_refresh_all()


func _on_end_pressed() -> void:
	if app_state == "running" or app_state == "paused":
		_finish_session(TimerSessionService.classify_early_end(elapsed_sec, planned_duration_sec))


func _on_reset_pressed() -> void:
	_apply_timer_state(TimerSessionService.reset_focus(duration_minutes))
	result_dismissed = true
	_dismiss_result_panel()
	_hide_break_interaction()
	_hide_ambient_prompt()
	_stop_break_media()
	_refresh_all()


func _on_break_pressed() -> void:
	_start_break_countdown()
	_dismiss_result_panel()


func _start_break_countdown() -> void:
	_hide_ambient_prompt()
	_apply_timer_state(TimerSessionService.start_break(break_duration_minutes))
	if not _start_break_media():
		_show_break_interaction()
	_refresh_all()


func _finish_break() -> void:
	_play_alarm()
	_hide_break_interaction()
	_hide_ambient_prompt()
	_stop_break_media()
	if auto_restart_enabled:
		app_state = "idle"
		_start_focus_session()
		return
	_apply_timer_state(TimerSessionService.finish_break(duration_minutes))
	_refresh_all()


func _show_break_interaction() -> void:
	if companion_controller != null and companion_controller.has_method("show_break_interaction"):
		companion_controller.show_break_interaction(
			int(bond_progress.get("bond_level", 1)),
			selected_context,
			interaction_history
		)


func _hide_break_interaction() -> void:
	if companion_controller != null and companion_controller.has_method("hide_break_interaction"):
		companion_controller.hide_break_interaction()


func _show_ambient_prompt() -> void:
	if passenger_quiz_active:
		return
	if companion_controller == null or not companion_controller.has_method("show_ambient_prompt"):
		return
	companion_controller.show_ambient_prompt(
		int(bond_progress.get("bond_level", 1)),
		_ambient_prompt_context(),
		interaction_history
	)
	ambient_prompt_visible_sec = 0.0


func _hide_ambient_prompt(emit_dismissed: bool = false) -> void:
	if companion_controller != null and companion_controller.has_method("hide_ambient_prompt"):
		companion_controller.hide_ambient_prompt(emit_dismissed)
	ambient_prompt_visible_sec = 0.0


func _update_ambient_prompt(delta: float) -> void:
	if passenger_quiz_active:
		_hide_ambient_prompt()
		ambient_prompt_elapsed_sec = 0.0
		return
	if _is_ambient_prompt_visible():
		ambient_prompt_visible_sec += delta
		if ambient_prompt_visible_sec >= AMBIENT_PROMPT_VISIBLE_SEC:
			_hide_ambient_prompt()
		return
	if not _ambient_prompt_allowed():
		ambient_prompt_elapsed_sec = 0.0
		return
	ambient_prompt_elapsed_sec += delta
	var interval := _ambient_prompt_interval_sec()
	if app_state == "idle" and not ambient_prompt_has_shown:
		interval = AMBIENT_PROMPT_INITIAL_IDLE_SEC
	if ambient_prompt_elapsed_sec >= interval:
		ambient_prompt_elapsed_sec = 0.0
		ambient_prompt_has_shown = true
		_show_ambient_prompt()


func _ambient_prompt_allowed() -> bool:
	if passenger_quiz_active:
		return false
	if ambient_prompt_frequency == AMBIENT_PROMPT_OFF:
		return false
	if session_mode == "short_break":
		return false
	if app_state != "idle" and not (app_state == "running" and session_mode == "focus"):
		return false
	if result_controller != null and result_controller.has_method("is_result_visible") and result_controller.is_result_visible():
		return false
	return true


func _ambient_prompt_interval_sec() -> int:
	if app_state == "running":
		return AMBIENT_PROMPT_FOCUS_INTERVAL_SEC
	return AMBIENT_PROMPT_LOW_IDLE_INTERVAL_SEC if ambient_prompt_frequency == AMBIENT_PROMPT_LOW else AMBIENT_PROMPT_NORMAL_IDLE_INTERVAL_SEC


func _ambient_prompt_context() -> Dictionary:
	var context := selected_context.duplicate()
	context.app_state = app_state
	context.session_mode = session_mode
	context.ambient_state = "focus" if app_state == "running" and session_mode == "focus" else "idle"
	return context


func _is_ambient_prompt_visible() -> bool:
	if companion_controller == null or not companion_controller.has_method("is_ambient_prompt_visible"):
		return false
	return companion_controller.is_ambient_prompt_visible()


func _start_break_media() -> bool:
	if break_media_controller == null or not break_media_controller.has_method("play_break_media"):
		return false
	return break_media_controller.play_break_media()


func _stop_break_media() -> void:
	if break_media_controller != null and break_media_controller.has_method("stop_break_media"):
		break_media_controller.stop_break_media()


func _apply_timer_state(next_state: Dictionary) -> void:
	if next_state.has("app_state"):
		app_state = str(next_state.app_state)
	if next_state.has("session_mode"):
		session_mode = str(next_state.session_mode)
	if next_state.has("planned_duration_sec"):
		planned_duration_sec = int(next_state.planned_duration_sec)
	if next_state.has("elapsed_sec"):
		elapsed_sec = float(next_state.elapsed_sec)
	if next_state.has("session_started_at"):
		session_started_at = str(next_state.session_started_at)
	if next_state.has("active_task_id"):
		active_task_id = str(next_state.active_task_id)
	if next_state.has("message_key") and str(next_state.message_key) != "":
		message_label.text = localizer.translate(str(next_state.message_key))
		return
	if next_state.has("message"):
		message_label.text = str(next_state.message)


func _finish_session(status: String, start_break_after: bool = false) -> void:
	var actual_sec := int(round(elapsed_sec))
	var focus_points_reward := 0
	if status == "completed" and session_mode == "focus":
		focus_points_reward = PassengerFlowService.reward_for_seconds(
			actual_sec,
			PASSENGER_MIN_REWARDABLE_SESSION_SEC,
			current_passenger_complete_bonus
		)
		currencies.focus_points = int(currencies.get("focus_points", 0)) + focus_points_reward
	var rewards := {
		"rewardable": focus_points_reward > 0,
		"focus_points": focus_points_reward,
		"xp": 0,
		"bond": 0
	}
	var session := {
		"session_id": "session_%s" % Time.get_unix_time_from_system(),
		"user_id": "local_user",
		"mode": session_mode,
		"planned_duration_sec": planned_duration_sec,
		"actual_duration_sec": actual_sec,
		"status": status,
		"started_at": session_started_at,
		"ended_at": Time.get_datetime_string_from_system(false, true),
		"linked_task_id": active_task_id,
		"context_id": _context_id(),
		"reward_granted_at": Time.get_datetime_string_from_system(false, true) if rewards.rewardable else ""
	}
	sessions.append(session)
	_update_stats(status, actual_sec)
	selected_context.mood = "good" if status == "completed" else "troubled"
	drive_scene.load_selected_background()
	_save_game()
	_play_alarm()
	_apply_timer_state(TimerSessionService.reset_focus(duration_minutes))
	if status != "completed" or actual_sec < PASSENGER_MIN_REWARDABLE_SESSION_SEC:
		_begin_next_passenger()
		_refresh_all()
		return
	if current_passenger_complete_bonus:
		_begin_next_passenger()
		_refresh_all()
		return
	_show_parking_dialogue()
	_refresh_all()


func _grant_rewards(status: String, actual_sec: int) -> Dictionary:
	return SessionRewardCoordinator.grant_session_rewards(
		session_mode,
		status,
		actual_sec,
		planned_duration_sec,
		currencies,
		level_progress,
		bond_progress,
		MIN_REWARDABLE_SESSION_SEC,
		BASE_FOCUS_POINTS,
		BASE_BOND,
		BASE_XP
	)


func _show_parking_dialogue() -> void:
	if avg_dialogue_controller == null or current_passenger.is_empty():
		_start_passenger_quiz()
		return
	var dialogue := PassengerFlowService.parking_dialogue(current_passenger)
	avg_dialogue_controller.show_dialogue(dialogue)


func _start_passenger_quiz() -> void:
	var event := PassengerFlowService.next_event(current_passenger, passenger_progress)
	if event.is_empty():
		_begin_next_passenger()
		return
	quiz_state = {
		"round": 0,
		"emotion": int(event.get("initial_emotion", 0)),
		"alert": int(event.get("initial_alert", 0)),
		"used_question_ids": [],
		"event": event
	}
	passenger_quiz_active = true
	_hide_top_bar_popups()
	_hide_ambient_prompt()
	_restore_music_after_avg_dialogue()
	_suspend_music_for_passenger_quiz()
	timer_ui_visible = false
	tasks_ui_visible = false
	_apply_ui_visibility()
	_show_next_quiz_question()


func _show_next_quiz_question() -> void:
	if quiz_state.is_empty():
		return
	if int(quiz_state.get("emotion", 0)) >= PassengerFlowService.EMOTION_MAX:
		_finish_quiz_success()
		return
	if int(quiz_state.get("alert", 0)) >= PassengerFlowService.ALERT_MAX:
		_finish_quiz_failed()
		return
	if int(quiz_state.get("round", 0)) >= PASSENGER_QUIZ_ROUNDS:
		_finish_quiz_normal()
		return
	var candidates := PassengerFlowService.questions_for_round(
		passenger_questions,
		current_passenger_id,
		int(quiz_state.get("emotion", 0)),
		quiz_state.get("used_question_ids", [])
	)
	if candidates.is_empty():
		_finish_quiz_normal()
		return
	var question = candidates[randi() % candidates.size()]
	var used: Array = quiz_state.get("used_question_ids", [])
	used.append(str(question.get("question_id", "")))
	quiz_state.used_question_ids = used
	quiz_state.round = int(quiz_state.get("round", 0)) + 1
	passenger_quiz_controller.show_question(
		_passenger_display_name(current_passenger),
		question,
		int(quiz_state.round),
		PASSENGER_QUIZ_ROUNDS,
		int(quiz_state.emotion),
		int(quiz_state.alert)
	)


func _on_passenger_quiz_answer_selected(answer: Dictionary) -> void:
	if quiz_state.is_empty():
		return
	quiz_state.emotion = clamp(int(quiz_state.get("emotion", 0)) + int(answer.get("emotion_delta", 0)), 0, 100)
	quiz_state.alert = clamp(int(quiz_state.get("alert", 0)) + int(answer.get("alert_delta", 0)), 0, 100)
	_record_interaction_event("passenger_quiz_answered", "%s:%d" % [current_passenger_id, int(quiz_state.get("round", 0))])


func _on_passenger_quiz_answer_response_finished() -> void:
	if quiz_state.is_empty():
		return
	_show_next_quiz_question()


func _on_passenger_quiz_dismissed() -> void:
	_finish_quiz_normal()


func _finish_quiz_success() -> void:
	if passenger_quiz_controller != null:
		passenger_quiz_controller.hide_quiz()
	var event: Dictionary = quiz_state.get("event", {})
	pending_passenger_success_event = event
	quiz_state = {}
	_restore_main_ride_ui()
	_show_passenger_ending_dialogue("success")


func _finish_quiz_failed() -> void:
	if passenger_quiz_controller != null:
		passenger_quiz_controller.hide_quiz()
	quiz_state = {}
	_restore_main_ride_ui()
	_show_passenger_ending_dialogue("failed")


func _finish_quiz_normal() -> void:
	if passenger_quiz_controller != null:
		passenger_quiz_controller.hide_quiz()
	quiz_state = {}
	_restore_main_ride_ui()
	_show_passenger_ending_dialogue("normal")


func _debug_start_passenger_quiz() -> void:
	_ensure_quiz_passenger()
	if current_passenger_id == "":
		return
	if avg_dialogue_controller != null and avg_dialogue_controller.has_method("hide_dialogue"):
		avg_dialogue_controller.hide_dialogue()
	if avg_gallery_controller != null and avg_gallery_controller.has_method("hide_gallery"):
		avg_gallery_controller.hide_gallery()
	if result_controller != null and result_controller.has_method("hide_result"):
		result_controller.hide_result()
	_stop_break_media()
	_hide_break_interaction()
	_hide_ambient_prompt()
	_apply_timer_state(TimerSessionService.reset_focus(duration_minutes))
	_show_parking_dialogue()


func _ensure_quiz_passenger() -> void:
	if not current_passenger.is_empty() and not PassengerFlowService.is_passenger_complete(current_passenger, passenger_progress):
		return
	for passenger in passenger_defs:
		if typeof(passenger) != TYPE_DICTIONARY:
			continue
		if PassengerFlowService.is_passenger_complete(passenger, passenger_progress):
			continue
		current_passenger = passenger
		current_passenger_id = str(passenger.get("passenger_id", ""))
		current_passenger_complete_bonus = false
		if drive_scene != null and drive_scene.has_method("set_passenger"):
			drive_scene.set_passenger(current_passenger_id)
		return
	current_passenger = {}
	current_passenger_id = ""


func _show_passenger_ending_dialogue(ending_type: String) -> void:
	if avg_dialogue_controller == null:
		_begin_next_passenger()
		return
	var dialogue := PassengerFlowService.ending_dialogue(current_passenger, ending_type)
	avg_dialogue_controller.show_dialogue(dialogue)


func _restore_main_ride_ui() -> void:
	passenger_quiz_active = false
	_restore_music_after_passenger_quiz()
	timer_ui_visible = true
	tasks_ui_visible = true
	_apply_ui_visibility()


func _show_result_panel(status: String, actual_sec: int, rewards: Dictionary, bond_level_up_text: String, can_start_break: bool) -> void:
	result_dismissed = false
	if result_controller == null or not result_controller.has_method("show_result"):
		return
	var reward_text := _result_summary(status, actual_sec, rewards, bond_level_up_text)
	result_controller.show_result(
		status,
		reward_text,
		active_task_id != "" and _task_status(active_task_id) != "done",
		can_start_break and status != "abandoned"
	)


func _add_xp(amount: int) -> void:
	ProgressionService.add_xp(level_progress, amount, currencies)


func _add_bond(amount: int) -> void:
	ProgressionService.add_bond(bond_progress, amount)


func _xp_required_for_next_level() -> int:
	return ProgressionService.xp_required_for_next_level(level_progress)


func _bond_required_for_next_level() -> int:
	return ProgressionService.bond_required_for_next_level(bond_progress)


func _on_mark_bound_task_done() -> void:
	var result := SessionRewardCoordinator.apply_task_completion_bonus(
		tasks,
		active_task_id,
		currencies,
		level_progress,
		daily_stats,
		TASK_BONUS_FOCUS_POINTS,
		TASK_BONUS_XP,
		localizer
	)
	if bool(result.get("changed", false)):
		if result_controller != null and result_controller.has_method("append_reward_line"):
			result_controller.append_reward_line(str(result.get("summary", "")))
		_save_game()
		_refresh_all()


func _set_task_status(task_id: String, status: String) -> bool:
	if task_controller != null and task_controller.has_method("set_task_status"):
		return task_controller.set_task_status(task_id, status)
	return false


func _on_tasks_changed() -> void:
	_save_game()
	_refresh_all()


func _on_task_renamed() -> void:
	_save_game()


func _on_task_completed(_task_id: String) -> void:
	daily_stats.tasks_completed += 1


func _selected_task_id() -> String:
	if task_controller != null and task_controller.has_method("selected_task_id"):
		return task_controller.selected_task_id()
	return ""


func _refresh_all() -> void:
	_refresh_timer_ui()
	_refresh_tasks_ui()
	_refresh_progress_ui()
	_refresh_controls()


func _refresh_timer_ui() -> void:
	if timer_rail != null and timer_rail.has_method("refresh_timer"):
		timer_rail.refresh_timer(
			app_state,
			session_mode,
			planned_duration_sec,
			elapsed_sec,
			duration_minutes,
			break_duration_minutes
		)
	if timer_settings != null and timer_settings.has_method("refresh_durations"):
		timer_settings.refresh_durations(duration_minutes, break_duration_minutes)


func _refresh_controls() -> void:
	if timer_rail != null and timer_rail.has_method("refresh_controls"):
		timer_rail.refresh_controls(app_state)
	if result_controller != null and result_controller.has_method("refresh_controls"):
		result_controller.refresh_controls(app_state, active_task_id, _task_status(active_task_id) == "done")


func _dismiss_result_panel() -> void:
	result_dismissed = true
	if result_controller != null and result_controller.has_method("hide_result"):
		result_controller.hide_result()


func _set_duration_minutes(minutes: int) -> void:
	if app_state == "running" or app_state == "paused":
		return
	var settings := TimerSessionService.set_focus_duration(minutes)
	duration_minutes = int(settings.duration_minutes)
	planned_duration_sec = int(settings.planned_duration_sec)
	_save_game()
	_refresh_timer_ui()


func _adjust_duration_minutes(delta_minutes: int) -> void:
	_set_duration_minutes(duration_minutes + delta_minutes)


func _adjust_break_duration_minutes(delta_minutes: int) -> void:
	if app_state == "running" or app_state == "paused":
		return
	break_duration_minutes = TimerSessionService.set_break_duration(break_duration_minutes + delta_minutes)
	_save_game()
	_refresh_timer_ui()


func _toggle_settings_panel() -> void:
	if timer_settings != null and timer_settings.has_method("toggle_visible"):
		timer_settings.toggle_visible()


func _on_auto_restart_toggled() -> void:
	auto_restart_enabled = not auto_restart_enabled
	if timer_settings != null and timer_settings.has_method("refresh_auto_restart"):
		timer_settings.refresh_auto_restart(auto_restart_enabled)
	_save_game()


func _on_alarm_toggled() -> void:
	alarm_enabled = not alarm_enabled
	if timer_settings != null and timer_settings.has_method("refresh_alarm"):
		timer_settings.refresh_alarm(alarm_enabled)
	_save_game()


func _on_previous_language_pressed() -> void:
	language_code = localizer.previous_language()
	_refresh_localized_text()
	_save_game()


func _on_next_language_pressed() -> void:
	language_code = localizer.next_language()
	_refresh_localized_text()
	_save_game()


func _on_break_media_toggled() -> void:
	break_media_enabled = not break_media_enabled
	if option_controller != null and option_controller.has_method("refresh_break_media"):
		option_controller.refresh_break_media(break_media_enabled)
	var is_break_running := session_mode == "short_break" and app_state == "running"
	if not is_break_running and break_media_controller != null and break_media_controller.has_method("set_enabled"):
		break_media_controller.set_enabled(break_media_enabled)
	_save_game()


func _on_ambient_prompt_frequency_pressed() -> void:
	if ambient_prompt_frequency == AMBIENT_PROMPT_NORMAL:
		ambient_prompt_frequency = AMBIENT_PROMPT_LOW
	elif ambient_prompt_frequency == AMBIENT_PROMPT_LOW:
		ambient_prompt_frequency = AMBIENT_PROMPT_OFF
	else:
		ambient_prompt_frequency = AMBIENT_PROMPT_NORMAL
	ambient_prompt_elapsed_sec = 0.0
	if ambient_prompt_frequency == AMBIENT_PROMPT_OFF:
		_hide_ambient_prompt(true)
	if option_controller != null and option_controller.has_method("refresh_ambient_prompt"):
		option_controller.refresh_ambient_prompt(ambient_prompt_frequency)
	_save_game()


func _refresh_localized_text() -> void:
	if task_controller != null and task_controller.has_method("set_localizer"):
		task_controller.set_localizer(localizer)
	if result_controller != null and result_controller.has_method("set_localizer"):
		result_controller.set_localizer(localizer)
	if timer_rail != null and timer_rail.has_method("set_localizer"):
		timer_rail.set_localizer(localizer)
	if timer_settings != null and timer_settings.has_method("set_localizer"):
		timer_settings.set_localizer(localizer)
	if companion_controller != null and companion_controller.has_method("set_localizer"):
		companion_controller.set_localizer(localizer)
	if music_controller != null and music_controller.has_method("set_localizer"):
		music_controller.set_localizer(localizer)
	if option_controller != null and option_controller.has_method("refresh_text"):
		option_controller.refresh_text()
	if store_controller != null and store_controller.has_method("set_localizer"):
		store_controller.set_localizer(localizer)
	if avg_dialogue_controller != null and avg_dialogue_controller.has_method("set_localizer"):
		avg_dialogue_controller.set_localizer(localizer)
	if avg_gallery_controller != null and avg_gallery_controller.has_method("set_localizer"):
		avg_gallery_controller.set_localizer(localizer)
	if passenger_quiz_controller != null and passenger_quiz_controller.has_method("set_localizer"):
		passenger_quiz_controller.set_localizer(localizer)
	_refresh_fullscreen_button()
	_refresh_background_menu()
	_refresh_all()


func _on_break_interaction_viewed(dialogue_id: String) -> void:
	_record_interaction_event("break_interaction_viewed", dialogue_id)


func _on_break_interaction_skipped(dialogue_id: String) -> void:
	_record_interaction_event("break_interaction_skipped", dialogue_id)


func _on_break_interaction_advanced(from_id: String, to_id: String) -> void:
	_record_interaction_event("break_interaction_advanced", "%s>%s" % [from_id, to_id])


func _on_ambient_prompt_shown(dialogue_id: String) -> void:
	_record_interaction_event("ambient_prompt_shown", dialogue_id)


func _on_ambient_prompt_dismissed(dialogue_id: String) -> void:
	_record_interaction_event("ambient_prompt_dismissed", dialogue_id)


func _on_break_media_failed(_path: String) -> void:
	if session_mode == "short_break" and app_state == "running":
		_show_break_interaction()


func _record_interaction_event(event_type: String, dialogue_id: String) -> void:
	interaction_history.append({
		"event_type": event_type,
		"dialogue_id": dialogue_id,
		"created_at": Time.get_datetime_string_from_system(false, true),
		"context_id": _context_id()
	})
	if interaction_history.size() > 200:
		interaction_history.pop_front()
	_save_game()


func _play_alarm() -> void:
	if not alarm_enabled or alarm_player == null or alarm_player.stream == null:
		return
	alarm_player.stop()
	alarm_player.play()


func _toggle_stats_message() -> void:
	if stats_panel == null:
		return
	var should_open := not stats_panel.visible
	if should_open:
		_hide_top_bar_popups("stats")
		_raise_stats_panel()
	stats_panel.visible = should_open


func _toggle_tutorial_panel() -> void:
	if tutorial_panel == null:
		return
	var should_open := not tutorial_panel.visible
	if should_open:
		_hide_top_bar_popups("tutorial")
		_raise_tutorial_panel()
	tutorial_panel.visible = should_open


func _on_option_panel_opened() -> void:
	_hide_top_bar_popups("option")


func _hide_top_bar_popups(except: String = "") -> void:
	if except != "option" and option_controller != null and option_controller.has_method("hide"):
		option_controller.hide()
	if except != "gallery" and avg_gallery_controller != null and avg_gallery_controller.has_method("hide_gallery"):
		avg_gallery_controller.hide_gallery()
	if except != "stats" and stats_panel != null:
		stats_panel.visible = false
	if except != "tutorial" and tutorial_panel != null:
		tutorial_panel.visible = false


func _raise_stats_panel() -> void:
	if stats_panel == null:
		return
	var parent := stats_panel.get_parent()
	if parent != null:
		parent.move_child(stats_panel, parent.get_child_count() - 1)


func _raise_tutorial_panel() -> void:
	if tutorial_panel == null:
		return
	var parent := tutorial_panel.get_parent()
	if parent != null:
		parent.move_child(tutorial_panel, parent.get_child_count() - 1)


func _toggle_simple_mode() -> void:
	simple_mode_enabled = not simple_mode_enabled
	_apply_ui_visibility()
	_refresh_bottom_mode_icons()


func _toggle_tasks_ui() -> void:
	tasks_ui_visible = not tasks_ui_visible
	_apply_ui_visibility()
	_refresh_bottom_mode_icons()


func _toggle_timer_ui() -> void:
	timer_ui_visible = not timer_ui_visible
	_apply_ui_visibility()
	_refresh_bottom_mode_icons()


func _apply_ui_visibility() -> void:
	var hide_main_ui := simple_mode_enabled or passenger_quiz_active
	if top_bar != null:
		top_bar.visible = not hide_main_ui
	if bottom_mode_controls != null:
		bottom_mode_controls.visible = not passenger_quiz_active
	if simple_mode_button != null:
		simple_mode_button.visible = not passenger_quiz_active
	if ambience_toggle_button != null:
		ambience_toggle_button.visible = not hide_main_ui
	if tasks_toggle_button != null:
		tasks_toggle_button.visible = not hide_main_ui
	if timer_toggle_button != null:
		timer_toggle_button.visible = not hide_main_ui
	if stats_panel != null:
		stats_panel.visible = false if hide_main_ui else stats_panel.visible
	if tutorial_panel != null:
		tutorial_panel.visible = false if hide_main_ui else tutorial_panel.visible
	if option_controller != null and hide_main_ui and option_controller.has_method("hide"):
		option_controller.hide()
	if store_controller != null and hide_main_ui and store_controller.has_method("hide_store"):
		store_controller.hide_store()
	if avg_gallery_controller != null and hide_main_ui and avg_gallery_controller.has_method("hide_gallery"):
		avg_gallery_controller.hide_gallery()
	if avg_dialogue_controller != null and hide_main_ui and avg_dialogue_controller.has_method("hide_dialogue"):
		avg_dialogue_controller.hide_dialogue()
		if not h_event_active and not passenger_quiz_active:
			_restore_music_after_avg_dialogue()
	if result_controller != null and hide_main_ui and result_controller.has_method("hide_result"):
		result_controller.hide_result()
	if music_controller != null and music_controller.has_method("set_ui_visible"):
		music_controller.set_ui_visible(not hide_main_ui)
	if task_controller != null and task_controller.has_method("set_panel_visible"):
		task_controller.set_panel_visible(not hide_main_ui and tasks_ui_visible)
	if focus_progress_hud != null:
		focus_progress_hud.visible = not hide_main_ui and tasks_ui_visible
	if timer_rail != null and timer_rail.has_method("set_panel_visible"):
		timer_rail.set_panel_visible(not hide_main_ui and timer_ui_visible)
	if timer_settings != null and timer_settings.has_method("hide") and (hide_main_ui or not timer_ui_visible):
		timer_settings.hide()
	if companion_controller != null and hide_main_ui:
		_hide_break_interaction()
		_hide_ambient_prompt()
	if break_media_controller != null and hide_main_ui:
		_stop_break_media()
	if background_menu_panel != null and hide_main_ui:
		background_menu_panel.visible = false
	_refresh_bottom_mode_icons()


func _refresh_bottom_mode_icons() -> void:
	if simple_mode_button != null:
		simple_mode_button.tooltip_text = "Simple Mode"
	if tasks_toggle_button != null:
		tasks_toggle_button.tooltip_text = "Tasks"
		_set_texture_button_icon(tasks_toggle_button, ICON_MISSION_PATH if tasks_ui_visible else ICON_HIDE_MISSION_PATH)
	if timer_toggle_button != null:
		timer_toggle_button.tooltip_text = "Pomodoro"


func _cycle_time_context() -> void:
	match manual_time_state:
		"day":
			manual_time_state = "sunfall"
			selected_context.time = "sunfall"
			selected_context.weather = "clear"
		"sunfall":
			manual_time_state = "night"
			selected_context.time = "night"
			selected_context.weather = "clear"
		"night":
			manual_time_state = "cloudy"
			selected_context.time = "day"
			selected_context.weather = "rain"
		_:
			manual_time_state = "day"
			selected_context.time = "day"
			selected_context.weather = "clear"
	drive_scene.load_selected_background()


func _toggle_background_menu() -> void:
	if background_menu_panel == null:
		return
	_refresh_background_menu()
	background_menu_panel.visible = not background_menu_panel.visible


func _select_background(background_id: String) -> void:
	selected_background_id = background_id
	if background_menu_panel != null:
		background_menu_panel.visible = false
	if drive_scene != null and drive_scene.has_method("set_selected_background"):
		drive_scene.set_selected_background(selected_background_id)
		drive_scene.load_selected_background()
	_save_game()


func _toggle_store_panel() -> void:
	if store_controller == null:
		return
	if store_controller.has_method("is_store_visible") and store_controller.is_store_visible():
		store_controller.hide_store()
		return
	store_controller.show_store(_store_items())


func _toggle_avg_gallery() -> void:
	if avg_gallery_controller == null:
		return
	if avg_gallery_controller.has_method("is_gallery_visible") and avg_gallery_controller.is_gallery_visible():
		avg_gallery_controller.hide_gallery()
		return
	_hide_top_bar_popups("gallery")
	avg_gallery_controller.show_gallery(
		AVGDialogueService.dialogues_by_type("main"),
		AVGDialogueService.viewed_dialogue_ids(interaction_history),
		PassengerFlowService.next_unlockable_dialogue_ids(passenger_defs, passenger_progress),
		PassengerFlowService.unlock_costs_by_dialogue(passenger_defs, passenger_progress),
		int(currencies.get("focus_points", 0)),
		passenger_defs
	)


func _on_avg_gallery_dialogue_selected(dialogue_id: String) -> void:
	if avg_gallery_controller != null and avg_gallery_controller.has_method("hide_gallery"):
		avg_gallery_controller.hide_gallery()
	_start_avg_dialogue(dialogue_id)


func _on_avg_gallery_unlock_requested(dialogue_id: String) -> void:
	var passenger_id := PassengerFlowService.passenger_id_for_dialogue(passenger_defs, dialogue_id)
	if passenger_id == "":
		return
	var costs := PassengerFlowService.unlock_costs_by_dialogue(passenger_defs, passenger_progress)
	var cost := int(costs.get(dialogue_id, 0))
	if int(currencies.get("focus_points", 0)) < cost:
		return
	var passenger := PassengerFlowService.find_passenger(passenger_defs, passenger_id)
	var dialogue := AVGDialogueService.find_dialogue(dialogue_id)
	pending_gallery_unlock = {
		"dialogue_id": dialogue_id,
		"passenger_id": passenger_id,
		"cost": cost
	}
	if gallery_unlock_confirm_dialog != null:
		gallery_unlock_confirm_dialog.dialog_text = "Spend %d Focus Points to unlock %s for %s?" % [
			cost,
			_dialogue_display_name(dialogue),
			_passenger_display_name(passenger)
		]
		gallery_unlock_confirm_dialog.popup_centered()


func _confirm_gallery_unlock() -> void:
	if pending_gallery_unlock.is_empty():
		return
	var dialogue_id := str(pending_gallery_unlock.get("dialogue_id", ""))
	var passenger_id := str(pending_gallery_unlock.get("passenger_id", ""))
	var cost := int(pending_gallery_unlock.get("cost", 0))
	pending_gallery_unlock = {}
	if int(currencies.get("focus_points", 0)) < cost:
		return
	if avg_gallery_controller != null and avg_gallery_controller.has_method("hide_gallery"):
		avg_gallery_controller.hide_gallery()
	currencies.focus_points = int(currencies.get("focus_points", 0)) - cost
	_save_game()
	_refresh_progress_ui()
	_start_h_event_for_dialogue(dialogue_id, passenger_id, true)


func _dialogue_display_name(dialogue: Dictionary) -> String:
	var key := str(dialogue.get("display_name_key", ""))
	if key != "":
		return _localized_value(key, str(dialogue.get("display_name", "")))
	var display_name := str(dialogue.get("display_name", ""))
	if display_name != "":
		return display_name
	return str(dialogue.get("dialogue_id", "Gallery Event"))


func _passenger_display_name(passenger: Dictionary) -> String:
	var fallback := str(passenger.get("display_name", passenger.get("passenger_id", "Passenger")))
	return _localized_value(str(passenger.get("display_name_key", "")), fallback)


func _localized_value(key: String, fallback: String) -> String:
	if key == "":
		return fallback
	if localizer != null and localizer.has_method("translate_or_fallback"):
		return str(localizer.translate_or_fallback(key, fallback))
	if localizer != null:
		var translated: String = localizer.translate(key)
		return fallback if translated == key and fallback != "" else translated
	return fallback


func _start_avg_dialogue(dialogue_id: String) -> bool:
	if avg_dialogue_controller == null:
		return false
	var dialogue := AVGDialogueService.find_dialogue(dialogue_id)
	if dialogue.is_empty():
		return false
	_hide_ambient_prompt()
	_hide_break_interaction()
	_stop_break_media()
	_suspend_music_for_avg_dialogue()
	avg_dialogue_controller.show_dialogue(dialogue)
	return true


func _show_first_entry_dialogue_if_needed() -> void:
	if avg_dialogue_controller == null:
		return
	var lines := [
		{
			"speaker": "女司機",
			"text": "終於來了，我等你很久了。"
		},
		{
			"speaker": "女司機",
			"text": "上車吧，今晚只載你一個。"
		},
		{
			"speaker": "女司機",
			"text": "又想被我陪著努力了？"
		},
		{
			"speaker": "女司機",
			"text": "門鎖好了，現在逃不掉囉。"
		},
		{
			"speaker": "女司機",
			"text": "安全帶繫好，別偷看別處喔。"
		}
	]
	var dialogue := {
		"dialogue_id": FIRST_ENTRY_DIALOGUE_ID,
		"transparent_overlay": true,
		"lines": [lines[randi() % lines.size()]]
	}
	avg_dialogue_controller.show_dialogue(dialogue)


func _begin_next_passenger(force_change: bool = false) -> void:
	if passenger_defs.is_empty():
		return
	if force_change and current_passenger_id != "":
		passenger_progress.last_passenger_id = current_passenger_id
	current_passenger = PassengerFlowService.choose_next_passenger(passenger_defs, passenger_progress)
	current_passenger_id = str(current_passenger.get("passenger_id", ""))
	current_passenger_complete_bonus = false
	if drive_scene != null and drive_scene.has_method("set_passenger"):
		drive_scene.set_passenger(current_passenger_id)
	if current_passenger_id == "":
		return
	if PassengerFlowService.is_passenger_complete(current_passenger, passenger_progress):
		if completed_passenger_dialog != null:
			completed_passenger_dialog.dialog_text = "%s has no locked gallery events left. Continue for double Focus Points?" % _passenger_display_name(current_passenger)
			completed_passenger_dialog.popup_centered()
		return
	_show_passenger_boarding_dialogue()


func _show_passenger_boarding_dialogue() -> void:
	if avg_dialogue_controller == null or current_passenger.is_empty():
		return
	var dialogue := PassengerFlowService.boarding_dialogue(current_passenger, passenger_progress)
	PassengerFlowService.mark_boarding_seen(passenger_progress, current_passenger_id)
	_save_game()
	avg_dialogue_controller.show_dialogue(dialogue)


func _continue_completed_passenger() -> void:
	current_passenger_complete_bonus = true
	_show_passenger_boarding_dialogue()


func _change_completed_passenger() -> void:
	_begin_next_passenger(true)


func _on_gold_token_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_h_event_from_gold_token()


func _start_h_event_from_gold_token() -> void:
	if h_event_active or avg_dialogue_controller == null:
		return
	var tokens := int(currencies.get("gold_tokens", 0))
	if tokens <= 0:
		return
	var selected := _pick_h_event_dialogues()
	if selected.is_empty():
		return
	currencies.gold_tokens = tokens - 1
	h_event_active = true
	h_event_queue = selected
	_suspend_music_for_h_event()
	for dialogue in selected:
		if typeof(dialogue) == TYPE_DICTIONARY:
			_unlock_avg_dialogue(str(dialogue.get("dialogue_id", "")))
	_save_game()
	_refresh_progress_ui()
	_show_h_event_preview_dialogue()


func _start_h_event_for_dialogue(dialogue_id: String, passenger_id: String, advance_after_playback: bool) -> void:
	if h_event_active or avg_dialogue_controller == null:
		return
	var dialogue := AVGDialogueService.find_dialogue(dialogue_id)
	if dialogue.is_empty():
		_restore_main_ride_ui()
		_begin_next_passenger()
		return
	h_event_active = true
	h_event_queue = [dialogue]
	h_event_pending_unlock = {
		"dialogue_id": dialogue_id,
		"passenger_id": passenger_id,
		"advance_after_playback": advance_after_playback
	}
	_suspend_music_for_h_event()
	_show_h_event_preview_dialogue()


func _show_h_event_preview_dialogue() -> void:
	var dialogue := {
		"dialogue_id": H_EVENT_PREVIEW_DIALOGUE_ID,
		"transparent_overlay": true,
		"lines": [
			{
				"speaker": "女司機",
				"text": "嘻嘻，似乎有好事要發生囉！"
			}
		]
	}
	avg_dialogue_controller.show_dialogue(dialogue)


func _pick_h_event_dialogues() -> Array:
	var candidates := AVGDialogueService.dialogues_by_type("main")
	candidates.shuffle()
	var selected := []
	for dialogue in candidates:
		if typeof(dialogue) != TYPE_DICTIONARY:
			continue
		selected.append(dialogue)
		if selected.size() >= H_EVENT_DIALOGUE_COUNT:
			break
	return selected


func _play_next_h_event_dialogue(transition_background: bool) -> void:
	if h_event_queue.is_empty():
		var should_resume_passenger_flow := not h_event_pending_unlock.is_empty()
		_finish_h_event_unlock()
		h_event_active = false
		_restore_music_after_h_event()
		_save_game()
		_refresh_progress_ui()
		if should_resume_passenger_flow:
			_restore_main_ride_ui()
			_begin_next_passenger()
		return
	var dialogue = h_event_queue.pop_front()
	if typeof(dialogue) != TYPE_DICTIONARY:
		_play_next_h_event_dialogue(transition_background)
		return
	avg_dialogue_controller.show_dialogue(dialogue, transition_background, 2.0)


func _finish_h_event_unlock() -> void:
	if h_event_pending_unlock.is_empty():
		return
	var dialogue_id := str(h_event_pending_unlock.get("dialogue_id", ""))
	var passenger_id := str(h_event_pending_unlock.get("passenger_id", ""))
	_unlock_avg_dialogue(dialogue_id)
	if bool(h_event_pending_unlock.get("advance_after_playback", false)) and passenger_id != "":
		var passenger := PassengerFlowService.find_passenger(passenger_defs, passenger_id)
		var next_event := PassengerFlowService.next_event(passenger, passenger_progress)
		if str(next_event.get("dialogue_id", "")) == dialogue_id:
			PassengerFlowService.advance_gallery(passenger_progress, passenger_id)
	h_event_pending_unlock = {}


func _suspend_music_for_h_event() -> void:
	h_event_music_state = {}
	if music_controller != null and music_controller.has_method("suspend_for_event"):
		h_event_music_state = music_controller.suspend_for_event()


func _restore_music_after_h_event() -> void:
	if music_controller != null and music_controller.has_method("restore_after_event"):
		music_controller.restore_after_event(h_event_music_state)
	h_event_music_state = {}


func _suspend_music_for_passenger_quiz() -> void:
	if not passenger_quiz_music_state.is_empty():
		return
	if music_controller != null and music_controller.has_method("suspend_for_event"):
		passenger_quiz_music_state = music_controller.suspend_for_event()


func _restore_music_after_passenger_quiz() -> void:
	if passenger_quiz_music_state.is_empty():
		return
	if music_controller != null and music_controller.has_method("restore_after_event"):
		music_controller.restore_after_event(passenger_quiz_music_state)
	passenger_quiz_music_state = {}


func _suspend_music_for_avg_dialogue() -> void:
	if h_event_active or avg_dialogue_music_suspended:
		return
	avg_dialogue_music_state = {}
	if music_controller != null and music_controller.has_method("suspend_for_event"):
		avg_dialogue_music_state = music_controller.suspend_for_event()
	avg_dialogue_music_suspended = true


func _restore_music_after_avg_dialogue() -> void:
	if not avg_dialogue_music_suspended:
		return
	if music_controller != null and music_controller.has_method("restore_after_event"):
		music_controller.restore_after_event(avg_dialogue_music_state)
	avg_dialogue_music_state = {}
	avg_dialogue_music_suspended = false


func _unlock_avg_dialogue(dialogue_id: String) -> void:
	if dialogue_id == "":
		return
	if AVGDialogueService.is_viewed(dialogue_id, interaction_history):
		return
	_record_interaction_event(AVGDialogueService.VIEWED_EVENT_TYPE, dialogue_id)


func _start_avg_dialogue_for_trigger(trigger_key: String) -> bool:
	var dialogues := AVGDialogueService.dialogues_for_trigger(trigger_key)
	if dialogues.is_empty():
		return false
	var dialogue = dialogues[0]
	if typeof(dialogue) != TYPE_DICTIONARY:
		return false
	return _start_avg_dialogue(str(dialogue.get("dialogue_id", "")))


func _on_avg_dialogue_finished(dialogue_id: String) -> void:
	if dialogue_id == "":
		return
	if dialogue_id == H_EVENT_PREVIEW_DIALOGUE_ID and h_event_active:
		_play_next_h_event_dialogue(true)
		return
	if h_event_active:
		_play_next_h_event_dialogue(true)
		return
	if dialogue_id == "%s_parking" % current_passenger_id:
		_start_passenger_quiz()
		return
	if dialogue_id == "%s_success" % current_passenger_id:
		var event: Dictionary = pending_passenger_success_event
		pending_passenger_success_event = {}
		_start_h_event_for_dialogue(str(event.get("dialogue_id", "")), current_passenger_id, true)
		return
	if dialogue_id == "%s_normal" % current_passenger_id or dialogue_id == "%s_failed" % current_passenger_id:
		_begin_next_passenger()
		return
	_restore_music_after_avg_dialogue()
	if AVGDialogueService.is_viewed(dialogue_id, interaction_history):
		return
	_record_interaction_event(AVGDialogueService.VIEWED_EVENT_TYPE, dialogue_id)


func _store_items() -> Array:
	return ContentUnlockService.store_items(background_defs, unlocked_content, localizer)


func _on_store_purchase_requested(content_id: String) -> void:
	var result := ContentUnlockService.purchase_background(content_id, background_defs, unlocked_content, currencies)
	if bool(result.get("changed", false)):
		_record_interaction_event("background_unlocked", content_id)
		_save_game()
		_refresh_progress_ui()
		if drive_scene != null and drive_scene.has_method("set_content_state"):
			drive_scene.set_content_state(background_defs, unlocked_content)
			drive_scene.load_selected_background()
		_refresh_background_menu()
		if store_controller != null:
			store_controller.refresh_items(_store_items())
			store_controller.show_status(localizer.translate("store.purchase_success"))
		return
	if store_controller == null:
		return
	var status := str(result.get("status", ""))
	if status == "insufficient":
		store_controller.show_status(localizer.trf("store.insufficient", {"focus_points": int(result.get("cost_focus_points", 0))}))
	elif status == "already_unlocked":
		store_controller.show_status(localizer.translate("store.already_unlocked"))
	else:
		store_controller.show_status(localizer.translate("store.purchase_failed"))


func _refresh_tasks_ui() -> void:
	if task_controller != null and task_controller.has_method("refresh_tasks"):
		task_controller.refresh_tasks()


func _refresh_progress_ui() -> void:
	if fp_label != null:
		fp_label.tooltip_text = "%s: %d" % [localizer.translate("top.focus_points"), currencies.focus_points]
	if focus_points_value_label != null:
		focus_points_value_label.text = _format_compact_number(int(currencies.get("focus_points", 0)))
	if level_label != null:
		level_label.visible = false
		var tokens := int(currencies.get("gold_tokens", 0))
		level_label.tooltip_text = "%s: %d  XP %d / %d" % [localizer.translate("top.gold_tokens"), tokens, level_progress.focus_xp, _xp_required_for_next_level()]
		level_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if tokens > 0 else Control.CURSOR_ARROW
	if focus_level_badge_label != null:
		focus_level_badge_label.visible = false
		focus_level_badge_label.text = str(int(currencies.get("gold_tokens", 0)))
	if focus_level_progress != null:
		focus_level_progress.visible = false
		var required := _xp_required_for_next_level()
		focus_level_progress.max_value = max(required, 1)
		focus_level_progress.value = clamp(int(level_progress.get("focus_xp", 0)), 0, required)
	var bond_tooltip := "%s Lv.%d  %d / %d" % [localizer.translate("top.bond"), bond_progress.bond_level, bond_progress.bond_points_current, _bond_required_for_next_level()]
	if bond_level_label != null:
		bond_level_label.visible = false
		bond_level_label.text = "LV %d" % int(bond_progress.get("bond_level", 1))
		bond_level_label.tooltip_text = bond_tooltip
	if bond_label != null:
		bond_label.visible = false
		bond_label.text = ""
		bond_label.tooltip_text = ""
	if unlocks_label != null:
		unlocks_label.text = ""
		unlocks_label.tooltip_text = ""
	if store_button != null:
		store_button.text = ""
		store_button.tooltip_text = ""
	if avg_gallery_button != null:
		avg_gallery_button.tooltip_text = localizer.translate("avg.gallery.title")
	if stats_button != null:
		stats_button.tooltip_text = localizer.translate("top.stats")
	if tutorial_button != null:
		tutorial_button.tooltip_text = "簡易教學"
	stats_label.text = "%s: %d\n%s: %d\n%s: %d\n%s: %d" % [
		localizer.translate("stats.completed"),
		daily_stats.completed_sessions,
		localizer.translate("stats.partial"),
		daily_stats.partial_sessions,
		localizer.translate("stats.focus_minutes"),
		daily_stats.focus_minutes_completed + daily_stats.focus_minutes_partial,
		localizer.translate("stats.tasks_done"),
		daily_stats.tasks_completed
	]


func _format_compact_number(value: int) -> String:
	if abs(value) >= 1000:
		var compact := value / 1000.0
		if value % 1000 == 0:
			return "%dK" % int(compact)
		return "%.2fK" % compact
	return str(value)


func _update_stats(status: String, actual_sec: int) -> void:
	SessionRewardCoordinator.update_focus_stats(daily_stats, session_mode, status, actual_sec)


func _format_time(seconds: int) -> String:
	var minutes := seconds / 60
	var secs := seconds % 60
	return "%02d:%02d" % [minutes, secs]


func _status_title(status: String) -> String:
	return localizer.translate("timer.state_%s" % status)


func _reward_summary(rewards: Dictionary) -> String:
	return SessionRewardCoordinator.reward_summary(localizer, rewards)


func _result_summary(status: String, actual_sec: int, rewards: Dictionary, bond_level_up_text: String) -> String:
	return SessionRewardCoordinator.result_summary(
		localizer,
		planned_duration_sec,
		actual_sec,
		rewards,
		bond_level_up_text,
		_result_next_action_key(status)
	)


func _result_next_action_key(status: String) -> String:
	if status == "abandoned":
		return "result.next_action_retry"
	return "result.next_action_break"


func _bond_level_up_summary(level: int) -> String:
	if localizer != null:
		return localizer.trf("result.bond_level_up", {"level": level})
	return "Bond Level Up: Lv.%d" % level


func _task_status(task_id: String) -> String:
	if task_controller != null and task_controller.has_method("task_status"):
		return task_controller.task_status(task_id)
	return ""


func _apply_time_context() -> void:
	var hour: int = Time.get_datetime_dict_from_system().hour
	if hour >= 18 or hour < 6:
		selected_context.time = "night"
	elif hour >= 16:
		selected_context.time = "sunfall"
	else:
		selected_context.time = "day"
	selected_context.weather = "clear"


func _time_state_from_context() -> String:
	if str(selected_context.get("weather", "clear")) == "rain":
		return "cloudy"
	return str(selected_context.get("time", "day"))


func _context_id() -> String:
	return "%s_%s_%s" % [selected_context.mood, selected_context.time, selected_context.weather]


func _load_save() -> void:
	var parsed := SaveDataService.load_payload(SAVE_PATH, {})
	if parsed.is_empty():
		_ensure_currency_defaults()
		return
	tasks = parsed.get("tasks", tasks)
	sessions = parsed.get("sessions", sessions)
	currencies = parsed.get("currencies", currencies)
	level_progress = parsed.get("level_progress", level_progress)
	bond_progress = parsed.get("bond_progress", bond_progress)
	daily_stats = parsed.get("daily_stats", daily_stats)
	interaction_history = parsed.get("interaction_history", interaction_history)
	unlocked_content = parsed.get("unlocked_content", unlocked_content)
	passenger_progress = parsed.get("passenger_progress", passenger_progress)
	var timer_settings = parsed.get("timer_settings", {})
	if typeof(timer_settings) == TYPE_DICTIONARY:
		duration_minutes = int(timer_settings.get("focus_minutes", duration_minutes))
		break_duration_minutes = int(timer_settings.get("break_minutes", break_duration_minutes))
		auto_restart_enabled = bool(timer_settings.get("auto_restart", auto_restart_enabled))
		alarm_enabled = bool(timer_settings.get("alarm", alarm_enabled))
	planned_duration_sec = duration_minutes * 60
	var music_state = parsed.get("music_state", {})
	if typeof(music_state) == TYPE_DICTIONARY:
		saved_music_path = str(music_state.get("current_path", saved_music_path))
		music_loop = bool(music_state.get("loop", music_loop))
		music_volume = float(music_state.get("volume", music_volume))
	var app_settings = parsed.get("app_settings", {})
	if typeof(app_settings) == TYPE_DICTIONARY:
		language_code = str(app_settings.get("language", language_code))
		break_media_enabled = bool(app_settings.get("break_media_enabled", break_media_enabled))
		break_media_path = str(app_settings.get("break_media_path", break_media_path))
		ambient_prompt_frequency = str(app_settings.get("ambient_prompt_frequency", ambient_prompt_frequency))
		selected_background_id = str(app_settings.get("selected_background_id", selected_background_id))
		if ambient_prompt_frequency != AMBIENT_PROMPT_LOW and ambient_prompt_frequency != AMBIENT_PROMPT_NORMAL and ambient_prompt_frequency != AMBIENT_PROMPT_OFF:
			ambient_prompt_frequency = AMBIENT_PROMPT_NORMAL
		if selected_background_id == "":
			selected_background_id = BACKGROUND_LOFI_AUTO


func _ensure_currency_defaults() -> void:
	if not currencies.has("focus_points"):
		currencies.focus_points = 0
	if not currencies.has("bond_points_total"):
		currencies.bond_points_total = 0
	if not currencies.has("gold_tokens"):
		currencies.gold_tokens = 0


func _reset_debug_data() -> void:
	tasks = []
	sessions = []
	currencies = {
		"focus_points": 0,
		"bond_points_total": 0,
		"gold_tokens": 0
	}
	level_progress = {
		"focus_level": 1,
		"focus_xp": 0,
		"focus_xp_lifetime": 0
	}
	bond_progress = {
		"character_id": "companion_01",
		"bond_level": 1,
		"bond_points_current": 0,
		"bond_points_lifetime": 0
	}
	daily_stats = {
		"focus_minutes_completed": 0,
		"focus_minutes_partial": 0,
		"completed_sessions": 0,
		"partial_sessions": 0,
		"tasks_completed": 0
	}
	interaction_history = []
	unlocked_content = []
	passenger_progress = PassengerFlowService.default_progress(passenger_defs)
	current_passenger_id = ""
	current_passenger = {}
	current_passenger_complete_bonus = false
	pending_gallery_unlock = {}
	pending_passenger_success_event = {}
	quiz_state = {}
	passenger_quiz_active = false
	h_event_active = false
	h_event_queue = []
	h_event_pending_unlock = {}
	result_dismissed = true
	duration_minutes = DEFAULT_FOCUS_MINUTES
	break_duration_minutes = DEFAULT_BREAK_MINUTES
	auto_restart_enabled = false
	alarm_enabled = false
	active_task_id = ""
	session_started_at = ""
	elapsed_sec = 0.0
	_apply_timer_state(TimerSessionService.reset_focus(duration_minutes))
	selected_background_id = BACKGROUND_LOFI_AUTO
	_apply_time_context()
	manual_time_state = _time_state_from_context()
	tasks_ui_visible = true
	timer_ui_visible = true
	simple_mode_enabled = false
	if passenger_quiz_controller != null and passenger_quiz_controller.has_method("hide_quiz"):
		passenger_quiz_controller.hide_quiz()
	if avg_dialogue_controller != null and avg_dialogue_controller.has_method("hide_dialogue"):
		avg_dialogue_controller.hide_dialogue()
	if avg_gallery_controller != null and avg_gallery_controller.has_method("hide_gallery"):
		avg_gallery_controller.hide_gallery()
	if result_controller != null and result_controller.has_method("hide_result"):
		result_controller.hide_result()
	if store_controller != null and store_controller.has_method("hide_store"):
		store_controller.hide_store()
	if option_controller != null and option_controller.has_method("hide"):
		option_controller.hide()
	if timer_settings != null and timer_settings.has_method("hide"):
		timer_settings.hide()
	_hide_break_interaction()
	_hide_ambient_prompt()
	_stop_break_media()
	_restore_music_after_h_event()
	_restore_music_after_passenger_quiz()
	_restore_music_after_avg_dialogue()
	if drive_scene != null:
		if drive_scene.has_method("set_passenger"):
			drive_scene.set_passenger("")
		if drive_scene.has_method("set_content_state"):
			drive_scene.set_content_state(background_defs, unlocked_content)
		if drive_scene.has_method("set_selected_background"):
			drive_scene.set_selected_background(selected_background_id)
		if drive_scene.has_method("load_selected_background"):
			drive_scene.load_selected_background()
	_save_game()
	_refresh_all()
	call_deferred("_begin_next_passenger")


func _save_game() -> void:
	var current_music_state := {
		"current_path": saved_music_path,
		"loop": music_loop,
		"volume": music_volume
	}
	if music_controller != null and music_controller.has_method("get_state"):
		current_music_state = music_controller.get_state()
	var payload := {
		"tasks": tasks,
		"sessions": sessions,
		"currencies": currencies,
		"level_progress": level_progress,
		"bond_progress": bond_progress,
		"daily_stats": daily_stats,
		"interaction_history": interaction_history,
		"unlocked_content": unlocked_content,
		"passenger_progress": passenger_progress,
		"timer_settings": {
			"focus_minutes": duration_minutes,
			"break_minutes": break_duration_minutes,
			"auto_restart": auto_restart_enabled,
			"alarm": alarm_enabled
		},
		"music_state": current_music_state,
		"app_settings": {
			"language": language_code,
			"break_media_enabled": break_media_enabled,
			"break_media_path": break_media_path,
			"ambient_prompt_frequency": ambient_prompt_frequency,
			"selected_background_id": selected_background_id
		}
	}
	SaveDataService.save_payload(SAVE_PATH, payload)
