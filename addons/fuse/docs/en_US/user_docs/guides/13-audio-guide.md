> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/13-audio-guide.md) | English

# Audio System Guide

The Fuse audio system provides 6 audio instructions and 4 audio events, covering the complete audio interaction chain: sound effect playback, music playback and switching, volume control, pause/resume, and music beat detection.

## Instruction List

| Name | Description | Key parameters |
|------|----------|----------|
| **PlaySound** | Play a sound effect (one-shot, cleaned up automatically when finished) | `sound_path` (audio file path), `volume` (volume 0.0-1.0), `pitch_scale` (pitch 0.01-4.0), `bus` (mixer bus) |
| **PlayMusic** | Play music (async instruction, ends only after playback completes) | `music_path` (music file path), `volume` (volume 0.0-1.0), `bus` (mixer bus), `fade_in` (whether to fade in), `fade_duration` (fade-in time) |
| **CrossfadeToMusic** | Switch music with a crossfade (async instruction) | `music_path` (new music path), `volume` (volume 0.0-1.0), `bus` (mixer bus), `crossfade_duration` (crossfade duration) |
| **StopAudio** | Stop audio playback | `stop_mode` (stop mode: All/Bus/Name Pattern), `bus` (target bus), `name_pattern` (name match pattern), `fade_out` (whether to fade out), `fade_duration` (fade-out time) |
| **SetAudioVolume** | Set the volume of an audio player or bus | `target_mode` (target mode: Specific Player/Bus/Name Pattern), `volume` (volume 0.0-1.0), `fade` (whether to fade), `fade_duration` (fade time) |
| **PauseResumeAudio** | Pause or resume audio playback | `action_mode` (action: Pause/Resume), `target_mode` (target mode: Specific Player/Bus/Name Pattern/All Playing) |

### Instruction Usage Notes

**PlaySound:**
- Automatically creates an `AudioStreamPlayer` node, cleaned up automatically when playback finishes
- Named in the format `Fuse_AudioPlayer_<random>`, so `StopAudio` and `SetAudioVolume` can target them by name pattern

**PlayMusic / CrossfadeToMusic:**
- These two instructions are asynchronous; they mark the instruction as finished only after the music finishes playing
- `CrossfadeToMusic` automatically finds the currently playing `Fuse_MusicPlayer*` and performs the crossfade

**Target modes:**
- `Specific Player`: a specific audio player node path
- `Bus`: all players filtered by mixer bus name
- `Name Pattern`: matched by node name (wildcard `*` supported)
- `All Playing` (pause/resume only): all currently playing audio

---

## Event List

| Name | Trigger condition | Output data |
|------|----------|----------|
| **OnAudioStarted** | An AudioStreamPlayer transitions from not playing to playing | `audio_player` (audio player node), `audio_name` (optional, audio resource name) |
| **OnAudioFinished** | Fires when an AudioStreamPlayer finishes playback | `audio_player` (audio player node), `audio_name` (optional, audio file name), `stream_length` (optional, audio duration) |
| **OnMusicBeat** | Fires on a timed BPM beat (great for rhythm games) | `beat_count` (beat count), `bpm` (BPM value), `elapsed_time` (elapsed time), `beat_interval` (beat interval) |
| **OnAudioBusVolumeChanged** | Fires when an audio bus's volume changes | `bus_name` (bus name), `bus_index` (bus index), `old_volume_db` (old volume), `new_volume_db` (new volume), `volume_change_db` (change amount) |

### Event Usage Notes

**OnAudioStarted:**
- Detects the `playing` property transitioning from false to true via polling
- `trigger_on_loop`: whether to fire on every loop when looping; when off, fires only once per playback

**OnMusicBeat:**
- Uses `_process` to check beat timing every frame; precision depends on the frame rate
- `beat_interval`: beat interval multiplier, 1 = every beat, 2 = every two beats, 4 = every measure (4/4 time)

**OnAudioBusVolumeChanged:**
- Checks bus volume changes via polling, once every 0.1 seconds by default
- `volume_threshold`: volume change threshold (dB); changes below this value do not trigger

---

## Common Use Cases

### 1. Scene Music Switching

Use `CrossfadeToMusic` to smoothly transition background music when entering a new scene:

```
# Run after the scene finishes loading
CrossfadeToMusic → music_path: "res://audio/level2_bgm.ogg", volume: 0.8, crossfade_duration: 3.0
```

### 2. Pause Menu

Pause all playing audio when the pause menu opens, and resume when it closes:

```
# Pause
PauseResumeAudio → action_mode: Pause, target_mode: All Playing

# Resume
PauseResumeAudio → action_mode: Resume, target_mode: All Playing
```

### 3. Rhythm Game - Music Sync

Use `OnMusicBeat` to trigger visuals or game logic on the BPM:

```
# Event: fires on every beat (120 BPM)
OnMusicBeat → bpm: 120, beat_interval: 1, emit_beat_count: true

# Downstream instructions: run animations, spawn notes, etc. based on beat_count
```
