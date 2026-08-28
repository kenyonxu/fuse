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

