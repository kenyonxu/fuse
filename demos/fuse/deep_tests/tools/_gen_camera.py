"""M2 Camera preset——F5 观感版：阶段提示 + 步间停顿 + 终态复位。"""
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
m.append(pr("=== deep_camera START（每步约 1.5s，跟着控制台提示看画面）==="))
# 阶段1：zoom 2.0
m.append(pr(">>> [F5] 阶段1：变焦 zoom=2.0（画面放大）"))
m.append(I("SetCameraZoom", target_node="../Cam", zoom=2.0, zoom_mode=0))
m.append(check("SetCameraZoom", cnp("../Cam", "zoom", "(2.0, 2.0)")))
m.append(I("Wait", wait_time=1.5))
# 阶段2：手动边界
m.append(pr(">>> [F5] 阶段2：相机边界 Left=-100 Right=600（拖不出去）"))
m.append(I("SetCameraLimit", target_node="../Cam", limit_side=2, limit_value=-100))
m.append(check("SetCameraLimit(Left)", cnp("../Cam", "limit_left", -100)))
m.append(I("SetCameraLimit", target_node="../Cam", limit_side=3, limit_value=600))
m.append(check("SetCameraLimit(Right)", cnp("../Cam", "limit_right", 600)))
m.append(I("Wait", wait_time=1.5))
# 阶段3：Area2D 边界
m.append(pr(">>> [F5] 阶段3：从 Area2D 取边界（0..200 x 0..100 盒子）"))
m.append(I("SetCameraLimitFromArea2D", camera_node="../Cam", bounds_area="../Bounds"))
m.append(check("SetCameraLimitFromArea2D(left)", cnp("../Cam", "limit_left", 0)))
m.append(I("Wait", wait_time=1.5))
# 阶段4：跟随
m.append(pr(">>> [F5] 阶段4：相机跳去跟随 Player(400,0)（受边界钳制）"))
m.append(I("SetPosition", target_node="../Player", position="(400.0, 0.0, 0.0)"))
m.append(I("CameraFollow", target_node="../Player", camera_node="../Cam", follow_mode=0))
m.append(I("Wait", wait_time=0.5))
m.append(I("GetPosition", target="../Cam", save_to_variable="cam_pos"))
m.append(I("MathExpression", expression="Vector2(400, 0)", output_type=2, save_to_variable="cexp"))
m.append(check("CameraFollow", cv_eq_var("cam_pos", "cexp")))
m.append(I("Wait", wait_time=1.5))
# 阶段5：震动
m.append(pr(">>> [F5] 阶段5：相机震动 0.8s"))
m.append(I("CameraShake", target_node="../Cam", intensity=0.3, duration=0.8))
m.append(pr("PASS(m): CameraShake(F5 观感)"))
m.append(I("Wait", wait_time=1.5))
# 阶段6：淡出淡入
m.append(pr(">>> [F5] 阶段6：淡出→淡入"))
m.append(I("CameraFadeOut", color="(0, 0, 0, 1)", duration=0.6))
m.append(I("Wait", wait_time=0.9))
m.append(I("CameraFadeIn", color="(0, 0, 0, 1)", duration=0.6))
m.append(I("Wait", wait_time=0.9))
m.append(pr("PASS(m): CameraFadeOut+CameraFadeIn(F5 观感)"))
# 终态复位：zoom 1.0 + Player 回画面中心，方便继续观察/加节点
m.append(pr(">>> [F5] 终态复位：zoom=1.0，Player 回 (100,50)——此刻画面应稳定可见"))
m.append(I("SetCameraZoom", target_node="../Cam", zoom=1.0, zoom_mode=0))
m.append(I("SetPosition", target_node="../Player", position="(100.0, 50.0, 0.0)"))
m.append(I("Wait", wait_time=1.0))
m.append(pr("=== deep_camera DONE ==="))
ps = l4("DeepCamera", "camera", "深度测试·Camera：7 指令（F5 观感版：阶段提示+停顿+终态复位）", [binding({"type": "OnReady"}, m)])
declare_local_variables(ps)
write_preset(ps, "E:/GitHub/fuse/demos/fuse/deep_tests/presets/deep_camera.json")
