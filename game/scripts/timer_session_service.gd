extends RefCounted

const MODE_FOCUS := "focus"
const MODE_SHORT_BREAK := "short_break"
const STATE_IDLE := "idle"
const STATE_RUNNING := "running"
const STATE_PAUSED := "paused"
const STATUS_PARTIAL := "partial"
const STATUS_ABANDONED := "abandoned"


static func advance(elapsed_sec: float, delta: float, planned_duration_sec: int) -> Dictionary:
	var next_elapsed := elapsed_sec + delta
	var finished := false
	if next_elapsed >= planned_duration_sec:
		next_elapsed = planned_duration_sec
		finished = true
	return {
		"elapsed_sec": next_elapsed,
		"finished": finished
	}


static func primary_action(app_state: String) -> String:
	if app_state == STATE_PAUSED:
		return "resume"
	if app_state == STATE_RUNNING:
		return "pause"
	return "start_focus"


static func start_focus(duration_minutes: int, active_task_id: String) -> Dictionary:
	return {
		"app_state": STATE_RUNNING,
		"session_mode": MODE_FOCUS,
		"planned_duration_sec": duration_minutes * 60,
		"elapsed_sec": 0.0,
		"session_started_at": Time.get_datetime_string_from_system(false, true),
		"active_task_id": active_task_id,
		"message": "Keep the fare moving.",
		"message_key": "timer.message_focus"
	}


static func pause() -> Dictionary:
	return {
		"app_state": STATE_PAUSED,
		"message": "Paused",
		"message_key": "timer.message_pause"
	}


static func resume() -> Dictionary:
	return {
		"app_state": STATE_RUNNING,
		"message": "Back on route",
		"message_key": "timer.message_resume"
	}


static func reset_focus(duration_minutes: int) -> Dictionary:
	return {
		"app_state": STATE_IDLE,
		"session_mode": MODE_FOCUS,
		"planned_duration_sec": duration_minutes * 60,
		"elapsed_sec": 0.0,
		"session_started_at": "",
		"active_task_id": "",
		"message": "",
		"message_key": ""
	}


static func start_break(break_duration_minutes: int) -> Dictionary:
	return {
		"app_state": STATE_RUNNING,
		"session_mode": MODE_SHORT_BREAK,
		"planned_duration_sec": break_duration_minutes * 60,
		"elapsed_sec": 0.0,
		"active_task_id": "",
		"message": "Pulling into a quiet stop.",
		"message_key": "timer.message_break"
	}


static func finish_break(duration_minutes: int) -> Dictionary:
	return reset_focus(duration_minutes)


static func classify_early_end(elapsed_sec: float, planned_duration_sec: int) -> String:
	var ratio := elapsed_sec / float(max(planned_duration_sec, 1))
	return STATUS_PARTIAL if ratio >= 0.3 else STATUS_ABANDONED


static func set_focus_duration(minutes: int) -> Dictionary:
	var clamped: int = clamp(minutes, 1, 180)
	return {
		"duration_minutes": clamped,
		"planned_duration_sec": clamped * 60
	}


static func set_break_duration(minutes: int) -> int:
	return clamp(minutes, 1, 60)
