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

    print("Downloading Google Sheet CSV data...")
    csv_tables = download_tables(config, include_localization=not args.skip_localization)

    print("Converting passenger definitions...")
    passenger_defs = build_passenger_defs(
        csv_tables["passenger_defs"],
        csv_tables["passenger_state_lines"],
        passenger_defs_path,
    )

    print("Converting passenger quiz questions...")
    passenger_quiz_defs = build_passenger_quiz_defs(csv_tables["passenger_quiz_defs"])

    localization_rows = []
    if not args.skip_localization:
        print("Converting localization texts...")
        localization_rows = build_localization_csv_rows(csv_tables["localization_texts"])

    validate_payloads(passenger_defs, passenger_quiz_defs, localization_rows, require_localization=not args.skip_localization)

    if args.dry_run:
        print("Dry run complete. No files were written.")
        print_summary(passenger_defs, passenger_quiz_defs, localization_rows)
        return 0

    if not args.no_backup:
        paths = [passenger_defs_path, passenger_quiz_path]
        if not args.skip_localization:
            paths.append(localization_path)
        backup_existing(paths, backup_dir)

    write_json(passenger_defs_path, passenger_defs)
    write_json(passenger_quiz_path, passenger_quiz_defs)
    if not args.skip_localization:
        write_localization_csv(localization_path, localization_rows)

    print_summary(passenger_defs, passenger_quiz_defs, localization_rows)
    print("Wrote:")
    print(f"  {passenger_defs_path}")
    print(f"  {passenger_quiz_path}")
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


def download_tables(config: dict, include_localization: bool = True) -> dict:
    spreadsheet_id = str(config.get("spreadsheet_id", "")).strip()
    if not spreadsheet_id:
        raise ValueError("Missing spreadsheet_id in config.")

    sheets = config.get("sheets", {})
    required = ["passenger_defs", "passenger_quiz_defs", "passenger_state_lines"]
    if include_localization:
        required.append("localization_texts")
    result = {}
    for key in required:
        sheet_ref = sheets.get(key)
        if key == "localization_texts" and sheet_ref is None:
            sheet_ref = "localization_texts"
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


def print_summary(passenger_defs: dict, quiz_defs: dict, localization_rows: list = None) -> None:
    passengers = passenger_defs["passengers"]
    questions = quiz_defs["questions"]
    localization_rows = localization_rows or []
    print("Summary:")
    print(f"  passengers: {len(passengers)}")
    print(f"  quiz questions: {len(questions)}")
    print(f"  quiz answers: {sum(len(question.get('answers', [])) for question in questions)}")
    if localization_rows:
        print(f"  localization keys: {len(localization_rows)}")
    for passenger in passengers:
        passenger_id = passenger["passenger_id"]
        count = sum(1 for question in questions if question.get("passenger_id") == passenger_id)
        state_counts = {
            key: len(passenger.get(key, []))
            for key in STATE_TO_JSON_KEY.values()
        }
        print(f"  {passenger_id}: {count} questions, states={state_counts}")


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
