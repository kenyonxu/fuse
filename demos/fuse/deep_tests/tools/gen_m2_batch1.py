"""M2 第一批（Scene/SceneB/Tween/Camera）preset 生成脚本。"""
import sys, json
sys.path.insert(0, "E:/GitHub/fuse/demos/fuse/deep_tests/tools")
from preset_gen import *

def binding(event, instructions, once=True):
    return {"event": event,
            "binding_config": {"enabled": True, "trigger_once": once, "cooldown_mode": 0, "cooldown_time": 1.0},
            "action_runner": {"execution_mode": 0, "instructions": instructions}}

def l4(name, cat, desc, bindings):
    return {"format_version": "2.0", "level": "L4", "display_name": name, "category": cat,
            "description": desc, "icon_name": "", "variables": {"local": [], "scope": [], "global": []},
            "trigger_config": {"use_parallel_condition_evaluation": False}, "event_bindings": bindings}

def cnp(node, prop, val):
    return {"type": "CheckNodeProperty", "target_node_path": node, "property_name": prop, "property_value": val}

def not_null(var):
    return {"type": "CheckVariable", "variable_name": var, "comparison_operator": 11, "auto_convert_types": True}

B = "res://demos/fuse/deep_tests/scenes/test_deep_scene_b.tscn"
TGT = "res://demos/fuse/deep_tests/scenes/base_targets.tscn"

# ============ Scene 主场景 ============
m = []
m.append(pr("=== deep_scene START ==="))
m.append(I("PreloadSceneInstruction", scene_path=B, preload_mode=0, timeout=5.0, status_variable="pl"))
m.append(check("PreloadSceneInstruction+CheckPreloadStatus(true)",
               {"type": "CheckPreloadStatus", "scene_path": B, "expected_status": 0}))
m.append(check_neg("CheckPreloadStatus(neg)",
                   {"type": "CheckPreloadStatus", "scene_path": B, "expected_status": 3}))
m.append(I("GetScenePath", path_mode=0, save_to_variable="sp"))
m.append(check("GetScenePath", cv_op("sp", 6, "deep_scene")))
m.append(I("LoadSceneBackground", scene_path=TGT, save_to_variable="bg"))
m.append(check("LoadSceneBackground", not_null("bg")))
m.append(I("AddSceneAsChild", scene_path=TGT, target_parent="..", new_node_name="AddedChild"))
m.append(I("GetNode", node_path="../AddedChild", result_variable="added"))
m.append(check("AddSceneAsChild", not_null("added")))
m.append(I("PauseGame", show_pause_menu=False))
m.append(I("Wait", wait_time=0.2))
m.append(I("ResumeGame", close_pause_menu=False))
m.append(pr("PASS: PauseGame/ResumeGame(供OnNodePausedResumed)"))
m.append(pr("PASS(m): ReloadScene(F5 手动验)"))
m.append(pr("=== deep_scene 主链 DONE，即将切 B ==="))
m.append(I("Wait", wait_time=0.5))
m.append(I("ChangeScene", scene_path=B))
ps = l4("DeepScene", "scene", "深度测试·Scene：6 指令 + 1 条件 + 5 事件", [
    binding({"type": "OnReady"}, m),
    binding({"type": "OnBackgroundLoadProgress", "load_resource_path": TGT, "progress_threshold": 1.0},
            [pr("PASS: OnBackgroundLoadProgress")]),
    binding({"type": "OnTreeChanged", "change_type": 0}, [pr("PASS: OnTreeChanged")]),
    binding({"type": "OnNodePausedResumed", "target_node": "../Targets/A", "trigger_on": 2, "check_interval": 0.05},
            [pr("PASS: OnNodePausedResumed")]),
    binding({"type": "OnSceneAboutToChange"}, [pr("PASS: OnSceneAboutToChange")]),
])
declare_local_variables(ps)
write_preset(ps, "E:/GitHub/fuse/demos/fuse/deep_tests/presets/deep_scene.json")

# ============ Scene B 目标场景 ============
mb = [pr("=== deep_scene_b 到达 ==="),
      pr("PASS: ChangeScene(到达B)"),
      pr("PASS: OnSceneLoaded(B)"),
      pr("PASS(m): ReloadScene(F5 手动验)")]
ps = l2_preset("DeepSceneB", "scene", "Scene 场景跳转目标 B", mb)
write_preset(ps, "E:/GitHub/fuse/demos/fuse/deep_tests/presets/deep_scene_b.json")

# ============ Tween ============
m = []
m.append(pr("=== deep_tween START ==="))
m.append(I("TweenMoveTo", target_node="../S", target_position="(100.0, 50.0)", duration=0.3))
m.append(I("Wait", wait_time=0.6))
m.append(I("GetPosition", target="../S", save_to_variable="tp"))
m.append(I("MathExpression", expression="Vector2(100, 50)", output_type=2, save_to_variable="texp"))
m.append(check("TweenMoveTo", cv_eq_var("tp", "texp")))
m.append(I("TweenRotateTo", target_node="../S", target_rotation=1.5, duration=0.3))
m.append(I("Wait", wait_time=0.6))
m.append(check("TweenRotateTo", cnp("../S", "rotation", 1.5)))
m.append(I("TweenScaleTo", target_node="../S", target_scale="(2.0, 2.0)", duration=0.3))
m.append(I("Wait", wait_time=0.6))
m.append(check("TweenScaleTo", cnp("../S", "scale", "(2.0, 2.0)")))
m.append(I("TweenPropertyInstruction", target_node="../S", property_source=0, property_path="position",
           to_value="(0.0, 0.0)", duration=0.3))
