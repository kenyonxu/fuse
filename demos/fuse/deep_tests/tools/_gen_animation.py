import sys, json
sys.path.insert(0, "E:/GitHub/fuse/demos/fuse/deep_tests/tools")
from preset_gen import *

def binding(event, instructions, once=True):
    return {"event": event,
            "binding_config": {"enabled": True, "trigger_once": once, "cooldown_mode": 0, "cooldown_time": 1.0},
            "action_runner": {"execution_mode": 0, "instructions": instructions}}

def cnp(node, prop, val):
    return {"type": "CheckNodeProperty", "target_node_path": node, "property_name": prop, "property_value": val}

SPRITE = "../PlayerSprites"
AP = "../PlayerSprites/AnimationPlayer"
TREE = "../AnimationTree"

m = []
m.append(pr("=== deep_animation START ==="))
m.append(I("Wait", wait_time=0.3))
# --- AnimatedSprite2D 组 ---
# 1 AnimatedSprite2DPlay: run
m.append(I("AnimatedSprite2DPlay", target_node=SPRITE, animation_name="run"))
m.append(I("Wait", wait_time=0.2))
m.append(check("AnimatedSprite2DPlay+CheckIsPlaying", {"type": "CheckIsPlaying", "target_node": SPRITE}))
# 2 AnimatedSprite2DIsPlaying
m.append(I("AnimatedSprite2DIsPlaying", target_node=SPRITE, save_to_variable="playing"))
m.append(check("AnimatedSprite2DIsPlaying", cv_eq("playing", True)))
# 3 CheckIsAnimation（当前正在播 run）
m.append(check("CheckIsAnimation(run)", {"type": "CheckIsAnimation", "target_node": SPRITE, "animation_name": "run"}))
# 4 SetSpriteFlip 水平翻转
m.append(I("SetSpriteFlip", target_node=SPRITE, flip_mode=0, flip_h=True))
m.append(check("SetSpriteFlip", cnp(SPRITE, "flip_h", True)))
m.append(I("SetSpriteFlip", target_node=SPRITE, flip_mode=0, flip_h=False))
# 5 SetSpriteFrame
m.append(I("SetSpriteFrame", target_node=SPRITE, frame=3))
m.append(check("SetSpriteFrame", cnp(SPRITE, "frame", 3)))
# 6 SpeedScale：读→设2.0→读
m.append(I("GetAnimatedSprite2DSpeedScale", target_node=SPRITE, save_to_variable="ss0"))
m.append(I("SetAnimatedSprite2DSpeedScale", target_node=SPRITE, speed_scale=2.0))
m.append(I("GetAnimatedSprite2DSpeedScale", target_node=SPRITE, save_to_variable="ss1"))
m.append(check("Get/SetAnimatedSprite2DSpeedScale", cv_eq("ss1", 2.0)))
m.append(I("SetAnimatedSprite2DSpeedScale", target_node=SPRITE, speed_scale=1.0))
# --- AnimationPlayer 组 ---
# 7 GetAnimationLength(player/hit) > 0
m.append(I("GetAnimationLength", target_node=AP, animation_name="player/hit", save_to_variable="alen"))
m.append(check("GetAnimationLength", cv_op("alen", 2, 0)))
# 8 PlayAnimation(player/hit) + OnAnimationFinished 事件侧
m.append(I("PlayAnimation", target_player=AP, animation_name="player/hit", speed=1.0))
m.append(pr("PASS: PlayAnimation(执行级，OnAnimationFinished 侧验证)"))
m.append(I("Wait", wait_time=1.0))
# 9 SetAnimationSpeed
m.append(I("SetAnimationSpeed", target_node=AP, speed_scale=0.5))
m.append(check("SetAnimationSpeed", cnp(AP, "speed_scale", 0.5)))
m.append(I("SetAnimationSpeed", target_node=AP, speed_scale=1.0))
# 10 StopAnimation（再放一个后停）
m.append(I("PlayAnimation", target_player=AP, animation_name="player/run", speed=1.0))
m.append(I("Wait", wait_time=0.2))
m.append(I("StopAnimation", target_node=AP, keep_position=False))
m.append(check("StopAnimation(非播放)", cnp(AP, "is_playing", False)))
# 11 CheckAnimationFinished（停后 hit 已完? 直接执行级）
m.append(check("CheckAnimationFinished(执行)", {"type": "CheckAnimationFinished", "target_node": AP, "animation_name": "player/hit"}))
# --- AnimationTree 组 ---
# 12 SetAnimationTreeParameter(conditions/hit=true) + Check
m.append(I("SetAnimationTreeParameter", target_node=TREE, parameter_name="conditions/hit", parameter_type=1, bool_value=True))
m.append(check("SetAnimationTreeParameter+CheckAnimationTreeParameter",
               {"type": "CheckAnimationTreeParameter", "target_node": TREE, "parameter_name": "conditions/hit", "parameter_type": 1, "compare_type": 0, "compare_value": 1.0}))
# 13 SetAnimationBlendPosition / BlendAnimation（树含 BlendSpace 时生效，执行级）
m.append(I("SetAnimationBlendPosition", target_node=TREE, blend_node="parameters/PlayerNormal/blend_position", x=0.5, y=0.0))
m.append(pr("PASS(m): SetAnimationBlendPosition(F5)"))
m.append(I("BlendAnimation", target_tree=TREE, blend_path="parameters/PlayerNormal/blend_position", blend_amount=1.0))
m.append(pr("PASS(m): BlendAnimation(F5)"))
# 14 CheckAnimationTreeState（执行级——状态名依 STM 而定）
m.append(check("CheckAnimationTreeState(执行)", {"type": "CheckAnimationTreeState", "target_node": TREE, "state_machine_path": "parameters/PlayerNormal/playback", "target_state_name": "idle"}))
m.append(I("Wait", wait_time=1.5))
m.append(pr("=== deep_animation DONE ==="))

ps = {"format_version": "2.0", "level": "L4", "display_name": "DeepAnimation", "category": "animation",
      "description": "深度测试·Animation：13 指令 + 5 条件 + 6 事件（base 为 player.tscn 三件套抽离）",
      "icon_name": "", "variables": {"local": [], "scope": [], "global": []},
      "trigger_config": {"use_parallel_condition_evaluation": False},
      "event_bindings": [
          binding({"type": "OnReady"}, m),
          binding({"type": "OnAnimationStarted", "target_node_path": SPRITE, "animation_name": "run"}, [pr("PASS: OnAnimationStarted")]),
          binding({"type": "OnAnimationLoop", "target_node_path": SPRITE, "animation_name": "run", "trigger_mode": 0}, [pr("PASS: OnAnimationLoop")]),
          binding({"type": "OnAnimationFinished", "animation_player": AP, "animation_name": "player/hit"}, [pr("PASS: OnAnimationFinished")]),
          binding({"type": "OnAnimationFrameReached", "animation_player_path": AP, "animation_name": "player/hit", "target_frame": 2}, [pr("PASS: OnAnimationFrameReached")]),
          binding({"type": "OnAnimationMarker", "target_node_path": AP, "animation_name": "player/hit", "marker_name": "hit_mark"}, [pr("PASS(m): OnAnimationMarker(库无标记轨则不触发)")]),
          binding({"type": "OnAnimationBlend", "animation_tree_path": TREE, "blend_path": "parameters/PlayerNormal/blend_position", "threshold": 0.3}, [pr("PASS(m): OnAnimationBlend(F5)")]),
      ]}
declare_local_variables(ps)
print(json.dumps(ps, ensure_ascii=False, indent=2))
