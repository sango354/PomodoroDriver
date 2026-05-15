#!/usr/bin/env python3
import argparse
import csv
import datetime as dt
import io
import json
import re
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = Path(__file__).with_name("text_data_config.json")

QUIZ_HEADERS = [
    "question_id",
    "passenger_id",
    "stage",
    "emotion_min",
    "emotion_max",
    "direction",
    "prompt_speaker",
    "prompt_type",
    "stem_display_target",
    "stem_text_type",
    "stem_text",
    "question_text",
    "narration_text",
    "driver_monologue",
    "scene_text",
    "description_text",
    "status_text",
    "option_a_text",
    "option_a_response",
    "option_a_emotion_delta",
    "option_a_alert_delta",
    "option_b_text",
    "option_b_response",
    "option_b_emotion_delta",
    "option_b_alert_delta",
    "option_c_text",
    "option_c_response",
    "option_c_emotion_delta",
    "option_c_alert_delta",
]

PASSENGER_HEADERS = [
    "passenger_id",
    "display_name",
    "short_label",
    "personality",
    "gallery_sequence_json",
]

STATE_HEADERS = [
    "passenger_id",
    "display_name",
    "status_type",
    "line_index",
    "speaker",
    "text",
]

H_EVENT_DEF_HEADERS = [
    "event_id",
    "dialogue_id",
    "passenger_id",
    "sequence_order",
    "type",
    "display_name",
    "display_name_key",
    "thumbnail_path",
    "background_path",
    "trigger_key",
    "default_unlocked",
    "unlock_cost_fp",
    "initial_emotion",
    "initial_alert",
    "is_active",
    "notes",
]

H_EVENT_LINE_HEADERS = [
    "dialogue_id",
    "line_index",
    "speaker",
    "speaker_key",
    "text",
    "text_key",
    "visual_mode",
    "background_path",
    "spine_scene",
    "spine_skin",
    "spine_animation",
    "transition",
    "bgm",
    "sfx",
    "wait_seconds",
    "notes",
]

STATE_TO_JSON_KEY = {
    "first_boarding": "first_boarding_lines",
    "repeat_boarding": "repeat_boarding_lines",
    "success": "success_lines",
    "failed": "failed_lines",
    "normal_end": "normal_end_lines",
}

LOCALIZATION_OUTPUT_HEADERS = [
    "key",
    "en",
    "zh_TW",
    "zh_CN",
    "ja",
    "ko",
    "fr",
    "de",
    "it",
    "ru",
    "es_ES",
    "pt_BR",
]


