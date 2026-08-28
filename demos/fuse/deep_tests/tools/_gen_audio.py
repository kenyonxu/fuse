import sys, json
sys.path.insert(0, "E:/GitHub/fuse/demos/fuse/deep_tests/tools")
from preset_gen import *

def binding(event, instructions, once=True):
    return {"event": event,
            "binding_config": {"enabled": True, "trigger_once": once, "cooldown_mode": 0, "cooldown_time": 1.0},
            "action_runner": {"execution_mode": 0, "instructions": instructions}}

def cnp(node, prop, val):
    return {"type": "CheckNodeProperty", "target_node_path": node, "property_name": prop, "property_value": val}

SFX = "res://demos/fuse/fuse_adventure/resources/sfx/"
MUSIC = "res://demos/fuse/fuse_adventure/resources/music/SpaceBattle_8bit_final.wav"

# 绑定1：音效指令链
m1 = []
m1.append(pr("=== deep_audio START ==="))
m1.append(I("Wait", wait_time=0.3))
m1.append(I("PlaySound", sound_path=SFX + "jumps/sfx_movement_jump1.wav", volume=0.8))
m1.append(pr("PASS: PlaySound(执行级)"))
m1.append(I("PlayRandomSound", sound_paths=[SFX + "coins/sfx_coin_cluster1.wav", SFX + "coins/sfx_coin_cluster3.wav", SFX + "coins/sfx_coin_cluster4.wav"], volume=0.8))
m1.append(pr("PASS: PlayRandomSound(执行级)"))
m1.append(I("SetAudioVolume", target_mode=1, bus="Master", volume=0.5))
m1.append(pr("PASS(m): SetAudioVolume(bus内播放器 0.5)"))
m1.append(pr("=== 绑定1 DONE（音效链）==="))

# 绑定2：音乐（PlayMusic 为长指令——曲目播完才完成，打印置于前）
m2 = [I("Wait", wait_time=0.5),
      pr("PASS(m): PlayMusic(已启动；指令在曲目 37.8s 播完后才自然完成，F5 听淡入)") ,
      I("PlayMusic", music_path=MUSIC, volume=0.6, fade_in=True, fade_duration=0.3)]

# 绑定3：暂停/恢复音乐（名称模式靶向 Fuse_MusicPlayer*）+ 交叉淡化 + 停止
m3 = [I("Wait", wait_time=2.5),
      I("PauseResumeAudio", target_mode=2, name_pattern="Fuse_MusicPlayer*", action_mode=0),
      pr("PASS(m): PauseResumeAudio(暂停音乐 1.5s，F5 听静音)"),
      I("Wait", wait_time=1.5),
      I("PauseResumeAudio", target_mode=2, name_pattern="Fuse_MusicPlayer*", action_mode=1),
      pr("PASS(m): PauseResumeAudio(恢复音乐，F5 听回归)"),
      I("Wait", wait_time=1.0),
      I("CrossfadeToMusic", music_path=MUSIC, volume=0.5, crossfade_duration=1.0),
      pr("PASS(m): CrossfadeToMusic(F5 听交叉淡化)"),
      I("Wait", wait_time=1.5),
      I("StopAudio", stop_mode=0, fade_out=True, fade_duration=0.5),
      I("Wait", wait_time=1.0),
      check("StopAudio(AP1停)", cnp("../AP1", "playing", False)),
      pr("=== deep_audio DONE ===")]

ps = {"format_version": "2.0", "level": "L4", "display_name": "DeepAudio", "category": "audio",
      "description": "深度测试·Audio：7 指令 + 4 事件 v2（PlayMusic 长指令语义/暂停恢复靶向音乐/节拍事件修复后可 headless 验证）",
      "icon_name": "", "variables": {"local": [], "scope": [], "global": []},
      "trigger_config": {"use_parallel_condition_evaluation": False},
      "event_bindings": [
          binding({"type": "OnReady"}, m1),
          binding({"type": "OnReady"}, m2),
          binding({"type": "OnReady"}, m3),
          binding({"type": "OnAudioStarted", "audio_player_path": "../AP1"}, [pr("PASS(m): OnAudioStarted(F5)")]),
          binding({"type": "OnAudioFinished", "audio_player_path": "../AP1"}, [pr("PASS(m): OnAudioFinished(F5)")]),
          binding({"type": "OnAudioBusVolumeChanged", "bus_name": "Master", "trigger_on_any_change": True}, [pr("PASS(m): OnAudioBusVolumeChanged(F5)")]),
          binding({"type": "OnMusicBeat", "bpm": 120.0, "beat_interval": 1}, [pr("PASS: OnMusicBeat")]),
      ]}
declare_local_variables(ps)
print(json.dumps(ps, ensure_ascii=False, indent=2))
