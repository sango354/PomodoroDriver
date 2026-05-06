# Current Development Progress

Last updated: 2026-05-07

This document records the current implementation state so work can continue
from another machine without relying on chat history.

## Repository State

- Active Godot project: `game/`
- Main scene: `res://scenes/main.tscn`
- Spine probe scene kept for validation: `res://scenes/spine_background_probe.tscn`
- Room Spine probe script kept for validation:
  `res://scripts/room_spine_probe.gd`
- Latest localization/options spec:
  `docs/product-spec/systems/07-localization-and-options.md`
- Manual QA checklist:
  `docs/product-spec/engineering/manual-qa-checklist.md`
- Spine-enabled Godot editor expected locally:

Project root paths differ between development machines. Existing examples may
use `E:\ProjectPomodoro`; the current checkout may instead be `E:\Pomodoro`.
Use the same relative paths under the repository root when moving between
machines.

```powershell
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe
```

Open project:

```powershell
E:\ProjectPomodoro\scripts\open-godot-spine.ps1
```

Headless validation:

```powershell
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game --quit
```

Windows build:

```powershell
E:\ProjectPomodoro\build-windows.cmd
```

The build script regenerates runtime manifests for localization and music,
creates the Windows export preset when needed, and writes ignored output under
`builds/windows/`.

## Implemented Prototype Scope

The current prototype targets the M1 core loop from the roadmap.

Headless validation passed locally with the Spine-enabled Godot
`4.1.3.stable.custom_build` editor:

```powershell
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game --quit
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game res://scenes/spine_background_probe.tscn --quit
```

Implemented:

- Spine background loading through the Spine-enabled Godot 4.1.3 editor.
- Main Pomodoro scene with edge HUD layout.
- Focus timer with `Start` / `Pause` / `Resume` sharing one primary button.
- Timer rail uses icon-only Settings and Reset buttons beside the primary
  `Start` / `Pause` / `Resume` button.
- Reset restores the focus timer to the current Settings focus duration and
  returns the timer to idle.
- Timer settings panel for focus duration, break duration, auto restart, and
  alarm.
- Default focus duration is 5 minutes. Timer Settings and the right-side timer
  rail both read from the same `duration_minutes` value after save data loads.
- Existing local save data can still override the default focus duration through
  `timer_settings.focus_minutes`.
- Focus and break duration controls step by one minute.
- Auto restart and alarm use switch-style controls with `on` / `off` tooltips.
- Focus completion always starts the break countdown. Auto restart only controls
  whether the next focus session starts automatically after break completion.
- Alarm playback is implemented behind an `Alarm` switch with a silent
  placeholder file at `game/assets/sfx/alarm_placeholder.wav`.
- Settings panel is positioned immediately left of the timer rail with a small
  gap.
- Session result popup for `completed`, `partial`, and `abandoned`.
- Result popup can be dismissed by clicking anywhere outside the popup.
- Basic reward calculation for Focus Points, XP, and Bond.
- Local task list with up to 5 visible tasks.
- Task add button next to the `Tasks` title.
- New tasks default to `Type Here`.
- Task title is directly editable in-place.
- Long task titles are truncated in display form and expose full text via tooltip.
- Local persistence to `user://save.json` for tasks, sessions, progress, and stats.
- Focus Points and Focus Level now use a compact Tasks-adjacent HUD beside the
  task add button. It shows a diamond + compact Focus Points value, plus a
  circular level badge and XP progress bar. Tooltips still expose exact Focus
  Points and XP/level progress.
- Top-right icon HUD now keeps Bond, Unlocks, Store, Dialogue Gallery, Stats,
  and Options.
- Bottom music bar with list, previous, play/pause, next, loop toggle, and volume slider.
- Bottom music controls use icon-only buttons for list, previous, play/pause,
  next, loop, and ambience.
- Bottom-right debug/background controls include `A`, `B`, `C`, time-cycle,
  background menu (`BG`), and ambience.
- Background menu can switch between automatic Lo-fi context backgrounds,
  Room Background 01, and Room Background 02.
- Selected background mode is saved under
  `app_settings.selected_background_id` in `user://save.json`.
- Loop off is shown with a gray overlay on the loop icon.
- Music playback auto-starts the last played track, or the first scanned track
  when there is no saved track.
- `main_game.gd` has started being split into focused scripts:
  - `save_data_service.gd`
  - `task_service.gd`
  - `progression_service.gd`
  - `spine_background_controller.gd`
  - `companion_dialogue_service.gd`
  - `music_player_controller.gd`
  - `companion_panel_controller.gd`
  - `timer_rail_controller.gd`
  - `timer_session_service.gd`
  - `timer_settings_controller.gd`
  - `localization_service.gd`
  - `option_panel_controller.gd`
  - `task_panel_controller.gd`
  - `result_panel_controller.gd`
  - `session_reward_coordinator.gd`
  - `break_media_controller.gd`