def main() -> int:
    args = parse_args()
    config = read_json(Path(args.config))
    if args.sheet_url:
        config["spreadsheet_id"] = spreadsheet_id_from_url(args.sheet_url)
    elif args.sheet_id:
        config["spreadsheet_id"] = args.sheet_id

    backup_dir = resolve_repo_path(config.get("backup_dir", "tools/downloads/text_data_backups"))
    outputs = config.get("outputs", {})
    passenger_defs_path = resolve_repo_path(outputs.get("passenger_defs", "game/data/passenger_defs.json"))
    passenger_quiz_path = resolve_repo_path(outputs.get("passenger_quiz_defs", "game/data/passenger_quiz_defs.json"))
    localization_path = resolve_repo_path(outputs.get("localization_texts", "game/data/localization.csv"))
    avg_dialogue_path = resolve_repo_path(outputs.get("avg_dialogue_defs", "game/data/avg_dialogue_defs.json"))

    print("Downloading Google Sheet CSV data...")
    csv_tables = download_tables(
        config,
        include_localization=not args.skip_localization,
        include_h_events=not args.skip_h_events,
    )

    print("Converting passenger definitions...")
    passenger_defs = build_passenger_defs(
        csv_tables["passenger_defs"],
        csv_tables["passenger_state_lines"],
        passenger_defs_path,
    )

    print("Converting passenger quiz questions...")
    passenger_quiz_defs = build_passenger_quiz_defs(csv_tables["passenger_quiz_defs"])

    avg_dialogue_defs = None
    if not args.skip_h_events:
        print("Converting H event dialogues...")
        avg_dialogue_defs, gallery_by_passenger = build_h_event_payloads(
            csv_tables["h_event_defs"],
            csv_tables["h_event_lines"],
        )
        apply_gallery_sequence_from_h_events(passenger_defs, gallery_by_passenger)

    localization_rows = []
    if not args.skip_localization:
        print("Converting localization texts...")
        localization_rows = build_localization_csv_rows(csv_tables["localization_texts"])
        if avg_dialogue_defs is not None:
            localization_rows = merge_h_event_localization_rows(localization_rows, avg_dialogue_defs)

    validate_payloads(
        passenger_defs,
        passenger_quiz_defs,
        localization_rows,
        require_localization=not args.skip_localization,
        avg_dialogue_defs=avg_dialogue_defs,
    )

    if args.dry_run:
        print("Dry run complete. No files were written.")
        print_summary(passenger_defs, passenger_quiz_defs, localization_rows, avg_dialogue_defs)
        return 0

    if not args.no_backup:
        paths = [passenger_defs_path, passenger_quiz_path]
        if not args.skip_h_events:
            paths.append(avg_dialogue_path)
        if not args.skip_localization:
            paths.append(localization_path)
        backup_existing(paths, backup_dir)

    write_json(passenger_defs_path, passenger_defs)
    write_json(passenger_quiz_path, passenger_quiz_defs)
    if avg_dialogue_defs is not None:
        write_json(avg_dialogue_path, avg_dialogue_defs)
    if not args.skip_localization:
        write_localization_csv(localization_path, localization_rows)

    print_summary(passenger_defs, passenger_quiz_defs, localization_rows, avg_dialogue_defs)
    print("Wrote:")
    print(f"  {passenger_defs_path}")
    print(f"  {passenger_quiz_path}")
    if avg_dialogue_defs is not None:
        print(f"  {avg_dialogue_path}")
    if not args.skip_localization:
        print(f"  {localization_path}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download standardized Google Sheet text tables and overwrite game JSON text data."
    )
    parser.add_argument("--config", default=str(DEFAULT_CONFIG), help="Path to text data config JSON.")
    parser.add_argument("--sheet-id", default="", help="Override spreadsheet id from config.")
    parser.add_argument("--sheet-url", default="", help="Override spreadsheet id by passing a Google Sheets URL.")
    parser.add_argument("--dry-run", action="store_true", help="Download and validate without writing JSON.")
    parser.add_argument("--no-backup", action="store_true", help="Overwrite JSON without creating backups.")
    parser.add_argument(
        "--skip-localization",
        action="store_true",
        help="Only import passenger JSON data and leave game/data/localization.csv unchanged.",
    )
    parser.add_argument(
        "--skip-h-events",
        action="store_true",
        help="Skip h_event_defs/h_event_lines and leave game/data/avg_dialogue_defs.json unchanged.",
    )
    return parser.parse_args()


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def spreadsheet_id_from_url(url: str) -> str:
    match = re.search(r"/spreadsheets/d/([^/]+)", url)
    if not match:
        raise ValueError("Could not find spreadsheet id in --sheet-url.")
    return match.group(1)


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_localization_csv(path: Path, rows: list) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=LOCALIZATION_OUTPUT_HEADERS, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def resolve_repo_path(value: str) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return REPO_ROOT / path


def download_tables(config: dict, include_localization: bool = True, include_h_events: bool = True) -> dict:
    spreadsheet_id = str(config.get("spreadsheet_id", "")).strip()
    if not spreadsheet_id:
        raise ValueError("Missing spreadsheet_id in config.")

    sheets = config.get("sheets", {})
    required = ["passenger_defs", "passenger_quiz_defs", "passenger_state_lines"]
    if include_h_events:
        required.extend(["h_event_defs", "h_event_lines"])
    if include_localization:
        required.append("localization_texts")
    result = {}
    for key in required:
        sheet_ref = sheets.get(key)
        if sheet_ref is None and key in ["localization_texts", "h_event_defs", "h_event_lines"]:
            sheet_ref = key
        if sheet_ref is None:
            raise ValueError(f"Missing sheets.{key} in config.")
        result[key] = download_csv(spreadsheet_id, sheet_ref)
    return result


