extends RefCounted

const AVG_DIALOGUE_PATH := "res://data/avg_dialogue_defs.json"
const VIEWED_EVENT_TYPE := "avg_dialogue_viewed"


static func load_dialogues() -> Array:
	var file := FileAccess.open(AVG_DIALOGUE_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var dialogues = parsed.get("dialogues", [])
	if typeof(dialogues) != TYPE_ARRAY:
		return []
	return dialogues


static func dialogues_by_type(dialogue_type: String) -> Array:
	var result := []
	for dialogue in load_dialogues():
		if typeof(dialogue) != TYPE_DICTIONARY:
			continue
		if str(dialogue.get("type", "")) == dialogue_type:
			result.append(dialogue)
	return result


static func find_dialogue(dialogue_id: String) -> Dictionary:
	for dialogue in load_dialogues():
		if typeof(dialogue) == TYPE_DICTIONARY and str(dialogue.get("dialogue_id", "")) == dialogue_id:
			return dialogue
	return {}


static func dialogues_for_trigger(trigger_key: String) -> Array:
	var result := []
	for dialogue in load_dialogues():
		if typeof(dialogue) != TYPE_DICTIONARY:
			continue
		if str(dialogue.get("trigger_key", "")) == trigger_key:
			result.append(dialogue)
	return result


static func viewed_dialogue_ids(interaction_history: Array) -> Array:
	var viewed := []
	for event in interaction_history:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("event_type", "")) != VIEWED_EVENT_TYPE:
			continue
		var dialogue_id := str(event.get("dialogue_id", ""))
		if dialogue_id != "" and not viewed.has(dialogue_id):
			viewed.append(dialogue_id)
	return viewed


static func is_viewed(dialogue_id: String, interaction_history: Array) -> bool:
	return viewed_dialogue_ids(interaction_history).has(dialogue_id)