- Localization table created at `game/data/localization.csv`.
  - Columns are open for English, Traditional Chinese, Simplified Chinese,
    Japanese, Korean, French, German, Italian, Russian, Spanish-Spain, and
    Portuguese-Brazil.
  - English and Traditional Chinese values are filled for current game UI text.
  - Other language columns are currently placeholders.
- Top-right Option button opens an option panel with language switching.
- Current language is saved under `app_settings.language` in `user://save.json`.
- To edit UI text, update `game/data/localization.csv` and restart the game.
- Break dialogue entries in `game/data/dialogue_defs.json` now include
  `text_key` values that resolve through the localization table.
- Break dialogue runtime control fields that should later be pulled into table
  control are `dialogue_id`, `interaction_type`, `text_key`,
  `bond_requirement`, `context_requirement`, `cooldown_minutes`, `weight`, and
  `is_active`.
- Break media runtime control fields that should later remain data-driven are
  `media_id`, `path`, `enabled`, `bond_requirement`, `context_requirement`,
  playback mode, and fallback behavior.
- Companion dialogue data has a spreadsheet-ready copy at
  `docs/product-spec/data/csv/dialogue_defs.csv`.
- M2 companion interaction has a first break-panel prototype:
  - Break countdown shows a companion dialogue panel.
  - Dialogue content is loaded from `game/data/dialogue_defs.json`.
  - Dialogue selection now filters by Bond and current context.
  - Dialogue entries support `bond_requirement`, `context_requirement`,
    `cooldown_minutes`, `weight`, and `is_active`.
  - Dialogue cooldowns are enforced from local `interaction_history`; if every
    matching line is still cooling down, Break falls back to the matching pool
    instead of showing no dialogue.
  - Break panel supports cycling to the next line and skipping the panel.
  - Break panel emits viewed, skipped, and advanced events. Advanced selection
    avoids choosing the same dialogue again when another valid line exists.
  - Interaction events are saved locally in `interaction_history`.
  - Bond level-up is recorded as an interaction event and shown in the session
    result summary.
  - Ambient companion prompts now appear at low frequency during idle/focus.
    They reuse the same Bond/context/cooldown/weight dialogue selection path as
    Break dialogue.
  - Ambient prompt events are saved as `ambient_prompt_shown` and
    `ambient_prompt_dismissed`.
  - Options can toggle Break media playback during Break countdown.
  - Break media uses `app_settings.break_media_enabled` and
    `app_settings.break_media_path`.
  - If the configured video is missing or unsupported, Break falls back to the
    text companion panel without interrupting the timer.
- Music folder scanning from `res://assets/music`.
- MP3 fallback loading via `AudioStreamMP3` when imported resources are unavailable.
- Added a first data-driven AVG dialogue system:
  - runtime data: `game/data/avg_dialogue_defs.json`
  - loader/state helper: `game/scripts/avg_dialogue_service.gd`
  - full-screen dialogue UI: `game/scripts/avg_dialogue_controller.gd`
  - gallery UI: `game/scripts/avg_gallery_controller.gd`
  - viewed dialogue state is tracked in `interaction_history` as
    `avg_dialogue_viewed`.
  - AVG dialogue lines support per-line `speaker_key`, `text_key`, and
    `background_path`.
  - Trigger timing is intentionally not finalized. Runtime exposes
    `_start_avg_dialogue_for_trigger(trigger_key)` in `main_game.gd` for later
    binding to session, unlock, story, or mission events.
- Added a top-right Dialogue Gallery button (`DG`):
  - Opens a gallery of `type = main` AVG dialogue entries.
  - Unviewed entries show grayscale thumbnails and are disabled.
  - Viewed entries show normal thumbnails and can be replayed.
- Updated current dialogue copy toward the next theme direction: a female
  succubus night taxi driver. Current timer, break, ambient, and AVG sample
  lines now use fare/meter/route/rest-stop language while keeping gameplay
  mechanics unchanged.
- Localization loading now reads CSV first and uses generated
  `localization_manifest.json` only as fallback, so local stale manifests do not
  override freshly edited CSV text during development.

## Current UI Layout

- Top-left: Tasks.
  - Title and `+` button are aligned.
  - Focus Points / Focus Level HUD sits immediately to the right of the task
    add button.
  - Focus Points display compact values: `1000` -> `1K`, `1255` -> `1.25K`.
  - Focus Level display uses a circular badge and XP progress bar.
  - Focus Points and Focus Level tooltips show exact numeric state.
  - No global task input field.
  - Each task has its own checkbox, editable text field, and delete/archive button.
