extends RefCounted

const TABLE_PATH := "res://data/localization.csv"
const MANIFEST_PATH := "res://data/localization_manifest.json"
const DEFAULT_LANGUAGE := "en"
const LANGUAGE_CODES := ["en", "zh_TW", "zh_CN", "ja", "ko", "fr", "de", "it", "ru", "es_ES", "pt_BR"]

var current_language := DEFAULT_LANGUAGE
var _rows := {}
var _column_index := {}
var _manifest_rows := {}


func _init(language_code: String = DEFAULT_LANGUAGE) -> void:
	load_table()
	set_language(language_code)


func load_table() -> void:
	_rows.clear()
	_column_index.clear()
	_manifest_rows.clear()
	_load_manifest()
	var file := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if file == null:
		return
	if file.eof_reached():
		return
	var header := file.get_csv_line()
	for i in range(header.size()):
		_column_index[str(header[i])] = i
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty() or str(row[0]) == "":
			continue
		_rows[str(row[0])] = row


func _load_manifest() -> bool:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var rows = parsed.get("rows", {})
	if typeof(rows) != TYPE_DICTIONARY:
		return false
	_manifest_rows = rows
	return not _manifest_rows.is_empty()


func set_language(language_code: String) -> void:
	current_language = language_code if LANGUAGE_CODES.has(language_code) else DEFAULT_LANGUAGE


func next_language() -> String:
	var index := LANGUAGE_CODES.find(current_language)
	if index < 0:
		index = 0
	set_language(LANGUAGE_CODES[(index + 1) % LANGUAGE_CODES.size()])
	return current_language


func previous_language() -> String:
	var index := LANGUAGE_CODES.find(current_language)
	if index < 0:
		index = 0
	set_language(LANGUAGE_CODES[(index - 1 + LANGUAGE_CODES.size()) % LANGUAGE_CODES.size()])
	return current_language


func language_name(language_code: String = "") -> String:
	var code := current_language if language_code == "" else language_code
	return translate("language.%s" % code)


func translate(key: String) -> String:
	if _rows.has(key):
		var row: PackedStringArray = _rows[key]
		var lang_index := int(_column_index.get(current_language, -1))
		var fallback_index := int(_column_index.get(DEFAULT_LANGUAGE, -1))
		if lang_index >= 0 and lang_index < row.size() and str(row[lang_index]) != "":
			return str(row[lang_index])
		if fallback_index >= 0 and fallback_index < row.size() and str(row[fallback_index]) != "":
			return str(row[fallback_index])
	if _manifest_rows.has(key):
		var entry = _manifest_rows[key]
		if typeof(entry) == TYPE_DICTIONARY:
			var translated := str(entry.get(current_language, ""))
			if translated != "":
				return translated
			var fallback := str(entry.get(DEFAULT_LANGUAGE, ""))
			if fallback != "":
				return fallback
	return key


func trf(key: String, values: Dictionary) -> String:
	var text := translate(key)
	for value_key in values.keys():
		text = text.replace("{%s}" % str(value_key), str(values[value_key]))
	return text