def download_csv(spreadsheet_id: str, sheet_ref) -> list:
    label = f"gid={sheet_ref}" if is_gid(sheet_ref) else f"sheet={sheet_ref}"
    if is_gid(sheet_ref):
        url = f"https://docs.google.com/spreadsheets/d/{spreadsheet_id}/export?format=csv&gid={sheet_ref}"
    else:
        query = urllib.parse.urlencode({"tqx": "out:csv", "sheet": str(sheet_ref)})
        url = f"https://docs.google.com/spreadsheets/d/{spreadsheet_id}/gviz/tq?{query}"
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            data = response.read()
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"Failed to download {label}: HTTP {exc.code}. Check sharing permissions.") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Failed to download {label}: {exc.reason}") from exc

    text = data.decode("utf-8-sig")
    if "<html" in text[:200].lower():
        raise RuntimeError(f"{label} returned HTML, not CSV. Check that the sheet is accessible.")
    reader = csv.DictReader(io.StringIO(text))
    if not reader.fieldnames:
        raise RuntimeError(f"{label} returned CSV without a header row.")
    return list(reader)


def is_gid(value) -> bool:
    if isinstance(value, int):
        return True
    text = str(value).strip()
    return text.isdigit()


def build_passenger_defs(passenger_rows: list, state_rows: list, existing_path: Path) -> dict:
    existing_payload = read_json(existing_path) if existing_path.exists() else {"passengers": []}
    existing_by_id = {
        str(passenger.get("passenger_id", "")): passenger
        for passenger in existing_payload.get("passengers", [])
        if isinstance(passenger, dict)
    }

    passengers = []
    for row in passenger_rows:
        passenger_id = clean(row.get("passenger_id"))
        if not passenger_id:
            continue
        passenger = dict(existing_by_id.get(passenger_id, {}))
        passenger["passenger_id"] = passenger_id
        passenger["display_name"] = clean(row.get("display_name"))
        passenger["display_name_key"] = f"passenger.{passenger_id}.name"
        short_label = clean(row.get("short_label"))
        passenger["short_label"] = short_label
        if short_label:
            passenger["short_label_key"] = f"passenger.{passenger_id}.short_label"
        elif "short_label_key" in passenger:
            del passenger["short_label_key"]
        passenger["personality"] = clean(row.get("personality"))

        gallery_sequence_raw = clean(row.get("gallery_sequence_json"))
        if gallery_sequence_raw:
            try:
                gallery_sequence = json.loads(gallery_sequence_raw)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{passenger_id} has invalid gallery_sequence_json: {exc}") from exc
            if not isinstance(gallery_sequence, list):
                raise ValueError(f"{passenger_id} gallery_sequence_json must be a JSON array.")
            passenger["gallery_sequence"] = gallery_sequence

        passengers.append(passenger)

    state_lines = parse_state_lines(state_rows)
    for passenger in passengers:
        passenger_id = passenger["passenger_id"]
        for json_key in STATE_TO_JSON_KEY.values():
            passenger[json_key] = state_lines.get(passenger_id, {}).get(json_key, [])

    return {"passengers": passengers}


def parse_state_lines(rows: list) -> dict:
    grouped = {}
    for row in rows:
        passenger_id = clean(row.get("passenger_id"))
        status_type = clean(row.get("status_type"))
        text = clean(row.get("text"))
        if not passenger_id and not status_type and not text:
            continue
        if passenger_id == "" or status_type == "" or text == "":
            raise ValueError(f"Incomplete state line row: {row}")
        if status_type not in STATE_TO_JSON_KEY:
            raise ValueError(f"Unknown status_type '{status_type}' for {passenger_id}.")

        try:
            line_index = int_or_default(row.get("line_index"), 999999)
        except ValueError as exc:
            raise ValueError(f"Invalid line_index for {passenger_id}/{status_type}: {row.get('line_index')}") from exc

        speaker = clean(row.get("speaker")) or clean(row.get("display_name")) or passenger_id
        json_key = STATE_TO_JSON_KEY[status_type]
        text_key = f"passenger.{passenger_id}.{status_type}.{line_index:02d}"
        grouped.setdefault(passenger_id, {}).setdefault(json_key, []).append(
            {
                "line_index": line_index,
                "speaker": speaker,
                "speaker_key": f"passenger.{passenger_id}.name",
                "text": text,
                "text_key": text_key,
            }
        )

    for passenger_groups in grouped.values():
        for json_key, lines in passenger_groups.items():
            lines.sort(key=lambda line: line["line_index"])
            passenger_groups[json_key] = [
                {
                    "speaker": line["speaker"],
                    "speaker_key": line["speaker_key"],
                    "text": line["text"],
                    "text_key": line["text_key"],
                }
                for line in lines
            ]
    return grouped