- Top-right: compact icon HUD.
  - `BD`: Bond tooltip.
  - `UL`: Unlocks placeholder.
  - `SH`: Store.
  - `DG`: Dialogue Gallery.
  - `ST`: Stats toggle.
  - `OP`: opens Options.
- Options panel:
  - Currently contains language switching with previous/next arrow buttons.
  - Language switching updates the main UI labels/tooltips immediately.
  - Contains a Break Video switch for Break media playback.
- AVG Dialogue:
  - Full-screen overlay with a per-line background image, speaker name,
    dialogue text, continuation prompt, Next/Finish, and Close.
  - Current prototype data uses Spine PNG exports as thumbnail/background
    placeholders.
  - Gallery replay is the only user-facing entry point until trigger timing is
    specified.
- Right side: narrow Pomodoro timer rail.
  - Focus state.
- Focus time display. White means running; gray means inactive or paused.
- Break time display. White means running; gray means inactive or paused.
  - No progress bar.
  - Icon Settings button on the left of the primary action.
  - Primary Start/Pause/Resume button in the center.
  - Icon Reset button on the right of the primary action.
- Timer Settings popup:
  - Positioned left of the timer rail.
  - Focus duration and break duration use `-` / `+` controls in one-minute
    steps.
  - Auto restart and Alarm switches align with the duration controls.
- Break companion panel:
  - Appears when break countdown starts.
  - Displays data-driven break dialogue.
  - Dialogue is filtered by Bond and context.
  - Can be skipped without stopping the break timer.
- Break media:
  - If enabled and the configured path loads, a `VideoStreamPlayer` appears
    during Break countdown.
  - The video plays once, then closes automatically.
  - Runtime accepts `.ogv` and `.mp4` paths; `.ogv` is validated in the current
    Godot Spine build, while `.mp4` depends on runtime/importer support.
  - If disabled or loading fails, the text Break companion panel is shown.
  - A default prototype video asset exists at
    `res://assets/videos/break/video.mp4`.
- Bottom: music player bar.
  - Left: music list button and current track title.
  - Middle-left: previous, play/pause, next, loop, and volume slider.
  - Right: ambience button.
- Center: reserved for Spine background and character.
- Ambient companion prompt:
  - Appears as a small, dismissible companion text panel during idle/focus.
  - First idle prompt appears after about 20 seconds so the feature is visible
    during QA.
  - Ambient Prompt frequency is set from Options with a single cycle button.
  - `Low`: first idle prompt 20 seconds, later idle prompts 90 seconds, focus
    prompts 8 minutes.
  - `Normal`: first idle prompt 20 seconds, later idle prompts 3 minutes, focus
    prompts 8 minutes.
  - `Off`: hides any current prompt and prevents future idle/focus ambient
    prompts.
  - Prompt auto-hides after 8 seconds.
  - It does not appear during Break countdown.

## Music Assets

Music files should be placed in:

```text
game/assets/music/
```

Supported extensions:

- `.ogg`
- `.mp3`
- `.wav`

Current implementation scans the folder at startup. If MP3 files are not
imported by Godot, the player falls back to reading file bytes into
`AudioStreamMP3`.

Music UI icon assets are stored in:

```text
game/assets/icons/
```

The current icon set includes list, previous, musicplay, musicpause, next,
loop, ambience, reset, and settings PNG assets.

The saved game payload includes `music_state` for current track, loop state,
and volume.

## Localization And Options

Runtime files:

```text
game/data/localization.csv
game/data/dialogue_defs.json
game/scripts/localization_service.gd
game/scripts/option_panel_controller.gd
docs/product-spec/systems/07-localization-and-options.md
```

Localization table columns:

```text
key,en,zh_TW,zh_CN,ja,ko,fr,de,it,ru,es_ES,pt_BR
```

Current state:

- English and Traditional Chinese are filled for active scripted UI text.
- Empty language cells fall back to English.
- The selected language is saved as `app_settings.language` in
  `user://save.json`.
- The top-right `OP` button opens the Options panel.
- Options currently contain language previous/next switching only.
- Options currently contain language previous/next switching and Break Video
  on/off.
- Options also contain an Ambient Prompt frequency cycle button:
  `Normal` -> `Low` -> `Off` -> `Normal`.
- Break media playback during Break countdown is implemented behind the Break
  Video switch. The default path is `res://assets/videos/break/video.mp4`.
- Changing the Break Video switch during an active Break countdown only updates
  the saved setting. It does not start or stop the currently active Break media
  or text Break panel.

When changing visible text:

- Edit `game/data/localization.csv`.
- Keep localization keys stable.
- Preserve placeholders such as `{time}`, `{focus_points}`, `{xp}`, and
  `{bond}`.
