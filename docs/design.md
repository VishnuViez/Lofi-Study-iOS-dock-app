# Lofi Dock — design

**Purpose:** an always-on desk clock for iPhones whose StandBy goes dark. Only
iPhones with an always-on display keep StandBy lit; on the rest (including
the OLED iPhone 15) the screen turns off after a few seconds. Lofi Dock is a
landscape app that keeps the screen on while it's open, with a lofi look, a choice of
clock faces, a study-session timer and optional rain/vinyl ambience.

## Decisions

- **Native SwiftUI, iOS 17+, iPhone only, landscape only.** Status bar and home
  indicator hidden.
- **Faces**, swiped sideways and persisted: *Lofi Room* (animated study room
  drawn in code, clock on the wall), *Big Digits*, *Analog* (paper dial,
  sweeping second hand) and *Flip* (split-flap cards). The clock-only faces sit
  on a shared backdrop of drifting haze, faint rain and film grain. All art is
  drawn in code; no third-party images or audio.
- **Clock**: follows the 12/24-hour setting; every face shows the date and a
  `SESSION H:MM:SS` counter.
- **Session**: starts when the app comes to the front. Leaving the app (home,
  app switcher, lock button) ends it; the next return starts again at zero.
  Being briefly covered (Control Center, notification shade) does not reset.
- **Dock behaviour**: while the app is in front, `isIdleTimerDisabled` holds
  the screen on regardless of the Auto-Lock setting. A setting ("Only while
  charging", off by default) narrows that to when the phone is charging
  (wireless or cable, including "full"). iOS drops the flag when the app
  leaves the foreground, so `ScreenAwakeController` re-applies it on every
  activation, on charger changes and once a minute.
- **Controls**: hidden by default so the dock is a clean clock; a tap shows a
  bar (face, rain, vinyl, settings, charging bolt) that hides after 5 s.
- **Switchable display features** (all default on):
  - *Night dimming* between two times (default 22:00–07:00): colour-multiply
    toward amber-red plus darkening, done in the view. Screen brightness is not
    touched, because an app's brightness change persists after the app until
    the phone locks.
  - *Burn-in protection*: the whole face is scaled 3% and walks a small
    figure-eight, one step a minute.
  - *Ease off when warm*: animation frame rate 30 fps, dropping to 20/8/1 fps
    as `ProcessInfo.thermalState` rises (and lower in Low Power Mode). Clocks
    tick on their own 1 s timeline, so time display is unaffected.
- **Audio**: rain and vinyl crackle are synthesised in real time
  (`AVAudioSourceNode`), each with its own toggle, persisted, plus a master
  mute that silences everything (timer chime included) without changing the
  per-source choices. Session category `.playback` + `.mixWithOthers`.
  Audio stops when the app leaves the foreground.
- **Rain animation** has its own switch, independent of the rain sound.
- **Checklist face**: `Checklist` is a pure value (add trims and caps titles
  at 120 characters, toggle, remove, clear done, progress); `ChecklistStore`
  saves it to UserDefaults as JSON on every change, so tasks persist across
  launches. The add field is at the top because the landscape keyboard covers
  the lower half. Delete is a long-press context menu, not swipe-to-delete,
  because horizontal swipes change faces. The macOS preview renders rows in
  a plain stack and a static field, since ImageRenderer can't draw scroll
  views or text fields.
- **Timer face**: Clock-app layout (wheels + presets, Cancel / Start-Pause-
  Resume, emptying ring with end time). `CountdownTimer` is a pure state
  machine (idle → running ⇄ paused → finished). `TimerController` fires the
  alert in-app at the end and schedules a local notification for when the app
  is in the background; a work item that was overdue because the app was
  suspended does not ring on return. The chime (three bell strikes) is
  generated in code and written once to `Library/Sounds`, the folder both
  `AVAudioPlayer` and notification sounds can play from. Muted: no chime, the
  ring blinks and the phone vibrates. Other faces show a countdown chip.
- **StandBy**: iOS lets only widgets and Live Activities into StandBy, so the
  app itself is the dock. A Shortcuts automation (Charger → Is Connected →
  Open App) launches it on charge; documented in the README and in Settings.

## Testing

Pure logic (session clock, formatting, burn-in drift, night schedule, frame
budget, analog hand angles, face cycling, synth) has Swift Testing tests that
run from Xcode and, without Xcode, via `tools/check-mac.sh`. The same script
renders every face plus night and controls variants, the app icon and audio
samples on macOS for inspection.
