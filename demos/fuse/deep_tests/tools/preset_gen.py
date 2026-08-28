"""deep_tests preset 生成助手——M0 沉淀的构建函数与组件清单访问。

用法（在场景生成脚本中）：
    import sys; sys.path.insert(0, r"E:/GitHub/fuse/demos/fuse/deep_tests/tools")
    from preset_gen import *
"""

import json
import re

COMPONENTS = json.load(open(
    "E:/GitHub/fuse/addons/fuse/preset_ai_context/fuse_components.json", encoding="utf-8"))
SCHEMAS = json.load(open(
    "E:/GitHub/fuse/addons/fuse/preset_ai_context/fuse_component_schemas.json", encoding="utf-8"))


def types_by_category(category_key):
    """按 category_key（如 FUSE_CATEGORY_STRING）取组件 type 列表。"""
    return [c["type"] for c in COMPONENTS if c["category_key"] == category_key]


def I(t, **kw):
    d = {"type": t}
    d.update(kw)
    return d


def pr(msg):
    return I("Print", message=msg)


# ---- 条件构造 ----

def cv_eq(var, val):
    return {"type": "CheckVariable", "variable_name": var, "comparison_operator": 0,
            "expected_value": val, "auto_convert_types": True}


def cv_op(var, op, val):
    return {"type": "CheckVariable", "variable_name": var, "comparison_operator": op,
            "expected_value": val, "auto_convert_types": True}


def cv_eq_var(var, cmp):
    return {"type": "CheckVariable", "variable_name": var, "check_with_another_variable": True,
            "compare_variable": cmp, "comparison_operator": 0, "auto_convert_types": True}


# ---- 自检链 ----

def check(name, cond):
    """条件应成立：成立→PASS，不成立→FAIL。"""
    return {"type": "IfElse", "sequence_mode": 0, "condition": cond,
            "true_instructions": [pr("PASS: " + name)],
            "false_instructions": [pr("FAIL: " + name)]}


def check_neg(name, cond):
    """条件应不成立：成立→FAIL，不成立→PASS（条件的反例分支）。"""
    return {"type": "IfElse", "sequence_mode": 0, "condition": cond,
            "true_instructions": [pr("FAIL: " + name)],
            "false_instructions": [pr("PASS: " + name)]}


# ---- preset 骨架 ----

def l2_preset(display_name, category, description, instructions, event=None, trigger_once=True):
    return {
        "format_version": "2.0", "level": "L2", "display_name": display_name,
        "category": category, "description": description, "icon_name": "",
        "variables": {"local": [], "scope": [], "global": []},
        "action_runner": {"execution_mode": 0, "instructions": instructions},
        "event": event or {"type": "OnReady"},
        "trigger_config": {"trigger_once": trigger_once, "cooldown_mode": 0, "cooldown_time": 1.0},
    }


def declare_local_variables(preset):
    """从指令 JSON 里收集局部变量名，填进 variables.local（消 W_VARIABLE_UNDECLARED）。"""
    txt = json.dumps(preset)
    names = sorted(set(re.findall(
        r'"(?:array_variable|target_variable|save_to_variable|element_from_variable|'
        r'reference_variable|compare_variable)":\s*"([a-z_0-9]+)"', txt)))
    preset["variables"]["local"] = names
    return names


def expected_pass_count(instructions):
    return json.dumps(instructions).count('"PASS: ')


def write_preset(preset, out_path):
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(preset, f, ensure_ascii=False, indent=2)
    n = expected_pass_count(preset["action_runner"]["instructions"])
    print(f"written {out_path}: 预期唯一 PASS 标记 {n} 个")