- Restart the game after editing the CSV.

## Spine Notes

Source Spine assets are stored at:

```text
docs/product-spec/ArtResource/Spine/
```

Godot-ready copies are stored at:

```text
game/assets/spine/backgrounds/
```

The source atlas files declare `pma:true`. Official spine-godot documentation
states premultiplied alpha atlases are not currently supported. The current
prototype can load and display the assets, but production assets should be
re-exported from Spine 4.1.x with premultiplied alpha disabled.

## Known Gaps

- UI is still generated from scripts, but the timer rail, music player, break
  companion panel, Spine background, save data, task, and progression logic have
  been split out of `game/scripts/main_game.gd`.
- Remaining `main_game.gd` responsibilities are still broad: scene assembly,
  session flow coordination, progress HUD, save/load, and high-level controller
  wiring.
- Task editing uses a display truncation helper instead of a native LineEdit
  ellipsis mode because Godot 4.1 `LineEdit` does not expose
  `text_overrun_behavior`.
- Result rewards are prototype-level and not yet fully idempotent across all
  edge cases.
- Auto restart and alarm are prototype-level local settings saved in
  `user://save.json`; they are not yet backed by content/config data.
- Alarm currently uses a silent placeholder audio file until final SFX is
  supplied.
- `UL` unlocks is a placeholder.
- `ST` only toggles a compact stats text display.
- No final inventory, equipment, mission, or achievement system is implemented
  yet.
- AVG trigger timing is not defined yet. The gallery and replay path are
  functional, but story unlock rules and automatic trigger points still need
  product decisions.
- Current female succubus taxi-driver theme is represented in text only. Visual
  assets, naming, UI labels, and reward terminology are still largely inherited
  from the Pomodoro prototype.
- Break media playback has a simple prototype `.ogv` video asset. A final
  production video can replace `game/assets/videos/break/video.mp4` or use a
  supported `.mp4` path if the target Godot build supports it.
- Break media path selection is not exposed in Options yet.
- Windows export is available through `build-windows.cmd` and
  `scripts/build-windows.ps1`. Build outputs and generated export/manifest
  files are intentionally ignored and regenerated locally.
- Music playback should still be manually tested with real local audio files
  after pulling on another machine.
- Localization currently covers the active scripted UI and break dialogue keys,
  but needs manual UI review for text length in every target language once those
  translations are filled.

## Next Recommended Work

If work resumes on another machine and the next step is unclear, start from a
windowed QA pass for the latest UI/debug controls. Headless validation only
catches script/runtime load errors; the current risk is layout and interaction
behavior.

1. Manually verify the top-left Tasks-adjacent Focus HUD:
   - Focus Points sits just right of the task add button.
   - Compact formatting shows `1K` for exactly 1000 and `1.25K` for 1255.
   - Focus Level badge and XP bar are vertically aligned with the task header.
   - Hover tooltips still show exact Focus Points and XP/level state.
2. Manually verify Dialogue Gallery and AVG replay:
   - `DG` opens the gallery.
   - Unviewed dialogue entries are grayscale and disabled.
   - After an AVG dialogue is viewed through a trigger or debug call, it is
     stored as `avg_dialogue_viewed` in `interaction_history`.
   - Viewed entries become normal-color thumbnails and can replay.
   - AVG line backgrounds switch per line.
3. Manually verify the bottom music bar and debug/background controls:
   - `A`, `B`, `C`, time-cycle, `BG`, and ambience sit together on the music
     bar background.
   - `A` hides most UI while keeping Tasks and Pomodoro available.
   - `B` toggles Tasks independently.
   - `C` toggles Pomodoro independently and closes Timer Settings when hidden.
   - The time-cycle button cycles Day, Sunset, Night, and Cloudy backgrounds.
   - `BG` opens the background menu and switches Lo-fi, Background 01, and
     Background 02.
   - `F1` adds 100 Focus Points and updates the top-right Focus Points tooltip.
4. Manually verify Store modal behavior:
   - Store opens centered and above the Pomodoro rail.
   - Store confirmation appears above the Store panel.
   - Clicking outside the confirmation cancels only the confirmation.
   - Purchases deduct Focus Points, persist after restart, and unlock the
     matching background content.
5. Continue Inventory / Equipment design from the new background menu:
   - current behavior is a small runtime background selector;
   - next likely step is a full inventory/equipment panel with thumbnails,
     clearer locked states, and production unlock balancing.
6. Add lightweight data integrity probes:
   - every `background_defs.json` Spine variant exists under
     `game/assets/spine/backgrounds`;
   - every `display_name_key` exists in `game/data/localization.csv`;
   - every purchasable item has a positive Focus Point cost.
