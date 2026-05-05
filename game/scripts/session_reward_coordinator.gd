extends RefCounted

const ProgressionService = preload("res://scripts/progression_service.gd")
const TaskService = preload("res://scripts/task_service.gd")
const RESULT_SUMMARY_DEFS_PATH := "res://data/reward_summary_defs.json"


static func grant_session_rewards(
	session_mode: String,
	status: String,
	actual_sec: int,
	planned_duration_sec: int,
	currencies: Dictionary,
	level_progress: Dictionary,
	bond_progress: Dictionary,
	min_rewardable_session_sec: int,
	base_focus_points: int,
	base_bond: int,
	base_xp: int
) -> Dictionary:
	return ProgressionService.grant_session_rewards(
		session_mode,
		status,
		actual_sec,
		planned_duration_sec,
		currencies,
		level_progress,
		bond_progress,
		min_rewardable_session_sec,
		base_focus_points,
		base_bond,
		base_xp
	)


static func apply_task_completion_bonus(
	tasks: Array,
	task_id: String,
	currencies: Dictionary,
	level_progress: Dictionary,
	daily_stats: Dictionary,
	focus_points_bonus: int,
	xp_bonus: int,
	localizer
) -> Dictionary:
	if task_id == "":
		return {"changed": false, "summary": ""}
	if not TaskService.set_task_status(tasks, task_id, "done"):
		return {"changed": false, "summary": ""}
	currencies.focus_points += focus_points_bonus
	ProgressionService.add_xp(level_progress, xp_bonus, currencies)
	daily_stats.tasks_completed += 1
	return {
		"changed": true,
		"summary": localizer.trf("result.task_bonus", {
			"focus_points": focus_points_bonus,
			"xp": xp_bonus
		}) if localizer != null else "+%d Focus Points  +%d XP" % [focus_points_bonus, xp_bonus]
	}


static func update_focus_stats(daily_stats: Dictionary, session_mode: String, status: String, actual_sec: int) -> void:
	if session_mode != "focus":
		return
	var minutes := int(round(actual_sec / 60.0))
	if status == "completed":
		daily_stats.completed_sessions += 1
		daily_stats.focus_minutes_completed += minutes
	elif status == "partial":
		daily_stats.partial_sessions += 1
		daily_stats.focus_minutes_partial += minutes


static func reward_summary(localizer, rewards: Dictionary) -> String:
	if not bool(rewards.get("rewardable", false)):
		return localizer.translate("result.no_reward") if localizer != null else "No reward."
	if localizer != null:
		return localizer.trf("result.reward_summary", {
			"focus_points": int(rewards.get("focus_points", 0)),
			"xp": int(rewards.get("xp", 0)),
			"bond": int(rewards.get("bond", 0))
		})
	return "+%d Focus Points  +%d XP  +%d Bond" % [
		int(rewards.get("focus_points", 0)),
		int(rewards.get("xp", 0)),
		int(rewards.get("bond", 0))
	]


static func result_summary(
	localizer,
	planned_duration_sec: int,
	actual_sec: int,
	rewards: Dictionary,
	bond_level_up_text: String,
	next_action_key: String
) -> String:
	var values := {
		"focus_duration": {"minutes": _minutes(planned_duration_sec)},
		"actual_duration": {"minutes": _minutes(actual_sec)},
		"rewards": {"summary": reward_summary(localizer, rewards)},
		"bond_level_up": {"summary": bond_level_up_text},
		"next_action": {"action": _tr(localizer, next_action_key)}
	}
	var lines := []
	for definition in _result_summary_defs():
		if typeof(definition) != TYPE_DICTIONARY:
			continue
		var field := str(definition.get("field", ""))
		if bool(definition.get("optional", false)) and field == "bond_level_up" and bond_level_up_text == "":
			continue
		var text_key := str(definition.get("text_key", ""))
		lines.append(_trf(localizer, text_key, values.get(field, {})))
	return "\n".join(lines)


static func _result_summary_defs() -> Array:
	var file := FileAccess.open(RESULT_SUMMARY_DEFS_PATH, FileAccess.READ)
	if file == null:
		return [
			{"field": "focus_duration", "text_key": "result.focus_duration"},
			{"field": "actual_duration", "text_key": "result.actual_duration"},
			{"field": "rewards", "text_key": "result.rewards"},
			{"field": "bond_level_up", "text_key": "result.bond_level_up_line", "optional": true},
			{"field": "next_action", "text_key": "result.next_action"}
		]
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var result_summary = parsed.get("result_summary", [])
	if typeof(result_summary) != TYPE_ARRAY:
		return []
	return result_summary


static func _minutes(seconds: int) -> int:
	return int(round(seconds / 60.0))


static func _tr(localizer, key: String) -> String:
	if localizer != null:
		return localizer.translate(key)
	return key


static func _trf(localizer, key: String, values: Dictionary) -> String:
	if localizer != null:
		return localizer.trf(key, values)
	var text := key
	for value_key in values.keys():
		text = text.replace("{%s}" % str(value_key), str(values[value_key]))
	return text
