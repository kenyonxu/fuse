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