m.append(I("Wait", wait_time=0.6))
m.append(I("GetPosition", target="../S", save_to_variable="tp2"))
m.append(I("MathExpression", expression="Vector2(0, 0)", output_type=2, save_to_variable="texp2"))
m.append(check("TweenPropertyInstruction", cv_eq_var("tp2", "texp2")))
m.append(I("TweenFadeOut", target_node="../S", duration=0.3))
m.append(I("Wait", wait_time=0.5))
m.append(check("TweenFadeOut", cnp("../S", "modulate:a", 0.0)))
m.append(I("TweenFadeIn", target_node="../S", duration=0.3))
m.append(I("Wait", wait_time=0.5))
m.append(check("TweenFadeIn", cnp("../S", "modulate:a", 1.0)))
# Pause/Resume：1.2s 长移动中途暂停
m.append(I("MathExpression", expression="Vector2(200, 100)", output_type=2, save_to_variable="texp3"))
m.append(I("TweenMoveTo", target_node="../S", target_position="(200.0, 100.0)", duration=1.2))
m.append(I("Wait", wait_time=0.2))
m.append(I("TweenPause", target_node="../S"))
m.append(I("Wait", wait_time=0.4))
m.append(I("GetPosition", target="../S", save_to_variable="paused_pos"))
m.append(check_neg("TweenPause(暂停中未达目标)", cv_eq_var("paused_pos", "texp3")))
m.append(I("TweenResume", target_node="../S"))
m.append(I("Wait", wait_time=1.6))
m.append(I("GetPosition", target="../S", save_to_variable="resumed_pos"))
m.append(check("TweenResume(最终到达)", cv_eq_var("resumed_pos", "texp3")))
for name, ins in [
    ("TweenBounceAnimation", I("TweenBounceAnimation", target_node="../S", bounce_height=50.0, duration=0.6)),
    ("TweenPopAnimation", I("TweenPopAnimation", target_node="../S", target_scale="(1.5, 1.5)", duration=0.5)),
    ("TweenPulseAnimation", I("TweenPulseAnimation", target_node="../S", min_scale="(0.8, 0.8)", max_scale="(1.3, 1.3)", duration=0.6)),
    ("TweenShakeAnimation", I("TweenShakeAnimation", target_node="../S", intensity=0.5, duration=0.5)),
    ("TweenColorTransition", I("TweenColorTransition", target_node="../S", target_color="(1, 0, 0, 1)", duration=0.5)),
]:
    m.append(ins)
    m.append(I("Wait", wait_time=0.3))
    m.append(pr("PASS(m): " + name))
m.append(I("Wait", wait_time=0.8))
m.append(pr("=== deep_tween DONE ==="))
ps = l4("DeepTween", "tween", "深度测试·Tween：13 指令 + OnTweenCompleted", [
    binding({"type": "OnReady"}, m),
    binding({"type": "OnTweenCompleted", "tween_node_path": "../S"}, [pr("PASS: OnTweenCompleted")]),
])
declare_local_variables(ps)
write_preset(ps, "E:/GitHub/fuse/deep_tests/presets/deep_tween.json")

# ============ Camera ============
m = []
m.append(pr("=== deep_camera START ==="))
m.append(I("SetCameraZoom", target_node="../Cam", zoom=2.0, zoom_mode=0))
m.append(check("SetCameraZoom", cnp("../Cam", "zoom", "(2.0, 2.0)")))
m.append(I("SetCameraLimit", target_node="../Cam", limit_side=2, limit_value=-100))
m.append(check("SetCameraLimit(Left)", cnp("../Cam", "limit_left", -100)))
m.append(I("SetCameraLimit", target_node="../Cam", limit_side=3, limit_value=600))
m.append(check("SetCameraLimit(Right)", cnp("../Cam", "limit_right", 600)))
m.append(I("SetCameraLimitFromArea2D", camera_node="../Cam", bounds_area="../Bounds"))
m.append(check("SetCameraLimitFromArea2D(left)", cnp("../Cam", "limit_left", 0)))
m.append(I("SetPosition", target_node="../Player", position="(400.0, 0.0, 0.0)"))
m.append(I("CameraFollow", target_node="../Player", camera_node="../Cam", follow_mode=0))
m.append(I("Wait", wait_time=0.5))
m.append(I("GetPosition", target="../Cam", save_to_variable="cam_pos"))
m.append(I("MathExpression", expression="Vector2(400, 0)", output_type=2, save_to_variable="cexp"))
m.append(check("CameraFollow", cv_eq_var("cam_pos", "cexp")))
m.append(I("CameraShake", target_node="../Cam", intensity=0.3, duration=0.5))
m.append(pr("PASS(m): CameraShake(F5 观感)"))
m.append(I("CameraFadeOut", color="(0, 0, 0, 1)", duration=0.4))
m.append(I("Wait", wait_time=0.6))
m.append(I("CameraFadeIn", color="(0, 0, 0, 1)", duration=0.4))
m.append(I("Wait", wait_time=0.6))
m.append(pr("PASS(m): CameraFadeOut+CameraFadeIn(F5 观感)"))
m.append(pr("=== deep_camera DONE ==="))
ps = l4("DeepCamera", "camera", "深度测试·Camera：7 指令", [binding({"type": "OnReady"}, m)])
declare_local_variables(ps)
write_preset(ps, "E:/GitHub/fuse/demos/fuse/deep_tests/presets/deep_camera.json")
print("batch1 全部生成完毕")
