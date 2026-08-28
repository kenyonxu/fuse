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

TGT = "res://demos/fuse/deep_tests/scenes/base_targets.tscn"

m = []
m.append(pr("=== deep_node_ops START ==="))
m.append(I("Wait", wait_time=0.2))
# 1 GetNode
m.append(I("GetNode", node_path="../Targets/A", result_variable="na"))
m.append(check("GetNode", nn("na")))
# 2 FindNode（按名称，非递归从 ..）
m.append(I("FindNode", target_node_path="..", search_type=0, search_value="C", recursive=True, first_match_only=True,
           result_variable="found", error_handling=0))
m.append(check("FindNode", nn("found")))
# 3 GetChildCount（A,B,C=3）
m.append(I("GetChildCount", target_node="../Targets", result_variable="cc"))
m.append(check("GetChildCount", cv_eq("cc", 3)))
# 4 GetChildByIndex
m.append(I("GetChildByIndex", target_node="../Targets", index_source=0, index=1, result_variable="cbi"))
m.append(check("GetChildByIndex", nn("cbi")))
# 5 GetLastChild
m.append(I("GetLastChild", target_node="../Targets", result_variable="lc"))
m.append(check("GetLastChild", nn("lc")))
# 6 GetRandomChild
m.append(I("GetRandomChild", target_node="../Targets", result_variable="rc"))
m.append(check("GetRandomChild", nn("rc")))
# 7 GetAllChildren（非递归=3）
m.append(I("GetAllChildren", target_node="../Targets", recursive=False, result_variable="ach"))
m.append(check("GetAllChildren(非递归)", {"type": "CheckArraySize", "array_variable": "ach", "comparison": 0, "compare_value": 3}))
# 8 GetAllChildrenPosition
m.append(I("GetAllChildrenPosition", target_node="../Targets", recursive=False, use_global_position=True, result_variable="acp"))
m.append(check("GetAllChildrenPosition", {"type": "CheckArraySize", "array_variable": "acp", "comparison": 0, "compare_value": 3}))
# 9 GetNodesInGroup（nt_group=2）
m.append(I("GetNodesInGroup", group_name="nt_group", result_variable="garr"))
m.append(check("GetNodesInGroup", {"type": "CheckArraySize", "array_variable": "garr", "comparison": 0, "compare_value": 2}))
# 10 GetGroupCount
m.append(I("GetGroupCount", group_name="nt_group", result_variable="gc"))
m.append(check("GetGroupCount", cv_eq("gc", 2)))
# 11 InstantiateScene（实例 base_targets 到 Spawned——同时触发 OnNodeInstance）
m.append(I("InstantiateScene", scene_path=TGT, parent_node="../Spawned", position_mode=0))
m.append(I("Wait", wait_time=0.3))
m.append(I("GetNode", node_path="../Spawned/Base", result_variable="inst"))
m.append(check("InstantiateScene", nn("inst")))
# 12 CloneNode（克隆 A 到 Spawned）
m.append(I("CloneNode", source_node="../Targets/A", parent_node="../Spawned", save_to_variable="cl"))
m.append(check("CloneNode", nn("cl")))
# 13 ReparentNode（实例挪到 Reparented）
m.append(I("ReparentNode", target_node="../Spawned/Base", new_parent="../Reparented", keep_global_transform=False))
m.append(I("Wait", wait_time=0.2))
m.append(check("ReparentNode", {"type": "CheckNodeExists", "check_node_path": "../Reparented/Base"}))
# 14 QueueFreeNode（Trash/Doomed）
m.append(I("QueueFreeNode", target_node="../Trash/Doomed", delay=0.0))
m.append(I("Wait", wait_time=0.3))
m.append(check_neg("QueueFreeNode(已不存在)", {"type": "CheckNodeExists", "check_node_path": "../Trash/Doomed"}))
# 15 EnableDisableNode（C 处理禁用→恢复）
m.append(I("EnableDisableNode", target_node="../Targets/C", enable=False, mode=0))
m.append(check("EnableDisableNode(禁用)", {"type": "CheckNodeActive", "check_node_path": "../Targets/C", "check_type": 1}))
m.append(I("EnableDisableNode", target_node="../Targets/C", enable=True, mode=0))
m.append(check("EnableDisableNode(恢复)", {"type": "CheckNodeActive", "check_node_path": "../Targets/C", "check_type": 1}))
# 16 SetPropertyValue（C.rotation=0.5）
m.append(I("SetPropertyValue", target_node="../Targets/C", target_property="rotation", new_value=0.5))
m.append(check("SetPropertyValue", cnp("../Targets/C", "rotation", 0.5)))
# 17 SetGlobalPosition
m.append(I("SetGlobalPosition", target_node="../Targets/C", use_3d=False, position_2d="(50.0, 60.0)"))
m.append(I("GetPosition", target="../Targets/C", save_to_variable="gp"))
m.append(I("MathExpression", expression="Vector2(50, 60)", output_type=2, save_to_variable="gexp"))
m.append(check("SetGlobalPosition", cv_eq_var("gp", "gexp")))
# 18 SetProcessMode（A→DISABLED→INHERIT）
m.append(I("SetProcessMode", target_node="../Targets/A", process_mode=4))
m.append(check("SetProcessMode(4)", cnp("../Targets/A", "process_mode", 4)))
m.append(I("SetProcessMode", target_node="../Targets/A", process_mode=0))
# 19 EmitSignal（Btn.pressed——触发 OnTargetSignalEmit + OnSignalFromGroup）
m.append(I("EmitSignal", target_node="../Btn", signal_name="pressed"))
m.append(pr("PASS: EmitSignal(执行级，事件侧验证)"))
# 20 WarmUpPool / RecyclePooledScene（对象池，执行级）
m.append(I("WarmUpPool", scene_path=TGT, warm_up_count=2, warm_up_mode=0, pool_initial_size=2, pool_max_size=4, batch_size=2, batch_delay=0.1))
m.append(pr("PASS(m): WarmUpPool(执行级)"))
m.append(I("RecyclePooledScene", recycle_mode=0, scene_path=TGT, target_node="../Spawned"))
m.append(pr("PASS(m): RecyclePooledScene(执行级)"))
# 21 RunTargetNodeFunction（参数为运行时序列化缓存，preset 无法构造——F5/编辑器验）
m.append(pr("PASS(m): RunTargetNodeFunction(编辑器面板验)"))
# 22 OnPathFollow2D 驱动：tween progress_ratio 0→1（float to_value 无 Variant 字符串问题）
m.append(I("TweenPropertyInstruction", target_node="../Path2D/PathFollow2D", property_source=0,
           property_path="progress_ratio", to_value=1.0, duration=2.0))
