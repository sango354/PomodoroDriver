# System 07: Localization and Options

Last updated: 2026-05-13

This document records the current localization and options-menu implementation
for handoff between machines.

## Scope

The game supports a lightweight scripted localization layer for UI text,
break companion dialogue, ambient companion prompts, and AVG-related prototype
copy. The Options panel is implemented in the top-right HUD.

Options also includes a Break media switch and an Ambient Prompt frequency
cycle. When Break media is enabled, the Break countdown may play a configured
local video file as companion/rest media. When disabled or unsupported, Break
uses the current text-only companion panel.

## Localization Table

Runtime table:

```text
game/data/localization.csv
```

Current columns:

```text
key,en,zh_TW,zh_CN,ja,ko,fr,de,it,ru,es_ES,pt_BR
```

Language meaning:

- `en`: English
- `zh_TW`: Traditional Chinese
- `zh_CN`: Simplified Chinese
- `ja`: Japanese
- `ko`: Korean
- `fr`: French
- `de`: German
- `it`: Italian
- `ru`: Russian
- `es_ES`: Spanish - Spain
- `pt_BR`: Portuguese - Brazil

Current content status:

- English and Traditional Chinese are filled for active scripted UI text.
- The 2026-05-13 companion trigger copy is currently authored in Traditional
  Chinese and mirrored into the English column as source/prototype text until a
  separate English pass is written.
- Other language columns are intentionally open but mostly empty.
- Empty translations fall back to English at runtime.

## Editing Text

To change displayed text, edit `game/data/localization.csv`.

Example:

```csv
timer.start,Start,開始,,,,,,,,,
settings.title,Timer Settings,計時器設定,,,,,,,,,
```

Rules:

- Keep the `key` unchanged unless the code is also updated.
- Preserve placeholder names inside braces.
- Examples of placeholders:
  - `{time}`
  - `{focus_points}`
  - `{xp}`
  - `{bond}`
- The current implementation loads the CSV when the game starts, so restart the
  game after editing the CSV.

## Runtime Services

Scripts:

```text
game/scripts/localization_service.gd
game/scripts/option_panel_controller.gd
```

`LocalizationService` responsibilities:

- Load `game/data/localization.csv`.
- Track the active language.
- Provide `translate(key)` and `trf(key, values)`.
- Fall back to English when the active language value is empty.
- Cycle through supported language codes.

`OptionPanelController` responsibilities:

- Add the top-right image-only option button.
- Display the Options panel.
- Display the current language name.
- Emit previous/next language requests.
- Display and emit Break media switch requests.
- Display and emit Ambient Prompt frequency cycle requests.

## Saved State

The selected language is saved in:

```text
user://save.json
```

Payload path:

```json
{
  "app_settings": {
    "language": "en",
    "break_media_enabled": false,
    "break_media_path": "res://assets/videos/break/video.mp4",
    "ambient_prompt_frequency": "normal"
  }
}
```

Supported values currently match the CSV columns:

```text
en, zh_TW, zh_CN, ja, ko, fr, de, it, ru, es_ES, pt_BR
```

## Current UI Behavior

- The top-right HUD contains an image-only Options button using
  `game/assets/Arts/UI/ICON_option.png`.
- Clicking the Options image button opens the Options panel.
- The panel currently contains:
  - Language label
  - Previous language arrow
  - Current language display
  - Next language arrow
  - Break Video switch
  - Ambient Prompt frequency cycle button
- Switching language updates visible labels/tooltips immediately.
- The selected language is saved immediately.
- Break media playback switch updates the saved setting immediately.
- During an active Break countdown, changing the Break media switch must not
  start or stop Break media. The new value applies from the next Break.
- Ambient Prompt frequency cycles between `normal`, `low`, and `off` and is
  saved immediately.

## Localized Areas

Currently wired:

- Top HUD tooltips
- Task panel title and add/archive tooltips
- Timer rail labels and primary button text
- Timer Settings panel labels and switch tooltips
- Result panel buttons and result status text
- Reward summary and task bonus text
- Bottom music player tooltips and list panel empty states
- Break companion panel title/buttons
- Break companion dialogue through `text_key`
- Compact stats overlay labels
- Option button and language panel
- Break media option label and switch tooltip
- Ambient Prompt option label and frequency button
- Borderless fullscreen tooltip text

