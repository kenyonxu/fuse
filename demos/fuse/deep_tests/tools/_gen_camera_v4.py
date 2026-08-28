import sys, json
sys.path.insert(0, "E:/GitHub/fuse/demos/fuse/deep_tests/tools")
from preset_gen import *

def binding(event, instructions, once=True):
    return {"event": event,
            "binding_config": {"enabled": True, "trigger_once": once, "cooldown_mode": 0, "cooldown_time": 1.0},
            "action_runner": {"execution_mode": 0, "instructions": instructions}}

def cnp(node, prop, val):
    return {"type": "CheckNodeProperty", "target_node_path": node, "property_name": prop, "property_value": val}

m1 = []
m1.append(pr("=== deep_camera START（2 秒后开始，请盯住游戏窗口）==="))
m1.append(I("Wait", wait_time=2.0))
m1.append(pr(">>> [F5] 阶段1/5：变焦 zoom=2.0 —— 画面放大一倍"))
m1.append(I("SetCameraZoom", target_node="../Cam", zoom=2.0, zoom_mode=0))
m1.append(check("SetCameraZoom", cnp("../Cam", "zoom", "(2.0, 2.0)")))
m1.append(I("Wait", wait_time=2.5))
m1.append(pr(">>> [F5] 阶段2/5：相机锁定跟随 Player(0,0) —— 画面瞬移到左下角"))
m1.append(I("SetPosition", target_node="../Player", position="(0.0, 0.0, 0.0)"))
m1.append(I("CameraFollow", target_node="../Player", camera_node="../Cam", follow_mode=0))
m1.append(I("Wait", wait_time=0.3))
m1.append(I("GetPosition", target="../Cam", save_to_variable="cam_pos"))
m1.append(I("MathExpression", expression="Vector2(0, 0)", output_type=2, save_to_variable="cexp"))
m1.append(check("CameraFollow(锁定0,0)", cv_eq_var("cam_pos", "cexp")))
m1.append(I("Wait", wait_time=2.0))
m1.append(pr(">>> [F5] 阶段3/5：Player→(600,0) 相机跟跳；随后设右边界 400、Player 冲 900 —— 画面卡在边界"))
m1.append(I("SetPosition", target_node="../Player", position="(600.0, 0.0, 0.0)"))
m1.append(I("Wait", wait_time=0.5))
m1.append(I("GetPosition", target="../Cam", save_to_variable="cam_pos2"))
m1.append(I("MathExpression", expression="Vector2(600, 0)", output_type=2, save_to_variable="cexp2"))
m1.append(check("CameraFollow(跟随600)", cv_eq_var("cam_pos2", "cexp2")))
m1.append(I("Wait", wait_time=1.5))
m1.append(I("SetCameraLimit", target_node="../Cam", limit_side=2, limit_value=-100))
m1.append(check("SetCameraLimit(Left)", cnp("../Cam", "limit_left", -100)))
m1.append(I("SetCameraLimit", target_node="../Cam", limit_side=3, limit_value=400))
m1.append(check("SetCameraLimit(Right)", cnp("../Cam", "limit_right", 400)))
m1.append(I("SetPosition", target_node="../Player", position="(900.0, 0.0, 0.0)"))
m1.append(I("Wait", wait_time=2.5))
m1.append(pr(">>> [F5] 阶段4/5：Area2D 边界（0..200 盒子）—— 画面被拉回中央小区"))
m1.append(I("SetCameraLimitFromArea2D", camera_node="../Cam", bounds_area="../Bounds"))
m1.append(check("SetCameraLimitFromArea2D(left)", cnp("../Cam", "limit_left", 0)))
m1.append(I("Wait", wait_time=2.5))
m1.append(pr(">>> [F5] 阶段5/5：Player 静止回中央，随后另一链执行震动与淡出"))
m1.append(I("SetPosition", target_node="../Player", position="(100.0, 50.0, 0.0)"))
m1.append(I("Wait", wait_time=1.0))
m1.append(pr("=== 绑定1 DONE（跟随与边界）==="))

m2 = []
m2.append(I("Wait", wait_time=16.0))
m2.append(pr(">>> [F5] 附加A：相机震动 1.0s"))
m2.append(I("CameraShake", target_node="../Cam", intensity=0.3, duration=1.0))
m2.append(pr("PASS(m): CameraShake(F5 观感)"))
m2.append(I("Wait", wait_time=2.0))
m2.append(pr(">>> [F5] 附加B：淡出→淡入"))
m2.append(I("CameraFadeOut", color="(0, 0, 0, 1)", duration=0.6))
m2.append(I("Wait", wait_time=0.9))
m2.append(I("CameraFadeIn", color="(0, 0, 0, 1)", duration=0.6))
m2.append(I("Wait", wait_time=0.9))
m2.append(pr("PASS(m): CameraFadeOut+CameraFadeIn(F5 观感)"))
m2.append(pr(">>> [F5] 终态复位：zoom=1.0"))
m2.append(I("SetCameraZoom", target_node="../Cam", zoom=1.0, zoom_mode=0))
m2.append(pr("=== deep_camera DONE ==="))

ps = {"format_version": "2.0", "level": "L4", "display_name": "DeepCamera", "category": "camera",
      "description": "深度测试·Camera：7 指令（v4：跟随链与效果链分绑定）",
      "icon_name": "", "variables": {"local": [], "scope": [], "global": []},
      "trigger_config": {"use_parallel_condition_evaluation": False},
      "event_bindings": [binding({"type": "OnReady"}, m1), binding({"type": "OnReady"}, m2)]}
declare_local_variables(ps)
print(json.dumps(ps, ensure_ascii=False, indent=2))
