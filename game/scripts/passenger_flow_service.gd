extends RefCounted

const PASSENGER_DEFS_PATH := "res://data/passenger_defs.json"
const PASSENGER_QUIZ_DEFS_PATH := "res://data/passenger_quiz_defs.json"

const QUIZ_ROUNDS := 10
const EMOTION_MAX := 100
const ALERT_MAX := 100
const BASE_REWARD_SECONDS := 300
const BASE_FOCUS_POINTS := 20
const COMPLETED_PASSENGER_MULTIPLIER := 2


static func load_passengers() -> Array:
	return _load_array_from_key(PASSENGER_DEFS_PATH, "passengers")


static func load_questions() -> Array:
	return _load_array_from_key(PASSENGER_QUIZ_DEFS_PATH, "questions")


static func default_progress(passengers: Array) -> Dictionary:
	var progress := {
		"last_passenger_id": "",
		"passengers": {}
	}
	for passenger in passengers:
		if typeof(passenger) != TYPE_DICTIONARY:
			continue
		var passenger_id := str(passenger.get("passenger_id", ""))
		if passenger_id == "":
			continue
		progress.passengers[passenger_id] = {
			"ride_count": 0,
			"gallery_index": 0,
			"first_boarding_seen": false
		}
	return progress


static func normalize_progress(progress: Dictionary, passengers: Array) -> Dictionary:
	var normalized := progress.duplicate(true)
	if not normalized.has("last_passenger_id"):
		normalized.last_passenger_id = ""
	if not normalized.has("passengers") or typeof(normalized.passengers) != TYPE_DICTIONARY:
		normalized.passengers = {}
	for passenger in passengers:
		if typeof(passenger) != TYPE_DICTIONARY:
			continue
		var passenger_id := str(passenger.get("passenger_id", ""))
		if passenger_id == "":
			continue
		if not normalized.passengers.has(passenger_id) or typeof(normalized.passengers[passenger_id]) != TYPE_DICTIONARY:
			normalized.passengers[passenger_id] = {
				"ride_count": 0,
				"gallery_index": 0,
				"first_boarding_seen": false
			}
			continue
		var passenger_progress: Dictionary = normalized.passengers[passenger_id]
		passenger_progress.ride_count = int(passenger_progress.get("ride_count", 0))
		passenger_progress.gallery_index = int(passenger_progress.get("gallery_index", 0))
		passenger_progress.first_boarding_seen = bool(passenger_progress.get("first_boarding_seen", false))
	return normalized


static func choose_next_passenger(passengers: Array, progress: Dictionary) -> Dictionary:
	var candidates := []
	var last_id := str(progress.get("last_passenger_id", ""))
	for passenger in passengers:
		if typeof(passenger) != TYPE_DICTIONARY:
			continue
		var passenger_id := str(passenger.get("passenger_id", ""))
		if passenger_id == "" or passenger_id == last_id:
			continue
		candidates.append(passenger)
	if candidates.is_empty():
		for passenger in passengers:
			if typeof(passenger) == TYPE_DICTIONARY:
				candidates.append(passenger)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]


static func find_passenger(passengers: Array, passenger_id: String) -> Dictionary:
	for passenger in passengers:
		if typeof(passenger) == TYPE_DICTIONARY and str(passenger.get("passenger_id", "")) == passenger_id:
			return passenger
	return {}


static func passenger_state(progress: Dictionary, passenger_id: String) -> Dictionary:
	var all_states: Dictionary = progress.get("passengers", {})
	if all_states.has(passenger_id) and typeof(all_states[passenger_id]) == TYPE_DICTIONARY:
		return all_states[passenger_id]
	return {
		"ride_count": 0,
		"gallery_index": 0,
		"first_boarding_seen": false
	}


static func next_event(passenger: Dictionary, progress: Dictionary) -> Dictionary:
	var passenger_id := str(passenger.get("passenger_id", ""))
	var state := passenger_state(progress, passenger_id)
	var index := int(state.get("gallery_index", 0))
	var events: Array = passenger.get("gallery_sequence", [])
	if index < 0 or index >= events.size():
		return {}
	var event = events[index]
	return event if typeof(event) == TYPE_DICTIONARY else {}


static func is_passenger_complete(passenger: Dictionary, progress: Dictionary) -> bool:
	var passenger_id := str(passenger.get("passenger_id", ""))
	var state := passenger_state(progress, passenger_id)
	var index := int(state.get("gallery_index", 0))
	var events: Array = passenger.get("gallery_sequence", [])
	return index >= events.size()


static func boarding_dialogue(passenger: Dictionary, progress: Dictionary) -> Dictionary:
	var passenger_id := str(passenger.get("passenger_id", ""))
	var state := passenger_state(progress, passenger_id)
	var first_seen := bool(state.get("first_boarding_seen", false))
	var pool: Array = passenger.get("repeat_boarding_lines", [])
	if not first_seen:
		pool = passenger.get("first_boarding_lines", pool)
	return _dialogue_from_pool("%s_boarding" % passenger_id, passenger, pool, true)


static func parking_dialogue(passenger: Dictionary) -> Dictionary:
	var dialogue := _dialogue_from_pool(
		"%s_parking" % str(passenger.get("passenger_id", "")),
		passenger,
		passenger.get("parking_lines", []),
		false
	)
	dialogue.black_overlay = true
	return dialogue