7. Continue deferred settings/content work:
   - Break Video path setting
   - music autoplay setting
   - alarm sound selection
   - music metadata table
   - remaining localization columns and language fit review

Deferred from the 2026-04-29 planning pass:

- Break Video path setting is intentionally not implemented yet.
- Music autoplay setting is not implemented yet.
- Alarm sound selection is not implemented yet.
- Store/content unlocks are implemented as a skeleton. There is still no final
  thumbnail art, inventory/equipment flow, or production purchase balancing.
- Music metadata table remains future work.

## Latest Validation

2026-05-07:

- Taxi exterior scenery handoff:
  - Active taxi main screen now renders the exterior through a live 3D
    `SubViewport` instead of the previous flat 2D sky/side-loop/rear-road
    sprites.
  - `game/scripts/taxi_drive_controller.gd` owns the taxi interior layered UI
    and creates `TaxiStreetViewport`.
  - `game/scripts/taxi_street_world_controller.gd` owns the 3D city scene,
    route graph, camera motion, road blocks, perimeter buildings, props, and
    street lighting.
  - `game/scripts/glb_static_loader.gd` loads the generated GLB models and
    applies texture/material remaps for the Japanese street asset subset.
  - Runtime art used by the 3D street scene is under
    `game/assets/Generated/JapaneseStreet3D/`.
  - The raw Unity asset folder `game/assets/Japanese_Street/` is source
    material only and is not referenced by runtime scripts. Do not include it
    in normal commits unless source-asset archival is explicitly requested.
  - The older flat exterior prototype files under `game/assets/Taxi/Exterior/`
    for `exterior_sky_night`, `exterior_side_loop`, and `exterior_rear_road`
    were removed from the active runtime path.
- Current driving behavior:
  - Vehicle/camera position advances continuously along street graph segments
    at `DRIVE_SPEED = 2.6`.
  - The taxi interior and driver remain 2D UI layers in front of the 3D
    viewport.
  - Camera facing is intentionally opposite the route segment direction:
    straight segments use `(segment_start - segment_end).normalized()`.
  - Turn segments use the reversed Bezier tangent so the apparent exterior
    motion matches forward taxi travel from the user's view.
  - Route transitions no longer snap at regular intervals. If the next decision
    is straight, the controller continues through the full road segment. If a
    turn is required, it enters the turn curve before the intersection.
  - When an intersection has no straight path, the controller now forces the
    turn branch early instead of reaching the node and changing direction
    instantly.
- Map layout state:
  - Default active map id is `downtown_grid`.
  - Two map definitions currently exist in code: `countdown_grid` and
    `downtown_grid`.
  - The current structure is ready for later map switching by adding map
    definitions and calling `set_active_map(map_id)`.
- Local validation on `E:\Pomodoro-copy`:

```powershell
E:\Pomodoro-copy\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --path E:\Pomodoro-copy\game --quit-after 3
git diff --check -- game/scripts/taxi_street_world_controller.gd
```

- Windowed screenshot checks were saved under `tmp/` during development, but
  `tmp/` is local scratch output and should not be committed.

2026-05-05:

- Handoff update for remote work:
  - Active main background has moved from the previous Spine background
    controller to `game/scripts/taxi_drive_controller.gd`.
  - `game/scripts/spine_background_controller.gd` is retained as backup and
    rollback/reference only.
  - Added backup note at
    `game/assets/spine/backgrounds/SPINE_BACKUP_NOTE.md`.
  - Current Taxi art source folder is `game/assets/Taxi/`.
  - Current H gallery art folders are:
    - `game/assets/Arts/HIcon/`
    - `game/assets/Arts/HCG/`
- Taxi main-screen prototype:
  - layered Taxi PNG assets replace the active Spine main background;
  - front seat layer is fixed;
  - character/body layers use subtle road hum and occasional random pothole
    bumps;
  - pothole bumps trigger every 20-40 seconds and use reduced amplitude;
  - character layer has a temporary breathing scale motion because no separate
    chest part exists yet;
  - speed lines currently simulate side motion, but the next requested exterior
    scenery task is paused and not implemented in this handoff.
- AVG / H event update:
  - `game/data/avg_dialogue_defs.json` now contains 15 gallery dialogue entries
    mapped from HIcon thumbnails to HCG backgrounds.
  - First 8 gallery entries are `default_unlocked: true` for QA.
  - Gallery unlock state now merges viewed dialogue ids with
    `default_unlocked` entries.
  - AVG dialogue can use direct `display_name`, `speaker`, and `text` fields
    for temporary content without requiring localization keys.
  - Transparent text-only AVG mode is used for the startup welcome line and H
    event preview line so the main screen remains visible.
  - CG AVG mode uses a full-screen overlay attached to the top-level
    `app_container`, with opaque black backing so the main screen cannot show
    around the CG.
  - H event flow consumes one gold token, shows a preview dialogue, then plays
    two randomly selected gallery dialogues with two-second black fade
    transitions.
  - Selected H event dialogues are recorded as `avg_dialogue_viewed`, unlocking
    them in the gallery.
  - Music playback is suspended during H event playback and restored to the
    previous playing/paused state when the event returns to the main screen.
