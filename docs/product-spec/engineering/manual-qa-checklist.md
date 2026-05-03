# Manual QA Checklist

Last updated: 2026-05-03

Use this checklist after UI, timer, companion, media, localization, or save/load
changes. Run the headless checks first, then verify the windowed game manually.

## Headless Validation

```powershell
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game --quit
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game res://scenes/spine_background_probe.tscn --quit
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game --script res://scripts/break_media_probe.gd
E:\ProjectPomodoro\tools\godot-spine-4.1.3\godot-4.1-4.1.3-stable.exe --headless --path E:\ProjectPomodoro\game --script res://scripts/room_spine_probe.gd
E:\ProjectPomodoro\build-windows.cmd
```

## Result Panel

- Complete or partially end a focus session and confirm the result popup shows:
  focus duration, actual duration, reward summary, optional Bond level-up, and
  next suggested action.
- Confirm completed focus shows the result popup while Break countdown starts.
- Confirm the popup can still be dismissed by clicking outside it.

## Store / Unlocks

- Click the top-right `SH` button and confirm the Store panel opens.
- Confirm the Store panel opens centered on screen and above the Pomodoro rail.
- Confirm each background item shows a placeholder name and Focus Point cost.
- Confirm default unlocked items are shown as unlocked and cannot be purchased.
- Confirm Room Background 01 and Room Background 02 are listed as unlocked
  background content.
- Click a locked item and confirm the purchase dialog opens.
- Click outside the purchase dialog and confirm only the confirmation closes.
- Purchase a locked item with enough Focus Points and confirm Focus Points are
  deducted.
- Restart the game and confirm the purchased item remains unlocked.
- Confirm locked contextual backgrounds fall back to a normal unlocked
  background.

## Background Selection

- Confirm the `BG` button appears next to the bottom-right time-cycle button.
- Click `BG` and confirm the menu opens above the music bar.
- Confirm the menu contains Lo-fi, Background 01, and Background 02.
- Select Lo-fi and confirm the original context-driven Lo-fi Spine background
  behavior returns.
- Select Background 01 and confirm the Room Spine background loads.
- Select Background 02 and confirm the second Room Spine background loads.
- Cycle Day, Sunset, Night, and Cloudy while Background 01 and Background 02
  are selected, and confirm the Room animation changes without layout jumps.
- Restart the game and confirm the selected background mode persists.

## Debug UI Controls

- `A` toggles Simple Mode and hides most UI while keeping Tasks and Pomodoro
  visible.
- `B` toggles Tasks UI.
- `C` toggles Pomodoro UI.
- `F1` adds 100 Focus Points and updates the top-right Focus Points tooltip.
- Time button cycles Day, Sunset, Night, and Cloudy background contexts.
- `BG` opens the background selection menu.
- `A`, `B`, `C`, Time, `BG`, and ambience sit on the music bar background
  without a separate backing panel.

## Timer

- New or cleared save starts with 5:00 focus time.
- Timer Settings focus duration and right-side timer rail show the same value.
- Start closes Timer Settings if it is open.
- Start changes state to running.
- Pause freezes focus countdown and changes primary action to Resume.
- Resume continues focus countdown.
- Reset returns to focus idle and uses the current Settings focus duration.
- Focus completion always enters Break countdown.
- During Break countdown, focus time remains inactive/gray and does not count
  down.
- Break completion returns to focus idle when Auto restart is off.
- Break completion starts the next focus session when Auto restart is on.

## Timer Settings

- Focus duration `-` and `+` step by 1 minute.
- Break duration `-` and `+` step by 1 minute.
- Auto restart switch left/off and right/on behavior is correct.
- Alarm switch left/off and right/on behavior is correct.
- Switch tooltips show current state.
- Settings panel does not overlap the timer rail.

## Tasks

- `+` creates a new editable task.
- Empty rename falls back to localized default task title.
- Checkbox completes a task.
- Completed task cannot be completed twice.
- Archive button removes task from the visible list.
- Task changes persist after restart.

## Result Panel

- Completed focus session shows result panel.
- Partial/abandoned states show the correct result panel.
- Outside click dismisses the result panel.
- Mark Task Done grants task bonus once.
- Bond level-up summary appears when level increases.

## Companion Break Interaction

- Break text panel appears when Break Video is off or media playback fails.
- Break dialogue is localized through `text_key`.
- Next advances to a different eligible line when available.
- Skip hides the panel without stopping the Break timer.
- Viewed/skipped/advanced events are saved to `interaction_history`.
- Bond/context/cooldown/weight filters do not prevent fallback dialogue.

## Ambient Companion Prompt

- First idle prompt appears around 20 seconds after startup.
- Low frequency mode: later idle prompts use about 90 seconds.
- Normal frequency mode: later idle prompts use about 3 minutes.
- Focus prompts use about 8 minutes in both Low and Normal.
- Prompt auto-hides after about 8 seconds.
- Dismiss button hides the prompt and records `ambient_prompt_dismissed`.
- Prompt does not appear during Break countdown.
- Prompt does not cover Tasks, Timer rail, Timer Settings, music bar, Break
  dialogue, or Break media.

## Break Media

- Break Video off: Break uses text companion panel.
- Break Video on: Break attempts to play configured media.
- Video plays during Break countdown and closes after one play.
- Missing/unsupported media falls back to text companion panel.
- Toggling Break Video during active Break does not start or stop current
  Break media or text panel.
- New Break Video switch value applies from the next Break.

## Options And Localization

- OP button opens Options panel.
- Language arrows cycle supported languages.
- Selected language updates visible labels/tooltips immediately.
- Selected language persists after restart.
- Break Video switch updates saved setting immediately.
- Ambient Prompt button cycles `Normal`, `Low`, and `Off`.
- Ambient Prompt `Off` hides the current prompt and prevents future idle/focus
  prompts.
- Ambient Prompt frequency setting persists after restart.
- Long localized strings do not overflow critical controls.

## Music

- Music list opens and closes.
- Previous/play-pause/next controls work.
- Loop icon overlay reflects on/off state.
- Volume slider changes output volume.
- Last played track, loop state, and volume persist after restart.