## Dialogue Integration

Break dialogue data:

```text
game/data/dialogue_defs.json
```

Dialogue entries now support `text_key`:

```json
{
  "dialogue_id": "break_001",
  "text_key": "dialogue.break_001",
  "text": "休息時間到了，肩膀放鬆一點。",
  "bond_requirement": 0,
  "context_requirement": "any"
}
```

Runtime behavior:

- `text_key` is used for localized text when present.
- `text` remains as fallback/source content.
- Break interaction, idle ambient prompt, and focus ambient prompt each display
  one randomly selected eligible line per trigger.
- Ambient prompt entries are separated by `context_requirement.ambient_state`
  with `idle` and `focus` pools. Runtime passes the current state into
  dialogue selection so the pools do not mix.
- Startup welcome is a transparent text-only AVG popup and randomly chooses one
  line from the startup line pool per launch.

Spreadsheet-ready companion dialogue data:

```text
docs/product-spec/data/csv/dialogue_defs.csv
```

Current columns:

```text
dialogue_id,character_id,interaction_type,text_key,text,bond_requirement,context_requirement_json,cooldown_minutes,weight,is_active
```

The CSV currently mirrors the runtime Break and Ambient dialogue entries in
`game/data/dialogue_defs.json`.

Current runtime counts:

- Break interaction: 6 active lines.
- Idle ambient: 7 active lines.
- Focus ambient: 6 active lines.

## Known Gaps

- No hot reload for `localization.csv`; restart the game after CSV edits.
- UI has only been headless-validated. Manual visual review is still required.
- Non-English/non-Traditional-Chinese columns still need translation.
- Long translated strings may need layout tuning.
- Options panel currently supports language switching, Break media on/off, and
  Ambient Prompt Normal/Low/Off frequency.
- Break media path selection is not exposed in UI yet; the runtime uses
  `app_settings.break_media_path`.
- Prototype Break video assets are committed under `game/assets/videos/break/`.
  `.ogv` is validated in the current Godot Spine build; `.mp4` availability is
  target-runtime dependent.

## Ambient Prompt Option

Payload:

```json
{
  "app_settings": {
    "ambient_prompt_frequency": "normal"
  }
}
```

Values:

- `low`: first idle prompt 20 seconds, later idle prompts 90 seconds, focus
  prompts 8 minutes.
- `normal`: first idle prompt 20 seconds, later idle prompts 3 minutes, focus
  prompts 8 minutes.
- `off`: hide the current prompt and prevent future idle/focus ambient prompts.

Rules:

- The Options panel exposes this as a single button that cycles
  `Normal -> Low -> Off -> Normal`.
- Frequency changes reset the current ambient prompt timer and apply immediately.
- Ambient prompts still do not appear during Break countdown.

## Break Media Option

Target payload:

```json
{
  "app_settings": {
    "break_media_enabled": true,
    "break_media_path": "res://assets/videos/break/video.mp4"
  }
}
```

Rules:

- Default `break_media_enabled` is `false`; the packaged prototype video path is
  `res://assets/videos/break/video.mp4`.
- The configured path may be `res://` for packaged content or an allowed local
  file path for development builds.
- If the path is empty, missing, or unsupported, the game falls back to the
  existing Break companion panel.
- Runtime accepts `.ogv` and `.mp4` paths. `.ogv` is validated in this Godot
  build; `.mp4` depends on the runtime/importer support available on the target
  build.
- Break media plays once and then closes automatically.
- During an active Break countdown, the Break media switch only changes the
  saved setting. It must not interrupt currently playing media, start media that
  was not already playing, or close the text Break companion panel.
- The Options panel currently exposes the on/off switch; path selection can be
  added later if needed.

Validation:

```powershell
E:\PomodoroDriver\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\PomodoroDriver\game --script res://scripts/break_media_probe.gd
```

## Validation

Use the Spine-enabled Godot executable:

```powershell
E:\PomodoroDriver\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\PomodoroDriver\game --quit
E:\PomodoroDriver\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\PomodoroDriver\game res://scenes/spine_background_probe.tscn --quit
```