- Progression / currency update:
  - The former Focus Level badge is now a Gold Token badge.
  - XP remains as the progress bar; when XP reaches the requirement it grants
    one gold token and carries overflow XP.
  - `F2` debug shortcut grants one gold token.
  - `F1` still grants 100 Focus Points.
- Current paused request / next task:
  - User requested exterior scenery like a luxury train ride reference:
    left/right windows should show infinitely looping scenery, and the rear
    window should show an infinitely extending road.
  - This was explicitly paused before implementation.
  - No generated exterior scenery assets were created in this handoff.
  - Suggested next implementation: generate project-local looping night scenery
    and road assets, place them under `game/assets/Taxi/`, then add looping
    `Sprite2D`/viewport animation in `taxi_drive_controller.gd` behind the taxi
    interior layers.
- Validation passed on `E:\Pomodoro-copy` after the current changes:

```powershell
E:\Pomodoro-copy\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\Pomodoro-copy\game --quit
git diff --check
```

- Changed the active text direction toward a female succubus night taxi driver
  theme:
  - timer status messages now use fare/route/meter wording;
  - Break and ambient companion lines now use cab/rest-stop/night-route wording;
  - AVG sample dialogue uses `Night Driver` speaker and taxi route language.
- Added AVG dialogue runtime and gallery:
  - `game/data/avg_dialogue_defs.json`
  - `game/scripts/avg_dialogue_service.gd`
  - `game/scripts/avg_dialogue_controller.gd`
  - `game/scripts/avg_gallery_controller.gd`
- Added top-right `DG` button for the Dialogue Gallery.
- Moved Focus Points and Focus Level out of the top-right HUD and into a
  compact HUD aligned beside the task add button.
- Focus Points compact display behavior:
  - values under 1000 show normally;
  - exactly 1000 displays as `1K`;
  - values such as 1255 display as `1.25K`.
- Focus Level now displays as a circular badge with an XP progress bar, while
  tooltip text keeps exact XP progress.
- Localization service now prefers CSV values over generated localization
  manifests and uses manifests only as fallback.
- Headless validation passed on `E:\Pomodoro-copy`:

```powershell
E:\Pomodoro-copy\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\Pomodoro-copy\game --quit
git diff --check
```

Remote handoff notes:

- The Godot editor regenerated `game/data/localization.*.translation` resources
  after localization CSV changes. Keep them with this commit so another machine
  opens the project with matching imported translations.
- `game/data/localization_manifest.json` remains a generated ignored build
  artifact. It may contain old strings locally, but runtime now prefers CSV
  values during development.
- AVG trigger timing is still product work. Use
  `_start_avg_dialogue_for_trigger(trigger_key)` in `main_game.gd` when binding
  story events later.

2026-05-03:

- Added reproducible Windows build entry points:
  - `build-windows.cmd`
  - `scripts/build-windows.ps1`
- Runtime localization and music manifests are generated by the build flow so
  exported builds can load CSV text and bundled music consistently.
- Converted `game/assets/spine/backgrounds/Room` source Spine files into
  Godot-ready files:
  - `Room.skel`
  - `Room.atlas`
  - `Room.png`
- Added Room Spine metadata at `game/data/room_spine_defs.json`.
- Added Room animation probe at `game/scripts/room_spine_probe.gd`.
- Room Spine BG mapping:
  - `room_bg_01`: slots `BG_A_01`, `BG_A_02`, `BG_A_03`; animations
    `01`, `02`, `03`, `04`, `06`, `07`, `08`, `11`, `12`.
  - `room_bg_02`: slots `BG_B`, `BG_B_01`; animations
    `05`, `09`, `10`, `13`, `14`, `15`, `16`, `17`, `18`.
  - `00` is treated as setup/empty.
- Added bottom-right `BG` background menu next to the time-cycle button.
- Background menu options:
  - Lo-fi: existing automatic context-based backgrounds.
  - Background 01: new Room Spine BG01 animation set.
  - Background 02: new Room Spine BG02 animation set.
- Selected background mode persists in `user://save.json` under
  `app_settings.selected_background_id`.
- Added `room_bg_01` and `room_bg_02` to `game/data/background_defs.json` as
  Store content and default-unlocked Room backgrounds.
- Added localization keys for the background menu and Room background item
  names.
