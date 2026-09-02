> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/08-interaction-trio.md) | English

# Maxing Out Game Feel: UI, Camera, and Audio Feedback with Fuse

In the previous chapter the character learned to jump and climb walls, but you've probably noticed: every character action is correct, yet playing it just isn't "satisfying". The problem isn't the character — it's the feedback. An attack lands, and the health bar doesn't move, the camera doesn't shake, no sound plays — even the most refined logic feels like it's behind glass. This chapter solves game feel: with Fuse's UI, camera, and audio instruction sets, every player input gets a visible, audible echo. After reading, you can build the triple feedback of "hit moment: health bar drops + camera shakes + sound effect blasts", all visual.

Carrying over from the previous chapter: the character moves and jumps, and the actions are all correct yet the game doesn't feel satisfying — what's missing is feedback.

## UI Feedback: Making On-screen Numbers Move on Their Own

UI is feedback's most direct carrier. Fuse has 6 UI instructions total; the core 4 are `SetUIText` (set UI text), `SetUITexture` (set UI texture), `SetUIProgress` (set UI progress), and `ShowHideUI` (show/hide UI).

`SetUIText` handles text, supporting controls with a `text` property like Label, RichTextLabel, Button, and LineEdit. It has one key design: text can be hardcoded or read from a variable (`use_variable = true`). Score displays rely on this — store the score in a variable and refresh it to the Label with `SetUIText` on every change; the text can even use expressions for formatting, like `Score:{local:score}` with automatic interpolation.

`SetUIProgress` serves ProgressBar exclusively, taking a progress value from 0.0 to 1.0. Health bars, loading bars, and skill charges all run on it. It reads from variables too — health changes, and the bar follows smoothly. `SetUITexture` manages TextureRect textures, sourced from either a file path or a variable — handy for "weapon icons switching with equipment" and "expression changes". `ShowHideUI` controls visibility with three actions: SHOW, HIDE, and TOGGLE; one TOGGLE covers a pause menu's opening and closing.

Instructions alone aren't enough — you need to know when the UI should change. Fuse provides 7 UI events; the most used are: `OnButtonPressed` (button pressed) listens for clicks; `OnValueChanged` (value changed) listens to Slider/SpinBox/ProgressBar and has a threshold mode that only fires on "reaching a value" or "reaching maximum", no per-frame checks needed; `OnTextChanged` (text changed) listens to input fields, likewise with trigger modes like "is empty", "reached max length", and "matches regex" — great for form validation; `OnItemSelected` (ItemList selection changed) handles list selection; `OnFocus` (focus changed) handles controls gaining/losing focus.

A minimal runnable health bar example: suppose you already have a global variable `hp_ratio` holding the health ratio (0~1). Put a Trigger on the character with the Event `OnHealthChanged` (health changed), and after it fires attach a `SetUIProgress` whose `target_node` points at the health bar ProgressBar, with `use_variable = true` and `value_variable` set to `hp_ratio`. Every time the character loses health, the bar shrinks automatically. Wire the score's `SetUIText` in as well, and a damage-plus-score HUD takes shape.

## Camera Feedback: Letting the Lens Express Emotion for You

The camera is the player's only eye, and camera language is itself feedback. Fuse has 7 camera instructions; this chapter focuses on the 4 with the most effect: `CameraFollow` (camera follow), `CameraShake` (camera shake), `SetCameraZoom` (set camera zoom), and `SetCameraLimit` (set camera limit).

`CameraFollow` is the cornerstone of side-scrollers, with three follow modes. LOCK is a hard cut — the camera locks onto the target instantly, suited to precise top-down synchronization; SMOOTH uses `smooth_speed` to control tracking speed, the lens trailing the character slightly — the most used; DAMPED uses physical damping for natural deceleration, giving the camera a soft settle before stopping. Set it once when the game starts:

```
OnReady
└── CameraFollow  target_node: Player, camera_node: Camera2D, follow_mode: Smooth, smooth_speed: 8.0
```

`CameraShake` is the core of game feel, and it's an asynchronous instruction — it stays active for the shake's duration and only marks completion at the end, making it a natural fit for short, sharp feedback like "the hit moment". `intensity` (0~1) pairs with `duration` (seconds): 0.8 intensity for 0.3 seconds on a hit, 1.0 intensity for 0.5 seconds on an explosion — completely different sensations.