def build_passenger_quiz_defs(rows: list) -> dict:
    questions = []
    for row in rows:
        question_id = clean(row.get("question_id"))
        if not question_id:
            continue

        question = {
            "question_id": question_id,
            "passenger_id": required(row, "passenger_id", question_id),
            "stage": int_required(row, "stage", question_id),
            "stage_title": stage_title(
                int_required(row, "stage", question_id),
                int_required(row, "emotion_min", question_id),
                int_required(row, "emotion_max", question_id),
            ),
            "emotion_min": int_required(row, "emotion_min", question_id),
            "emotion_max": int_required(row, "emotion_max", question_id),
            "direction": clean(row.get("direction")),
            "prompt_speaker": clean(row.get("prompt_speaker")),
            "prompt_type": clean(row.get("prompt_type")),
            "stem_text": clean(row.get("stem_text")),
            "stem_display_target": clean(row.get("stem_display_target")),
            "stem_text_type": clean(row.get("stem_text_type")),
            "answers": [
                parse_answer(row, "a", question_id),
                parse_answer(row, "b", question_id),
                parse_answer(row, "c", question_id),
            ],
            "question_text": clean(row.get("question_text")),
        }

        stem_key = quiz_stem_key(question)
        if question["stem_text"]:
            question["stem_text_key"] = stem_key
        if question["question_text"]:
            question["question_text_key"] = stem_key

        for key in ["narration_text", "driver_monologue", "scene_text", "description_text", "status_text"]:
            value = clean(row.get(key))
            if value:
                question[key] = value
                question[f"{key}_key"] = stem_key

        questions.append(question)

    return {"schema_version": 2, "questions": questions}


def build_localization_csv_rows(rows: list) -> list:
    result = []
    seen = set()
    for row in rows:
        key = clean(row.get("key"))
        if not key:
            continue
        if key in seen:
            raise ValueError(f"Duplicate localization key: {key}")
        seen.add(key)
        result.append({
            header: clean(row.get(header))
            for header in LOCALIZATION_OUTPUT_HEADERS
        })
    return result


def build_h_event_payloads(def_rows: list, line_rows: list) -> tuple:
    dialogue_to_passenger = {}
    for row in def_rows:
        dialogue_id = clean(row.get("dialogue_id"))
        passenger_id = clean(row.get("passenger_id"))
        if dialogue_id and passenger_id:
            dialogue_to_passenger[dialogue_id] = passenger_id

    lines_by_dialogue = parse_h_event_lines(line_rows, dialogue_to_passenger)
    dialogues = []
    gallery_by_passenger = {}
    seen = set()
    for row in def_rows:
        dialogue_id = clean(row.get("dialogue_id"))
        if not dialogue_id:
            continue
        if dialogue_id in seen:
            raise ValueError(f"Duplicate H event dialogue_id: {dialogue_id}")
        seen.add(dialogue_id)

        display_name = clean(row.get("display_name"))
        display_name_key = clean(row.get("display_name_key")) or f"avg.{dialogue_id}.name"
        dialogue = {
            "dialogue_id": dialogue_id,
            "type": clean(row.get("type")) or "main",
            "display_name": display_name,
            "display_name_key": display_name_key,
            "thumbnail_path": clean(row.get("thumbnail_path")),
            "background_path": clean(row.get("background_path")),
            "trigger_key": clean(row.get("trigger_key")),
            "default_unlocked": bool_value(row.get("default_unlocked"), False),
            "lines": lines_by_dialogue.get(dialogue_id, []),
        }
        dialogues.append(dialogue)

        passenger_id = clean(row.get("passenger_id"))
        if passenger_id and bool_value(row.get("is_active"), True):
            sequence_order = int_or_default(row.get("sequence_order"), 999999)
            gallery_by_passenger.setdefault(passenger_id, []).append(
                {
                    "_sequence_order": sequence_order,
                    "event_id": clean(row.get("event_id")) or f"{passenger_id}_{dialogue_id}",
                    "dialogue_id": dialogue_id,
                    "unlock_cost_fp": int_or_default(row.get("unlock_cost_fp"), 100),
                    "initial_emotion": int_or_default(row.get("initial_emotion"), 20),
                    "initial_alert": int_or_default(row.get("initial_alert"), 0),
                }
            )

    for passenger_id, events in gallery_by_passenger.items():
        events.sort(key=lambda event: (event["_sequence_order"], event["dialogue_id"]))
        gallery_by_passenger[passenger_id] = [
            {
                key: value
                for key, value in event.items()
                if key != "_sequence_order"
            }
            for event in events
        ]

    return {"dialogues": dialogues}, gallery_by_passenger