- Build validation passed on `E:\Pomodoro`:

```powershell
E:\Pomodoro\scripts\build-windows.ps1
E:\Pomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\Pomodoro\game --script res://scripts/room_spine_probe.gd
```

- Windows output:
  - `builds/windows/Pomodoro.exe`
  - EXE SHA256:
    `45E6B7E8379FCDD5C47B82CC7FD07928DEEE399A57D9BF05AA5F02474371B6F6`
  - ZIP SHA256:
    `3C44E9E71B0687E0730AAF296B46A2FCDB5035267144883AEFAF35B17950750C`

Remote handoff notes:

- After pulling on another machine, verify the Room files exist under
  `game/assets/spine/backgrounds/Room/`.
- Rebuild with `build-windows.cmd`; do not commit `builds/`,
  `game/export_presets.cfg`, or generated manifest files.
- Untracked local MP3 files under `game/assets/music/` are not part of this
  handoff unless they are intentionally staged in a later music-content commit.

2026-04-29:

- Enhanced the session result popup from prototype reward text into a structured
  summary:
  - focus duration
  - actual duration
  - reward summary
  - Bond level-up summary when applicable
  - next suggested action
- Added data-driven result summary layout at
  `game/data/reward_summary_defs.json`.
- Added the unlock/content skeleton for background Spine variants:
  - runtime data: `game/data/background_defs.json`
  - spreadsheet copy: `docs/product-spec/data/csv/background_defs.csv`
  - unlock service: `game/scripts/content_unlock_service.gd`
- Added a top-right Store button (`SH`) and store popup controller at
  `game/scripts/store_panel_controller.gd`.
- Store popup lists background unlock items by name and Focus Point cost.
- Locked store items open a purchase confirmation dialog.
- Clicking outside the purchase confirmation cancels the confirmation.
- Purchased unlocks are saved in `user://save.json` under
  `unlocked_content`.
- Added bottom-right debug/UI controls:
  - `A`: Simple Mode, hides most UI while keeping Tasks and Pomodoro visible.
  - `B`: toggles Tasks UI.
  - `C`: toggles Pomodoro UI.
  - `Time`: cycles background time context through Day, Sunset, Night, and Cloudy, then reloads the matching unlocked Spine background.
- Debug/UI controls sit on the bottom music bar background without their own panel backing.
- Added debug cheat: pressing `F1` grants 100 Focus Points.
- Store UI now opens as a centered top-layer modal instead of overlapping the
  Pomodoro rail.
- Background Spine selection now respects unlock state. If the contextual
  background is locked, the runtime falls back to an unlocked normal background.
- Default unlocked backgrounds:
  - Normal Day
  - Normal Night
  - Normal Sunset
  - Normal Cloudy
- Purchasable background placeholders:
  - Good Day / Night / Sunset
  - Troubled Day / Night / Sunset
- Added localization keys for Store, background item names, and structured
  result summary lines.
- Updated Ambient Prompt option cycling to include `Off`.
- Completed focus sessions now show the Result Panel while Break countdown
  starts automatically.
- Headless validation passed:

```powershell
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game --quit
```

Remaining recommended next items:

1. Manually QA the Store popup in the Godot window:
   - top-right Store button opens/closes the panel
   - confirmation dialog appears for locked items
   - clicking outside the confirmation cancels it
   - purchase deducts Focus Points and persists after restart
   - locked contextual backgrounds fall back to normal backgrounds
   - purchased contextual backgrounds can display when the context matches
2. Replace store item name placeholders with thumbnails when final art is ready.
3. Add a real inventory/equipment flow if users should manually select unlocked
   backgrounds instead of automatic context-based selection.
4. Add automated probes for content unlock data integrity.
5. Continue deferred items from the planning pass:
   - Break Video path setting
   - music autoplay setting
   - alarm sound selection
   - music metadata table

2026-04-27:

- Split timer rail UI into `game/scripts/timer_rail_controller.gd`.
- Split timer settings popup into `game/scripts/timer_settings_controller.gd`.
- Split timer/session state transitions into
  `game/scripts/timer_session_service.gd`.
- Split bottom music player UI/playback into
  `game/scripts/music_player_controller.gd`.
- Split M2 break companion panel into
  `game/scripts/companion_panel_controller.gd`.
- Added immediate music state saving through `MusicPlayerController.state_changed`.
- `game/scripts/main_game.gd` no longer directly references timer rail labels or
  timer rail buttons.
- `game/scripts/main_game.gd` no longer builds Timer Settings controls directly.
- Added `game/data/localization.csv` and `game/scripts/localization_service.gd`.
- Added `game/scripts/option_panel_controller.gd` with language previous/next
  controls.
