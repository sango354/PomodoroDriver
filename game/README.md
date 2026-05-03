# Pomodoro Godot Project

This is the working Godot project for the Pomodoro game. The original Spine
probe scene is kept at `res://scenes/spine_background_probe.tscn`.

Use this editor:

```powershell
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --path E:\ProjectPomodoro\game
```

Or run:

```powershell
E:\ProjectPomodoro\scripts\open-godot-spine.ps1
```

The main scene is:

```text
res://scenes/main.tscn
```

The project stores prepared copies of the source Spine exports under:

```text
res://assets/spine/backgrounds/<variant>/<variant>.skel
res://assets/spine/backgrounds/<variant>/<variant>.atlas
res://assets/spine/backgrounds/<variant>/<variant>.png
```

The source files in `docs/product-spec/ArtResource/Spine` are left untouched.
The `.skel.bytes` and `.atlas.txt` files are copied into this project with the
`.skel` and `.atlas` extensions expected by spine-godot.

The Room background Spine export is currently prepared under:

```text
res://assets/spine/backgrounds/Room/Room.skel
res://assets/spine/backgrounds/Room/Room.atlas
res://assets/spine/backgrounds/Room/Room.png
```

Room animation metadata is tracked in `res://data/room_spine_defs.json`.

Important: the current atlas files contain `pma:true`. Official spine-godot
documentation says premultiplied alpha atlases are not currently supported.
These assets should be re-exported from Spine 4.1.x with premultiplied alpha
disabled for production use in Godot.

Verification performed:

```powershell
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game --quit
```

Expected output includes:

```text
SpineSprite: true
SpineSkeletonFileResource: true
SpineAtlasResource: true
SpineSkeletonDataResource: true
Skeleton resource loaded: true
Atlas resource loaded: true
SpineSprite instantiated: true
```

The MVP game scene currently covers the M1 loop from the product spec:

- Start a focus session.
- Pause, resume, or end early.
- Reset the focus timer back to the configured focus duration.
- Bind one local task to the current session.
- Classify results as completed, partial, or abandoned.
- Grant Focus Points, XP, and Bond when rewardable.
- Show a structured result summary from `res://data/reward_summary_defs.json`.
- Automatically enter break countdown after each completed focus session.
- Start the next focus session after break only when Auto restart is enabled.
- Show a first-pass companion break interaction panel during break countdown.
- Show low-frequency ambient companion prompts during idle/focus.
- Optionally play Break media during break countdown when Break Video is enabled.
- Save local tasks, sessions, progress, stats, timer settings, and music state
  to `user://save.json`.
- Play music from `res://assets/music`, restoring the last played track when
  possible.
- Open a top-right Store panel for background Spine unlock placeholders.
- Switch background mode from the bottom-right `BG` menu between Lo-fi,
  Background 01, and Background 02.
- Save selected background mode to `user://save.json`.

Current UI implementation notes:

- Timer controls use icon-only Settings and Reset buttons beside the primary
  Start/Pause/Resume button.
- Timer Settings supports one-minute focus/break adjustments plus Auto restart
  and Alarm switches.
- The Alarm switch currently plays a silent placeholder from
  `res://assets/sfx/alarm_placeholder.wav`.
- The bottom music bar uses icon-only controls from `res://assets/icons`.
- Loop off is represented by a gray overlay on the loop icon.
- Break interaction dialogue is loaded from `res://data/dialogue_defs.json`.
- Localized UI text is loaded from `res://data/localization.csv`.
- The top-right Option button opens a panel with language switching and Break
  Video on/off plus Ambient Prompt Low/Normal frequency.
- The saved game payload includes `app_settings.language`,
  `app_settings.break_media_enabled`, `app_settings.break_media_path`, and
  `app_settings.ambient_prompt_frequency`.
- Break media assets currently exist under `res://assets/videos/break/`.
- Background unlock content is defined in `res://data/background_defs.json`.
- Room Background 01 and Room Background 02 are Store content items and are
  currently default unlocked.
- Purchased background unlocks are saved in `user://save.json` under
  `unlocked_content`.
- The selected background mode is saved in `user://save.json` under
  `app_settings.selected_background_id`.
- Core logic and UI controllers have started moving out of `main_game.gd` into
  focused scripts under `res://scripts/`, including save data, tasks,
  progression, Spine background, timer session state, timer rail, timer
  settings, music player, companion dialogue, break companion panel,
  localization, option panel, task panel, result panel, session reward, and
  break media controllers.

For handoff status and current implementation notes, see:

```text
E:\ProjectPomodoro\docs\product-spec\engineering\current-progress.md
```

Localization/options details are documented in:

```text
E:\ProjectPomodoro\docs\product-spec\systems\07-localization-and-options.md
```

Manual QA steps are documented in:

```text
E:\ProjectPomodoro\docs\product-spec\engineering\manual-qa-checklist.md
```

Build Windows export:

```powershell
E:\ProjectPomodoro\build-windows.cmd
```

The build script regenerates localization/music manifests and writes ignored
output under `builds/windows/`.

For another machine, verify these local files exist after sync:

```text
game/data/localization.csv
game/data/dialogue_defs.json
game/data/background_defs.json
game/data/room_spine_defs.json
game/data/reward_summary_defs.json
game/assets/spine/backgrounds/Room/Room.skel
game/assets/spine/backgrounds/Room/Room.atlas
game/assets/spine/backgrounds/Room/Room.png
game/scripts/localization_service.gd
game/scripts/option_panel_controller.gd
game/scripts/task_panel_controller.gd
game/scripts/result_panel_controller.gd
game/scripts/session_reward_coordinator.gd
game/scripts/break_media_controller.gd
game/scripts/break_media_probe.gd
game/scripts/content_unlock_service.gd
game/scripts/store_panel_controller.gd
game/scripts/room_spine_probe.gd
build-windows.cmd
scripts/build-windows.ps1
```