static func ending_dialogue(passenger: Dictionary, ending_type: String) -> Dictionary:
	var key := "normal_end_lines"
	if ending_type == "failed":
		key = "failed_lines"
	elif ending_type == "success":
		key = "success_lines"
	return _dialogue_from_pool(
		"%s_%s" % [str(passenger.get("passenger_id", "")), ending_type],
		passenger,
		passenger.get(key, []),
		true
	)


static func mark_boarding_seen(progress: Dictionary, passenger_id: String) -> void:
	var state := passenger_state(progress, passenger_id)
	state.first_boarding_seen = true
	state.ride_count = int(state.get("ride_count", 0)) + 1
	progress.passengers[passenger_id] = state
	progress.last_passenger_id = passenger_id


static func advance_gallery(progress: Dictionary, passenger_id: String) -> void:
	var state := passenger_state(progress, passenger_id)
	state.gallery_index = int(state.get("gallery_index", 0)) + 1
	progress.passengers[passenger_id] = state


static func reward_for_seconds(actual_sec: int, minimum_reward_sec: int, completed_passenger_bonus: bool = false) -> int:
	if actual_sec < minimum_reward_sec:
		return 0
	var reward := int(floor(float(actual_sec) / float(BASE_REWARD_SECONDS) * float(BASE_FOCUS_POINTS)))
	if completed_passenger_bonus:
		reward *= COMPLETED_PASSENGER_MULTIPLIER
	return reward


static func questions_for_round(all_questions: Array, passenger_id: String, emotion: int, used_question_ids: Array) -> Array:
	var result := []
	for question in all_questions:
		if typeof(question) != TYPE_DICTIONARY:
			continue
		var question_id := str(question.get("question_id", ""))
		if question_id == "" or used_question_ids.has(question_id):
			continue
		if str(question.get("passenger_id", "")) != passenger_id:
			continue
		var min_value := int(question.get("emotion_min", 0))
		var max_value := int(question.get("emotion_max", EMOTION_MAX))
		if emotion >= min_value and emotion <= max_value:
			result.append(question)
	if result.is_empty():
		for question in all_questions:
			if typeof(question) != TYPE_DICTIONARY:
				continue
			var question_id := str(question.get("question_id", ""))
			if question_id != "" and not used_question_ids.has(question_id) and str(question.get("passenger_id", "")) == passenger_id:
				result.append(question)
	return result


static func next_unlockable_dialogue_ids(passengers: Array, progress: Dictionary) -> Array:
	var result := []
	for passenger in passengers:
		if typeof(passenger) != TYPE_DICTIONARY:
			continue
		var event := next_event(passenger, progress)
		var dialogue_id := str(event.get("dialogue_id", ""))
		if dialogue_id != "" and not result.has(dialogue_id):
			result.append(dialogue_id)
	return result


static func unlock_costs_by_dialogue(passengers: Array, progress: Dictionary) -> Dictionary:
	var result := {}
	for passenger in passengers:
		if typeof(passenger) != TYPE_DICTIONARY:
			continue
		var passenger_id := str(passenger.get("passenger_id", ""))
		var state := passenger_state(progress, passenger_id)
		var event := next_event(passenger, progress)
		var dialogue_id := str(event.get("dialogue_id", ""))
		if dialogue_id != "":
			result[dialogue_id] = int(event.get("unlock_cost_fp", 100 + int(state.get("gallery_index", 0)) * 50))
	return result


static func passenger_id_for_dialogue(passengers: Array, dialogue_id: String) -> String:
	for passenger in passengers:
		if typeof(passenger) != TYPE_DICTIONARY:
			continue
		for event in passenger.get("gallery_sequence", []):
			if typeof(event) == TYPE_DICTIONARY and str(event.get("dialogue_id", "")) == dialogue_id:
				return str(passenger.get("passenger_id", ""))
	return ""


static func event_for_dialogue(passengers: Array, dialogue_id: String) -> Dictionary:
	for passenger in passengers:
		if typeof(passenger) != TYPE_DICTIONARY:
			continue
		for event in passenger.get("gallery_sequence", []):
			if typeof(event) == TYPE_DICTIONARY and str(event.get("dialogue_id", "")) == dialogue_id:
				return event
	return {}


static func _dialogue_from_pool(dialogue_id: String, passenger: Dictionary, pool: Array, transparent: bool) -> Dictionary:
	if pool.is_empty():
		pool = [{
			"speaker": str(passenger.get("display_name", "Passenger")),
			"speaker_key": str(passenger.get("display_name_key", "")),
			"text": "..."
		}]
	var line = pool[randi() % pool.size()]
	if typeof(line) != TYPE_DICTIONARY:
		line = {
			"speaker": str(passenger.get("display_name", "Passenger")),
			"speaker_key": str(passenger.get("display_name_key", "")),
			"text": str(line)
		}
	return {
		"dialogue_id": dialogue_id,
		"transparent_overlay": transparent,
		"lines": [line]
	}


static func _load_array_from_key(path: String, key: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var value = parsed.get(key, [])
	return value if typeof(value) == TYPE_ARRAY else []