def parse_h_event_lines(rows: list, dialogue_to_passenger: dict) -> dict:
    grouped = {}
    for row in rows:
        dialogue_id = clean(row.get("dialogue_id"))
        text = clean(row.get("text"))
        if not dialogue_id and not text:
            continue
        if dialogue_id == "" or text == "":
            raise ValueError(f"Incomplete H event line row: {row}")

        line_index = int_or_default(row.get("line_index"), 999999)
        speaker = clean(row.get("speaker"))
        speaker_key = clean(row.get("speaker_key"))
        if speaker_key == "":
            speaker_key = infer_h_event_speaker_key(speaker, dialogue_to_passenger.get(dialogue_id, ""))

        line = {
            "line_index": line_index,
            "speaker": speaker,
            "speaker_key": speaker_key,
            "text": text,
            "text_key": clean(row.get("text_key")) or f"avg.{dialogue_id}.line_{line_index:03d}",
        }
        for key in [
            "visual_mode",
            "background_path",
            "spine_scene",
            "spine_skin",
            "spine_animation",
            "transition",
            "bgm",
            "sfx",
        ]:
            value = clean(row.get(key))
            if value != "":
                line[key] = value

        wait_seconds = clean(row.get("wait_seconds"))
        if wait_seconds != "":
            line["wait_seconds"] = float(wait_seconds)

        grouped.setdefault(dialogue_id, []).append(line)

    for dialogue_id, lines in grouped.items():
        lines.sort(key=lambda line: line["line_index"])
        grouped[dialogue_id] = [
            {
                key: value
                for key, value in line.items()
                if key != "line_index"
            }
            for line in lines
        ]
    return grouped


def infer_h_event_speaker_key(speaker: str, passenger_id: str) -> str:
    driver_speaker = "\u591c\u73ed\u53f8\u6a5f"
    passenger_speaker = "\u4e58\u5ba2"
    if speaker == driver_speaker:
        return "avg.speaker.driver"
    if speaker == passenger_speaker and passenger_id:
        return f"passenger.{passenger_id}.name"
    return ""


def apply_gallery_sequence_from_h_events(passenger_defs: dict, gallery_by_passenger: dict) -> None:
    for passenger in passenger_defs.get("passengers", []):
        passenger_id = clean(passenger.get("passenger_id"))
        if passenger_id in gallery_by_passenger:
            passenger["gallery_sequence"] = gallery_by_passenger[passenger_id]


def merge_h_event_localization_rows(localization_rows: list, avg_dialogue_defs: dict) -> list:
    rows = list(localization_rows)
    existing = {clean(row.get("key")) for row in rows}
    for dialogue in avg_dialogue_defs.get("dialogues", []):
        display_name_key = clean(dialogue.get("display_name_key"))
        display_name = clean(dialogue.get("display_name"))
        if display_name_key and display_name_key not in existing:
            rows.append(new_localization_row(display_name_key, display_name))
            existing.add(display_name_key)
        for line in dialogue.get("lines", []):
            speaker_key = clean(line.get("speaker_key"))
            speaker = clean(line.get("speaker"))
            if speaker_key and speaker_key not in existing:
                rows.append(new_localization_row(speaker_key, speaker))
                existing.add(speaker_key)
            text_key = clean(line.get("text_key"))
            text = clean(line.get("text"))
            if text_key and text_key not in existing:
                rows.append(new_localization_row(text_key, text))
                existing.add(text_key)
    return rows


