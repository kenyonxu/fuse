---
name: fuse-preset-generator
description: 生成 Fuse 可视化编程 preset JSON（L1 指令序列 / L2 事件触发器）。当用户想创建可复用的 Fuse 指令模板、preset、触发器配置、ActionRunner 指令序列，或提到"做个 preset"/"复用指令链"/"保存触发器配置"/"生成 Fuse 模板"/"把这个触发器存成预设"时，使用此 skill。即使用户没说 preset，只要意图是把 Fuse 指令/触发器保存成可复用模板，就触发。
---

# Fuse Preset Generator

据用户自然语言描述，产出可直接 import 的 Fuse preset JSON（L1/L2），落盘到 `res://addons/fuse/presets/<category>/`，用户在 Godot 编辑器 import 复用。

## 工作流

### 1. 必读两份结构文档（每次）
- `addons/fuse/preset_ai_context/preset_structure_cheatsheet.md` — L1/L2 JSON 结构 + 决策树 + NodePath 约定 + 枚举映射
- `addons/fuse/preset_ai_context/skill_workflow_brief.md` — 完整工作流 + 反例处理 + few-shot 引用

### 2. 据用户描述决策
- **选 level**：无触发 → L1（纯指令序列）；有触发 → L2（+ event + trigger_config）
- **选组件**：读 `addons/fuse/preset_ai_context/fuse_components.json`（按 category/keywords 匹配用户意图）
- **填参数**：读 `addons/fuse/preset_ai_context/fuse_component_schemas.json[<ClassName>]`（每组件参数 + 类型 + 默认值 + 嵌套标记）
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

### 4. 落盘
`res://addons/fuse/presets/<category>/<snake_case_name>.json`

### 5. 返回摘要
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
| **NodePath 相对占位** | `../Player` / `../../Score`，import 时映射兜底 |
| **不产 .tres** | AI 只产 .json，.tres 由编辑器导出处理 |
| **不跑 Godot 验证** | 留给编辑器 import（Deserializer + validate + NodePathResolver）|

---

## 反例（拒绝/澄清）

| 用户描述 | 处理 |
|----------|------|
| "做 RPG 对话系统" | 太大，拆解为多个 preset，请用户细化 |
| "用 L4 多事件触发器" | 超 MVP（仅 L1/L2），告知限制 |
| "用 IfElse 条件分支" | condition 是 .tscn 内嵌资源引用，AI 难构造 → 推荐用 ExpressionCondition 或留空让用户编辑器绑定 |
| "用 OnReceiveEvent" | 需明确 event_name + store_args_to_local → 询问用户 |

---

## MVP 范围

- ✅ **L1**（ActionRunner 指令序列）
- ✅ **L2**（Trigger：+ event + trigger_config）
- ❌ L3（Runner + signal_binding）/ L4（MultiEventTrigger + event_bindings）— 超 MVP，提示手动建或等扩展