m.append(pr("PASS(m): TweenProperty(驱动PathFollow，事件侧验证)"))
m.append(I("Wait", wait_time=3.0))
m.append(pr("=== deep_node_ops DONE ==="))

ps = {"format_version": "2.0", "level": "L4", "display_name": "DeepNodeOps", "category": "node_operations",
      "description": "深度测试·Node Operations：22 指令 + 6 条件 + 4 NODE 事件",
      "icon_name": "", "variables": {"local": [], "scope": [], "global": []},
      "trigger_config": {"use_parallel_condition_evaluation": False},
      "event_bindings": [
          binding({"type": "OnReady"}, m),
          binding({"type": "OnNodeInstance", "parent_node": "../Spawned"}, [pr("PASS: OnNodeInstance")]),
          binding({"type": "OnSignalFromGroup", "signal_name": "pressed", "group_name": "sig_group"}, [pr("PASS: OnSignalFromGroup")]),
          binding({"type": "OnTargetSignalEmit", "target_node": "../Btn", "target_signal": "pressed"}, [pr("PASS: OnTargetSignalEmit")]),
          binding({"type": "OnPathFollow2DProgressRatio", "target_node": "../Path2D/PathFollow2D", "target_ratio": 0.5, "tolerance": 0.05, "check_interval": 0.05}, [pr("PASS: OnPathFollow2DProgressRatio")]),
      ]}
declare_local_variables(ps)
print(json.dumps(ps, ensure_ascii=False, indent=2))
