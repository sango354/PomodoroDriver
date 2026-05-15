# Runtime Text Data Schema

This document records the current Google Sheet to runtime data contract for
passenger, quiz, state-line, localization, and H/AVG event text.

## Source Sheets

| Sheet | Purpose |
| --- | --- |
| `passenger_defs` | Passenger identity, labels, notes, and existing metadata. |
| `passenger_quiz_defs` | Quiz stems, choices, responses, and Emotion/Alert deltas. |
| `passenger_state_lines` | Boarding and ending passenger state lines. |
| `h_event_defs` | H/AVG event metadata and passenger gallery sequencing. |
| `h_event_lines` | H/AVG dialogue lines and per-line visual/audio instructions. |
| `localization_texts` | Formal multilingual text source. |

## Generated Runtime Files

| Runtime File | Generated From |
| --- | --- |
| `game/data/passenger_defs.json` | `passenger_defs`, `passenger_state_lines`, `h_event_defs` |
| `game/data/passenger_quiz_defs.json` | `passenger_quiz_defs` |
| `game/data/avg_dialogue_defs.json` | `h_event_defs`, `h_event_lines` |
| `game/data/localization.csv` | `localization_texts` plus imported H/AVG keys |

`localization_texts` is authoritative for display text. Generated JSON keeps
source Traditional Chinese as fallback. Runtime looks up localization keys
first and uses fallback fields only when a key is missing or unresolved.

## Import Tools

- `tools/google_apps_script_h_events.gs`: paste into Google Apps Script and run
  `setupHEventTextTables()` to create/update `h_event_defs` and
  `h_event_lines`.
- `tools/download-text-data.cmd`: downloads configured sheet tabs and overwrites
  generated runtime text files.
- `tools/import_google_sheet_text.py`: converter used by the command file.
- `tools/text_data_config.json`: spreadsheet id, tab names/gids, output paths,
  and backup directory.

## `h_event_defs`

| Field | Type | Notes |
| --- | --- | --- |
| `event_id` | string | Gallery event id. |
| `dialogue_id` | string | Links to `avg_dialogue_defs.dialogues[].dialogue_id`. |
| `passenger_id` | string optional | Assigns the event to a passenger gallery. |
| `sequence_order` | int optional | Passenger gallery order. |
| `type` | string | Usually `main`. |
| `display_name` | string | Fallback/source event name. |
| `display_name_key` | string | Localization key. |
| `thumbnail_path` | string | Gallery thumbnail path. |
| `background_path` | string | Default CG/BG path. |
| `trigger_key` | string optional | Future trigger binding. |
| `default_unlocked` | bool | Whether the dialogue starts viewed/unlocked. |
| `unlock_cost_fp` | int optional | Direct gallery unlock Focus Point cost. |
| `initial_emotion` | int optional | Quiz/event start metadata. |
| `initial_alert` | int optional | Quiz/event start metadata. |
| `is_active` | bool | Active rows with `passenger_id` generate gallery sequence entries. |
| `notes` | string optional | Sheet-only notes. |

Rows with `passenger_id` and `is_active=TRUE` are written into that passenger's
`gallery_sequence`. Rows without `passenger_id` stay in
`avg_dialogue_defs.json` but are not assigned to a passenger gallery.

## `h_event_lines`

| Field | Type | Notes |
| --- | --- | --- |
| `dialogue_id` | string | Parent H/AVG dialogue id. |
| `line_index` | int | Playback order. |
| `speaker` | string | Fallback/source speaker name. |
| `speaker_key` | string | Localization key for speaker. |
| `text` | string | Fallback/source line text. |
| `text_key` | string | Localization key for line text. |
| `visual_mode` | enum | `keep`, `bg`, `spine`, `bg_spine`, `clear_spine`, `black`. |
| `background_path` | string optional | Per-line BG/CG path. |
| `spine_scene` | string optional | Packed scene or Spine skeleton path. |
| `spine_skin` | string optional | Spine skin name. |
| `spine_animation` | string optional | Spine animation name. |
| `transition` | string optional | Reserved for future transition control. |
| `bgm` | string optional | Reserved for per-line music. |
| `sfx` | string optional | Reserved for per-line sound effect. |
| `wait_seconds` | float optional | Reserved for timed line behavior. |
| `notes` | string optional | Sheet-only notes. |

## AVG Visual Modes

- `keep`: keep the current AVG visual state.
- `bg`: switch or show a CG/background image.
- `spine`: show or update the embedded Spine node without changing BG.
- `bg_spine`: switch BG and show/update embedded Spine together.
- `clear_spine`: remove the embedded Spine node.
- `black`: show black overlay and clear active visual content.

## H/AVG Completion Rule

When the H/AVG queue ends, the game must:

- hide the AVG overlay;
- clear active CG/BG texture;
- stop pending BG transition tweens;
- clear embedded Spine;
- restore H-event music state;
- return to the driving main UI before continuing passenger flow.
