# Text Data Import

Use `download-text-data.cmd` to download the standardized Google Sheet tabs and overwrite the game text data.

## Managed Google Sheet Tabs

- `passenger_defs`
- `passenger_quiz_defs`
- `passenger_state_lines`
- `localization_texts`
- `h_event_defs`
- `h_event_lines`

The tab gids or names are stored in `tools/text_data_config.json`.

## First-Time Setup

Open `tools/text_data_config.json` and confirm:

- `spreadsheet_id` is the id of the Google Sheet that contains the standardized tabs.
- `sheets.passenger_defs` matches the `passenger_defs` gid.
- `sheets.passenger_quiz_defs` matches the `passenger_quiz_defs` gid.
- `sheets.passenger_state_lines` matches the `passenger_state_lines` gid.
- `sheets.localization_texts` can stay as `"localization_texts"`; the importer can download this tab by sheet name.
- `sheets.h_event_defs` can stay as `"h_event_defs"`.
- `sheets.h_event_lines` can stay as `"h_event_lines"`.

If the Google Sheet is private, set sharing so anyone with the link can view it, or the local downloader will receive an HTML/login page instead of CSV.

## Normal Import

Double-click:

```bat
tools\download-text-data.cmd
```

The tool writes:

- `game/data/passenger_defs.json`
- `game/data/passenger_quiz_defs.json`
- `game/data/avg_dialogue_defs.json`
- `game/data/localization.csv`

Passenger JSON and quiz JSON keep the original Chinese text as fallback, and also include localization keys:

- Passenger names: `display_name_key`, `short_label_key`
- Passenger state lines: `speaker_key`, `text_key`
- Quiz stems: `question_text_key`, `narration_text_key`, `driver_monologue_key`, `scene_text_key`, `description_text_key`, or `status_text_key`
- Quiz answers: `text_key`, `response_text_key`
- H event names and lines: `display_name_key`, `speaker_key`, `text_key`

At runtime the game reads the localization key first. If that key is missing or resolves to the key itself, the original JSON text is used as fallback.

`h_event_defs` controls the gallery sequence for each passenger. Rows with a `passenger_id` and `is_active=TRUE` are written back into that passenger's `gallery_sequence`; rows without a passenger remain in `avg_dialogue_defs.json` but are not shown in a passenger gallery.

`h_event_lines` controls the AVG text and visuals. Use `visual_mode=bg` to switch background, `visual_mode=spine` to show/change an embedded Spine, `visual_mode=bg_spine` to switch both, `visual_mode=clear_spine` to remove the embedded Spine, and `visual_mode=keep` to keep the previous visual state.

Existing JSON files are backed up under:

```text
tools/downloads/text_data_backups
```

## Import With a Sheet URL

If `spreadsheet_id` in the config is not current, run:

```bat
tools\download-text-data.cmd --sheet-url "https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID/edit"
```

## Validate Without Writing

```bat
tools\download-text-data.cmd --dry-run
```

## Import Passenger Data Only

If `localization_texts` has not been created yet, or you only want to update passenger JSON:

```bat
tools\download-text-data.cmd --skip-localization
```

## Skip H Events

If `h_event_defs` and `h_event_lines` have not been created yet:

```bat
tools\download-text-data.cmd --skip-h-events
```
