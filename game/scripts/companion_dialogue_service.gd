extends RefCounted

const DIALOGUE_PATH := "res://data/dialogue_defs.json"
const FALLBACK_DIALOGUE := {
	"dialogue_id": "break_fallback",
	"text_key": "dialogue.break_fallback",
	"text": "Take a short stop. I will keep the cab ready for the next fare.",
	"bond_requirement": 0,
	"context_requirement": "any",
	"cooldown_minutes": 0,
	"weight": 1,
	"is_active": true
}
const FALLBACK_AMBIENT_DIALOGUE := {
	"dialogue_id": "ambient_fallback",
	"text_key": "dialogue.ambient_fallback",
	"text": "I am at the wheel. Keep the ride smooth.",
	"bond_requirement": 0,
	"context_requirement": "any",
	"cooldown_minutes": 8,
	"weight": 1,
	"is_active": true
}


static func load_break_dialogues() -> Array:
	return _load_dialogues("break_interaction", FALLBACK_DIALOGUE)


static func load_ambient_dialogues() -> Array:
	return _load_dialogues("ambient", FALLBACK_AMBIENT_DIALOGUE)


static func _load_dialogues(section: String, fallback: Dictionary) -> Array:
	var parsed := _load_dialogue_payload()
	if parsed.has(section) and typeof(parsed[section]) == TYPE_ARRAY:
		return parsed[section]
	return [fallback]


static func filtered_break_dialogues(bond_level: int, context: Dictionary, interaction_history: Array = []) -> Array:
	return _filtered_dialogues(
		load_break_dialogues(),
		bond_level,
		context,
		interaction_history,
		"break_interaction_viewed",
		FALLBACK_DIALOGUE
	)


static func filtered_ambient_dialogues(bond_level: int, context: Dictionary, interaction_history: Array = []) -> Array:
	return _filtered_dialogues(
		load_ambient_dialogues(),
		bond_level,
		context,
		interaction_history,
		"ambient_prompt_shown",
		FALLBACK_AMBIENT_DIALOGUE
	)


static func _filtered_dialogues(dialogues: Array, bond_level: int, context: Dictionary, interaction_history: Array, viewed_event_type: String, fallback: Dictionary) -> Array:
	var eligible := []
	var cooldown_blocked := []
	for dialogue in dialogues:
		if typeof(dialogue) != TYPE_DICTIONARY:
			continue
		if not bool(dialogue.get("is_active", true)):
			continue
		if int(dialogue.get("bond_requirement", 0)) > bond_level:
			continue
		if not _context_matches(dialogue.get("context_requirement", "any"), context):
			continue
		if _is_on_cooldown(dialogue, interaction_history, viewed_event_type):
			cooldown_blocked.append(dialogue)
			continue
		eligible.append(dialogue)
	if eligible.is_empty() and not cooldown_blocked.is_empty():
		return cooldown_blocked
	if eligible.is_empty():
		eligible.append(fallback)
	return eligible


static func break_dialogue(index: int, bond_level: int, context: Dictionary, interaction_history: Array = [], excluded_dialogue_id: String = "") -> Dictionary:
	var dialogues := _weighted_dialogues(filtered_break_dialogues(bond_level, context, interaction_history))
	return _select_dialogue(dialogues, index, excluded_dialogue_id, FALLBACK_DIALOGUE)


static func ambient_dialogue(index: int, bond_level: int, context: Dictionary, interaction_history: Array = [], excluded_dialogue_id: String = "") -> Dictionary:
	var dialogues := _weighted_dialogues(filtered_ambient_dialogues(bond_level, context, interaction_history))
	return _select_dialogue(dialogues, index, excluded_dialogue_id, FALLBACK_AMBIENT_DIALOGUE)


static func _select_dialogue(dialogues: Array, index: int, excluded_dialogue_id: String, fallback: Dictionary) -> Dictionary:
	if dialogues.is_empty():
		return fallback
	var selected = dialogues[index % dialogues.size()]
	if excluded_dialogue_id == "":
		return selected
	for offset in range(dialogues.size()):
		var candidate = dialogues[(index + offset) % dialogues.size()]
		if str(candidate.get("dialogue_id", "")) != excluded_dialogue_id:
			return candidate
	return selected


static func _weighted_dialogues(dialogues: Array) -> Array:
	var weighted := []
	for dialogue in dialogues:
		var weight: int = max(int(dialogue.get("weight", 1)), 1)
		for _i in range(weight):
			weighted.append(dialogue)
	return weighted


static func _context_matches(requirement, context: Dictionary) -> bool:
	if requirement == null:
		return true
	if typeof(requirement) == TYPE_STRING:
		var text := str(requirement)
		if text == "" or text == "any":
			return true
		return _context_value_matches(text, context)
	if typeof(requirement) != TYPE_DICTIONARY:
		return true
	for key in requirement.keys():
		var expected = requirement[key]
		if str(expected) == "any":
			continue
		if not context.has(key):
			return false
		if str(context[key]) != str(expected):
			return false
	return true


static func _context_value_matches(value: String, context: Dictionary) -> bool:
	for key in context.keys():
		if str(context[key]) == value:
			return true
	return false


static func _is_on_cooldown(dialogue: Dictionary, interaction_history: Array, viewed_event_type: String) -> bool:
	var cooldown_minutes := int(dialogue.get("cooldown_minutes", 0))
	if cooldown_minutes <= 0:
		return false
	var dialogue_id := str(dialogue.get("dialogue_id", ""))
	if dialogue_id == "":
		return false
	var last_seen := _last_viewed_at(dialogue_id, interaction_history, viewed_event_type)
	if last_seen <= 0:
		return false
	var now := Time.get_unix_time_from_system()
	return now - last_seen < cooldown_minutes * 60


static func _last_viewed_at(dialogue_id: String, interaction_history: Array, viewed_event_type: String) -> int:
	for i in range(interaction_history.size() - 1, -1, -1):
		var event = interaction_history[i]
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("dialogue_id", "")) != dialogue_id:
			continue
		if str(event.get("event_type", "")) != viewed_event_type:
			continue
		return _unix_time_from_history_event(event)
	return 0


static func _unix_time_from_history_event(event: Dictionary) -> int:
	var created_at := str(event.get("created_at", ""))
	if created_at == "":
		return 0
	var unix_time := Time.get_unix_time_from_datetime_string(created_at)
	if unix_time > 0:
		return unix_time
	return Time.get_unix_time_from_datetime_string(created_at.replace(" ", "T"))


static func _load_dialogue_payload() -> Dictionary:
	if not FileAccess.file_exists(DIALOGUE_PATH):
		return {}
	var file := FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
