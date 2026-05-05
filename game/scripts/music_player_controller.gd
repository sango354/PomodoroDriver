extends Node

signal state_changed

const MUSIC_ROOT := "res://assets/music"
const ICON_AMBIENCE_PATH := "res://assets/icons/ambience.png"
const ICON_LIST_PATH := "res://assets/icons/list.png"
const ICON_LOOP_PATH := "res://assets/icons/loop.png"
const ICON_MUSIC_PAUSE_PATH := "res://assets/icons/musicpause.png"
const ICON_MUSIC_PLAY_PATH := "res://assets/icons/musicplay.png"
const ICON_NEXT_PATH := "res://assets/icons/next.png"
const ICON_PREVIOUS_PATH := "res://assets/icons/previous.png"
const MUSIC_MANIFEST_PATH := "res://data/music_manifest.json"

var music_player: AudioStreamPlayer
var music_bar: Control
var music_files: Array[String] = []
var current_music_index := -1
var saved_music_path := ""
var music_loop := false
var music_volume := 0.7
var music_list_panel: PanelContainer
var music_list: VBoxContainer
var track_label: Label
var play_button: TextureButton
var loop_button: TextureButton
var menu_button: TextureButton
var prev_button: TextureButton
var next_button: TextureButton
var ambience_button: TextureButton
var music_title_label: Label
var localizer


func setup(parent: Control, saved_path: String, loop_enabled: bool, volume: float, localization_service = null) -> void:
	localizer = localization_service
	saved_music_path = saved_path
	music_loop = loop_enabled
	music_volume = volume
	_build_bottom_bar(parent)
	_build_audio_player()
	_scan_music_files()


func get_state() -> Dictionary:
	return {
		"current_path": saved_music_path,
		"loop": music_loop,
		"volume": music_volume
	}


func suspend_for_event() -> Dictionary:
	var state := {
		"was_playing": false,
		"was_paused": false
	}
	if music_player == null:
		return state
	state.was_playing = music_player.playing
	state.was_paused = music_player.stream_paused
	if music_player.playing and not music_player.stream_paused:
		music_player.stream_paused = true
		_refresh_play_button(false)
	return state


func restore_after_event(state: Dictionary) -> void:
	if music_player == null:
		return
	if bool(state.get("was_playing", false)) and not bool(state.get("was_paused", false)):
		music_player.stream_paused = false
		_refresh_play_button(true)
	else:
		_refresh_play_button(music_player.playing and not music_player.stream_paused)


func set_ui_visible(is_visible: bool) -> void:
	if music_bar != null:
		music_bar.visible = is_visible
	if music_list_panel != null:
		music_list_panel.visible = false if not is_visible else music_list_panel.visible


