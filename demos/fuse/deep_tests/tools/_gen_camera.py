"""M2 Camera preset——F5 观感版 v3：震动/淡出前置（相机自由态），跟随与边界后置。"""
import sys
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


m = []
m.append(pr("=== deep_camera START（2 秒后开始，请盯住游戏窗口）==="))
m.append(I("Wait", wait_time=2.0))

# 阶段1：zoom 1→2（相机自由态）
m.append(pr(">>> [F5] 阶段1/6：变焦 zoom=2.0 —— 画面放大一倍"))
m.append(I("SetCameraZoom", target_node="../Cam", zoom=2.0, zoom_mode=0))
m.append(check("SetCameraZoom", cnp("../Cam", "zoom", "(2.0, 2.0)")))
m.append(I("Wait", wait_time=2.5))

# 阶段2：震动（自由态，无跟随冲突）
m.append(pr(">>> [F5] 阶段2/6：相机震动 1.0s"))
m.append(I("CameraShake", target_node="../Cam", intensity=0.3, duration=1.0))
m.append(pr("PASS(m): CameraShake(F5 观感)"))
m.append(I("Wait", wait_time=2.0))

# 阶段3：淡出淡入
m.append(pr(">>> [F5] 阶段3/6：淡出→淡入"))
m.append(I("CameraFadeOut", color="(0, 0, 0, 1)", duration=0.6))
m.append(I("Wait", wait_time=0.9))
m.append(I("CameraFadeIn", color="(0, 0, 0, 1)", duration=0.6))
m.append(I("Wait", wait_time=0.9))
m.append(pr("PASS(m): CameraFadeOut+CameraFadeIn(F5 观感)"))
m.append(I("Wait", wait_time=1.5))

# 阶段4：跟随锁定（无边界，瞬移可见）
m.append(pr(">>> [F5] 阶段4/6：相机锁定跟随 Player(0,0) —— 画面瞬移到左下角"))
m.append(I("SetPosition", target_node="../Player", position="(0.0, 0.0, 0.0)"))
m.append(I("CameraFollow", target_node="../Player", camera_node="../Cam", follow_mode=0))
m.append(I("Wait", wait_time=0.3))
m.append(I("GetPosition", target="../Cam", save_to_variable="cam_pos"))
m.append(I("MathExpression", expression="Vector2(0, 0)", output_type=2, save_to_variable="cexp"))
m.append(check("CameraFollow(锁定0,0)", cv_eq_var("cam_pos", "cexp")))
m.append(I("Wait", wait_time=2.0))

# 阶段5：跟随目标移动 + 手动边界
m.append(pr(">>> [F5] 阶段5/6：Player→(600,0) 相机跟跳；随后设右边界 400、Player 冲 900 —— 画面卡在边界"))
m.append(I("SetPosition", target_node="../Player", position="(600.0, 0.0, 0.0)"))
m.append(I("Wait", wait_time=0.5))
m.append(I("GetPosition", target="../Cam", save_to_variable="cam_pos2"))
m.append(I("MathExpression", expression="Vector2(600, 0)", output_type=2, save_to_variable="cexp2"))
m.append(check("CameraFollow(跟随600)", cv_eq_var("cam_pos2", "cexp2")))
m.append(I("Wait", wait_time=1.5))
m.append(I("SetCameraLimit", target_node="../Cam", limit_side=2, limit_value=-100))
m.append(check("SetCameraLimit(Left)", cnp("../Cam", "limit_left", -100)))
m.append(I("SetCameraLimit", target_node="../Cam", limit_side=3, limit_value=400))
m.append(check("SetCameraLimit(Right)", cnp("../Cam", "limit_right", 400)))
m.append(I("SetPosition", target_node="../Player", position="(900.0, 0.0, 0.0)"))
m.append(I("Wait", wait_time=2.5))

# 阶段6：Area2D 边界
m.append(pr(">>> [F5] 阶段6/6：Area2D 边界（0..200 盒子）—— 画面被拉回中央小区"))
m.append(I("SetCameraLimitFromArea2D", camera_node="../Cam", bounds_area="../Bounds"))
m.append(check("SetCameraLimitFromArea2D(left)", cnp("../Cam", "limit_left", 0)))
m.append(I("Wait", wait_time=2.5))

# 终态复位
m.append(pr(">>> [F5] 终态复位：zoom=1.0、Player 回 (100,50)——画面稳定居中"))
m.append(I("SetCameraZoom", target_node="../Cam", zoom=1.0, zoom_mode=0))
m.append(I("SetPosition", target_node="../Player", position="(100.0, 50.0, 0.0)"))
m.append(I("Wait", wait_time=1.0))
m.append(pr("=== deep_camera DONE ==="))
ps = l4("DeepCamera", "camera", "深度测试·Camera：7 指令（F5 观感版 v3：震动淡出前置避开跟随冲突）", [binding({"type": "OnReady"}, m)])
declare_local_variables(ps)
write_preset(ps, "E:/GitHub/fuse/demos/fuse/deep_tests/presets/deep_camera.json")