- Added localization keys to break dialogue data.
- Split task list UI into `game/scripts/task_panel_controller.gd`.
- Split result popup UI into `game/scripts/result_panel_controller.gd`.
- Split session reward/stat summary coordination into
  `game/scripts/session_reward_coordinator.gd`.
- Added Break media playback requirement to the system specs. This is not yet
  implemented in runtime.
- Headless validation passed:

```powershell
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game --quit
```

2026-04-28:

- Added Bond/context filtering for Break dialogue.
- Expanded Break dialogue content to 20 entries with English and Traditional
  Chinese localization keys.
- Added Break interaction viewed/skipped/advanced signals.
- Added local `interaction_history` persistence for Break interaction events.
- Enforced Break dialogue cooldowns from `interaction_history`.
- Updated Break Next behavior so it avoids repeating the same dialogue when a
  different eligible line exists.
- Added Bond level-up result text and `bond_level_up` interaction event.
- Added low-frequency ambient companion prompts for idle/focus.
- Added ambient dialogue content, localization keys, and
  `ambient_prompt_shown` / `ambient_prompt_dismissed` events.
- Added `game/scripts/break_media_controller.gd`.
- Added Break Video switch to Options.
- Added `app_settings.break_media_enabled` and
  `app_settings.break_media_path` persistence.
- Added prototype Break video asset at `game/assets/videos/break/video.mp4`.
- Added `game/scripts/break_media_probe.gd` for video resource validation.
- Break media attempts playback during Break countdown, closes after one play,
  and falls back to text interaction when the configured video is missing or
  unsupported.
- Updated Break Video option behavior: toggling it during an active Break no
  longer starts or stops Break media immediately. The setting applies from the
  next Break.
- Added `docs/product-spec/engineering/manual-qa-checklist.md`.
- Added Ambient Prompt frequency option with Low/Normal cycle behavior.
- Filled `docs/product-spec/data/csv/dialogue_defs.csv` with the current Break
  and Ambient companion dialogue runtime data.
- Updated `game/scripts/break_media_probe.gd` to inherit `SceneTree`, so the
  documented `--script res://scripts/break_media_probe.gd` validation command
  no longer opens an alert dialog.
- Headless validation passed on the current `E:\Pomodoro` checkout:

```powershell
E:\Pomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\Pomodoro\game --quit
E:\Pomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\Pomodoro\game --script res://scripts/break_media_probe.gd
```

## Git Notes

Before moving machines, confirm the latest commit was pushed:

```powershell
git status --short --branch
git log -1 --oneline
```

Files that are expected to exist locally for the current prototype:

- `game/scripts/save_data_service.gd`
- `game/scripts/task_service.gd`
- `game/scripts/progression_service.gd`
- `game/scripts/spine_background_controller.gd`
- `game/scripts/companion_dialogue_service.gd`
- `game/scripts/companion_panel_controller.gd`
- `game/scripts/music_player_controller.gd`
- `game/scripts/timer_rail_controller.gd`
- `game/scripts/timer_session_service.gd`
- `game/scripts/timer_settings_controller.gd`
- `game/scripts/localization_service.gd`
- `game/scripts/option_panel_controller.gd`
- `game/scripts/task_panel_controller.gd`
- `game/scripts/result_panel_controller.gd`
- `game/scripts/session_reward_coordinator.gd`
- `game/scripts/break_media_controller.gd`
- `game/scripts/break_media_probe.gd`
- `game/scripts/room_spine_probe.gd`
- `game/scripts/avg_dialogue_service.gd`
- `game/scripts/avg_dialogue_controller.gd`
- `game/scripts/avg_gallery_controller.gd`
- `game/data/dialogue_defs.json`
- `game/data/avg_dialogue_defs.json`
- `game/data/localization.csv`
- `game/data/background_defs.json`
- `game/data/room_spine_defs.json`
- `game/assets/videos/break/video.mp4`
- `game/assets/videos/break/video.ogv`
- `game/assets/spine/backgrounds/Room/Room.skel`
- `game/assets/spine/backgrounds/Room/Room.atlas`
- `game/assets/spine/backgrounds/Room/Room.png`
- `build-windows.cmd`
- `scripts/build-windows.ps1`

2026-04-29 remote-work check on `E:\ProjectPomodoro`:

- Confirmed the current checkout contains the 2026-04-28 M2 companion and Break
  media work.
- Confirmed `game/assets/videos/break/video.mp4` and
  `game/assets/videos/break/video.ogv` both exist locally.
- Headless validation passed:

```powershell
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game --quit
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game res://scenes/spine_background_probe.tscn --quit
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game --script res://scripts/break_media_probe.gd
```

Before moving machines, run:

```powershell
git status --short
git diff --stat
```

Then commit and push only the intended changes.