func _build_bottom_bar(parent: Control) -> void:
	var bar := PanelContainer.new()
	music_bar = bar
	bar.anchor_left = 0.0
	bar.anchor_top = 1.0
	bar.anchor_right = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 0
	bar.offset_top = -50
	bar.offset_right = 0
	bar.offset_bottom = 0
	bar.add_theme_stylebox_override("panel", _new_panel_style(0.64))
	parent.add_child(bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var left_group := HBoxContainer.new()
	left_group.add_theme_constant_override("separation", 10)
	left_group.custom_minimum_size = Vector2(260, 0)
	row.add_child(left_group)

	menu_button = _new_icon_asset_button(ICON_LIST_PATH, _tr("music.list"), Vector2(36, 32))
	menu_button.pressed.connect(_toggle_music_list)
	left_group.add_child(menu_button)

	track_label = _new_muted_label(_tr("music.no_music_loaded"))
	track_label.custom_minimum_size = Vector2(200, 0)
	left_group.add_child(track_label)

	var control_group := HBoxContainer.new()
	control_group.add_theme_constant_override("separation", 10)
	control_group.custom_minimum_size = Vector2(300, 0)
	row.add_child(control_group)

	prev_button = _new_icon_asset_button(ICON_PREVIOUS_PATH, _tr("music.previous"), Vector2(36, 32))
	prev_button.pressed.connect(_play_previous_music)
	control_group.add_child(prev_button)

	play_button = _new_icon_asset_button(ICON_MUSIC_PLAY_PATH, _tr("music.play"), Vector2(36, 32))
	play_button.pressed.connect(_toggle_music_playback)
	control_group.add_child(play_button)

	next_button = _new_icon_asset_button(ICON_NEXT_PATH, _tr("music.next"), Vector2(36, 32))
	next_button.pressed.connect(_play_next_music)
	control_group.add_child(next_button)

	loop_button = _new_icon_asset_button(ICON_LOOP_PATH, _tr("music.loop"), Vector2(36, 32))
	loop_button.pressed.connect(_toggle_music_loop)
	_add_icon_disabled_overlay(loop_button)
	_refresh_loop_button()
	control_group.add_child(loop_button)

	var volume_slider := HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = 0.01
	volume_slider.value = music_volume
	volume_slider.custom_minimum_size = Vector2(130, 32)
	volume_slider.value_changed.connect(_on_volume_changed)
	control_group.add_child(volume_slider)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	ambience_button = _new_icon_asset_button(ICON_AMBIENCE_PATH, _tr("music.ambience"), Vector2(36, 32))
	row.add_child(ambience_button)

	music_list_panel = _new_panel()
	music_list_panel.visible = false
	music_list_panel.anchor_left = 0.0
	music_list_panel.anchor_top = 1.0
	music_list_panel.anchor_right = 0.0
	music_list_panel.anchor_bottom = 1.0
	music_list_panel.offset_left = 0
	music_list_panel.offset_top = -332
	music_list_panel.offset_right = 430
	music_list_panel.offset_bottom = -58
	parent.add_child(music_list_panel)
	var list_box := _panel_box(music_list_panel)
	music_title_label = _new_title(_tr("music.title"))
	list_box.add_child(music_title_label)
	music_list = VBoxContainer.new()
	music_list.add_theme_constant_override("separation", 6)
	list_box.add_child(music_list)


func _build_audio_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.volume_db = linear_to_db(max(music_volume, 0.001))
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)


func _scan_music_files() -> void:
	music_files.clear()
	var dir := DirAccess.open(MUSIC_ROOT)
	if dir != null:
		for file_name in dir.get_files():
			var ext := file_name.get_extension().to_lower()
			if ext == "ogg" or ext == "mp3" or ext == "wav":
				music_files.append("%s/%s" % [MUSIC_ROOT, file_name])
	_load_music_manifest()
	music_files.sort()
	_refresh_music_list()
	if music_files.is_empty():
		track_label.text = _tr("music.add_files")
	else:
		current_music_index = _music_index_for_saved_path()
		if _can_autoplay_music():
			_play_current_music()
		else:
			_update_track_label()


