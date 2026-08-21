---
name: fuse-preset-generator
description: 生成 Fuse 可视化编程 preset JSON（L1-L4：指令序列 / 事件触发器 / 信号绑定 / 多事件绑定）。当用户想创建可复用的 Fuse 指令模板、preset、触发器配置、ActionRunner 指令序列，或提到"做个 preset"/"复用指令链"/"保存触发器配置"/"生成 Fuse 模板"/"把这个触发器存成预设"时，使用此 skill。即使用户没说 preset，只要意图是把 Fuse 指令/触发器保存成可复用模板，就触发。
---

# Fuse Preset Generator

据用户自然语言描述，产出可直接 import 的 Fuse preset JSON（L1-L4），落盘到 `res://addons/fuse/presets/<category>/`，用户在 Godot 编辑器 import 复用。

## 工作流

### 1. 必读两份结构文档（每次）
- `addons/fuse/preset_ai_context/preset_structure_cheatsheet.md` — L1-L4 JSON 结构 + 决策树 + NodePath 约定 + 枚举映射
- `addons/fuse/preset_ai_context/skill_workflow_brief.md` — 完整工作流 + 反例处理 + few-shot 引用

### 2. 据用户描述决策
- **选 level**：无触发 → L1（纯指令序列）；有触发 → L2（+ event + trigger_config）；需要挂信号触发 → L3（+ signal_binding）；多事件绑定 → L4（trigger_config + event_bindings）
- **选组件**：读 `addons/fuse/preset_ai_context/fuse_components.json`（按 category/keywords 匹配用户意图）
- **填参数**：读 `addons/fuse/preset_ai_context/fuse_component_schemas.json[<ClassName>]`（每组件参数 + 类型 + 默认值 + 嵌套标记；参数清单以 schemas JSON + 组件源码为准——个别组件按条件注册的动态参数如 `MathOperation.operand_a_variable` 未收录进 schema）
- **选枚举**：读 `addons/fuse/preset_ai_context/fuse_enums.json`（VariableScope/ExecutionMode/SequenceMode/CooldownMode/ScopeSource 的 int 值）
- **NodePath**：相对路径占位符（`../Player` / `../../HUD/Score`），import 时 NodePathResolver 三级匹配兜底
- **不确定结构时**：参考 `addons/fuse/preset_ai_context/sample_presets/`（4 真实 preset few-shot）

### 3. 产 JSON（FusePreset.from_json 兼容）

**L1 骨架**：
```json
{
  "format_version": "2.0",
  "level": "L1",
  "display_name": "<PascalCase>",
  "category": "<gameplay|ui|audio|...>",
  "description": "<意图简述>",
  "icon_name": "",
  "variables": {"local": [], "scope": [], "global": []},
  "action_runner": {
    "execution_mode": 0,
    "instructions": [{"type": "<ClassName>", "参数名": "值", ...}, ...]
  }
}
```

**L2** = L1 + `"level": "L2"` + `"event": {"type": "<EventClass>", ...}` + `"trigger_config": {"trigger_once": false, "cooldown_mode": 0, "cooldown_time": 1.0}`

**L3** = L1 + `"signal_binding": {"signal_name": "..."}`；**L4** = `"trigger_config": {"use_parallel_condition_evaluation": <bool>}` + `"event_bindings": [...]`（结构见 cheatsheet L3/L4 节）

### 4. 落盘
`res://addons/fuse/presets/<category>/<snake_case_name>.json`

### 5. （可选）headless 校验
```bash
Godot --headless --path <项目路径> res://addons/fuse/editor/preset_ai/validate_preset.tscn -- <落盘的 .json> [--report <out>]
```
退出码 `0`=通过 / `1`=校验失败 / `2`=运行错误；失败则按错误码修正后重写（如 `E_REPR_NONCANONICAL` → 改字符串规范形，`E_SCENE_PRIVATE_REF` → 去掉 `.tscn::Resource_*` 引用）。

### 6. 返回摘要
落盘路径 + level + 组件数 + import 指引 + NodePath 占位清单（若有）

---

## 关键约定（易错点）

| 约定 | 说明 |
|------|------|
| **type 用 class_name** | 如 `"SendEvent"`，与 deserializer 反查一致（非 metadata.name_key）|
| **指令嵌套在 `action_runner.instructions`** | 非顶层 `instructions` |
| **事件键名 `event`** | 非 `event_json`（后者是 .tres 资源属性）|
| **format_version `"2.0"`** | 当前版本 |
| **嵌套指令** | ForEach.loop_instructions / IfElse.true_instructions 等，schema 标记 `is_nested_instructions:true`，递归构造子指令 |
| **condition 用 inline dict** | IfThen/IfElse 的 condition 写 `{"type": "<ConditionClass>", ...}`（勿输出 `.tscn::Resource_*` 引用，校验器报 E_SCENE_PRIVATE_REF）|
| **引擎值类型写字符串** | Vector2/Color 等唯一规范表示为字符串 `"(100.0, 0.0)"`，数组/字典形式无法导入（校验器报 E_REPR_NONCANONICAL）|
| **NodePath 相对占位** | `../Player` / `../../Score`，import 时映射兜底 |
| **不产 .tres** | AI 只产 .json，.tres 由编辑器导出处理 |
| **验证可选** | headless 校验命令见工作流第 5 步；编辑器 import 也会自动兜底（Deserializer + validate + NodePathResolver）|

---

## 反例（拒绝/澄清）

| 用户描述 | 处理 |
|----------|------|
| "做 RPG 对话系统" | 太大，拆解为多个 preset，请用户细化 |
| "用 L4 多事件触发器" | 支持，按 cheatsheet L4 结构生成 |
| "用 OnReceiveEvent" | 需明确 event_name + store_args_to_local → 询问用户 |

> 注：IfElse/IfThen 条件分支已支持——condition 用 inline dict 构造（见上方"关键约定"表的 condition 行）。

---

## 支持范围

- ✅ **L1**（ActionRunner 指令序列）
- ✅ **L2**（Trigger：+ event + trigger_config）
- ✅ **L3**（Runner：+ signal_binding）/ **L4**（MultiEventTrigger：trigger_config + event_bindings）
- ⚠️ Vector2 等引擎值类型必须写字符串形式 `"(x, y)"`，数组形式无法导入
- ⚠️ IfThen/IfElse 的 condition 用 inline dict 构造（勿输出 `.tscn::Resource_*` 引用）