def new_localization_row(key: str, text: str) -> dict:
    row = {header: "" for header in LOCALIZATION_OUTPUT_HEADERS}
    row["key"] = key
    row["en"] = text
    row["zh_TW"] = text
    return row


def parse_answer(row: dict, option_key: str, question_id: str) -> dict:
    upper_key = option_key.upper()
    option_prefix = quiz_answer_key_prefix(row, question_id, option_key)
    return {
        "key": upper_key,
        "text": required(row, f"option_{option_key}_text", question_id),
        "text_key": f"{option_prefix}.text",
        "response_text": required(row, f"option_{option_key}_response", question_id),
        "response_text_key": f"{option_prefix}.response",
        "emotion_delta": int_required(row, f"option_{option_key}_emotion_delta", question_id),
        "alert_delta": int_required(row, f"option_{option_key}_alert_delta", question_id),
    }


def quiz_stem_key(question: dict) -> str:
    question_id = clean(question.get("question_id"))
    passenger_id = clean(question.get("passenger_id"))
    stage = int(question.get("stage", 0))
    return f"quiz.{passenger_id}.{stage_code(stage)}.{quiz_question_code(question_id)}.stem"


def quiz_answer_key_prefix(row: dict, question_id: str, option_key: str) -> str:
    passenger_id = required(row, "passenger_id", question_id)
    stage = int_required(row, "stage", question_id)
    return f"quiz.{passenger_id}.{stage_code(stage)}.{quiz_question_code(question_id)}.option_{option_key}"


def quiz_question_code(question_id: str) -> str:
    match = re.search(r"_(q\d+)$", question_id)
    return match.group(1) if match else question_id


def stage_code(stage: int) -> str:
    if stage == 1:
        return "low"
    if stage == 2:
        return "mid"
    if stage == 3:
        return "high"
    return f"stage{stage}"


def validate_payloads(
    passenger_defs: dict,
    quiz_defs: dict,
    localization_rows: list,
    require_localization: bool = True,
    avg_dialogue_defs: dict = None,
) -> None:
    passengers = passenger_defs.get("passengers", [])
    if not passengers:
        raise ValueError("No passengers generated.")

    passenger_ids = {passenger.get("passenger_id") for passenger in passengers}
    if "" in passenger_ids:
        raise ValueError("A passenger has an empty passenger_id.")

    for passenger in passengers:
        passenger_id = passenger["passenger_id"]
        if not passenger.get("display_name"):
            raise ValueError(f"{passenger_id} has empty display_name.")
        for key in STATE_TO_JSON_KEY.values():
            if key not in passenger:
                raise ValueError(f"{passenger_id} missing {key}.")

    questions = quiz_defs.get("questions", [])
    if not questions:
        raise ValueError("No quiz questions generated.")

    seen = set()
    for question in questions:
        question_id = question["question_id"]
        if question_id in seen:
            raise ValueError(f"Duplicate question_id: {question_id}")
        seen.add(question_id)
        if question["passenger_id"] not in passenger_ids:
            raise ValueError(f"{question_id} uses unknown passenger_id {question['passenger_id']}.")
        if len(question.get("answers", [])) != 3:
            raise ValueError(f"{question_id} must have exactly 3 answers.")

    if avg_dialogue_defs is not None:
        dialogues = avg_dialogue_defs.get("dialogues", [])
        if not dialogues:
            raise ValueError("No H event dialogues generated.")
        seen_dialogues = set()
        gallery_dialogue_ids = set()
        for passenger in passengers:
            for event in passenger.get("gallery_sequence", []):
                gallery_dialogue_ids.add(clean(event.get("dialogue_id")))
        for dialogue in dialogues:
            dialogue_id = clean(dialogue.get("dialogue_id"))
            if dialogue_id == "":
                raise ValueError("An H event dialogue has an empty dialogue_id.")
            if dialogue_id in seen_dialogues:
                raise ValueError(f"Duplicate H event dialogue_id: {dialogue_id}")
            seen_dialogues.add(dialogue_id)
            if clean(dialogue.get("display_name_key")) == "":
                raise ValueError(f"{dialogue_id} missing display_name_key.")
            if not dialogue.get("lines", []):
                raise ValueError(f"{dialogue_id} has no dialogue lines.")
            for line in dialogue.get("lines", []):
                if clean(line.get("text_key")) == "" or clean(line.get("text")) == "":
                    raise ValueError(f"{dialogue_id} has a line without text/text_key.")
        missing_dialogues = gallery_dialogue_ids - seen_dialogues - {""}
        if missing_dialogues:
            raise ValueError(f"gallery_sequence references missing H event dialogues: {sorted(missing_dialogues)}")

    if require_localization:
        if not localization_rows:
            raise ValueError("No localization rows generated.")
        for row in localization_rows:
            key = clean(row.get("key"))
            if not key:
                raise ValueError("A localization row has an empty key.")
            if clean(row.get("en")) == "" and clean(row.get("zh_TW")) == "":
                raise ValueError(f"{key} has neither en nor zh_TW text.")