func _load_music_manifest() -> void:
	var file := FileAccess.open(MUSIC_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var files = parsed.get("files", [])
	if typeof(files) != TYPE_ARRAY:
		return
	for path in files:
		var music_path := str(path)
		if music_path == "":
			continue
		if not music_files.has(music_path):
			music_files.append(music_path)


func _refresh_music_list() -> void:
	if music_list == null:
		return
	for child in music_list.get_children():
		child.queue_free()
	if music_files.is_empty():
		music_list.add_child(_new_muted_label(_tr("music.no_files")))
		return
	for i in range(music_files.size()):
		var button := Button.new()
		button.text = _music_display_name(music_files[i])
		button.tooltip_text = music_files[i]
		button.custom_minimum_size = Vector2(0, 32)
		button.pressed.connect(_select_music.bind(i))
		music_list.add_child(button)


func _toggle_music_list() -> void:
	music_list_panel.visible = not music_list_panel.visible


func _select_music(index: int) -> void:
	if index < 0 or index >= music_files.size():
		return
	current_music_index = index
	_play_current_music()
	music_list_panel.visible = false


func _toggle_music_playback() -> void:
	if music_files.is_empty():
		return
	if current_music_index < 0:
		current_music_index = 0
	if music_player.playing:
		music_player.stream_paused = true
		_refresh_play_button(false)
	elif music_player.stream != null and music_player.stream_paused:
		music_player.stream_paused = false
		_refresh_play_button(true)
	else:
		_play_current_music()


func _play_current_music() -> void:
	if current_music_index < 0 or current_music_index >= music_files.size():
		return
	var music_path := music_files[current_music_index]
	var stream := load(music_path)
	if stream == null:
		stream = _load_music_from_file(music_path)
	if stream == null:
		track_label.text = "Could not load: %s" % _music_display_name(music_path)
		return
	music_player.stream = stream
	music_player.stream_paused = false
	music_player.play()
	_refresh_play_button(true)
	saved_music_path = music_path
	_update_track_label()
	state_changed.emit()


func _load_music_from_file(path: String):
	var ext := path.get_extension().to_lower()
	if ext == "mp3" and ClassDB.class_exists("AudioStreamMP3"):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return null
		var stream := AudioStreamMP3.new()
		stream.data = bytes
		return stream
	return null


func _play_previous_music() -> void:
	if music_files.is_empty():
		return
	current_music_index = (current_music_index - 1 + music_files.size()) % music_files.size()
	_play_current_music()


func _play_next_music() -> void:
	if music_files.is_empty():
		return
	current_music_index = (current_music_index + 1) % music_files.size()
	_play_current_music()


func _toggle_music_loop() -> void:
	music_loop = not music_loop
	_refresh_loop_button()
	state_changed.emit()


func _on_volume_changed(value: float) -> void:
	music_volume = float(value)
	if music_player != null:
		music_player.volume_db = linear_to_db(max(music_volume, 0.001))
	state_changed.emit()


func _on_music_finished() -> void:
	if music_loop:
		_play_current_music()
	else:
		_play_next_music()


func _update_track_label() -> void:
	if current_music_index >= 0 and current_music_index < music_files.size():
		track_label.text = _music_display_name(music_files[current_music_index])


func _music_display_name(path: String) -> String:
	return path.get_file().get_basename()


func _refresh_play_button(is_playing: bool) -> void:
	if play_button == null:
		return
	var texture := _load_icon_texture(ICON_MUSIC_PAUSE_PATH if is_playing else ICON_MUSIC_PLAY_PATH)
	play_button.texture_normal = texture
	play_button.texture_hover = texture
	play_button.texture_pressed = texture
	play_button.texture_disabled = texture
	play_button.tooltip_text = _tr("music.pause") if is_playing else _tr("music.play")


func _refresh_loop_button() -> void:
	if loop_button == null:
		return
	loop_button.tooltip_text = _tr("music.loop_on") if music_loop else _tr("music.loop_off")
	_set_icon_disabled_overlay(loop_button, not music_loop)


func set_localizer(localization_service) -> void:
	localizer = localization_service
	if menu_button != null:
		menu_button.tooltip_text = _tr("music.list")
	if prev_button != null:
		prev_button.tooltip_text = _tr("music.previous")
	if next_button != null:
		next_button.tooltip_text = _tr("music.next")
	if ambience_button != null:
		ambience_button.tooltip_text = _tr("music.ambience")
	if music_title_label != null:
		music_title_label.text = _tr("music.title")
	if music_files.is_empty() and track_label != null:
		track_label.text = _tr("music.add_files")
	_refresh_play_button(music_player != null and music_player.playing and not music_player.stream_paused)
	_refresh_loop_button()
	_refresh_music_list()


func _music_index_for_saved_path() -> int:
	if saved_music_path != "":
		for i in range(music_files.size()):
			if music_files[i] == saved_music_path:
				return i
	return 0


func _can_autoplay_music() -> bool:
	return DisplayServer.get_name() != "headless"


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


func _add_icon_disabled_overlay(button: Control) -> void:
	var overlay := ColorRect.new()
	overlay.name = "DisabledOverlay"
	overlay.color = Color(0.08, 0.08, 0.08, 0.48)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(overlay)


func _set_icon_disabled_overlay(button: Control, visible: bool) -> void:
	var overlay := button.get_node_or_null("DisabledOverlay") as CanvasItem
	if overlay != null:
		overlay.visible = visible


func _load_icon_texture(icon_path: String) -> Texture2D:
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
	if FileAccess.file_exists(icon_path):
		var image := Image.new()
		if image.load(icon_path) == OK:
			return ImageTexture.create_from_image(image)
	return null


func _on_hover_scale(button: Control, hovered: bool) -> void:
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE * (1.1 if hovered else 1.0)


func _tr(key: String) -> String:
	if localizer != null:
		return localizer.translate(key)
	return key
