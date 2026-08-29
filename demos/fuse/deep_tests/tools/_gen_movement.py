import sys, json
sys.path.insert(0, "E:/GitHub/fuse/demos/fuse/deep_tests/tools")
from preset_gen import *

def binding(event, instructions, once=True):
    return {"event": event,
            "binding_config": {"enabled": True, "trigger_once": once, "cooldown_mode": 0, "cooldown_time": 1.0},
            "action_runner": {"execution_mode": 0, "instructions": instructions}}

m = []
m.append(pr("=== deep_movement START（InputDriver 1.0s 按住 Right 至 2.5s）==="))
m.append(I("GetPosition", target="../Player", save_to_variable="x0"))
m.append(I("Wait", wait_time=2.8))
m.append(I("GetPosition", target="../Player", save_to_variable="x1"))
m.append(I("MathExpression", expression="x1.x - x0.x", output_type=0, save_to_variable="dx"))
m.append(check("MoveCharacterBody2DComposite(位移>100)", cv_op("dx", 2, 100)))
m.append(pr("=== deep_movement DONE ==="))

ps = {"format_version": "2.0", "level": "L4", "display_name": "DeepMovement", "category": "movement",
      "description": "深度测试·Movement：MoveCharacterBody2DComposite（OnInterval 持续驱动 + input_driver 注入）",
      "icon_name": "", "variables": {"local": [], "scope": [], "global": []},
      "trigger_config": {"use_parallel_condition_evaluation": False},
      "event_bindings": [
          binding({"type": "OnReady"}, m),
          binding({"type": "OnInterval", "interval_seconds": 0.2, "auto_start": True},
                  [I("MoveCharacterBody2DComposite", target_node="../Player", speed=300.0, move_mode=0, acceleration=800.0, friction=10.0, smooth_factor=5.0)], once=False),
      ]}
declare_local_variables(ps)
print(json.dumps(ps, ensure_ascii=False, indent=2))
