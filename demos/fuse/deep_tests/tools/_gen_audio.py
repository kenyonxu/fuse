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

# 绑定1：状态断言主链（headless 可判定）
m1 = []
m1.append(pr("=== deep_audio START ==="))
m1.append(I("Wait", wait_time=0.3))
m1.append(I("PlaySound", sound_path=SFX + "jumps/sfx_movement_jump1.wav", volume=0.8))
m1.append(pr("PASS: PlaySound(执行级)"))
m1.append(I("PlayRandomSound", sound_paths=[SFX + "coins/sfx_coin_cluster1.wav", SFX + "coins/sfx_coin_cluster3.wav", SFX + "coins/sfx_coin_cluster4.wav"], volume=0.8))
m1.append(pr("PASS: PlayRandomSound(执行级)"))
m1.append(I("SetAudioVolume", target_mode=1, bus="Master", volume=0.5))
m1.append(I("Wait", wait_time=0.4))
m1.append(pr("PASS(m): SetAudioVolume(bus 0.5，事件侧验证)"))
m1.append(I("PauseResumeAudio", target_player="../AP1", action_mode=0))
m1.append(I("Wait", wait_time=0.3))
m1.append(check("PauseResumeAudio(暂停)", cnp("../AP1", "stream_paused", True)))
m1.append(I("PauseResumeAudio", target_player="../AP1", action_mode=1))
m1.append(I("Wait", wait_time=0.3))
m1.append(check("PauseResumeAudio(恢复)", cnp("../AP1", "stream_paused", False)))
m1.append(I("StopAudio", stop_mode=0, fade_out=True, fade_duration=0.3))
m1.append(I("Wait", wait_time=0.8))
m1.append(check("StopAudio(AP1停)", cnp("../AP1", "playing", False)))
m1.append(pr("=== 绑定1 DONE（指令链）==="))

# 绑定2：PlayMusic（隔离——headless 淡入 await 可能不归）
m2 = [I("Wait", wait_time=0.5),
      I("PlayMusic", music_path=MUSIC, volume=0.6, fade_in=True, fade_duration=0.3),
      pr("PASS(m): PlayMusic(F5 听感)")]

# 绑定3：CrossfadeToMusic（更晚启动）
m3 = [I("Wait", wait_time=3.0),
      I("CrossfadeToMusic", music_path=MUSIC, volume=0.5, crossfade_duration=0.5),
      pr("PASS(m): CrossfadeToMusic(F5 听感)")]

ps = {"format_version": "2.0", "level": "L4", "display_name": "DeepAudio", "category": "audio",
      "description": "深度测试·Audio：7 指令 + 4 事件（音乐类指令独立绑定隔离 headless 挂起）",
      "icon_name": "", "variables": {"local": [], "scope": [], "global": []},
      "trigger_config": {"use_parallel_condition_evaluation": False},
      "event_bindings": [
          binding({"type": "OnReady"}, m1),
          binding({"type": "OnReady"}, m2),
          binding({"type": "OnReady"}, m3),
          binding({"type": "OnAudioStarted", "audio_player_path": "../AP1"}, [pr("PASS(m): OnAudioStarted(F5)")]),
          binding({"type": "OnAudioFinished", "audio_player_path": "../AP1"}, [pr("PASS(m): OnAudioFinished(F5)")]),
          binding({"type": "OnAudioBusVolumeChanged", "bus_name": "Master", "trigger_on_any_change": True}, [pr("PASS: OnAudioBusVolumeChanged")]),
          binding({"type": "OnMusicBeat", "bpm": 120.0, "beat_interval": 1}, [pr("PASS(m): OnMusicBeat(F5)")]),
      ]}
declare_local_variables(ps)
print(json.dumps(ps, ensure_ascii=False, indent=2))