def backup_existing(paths: list, backup_dir: Path) -> None:
    timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir.mkdir(parents=True, exist_ok=True)
    for path in paths:
        if path.exists():
            backup_path = backup_dir / f"{path.name}.{timestamp}.bak"
            shutil.copy2(path, backup_path)
            print(f"Backup: {backup_path}")


def print_summary(
    passenger_defs: dict,
    quiz_defs: dict,
    localization_rows: list = None,
    avg_dialogue_defs: dict = None,
) -> None:
    passengers = passenger_defs["passengers"]
    questions = quiz_defs["questions"]
    localization_rows = localization_rows or []
    avg_dialogue_defs = avg_dialogue_defs or {}
    dialogues = avg_dialogue_defs.get("dialogues", [])
    print("Summary:")
    print(f"  passengers: {len(passengers)}")
    print(f"  quiz questions: {len(questions)}")
    print(f"  quiz answers: {sum(len(question.get('answers', [])) for question in questions)}")
    if dialogues:
        print(f"  H event dialogues: {len(dialogues)}")
        print(f"  H event lines: {sum(len(dialogue.get('lines', [])) for dialogue in dialogues)}")
    if localization_rows:
        print(f"  localization keys: {len(localization_rows)}")
    for passenger in passengers:
        passenger_id = passenger["passenger_id"]
        count = sum(1 for question in questions if question.get("passenger_id") == passenger_id)
        state_counts = {
            key: len(passenger.get(key, []))
            for key in STATE_TO_JSON_KEY.values()
        }
        gallery_count = len(passenger.get("gallery_sequence", []))
        print(f"  {passenger_id}: {count} questions, H events={gallery_count}, states={state_counts}")


def stage_title(stage: int, emotion_min: int, emotion_max: int) -> str:
    labels = {1: "第一階段", 2: "第二階段", 3: "第三階段"}
    label = labels.get(stage, f"第{stage}階段")
    return f"{label}：情緒 {emotion_min}～{emotion_max}"


def required(row: dict, key: str, context: str) -> str:
    value = clean(row.get(key))
    if value == "":
        raise ValueError(f"{context} missing required field '{key}'.")
    return value


def int_required(row: dict, key: str, context: str) -> int:
    value = required(row, key, context)
    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"{context} field '{key}' must be an integer, got '{value}'.") from exc


def int_or_default(value, default: int) -> int:
    value = clean(value)
    if value == "":
        return default
    return int(value)


def bool_value(value, default: bool = False) -> bool:
    value = clean(value).lower()
    if value == "":
        return default
    if value in ["true", "1", "yes", "y", "on", "是", "啟用"]:
        return True
    if value in ["false", "0", "no", "n", "off", "否", "停用"]:
        return False
    raise ValueError(f"Expected boolean value, got '{value}'.")


def clean(value) -> str:
    if value is None:
        return ""
    return str(value).strip()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
