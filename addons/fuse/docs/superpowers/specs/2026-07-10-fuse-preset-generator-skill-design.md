# Fuse Preset Generator Skill 设计规格

> 日期：2026-07-10
> 状态：设计已批准，待实现
> MVP 范围：L1-L2 preset 生成
> 关联：[55-preset-system-guide](../../user_docs/guides/55-preset-system-guide.md)、[fuse_preset_system_design](../../archive/specs/2026-06-17-fuse-preset-system-design.md)

---

## 1. 背景与动机

Fuse preset 系统已成熟（`FusePreset` Resource + JSON 纯字典序列化 + 注册表反射反序列化），手动建 preset 流程完整（Inspector 配置 → 导出 .tres/.json → 注册 → import 复用）。但手动配置组件 + 参数 + NodePath 成本高，尤其复杂指令链。

目标：开发一个 Claude Code skill，**AI 直接产 preset .json 文件落盘**，用户编辑器 import 复用。降低 preset 创建门槛，让 AI 承担组件选择 + 参数填充 + 结构组织的重复工作。

**现状调研关键结论**：
- preset 系统机器可生成（JSON 纯字典，反序列化反射）
- 组件注册表现成（174 Instruction / 69 Event / 55 Condition + metadata）
- **核心缺口**：注册表不暴露参数 schema（AI 不知每个组件的 @export 参数/类型/枚举/默认值/嵌套）
- CLAUDE.md 提的 `/fuse-*-generator` skill 不存在（从零开始）

---

## 2. MVP 范围

### 做（L1-L2）
- **L1**（ActionRunner 指令序列）：纯 instructions 数组 preset
- **L2**（Trigger）：+ event_json + trigger_config（trigger_once/cooldown_mode/cooldown_time）

### 不做（L3-L4，§7 扩展段说明）
- L3（Runner + signal_binding + target_node）
- L4（MultiEventTrigger + event_bindings_json 数组）

理由：L1-L2 覆盖最常用场景（指令序列 + 单事件触发器），跑通 schema→AI→JSON→import 全链路后再扩复杂层级。

---

## 3. 准备工作（基础设施，前置）

### 3.1 参数 schema 提取（核心缺口）

**`ComponentRegistry.get_parameter_schema(type_name: String) -> Array[Dictionary]`**

扫指定组件的 `get_property_list()`，过滤基类属性，返回参数 schema 数组。过滤规则**复用 `fuse_preset_serializer._serialize_instructions` 的过滤逻辑**（保持一致）：

过滤掉的属性（基类/内部）：
- `_` 前缀（内部属性）
- 非 `PROPERTY_USAGE_STORAGE`
- 基类固定字段：`log_level` / `completion_timing` / `execution_mode` / `script` / `resource_local_to_scene` / `resource_name` / `metadata`

每个参数 schema 字段：
```gdscript
{
    "name": String,           # 属性名（如 "target_variable"）
    "type": int,              # Godot type（TYPE_STRING=4 / TYPE_INT=2 / TYPE_NODE_PATH=20 ...）
    "type_name": String,      # 类型名（"String"/"int"/"NodePath"/"Array" ...）
    "hint": int,              # property hint
    "hint_string": String,    # 枚举值/范围等
    "default": Variant,       # 默认值
    "is_nested_instructions": bool  # 是否嵌套指令数组（instructions/true_instructions/false_instructions/loop_instructions/else_instructions）
}
```

**嵌套指令数组标记**：属性名在 `_SUB_INSTRUCTIONS`（instruction_analyzer.gd:20）中 → `is_nested_instructions=true`（AI 递归构造子指令）。

**`get_all_parameter_schemas() -> Dictionary`**：遍历全组件，返 `{type_name: [schema, ...]}`。

### 3.2 枚举值 dump

集中暴露散落枚举的 int 值（JSON 序列化用 int）：
- `VariableScope`（base_variable.gd:44）：LOCAL=0 / SCOPE=1 / GLOBAL=2
- `ExecutionMode`（action_runner.gd）
- `SequenceMode`（if_else 等控制流）
- `CooldownMode`（base_trigger.gd）
- `ScopeSource`（VariableScopeUtils / check_variable）

### 3.3 dump 工具

**位置**：`addons/fuse/editor/preset_ai/dump_context.gd`（编辑器内 @tool 脚本，手动跑一次 / 组件更新时重跑）

**产物**（3 JSON，放 `addons/fuse/preset_ai_context/` 或 skill 上下文目录）：
- `fuse_component_schemas.json` —— `{type_name: [{name, type, type_name, hint, hint_string, default, is_nested_instructions}, ...]}`
- `fuse_enums.json` —— `{VariableScope: {LOCAL:0, SCOPE:1, GLOBAL:2}, ExecutionMode: {...}, ...}`
- `fuse_components.json` —— `[{type, category, name_key, description_key, keywords, icon}, ...]`（从 metadata）

### 3.4 样例参考
现有 4 个 preset JSON（`presets/gameplay/{game_flow,red_planet,spawn_enemy}.json` + `presets/ui/hint_breath.json`）作 AI few-shot，零成本。

---

## 4. Skill 设计

