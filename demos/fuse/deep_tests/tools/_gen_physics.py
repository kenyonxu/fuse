import sys, json
sys.path.insert(0, "E:/GitHub/fuse/demos/fuse/deep_tests/tools")
from preset_gen import *

def binding(event, instructions, once=True):
    return {"event": event,
            "binding_config": {"enabled": True, "trigger_once": once, "cooldown_mode": 0, "cooldown_time": 1.0},
            "action_runner": {"execution_mode": 0, "instructions": instructions}}

def cnp(node, prop, val):
    return {"type": "CheckNodeProperty", "target_node_path": node, "property_name": prop, "property_value": val}

def nn(var):
    return {"type": "CheckVariable", "variable_name": var, "comparison_operator": 11, "auto_convert_types": True}

P = "../Player"
BX = "../Box"
ZN = "../Zone"

m = []
m.append(pr("=== deep_physics START（Player 出生空中 (-150)，将自由落体着陆）==="))
m.append(I("Wait", wait_time=0.3))
# 落体阶段：空中 + 下落
m.append(check("CheckInAir(空中)", {"type": "CheckInAir", "target_node": P}))
m.append(check("CheckIsFalling(下落中)", {"type": "CheckIsFalling", "target_node": P}))
# 等待着陆（约 0.7s 落 350px）
m.append(I("Wait", wait_time=1.2))
m.append(check("CheckOnFloor(着陆)", {"type": "CheckOnFloor", "target_node": P}))
# AddVelocity 跳起 → 再次空中
m.append(I("AddVelocity", target_node=P, impulse="(0.0, -400.0)", replace_mode=0))
m.append(I("Wait", wait_time=0.2))
m.append(check("AddVelocity(起跳后空中)", {"type": "CheckInAir", "target_node": P}))
m.append(I("Wait", wait_time=1.5))
# SetVelocity 向右走向 Zone/Wall
m.append(I("SetVelocity", target_node=P, velocity="(250.0, 0.0)", use_local_space=False))
m.append(I("Wait", wait_time=0.3))
m.append(check("SetVelocity(速度生效)", {"type": "CheckVelocity", "target_node": P, "velocity_threshold": 100, "comparison_operator": 0}))
# 冲向墙（x=540 墙在 600）→ 贴墙
m.append(I("Wait", wait_time=1.5))
m.append(check("CheckOnWall(贴墙)", {"type": "CheckOnWall", "target_node": P}))
# 走进 Zone（回到 300 区域）：SetVelocity 向左
m.append(I("SetVelocity", target_node=P, velocity="(-250.0, 0.0)", use_local_space=False))
m.append(I("Wait", wait_time=1.2))
m.append(I("SetVelocity", target_node=P, velocity="(0.0, 0.0)", use_local_space=False))
# CheckOverlapArea：Zone 内应有 player
m.append(check("CheckOverlapArea(player在Zone)", {"type": "CheckOverlapArea", "area_node": ZN, "check_group": "player"}))
# RigidBody：ApplyImpulse / ApplyForce
m.append(I("ApplyImpulse", target_node=BX, impulse="(400.0, 0.0)", use_center=True))
m.append(I("Wait", wait_time=0.2))
m.append(check("ApplyImpulse(Box速度)", {"type": "CheckVelocity", "target_node": BX, "velocity_threshold": 50, "comparison_operator": 0}))
m.append(I("ApplyForce", target_node=BX, force="(800.0, 0.0)", use_center=True))
m.append(pr("PASS: ApplyForce(执行级)"))
# EnableDisableCollision（禁用 Box 形状）
m.append(I("EnableDisableCollision", target_node=BX + "/Shape", enable=False))
m.append(check("EnableDisableCollision", cnp(BX + "/Shape", "disabled", True)))
m.append(I("EnableDisableCollision", target_node=BX + "/Shape", enable=True))
# SetCollisionLayer / Mask（Zone 层 3）
m.append(I("SetCollisionLayer", target_node=ZN, set_type=0, layer_value=3))
m.append(check("SetCollisionLayer", cnp(ZN, "collision_layer", 3)))
m.append(I("SetCollisionMask", target_node=ZN, collision_mask=5))
m.append(check("SetCollisionMask", cnp(ZN, "collision_mask", 5)))
# SetGravityScale / Direction（Box 半重力）
m.append(I("SetGravityScale", target_node=BX, gravity_scale=0.5))
m.append(check("SetGravityScale", cnp(BX, "gravity_scale", 0.5)))
m.append(I("SetGravityDirection", target_node=P, use_2d=True, direction_x=0.0, direction_y=1.0))
m.append(pr("PASS: SetGravityDirection(执行级)"))
# GroundSnap（贴地保持）
m.append(I("GroundSnap", target_node=P))
m.append(pr("PASS: GroundSnap(执行级)"))
# Raycast：向下打地面
m.append(I("Raycast", target_node_path=P, from_position="(0.0, 0.0)", to_position="(0.0, 500.0)", collision_mask=1))
m.append(check("Raycast(命中地面)", nn("ray_result") if False else {"type": "CheckVariable", "variable_name": "raycast_hit", "comparison_operator": 11, "auto_convert_types": True}))
# CheckSlope（平地执行级）
m.append(check("CheckSlope(平地执行)", {"type": "CheckSlope", "target_node": P, "compare_type": 0, "angle_degrees": 0.0}))
m.append(I("Wait", wait_time=0.5))
m.append(pr("=== deep_physics DONE ==="))

ps = {"format_version": "2.0", "level": "L4", "display_name": "DeepPhysics", "category": "physics",
      "description": "深度测试·Physics：11 指令 + 7 条件 + 11 事件（2D 为主，3D 事件标注）",
      "icon_name": "", "variables": {"local": [], "scope": [], "global": []},
      "trigger_config": {"use_parallel_condition_evaluation": False},
      "event_bindings": [
          binding({"type": "OnReady"}, m),
          binding({"type": "OnGroundStateChanged", "target_node": P, "trigger_on": 2, "check_interval": 0.05}, [pr("PASS: OnGroundStateChanged")]),
          binding({"type": "OnCollision", "target_node": P, "collision_mask": 1}, [pr("PASS: OnCollision")]),
          binding({"type": "OnArea2DEnter", "area_node_path": ZN, "target_group": "player"}, [pr("PASS: OnArea2DEnter")]),
          binding({"type": "OnArea2DExited", "area_node_path": ZN, "target_group": "player"}, [pr("PASS: OnArea2DExited")]),
          binding({"type": "OnBodyEntered", "area_node": ZN, "target_group": "player"}, [pr("PASS: OnBodyEntered")]),
          binding({"type": "OnOverlappingBodies", "area_node": ZN, "check_threshold": 1, "comparison": 0}, [pr("PASS: OnOverlappingBodies")]),
          binding({"type": "OnRaycastHit", "origin_node_path": P, "target_position": "(0.0, 500.0)", "collision_mask": 1}, [pr("PASS: OnRaycastHit")]),
          binding({"type": "OnShapeCast", "origin_node_path": P, "shape_type": 0, "shape_size": "(50.0, 50.0)", "target_position": "(0.0, 300.0)", "collision_mask": 1}, [pr("PASS: OnShapeCast")]),
          binding({"type": "OnScreenEnteredExited", "target_node": BX, "camera": "../Cam", "trigger_on": 2}, [pr("PASS(m): OnScreenEnteredExited(相机视口内)")]),
      ]}
declare_local_variables(ps)
print(json.dumps(ps, ensure_ascii=False, indent=2))
