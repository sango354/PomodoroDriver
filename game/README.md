# Pomodoro Godot Project

This is the working Godot project for the Pomodoro game. The original Spine
probe scene is kept at `res://scenes/spine_background_probe.tscn`.

Use this editor:

```powershell
E:\Pomodoro-copy\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --path E:\Pomodoro-copy\game
```

Or run:

```powershell
E:\Pomodoro-copy\scripts\open-godot-spine.ps1
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
E:\Pomodoro-copy\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\Pomodoro-copy\game --quit
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
- Selects a random passenger first, plays a boarding greeting, then waits for
  the player to choose focus time and press Start.
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
- Render the active taxi exterior through a live 3D `SubViewport` using runtime
  art under `res://assets/Generated/JapaneseStreet3D/`.
- Cycle the 3D taxi sky between panorama textures under
  `res://assets/Taxi/Exterior/`.
- For rewardable rides, enter a passenger parking dialogue and a 10-round
  question/answer quiz. Emotion reaching 100 starts that passenger's next H/AVG
  event; Alert reaching 100 fails the quiz.
- Keep Focus Points visible while XP, Gold Token, and Bond UI are hidden for
  the passenger-flow prototype.

Current UI implementation notes:

- Current authored UI art lives under `res://assets/Arts/UI/`.
- The active topbar uses image-only buttons for tutorial, memory/gallery,
  statistics, and options. The previous translucent topbar backing panel has
  been removed.
- Timer controls use icon-only Settings and Reset buttons beside the primary
  Start/Pause/Resume button. The timer rail uses `Panel_clock.png`,
  `Button_config.png`, `Button_reset.png`, and `Button_start.png`.
- Timer Settings supports one-minute focus/break adjustments plus Auto restart
  and Alarm switches.
- The Alarm switch currently plays a silent placeholder from
  `res://assets/sfx/alarm_placeholder.wav`.
- The bottom music bar uses icon-only controls from `res://assets/Arts/UI/`
  for list, previous, play, pause, next, and loop.
- Loop off is represented by a gray overlay on the loop icon.
- The bottom-right utility controls use the simple mode, mission/hide mission,
  and hide clock art. A borderless fullscreen toggle sits beside the ambience
  button and restores the previous window mode on the next click.
- The right-top resource HUD uses the current Focus Point, Token, Token bar,
  and Bond Level art.
- Visible button-like controls use a hover scale effect. The right-top Token
  hit area also scales on hover. Full-screen invisible dismiss layers do not.
- Break interaction dialogue is loaded from `res://data/dialogue_defs.json`.
- Startup welcome, idle ambient, focus ambient, and break companion triggers
  each randomly select one line from their matching line pool. Idle and focus
  ambient lines are split by `ambient_state`.
- Localized UI text is loaded from `res://data/localization.csv`.
- The top-right Option button opens a panel with language switching and Break
  Video on/off plus Ambient Prompt Normal/Low/Off frequency.
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
- The active taxi exterior path is split across
  `res://scripts/taxi_drive_controller.gd`,
  `res://scripts/taxi_street_world_controller.gd`, and
  `res://scripts/glb_static_loader.gd`.
- Passenger ride and quiz data lives in `res://data/passenger_defs.json` and
  `res://data/passenger_quiz_defs.json`. The first placeholder data set has 4
  passengers and 120 quiz questions.
- Passenger, quiz, state-line, localization, and H/AVG event text are imported
  from Google Sheets with `tools/download-text-data.cmd`. The current sheet
  contract is documented at
  `docs/product-spec/data/text-data-schema.md`.
- H/AVG event runtime data lives in `res://data/avg_dialogue_defs.json`.
  `h_event_defs` controls passenger gallery sequence and `h_event_lines`
  controls line text plus BG/embedded-Spine visual changes.
- Passenger flow support lives in `res://scripts/passenger_flow_service.gd` and
  `res://scripts/passenger_quiz_controller.gd`.
- The raw `res://assets/Japanese_Street/` Unity source folder is not required
  for the normal tracked runtime path. Keep it out of normal commits unless
  source-asset archival is intentional.

For handoff status and current implementation notes, see:

```text
E:\Pomodoro-copy\docs\product-spec\engineering\current-progress.md
```

Localization/options details are documented in:

```text
E:\Pomodoro-copy\docs\product-spec\systems\07-localization-and-options.md
```

Manual QA steps are documented in:

```text
E:\Pomodoro-copy\docs\product-spec\engineering\manual-qa-checklist.md
```

Build Windows export:

```powershell
E:\Pomodoro-copy\build-windows.cmd
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
game/data/passenger_defs.json
game/data/passenger_quiz_defs.json
game/data/avg_dialogue_defs.json
game/assets/spine/backgrounds/Room/Room.skel
game/assets/spine/backgrounds/Room/Room.atlas
game/assets/spine/backgrounds/Room/Room.png
game/assets/Arts/UI/
game/assets/Generated/JapaneseStreet3D/
game/assets/Taxi/Exterior/sky_panorama.png
game/assets/Taxi/Exterior/sky_afternoon.png
game/assets/Taxi/Exterior/sky_night.png
game/data/dialogue_defs.json
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
game/scripts/taxi_drive_controller.gd
game/scripts/taxi_street_world_controller.gd
game/scripts/glb_static_loader.gd
game/scripts/passenger_flow_service.gd
game/scripts/passenger_quiz_controller.gd
build-windows.cmd
scripts/build-windows.ps1
```