### 位置
`.claude/skills/fuse-preset-generator/`（项目 skill，随项目走）

### SKILL.md 工作流
1. **输入**：用户自然语言描述（"攻击序列：扣血+播放动画+发送事件"）
2. **读上下文**：3 JSON（schemas/enums/components）+ 样例 preset JSON
3. **AI 决策**：
   - 选 level：纯指令序列 → L1；需事件触发 → L2
   - 选组件（查 components.json）：匹配用户意图的 Event/Instruction/Condition
   - 填参数（查 schemas.json）：每个组件的参数 + 默认值
   - 选枚举（查 enums.json）：VariableScope/ExecutionMode 等 int 值
   - NodePath：相对路径占位符（`../Player`），import 时映射兜底
4. **产 JSON**：`FusePreset.from_json` 兼容结构
   ```json
   {
     "format_version": 1,
     "level": "L2",
     "display_name": "...",
     "category": "...",
     "description": "...",
     "icon_name": "...",
     "variables": {"local": [], "scope": [], "global": []},
     "instructions": [{type, 参数...}, ...],
     "event_json": {type, 参数...},
     "trigger_config": {trigger_once, cooldown_mode, cooldown_time}
   }
   ```
5. **落盘**：`res://addons/fuse/presets/<category>/<name>.json`
6. **提示用户**：编辑器 import（触发 NodePathResolver mapping）+ 验证

### 上下文文件（skill 目录）
- `context/fuse_component_schemas.json`
- `context/fuse_enums.json`
- `context/fuse_components.json`
- `context/sample_presets/`（4 样例 JSON 副本）
- `context/preset_structure_cheatsheet.md`（从 55-preset-system-guide 提炼的 L1/L2 JSON 结构速查）

---

## 5. 数据流

```
用户描述 → skill（读 3 JSON + 样例）
  → AI 选 level + 组件 + 参数 + 枚举
  → preset JSON（L1/L2 结构）
  → 落盘 presets/<category>/<name>.json
  → 用户编辑器 import
  → NodePathResolver.extract_nodepaths → 若有 NodePath，NodePathMappingDialog 用户确认
  → FusePresetDeserializer.deserialize → 创建 Trigger/Runner + ActionRunner + 指令
  → validate_imported_node 警告（缺 event_definition 等）
```

---

## 6. 验证

skill 产后 → 用户编辑器 import 验证：
- `FusePresetDeserializer` 反序列化（type 名 + 参数 set）
- `validate_imported_node` 警告（event_definition 缺失 / 指令空 / signal_name 空）
- NodePath 映射（三级匹配 + 手动）

skill 不做运行时验证（非 Godot 进程），依赖编辑器 import 兜底。

---

## 7. L3-L4 扩展（二期能力成熟后）

### 7.1 schema 覆盖扩展
- **L3**：`signal_binding`（signal_name）+ `__target_node__` mapping（Runner.target_node 特殊键）
- **L4**：`event_bindings_json` 数组（每 binding：`{event, action_runner:{instructions}, conditions[], binding_config}`）+ `trigger_config.use_parallel_condition_evaluation`

### 7.2 skill 决策树扩展
- L3 分支：Runner（信号触发，无 Event，signal_binding + target_node）
- L4 分支：MultiEventTrigger（多事件，每 binding 独立 event + action_runner + conditions）

### 7.3 嵌套指令递归
schema 已标记 `instructions`/`loop_instructions`/`true_instructions`/`false_instructions` 为 `is_nested_instructions`。扩展时 skill 支持递归构造（ForEach body / If-Then-Else / While loop）。

---

## 8. 实现规格（准备项）

### 8.1 ComponentRegistry 改动
- 加 `get_parameter_schema(type_name) -> Array[Dictionary]`（扫 get_property_list + 过滤 + 嵌套标记）
- 加 `get_all_parameter_schemas() -> Dictionary`
- 位置：`addons/fuse/editor/component_registry.gd`（或独立 `addons/fuse/editor/preset_ai/schema_extractor.gd`）

### 8.2 dump 工具
- `addons/fuse/editor/preset_ai/dump_context.gd`（@tool，编辑器内跑）
- 产物到 `addons/fuse/preset_ai_context/`（git 跟踪，skill 上下文源）

### 8.3 skill
- `.claude/skills/fuse-preset-generator/SKILL.md`
- `.claude/skills/fuse-preset-generator/context/`（3 JSON + 样例 + 速查）

---

## 9. 验收标准（MVP）

- [ ] `ComponentRegistry.get_parameter_schema(type)` 返回过滤后的参数 schema（无基类属性，嵌套指令标记正确）
- [ ] dump 工具生成 3 JSON（schemas/enums/components），组件更新重跑同步
- [ ] skill SKILL.md + context 文件齐全
- [ ] AI 据用户描述产 L1/L2 preset JSON（结构兼容 `FusePreset.from_json`）
- [ ] 产出的 JSON 在编辑器 import 成功（反序列化 + 实例化 + validate 警告合理）
- [ ] NodePath 相对路径占位符经 NodePathResolver 三级匹配兜底
- [ ] spec §7 L3-L4 扩展段完整（二期能力成熟后实现）

---

**下一步**：用户审 spec → writing-plans。