`SetCameraZoom` accepts a direct value or a variable, making "zoom out when dashing" and "zoom in when aiming" easy. `SetCameraLimit` keeps the camera inside the level's bounds; `limit_value` set to -9999 means unlimited in that direction. In a side-scrolling level, four `SetCameraLimit`s locking up, down, left, and right keep the lens from panning across the empty background outside the level.

Camera instructions don't end there: `CameraFadeIn` (camera fade in) and `CameraFadeOut` (camera fade out) are the standard for black-screen transitions and cutscene switches; combined with the event system covered in the next chapter, they can build the complete flow of "scene switch → fade out → loading finished → fade in".

## Audio Feedback: Getting the Ears Involved

Sound is the last puzzle piece of game feel, and often the player's subconscious basis for judging "did it hit". Fuse has 7 audio instructions; this chapter uses 4: `PlaySound` (play sound), `PlayMusic` (play music), `CrossfadeToMusic` (crossfade to music), plus the rhythm event `OnMusicBeat` (music beat).

`PlaySound` plays one-shot sound effects, automatically creating an `AudioStreamPlayer` that cleans itself up after playing — no memory management on your part. It has three parameters — `volume`, `pitch_scale`, `bus` — and `pitch_scale` is very useful: add a bit of random variation to hit sounds (say, 0.95~1.05) and combos never get grating. The naming format is `Fuse_AudioPlayer_<random number>`, so other instructions can locate them by name pattern.

`PlayMusic` plays background music; it's an asynchronous instruction supporting fade-in (`fade_in` + `fade_duration`). Don't hard-switch music on scene changes — use `CrossfadeToMusic`, which automatically finds the currently playing `Fuse_MusicPlayer*` and crossfades, smooth and seamless to the ear.

```
OnSceneLoaded
└── CrossfadeToMusic  music_path: "res://audio/level2_bgm.ogg", volume: 0.8, crossfade_duration: 3.0
```

The most distinctive is `OnMusicBeat` (music beat). It fires on a timer by the BPM you set, suited to rhythm games and music visualizations like "spawn enemies on the drumbeat" or "flash the screen every beat". `beat_interval` controls the firing interval: 1 is every beat, 2 every two beats, 4 every bar. When it fires it passes `beat_count` (beat count), `bpm`, and `elapsed_time` into the instruction chain — you can drive the entire game's rhythm off the beat count.

## The Triple-combo Mainline: One Hit, Three Feedback Channels at Once

Blend the three systems above into a complete "character hit" feedback chain. Setup: the character has an `hp` variable that decreases when hit. We want the bar to shrink, the camera to shake, and the sound to play — all three simultaneously.

Split it into three Triggers, each listening to the same trigger source, none blocking another:

Trigger 1 (health bar): the Event is `OnHealthChanged`; instructions attach `SetUIProgress` to refresh the new health ratio onto the bar, then stack a `SetUIColor` to flash the bar red before Tween-easing it back, emphasizing "damage taken".

```
OnHealthChanged
├── SetUIProgress  target_node: HPBar, use_variable: true, value_variable: hp_ratio
└── (Tween color: red → white, emphasizing the hit)
```

Trigger 2 (camera): also `OnHealthChanged`, attaching `CameraShake`, with intensity scaled by the damage amount.

```
OnHealthChanged
└── CameraShake  target_node: Camera2D, intensity: 0.8, duration: 0.3
```

Trigger 3 (sound): also `OnHealthChanged`, attaching `PlaySound` for the hit sound, with a touch of randomness in `pitch_scale` so combos don't grate.

```
OnHealthChanged
└── PlaySound  sound_path: "res://audio/hit.wav", pitch_scale: 0.97~1.03 random
```

Three Triggers listening to one event, each minding its own business — this is visual programming's decoupling advantage. Want a fourth feedback channel (say, particle effects)? Attach one more Trigger without touching the first three at all. This "one trigger source, many responses" pattern is underpinned by Fuse's event mechanism. The next chapter dissects "events" thoroughly: from node lifecycles and the various timing events, to the Event Bus for cross-scene communication — how Fuse makes "triggering" both powerful and controllable.
