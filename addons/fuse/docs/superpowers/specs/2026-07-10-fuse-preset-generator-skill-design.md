# Fuse Preset Generator Skill — 基础设施 + 文档准备规格

> 日期：2026-07-10
> 状态：设计已批准，待实现
> 范围：基础设施（schema 提取 + dump）+ 使用说明文档（skill-creator 输入素材）
> skill 本身由 skill-creator 创建（§10 最后一步，不在本 spec 实现范围）
> 关联：[55-preset-system-guide](../../user_docs/guides/55-preset-system-guide.md)、[fuse_preset_system_design](../../archive/specs/2026-06-17-fuse-preset-system-design.md)

---

## 1. 背景与动机 + 阶段划分

Fuse preset 系统已成熟（`FusePreset` Resource + JSON 纯字典 + 注册表反射反序列化），但手动配置组件/参数/NodePath 成本高。目标：AI 直接产 preset .json，用户编辑器 import 复用。

**核心缺口**：组件注册表不暴露参数 schema（AI 不知每个组件的参数/类型/枚举/默认/嵌套）。

### 两阶段交付

| 阶段 | 内容 | 本 spec |
|------|------|---------|
| **阶段 1**（本 spec/plan）| 基础设施（`get_parameter_schema` + dump 工具 3 JSON）+ 使用说明文档（preset 结构速查 + 工作流描述，作 skill-creator 输入素材）| ✅ |
| **阶段 2**（最后一步）| 用官方 **skill-creator** 技能，基于阶段 1 产出的文档 + JSON 上下文，创建 fuse-preset-generator skill | ❌（skill-creator 负责）|

理由：skill-creator 是创建 skill 的专业工具，本 spec 提供它需要的全部素材（schema 数据 + 结构文档 + 工作流），避免手写 SKILL.md 与 skill-creator 能力重复。

---

## 2. MVP 范围（preset 层级）

### 做（L1-L2）
- **L1**（ActionRunner 指令序列）：纯 instructions 数组
- **L2**（Trigger）：+ event_json + trigger_config

### 不做（L3-L4，§7 扩展段说明）
- L3（Runner + signal_binding）/ L4（MultiEventTrigger + event_bindings_json）

---

## 3. 准备工作（基础设施，阶段 1 实现）

### 3.1 参数 schema 提取（核心缺口）

**`ComponentRegistry.get_parameter_schema(type_name: String) -> Array[Dictionary]`**

扫组件 `get_property_list()`，过滤基类属性，返回参数 schema。**过滤规则复用 `fuse_preset_serializer._serialize_instructions`**（保持一致）：
- 过滤：`_` 前缀 / 非 `PROPERTY_USAGE_STORAGE` / 基类字段（`log_level`/`completion_timing`/`execution_mode`/`script`/`resource_local_to_scene`/`resource_name`/`metadata`）

每参数 schema：
```gdscript
{"name": String, "type": int, "type_name": String, "hint": int, "hint_string": String, "default": Variant, "is_nested_instructions": bool}
```

**嵌套标记**：属性名在 `_SUB_INSTRUCTIONS`（instruction_analyzer.gd:20）→ `is_nested_instructions=true`。

**`get_all_parameter_schemas() -> Dictionary`**：`{type_name: [schema, ...]}` 全量。

### 3.2 枚举值 dump
集中暴露散落枚举 int 值：`VariableScope`（LOCAL=0/SCOPE=1/GLOBAL=2）、`ExecutionMode`、`SequenceMode`、`CooldownMode`、`ScopeSource`。

### 3.3 dump 工具
**位置**：`addons/fuse/editor/preset_ai/dump_context.gd`（@tool，编辑器内手动跑 / 组件更新时重跑）

**产物**（3 JSON，放 `addons/fuse/preset_ai_context/`，git 跟踪，作 skill 上下文源）：
- `fuse_component_schemas.json` —— `{type_name: [{name, type, type_name, hint, hint_string, default, is_nested_instructions}, ...]}`
- `fuse_enums.json` —— `{VariableScope: {LOCAL:0, ...}, ExecutionMode: {...}, ...}`
- `fuse_components.json` —— `[{type, category, name_key, description_key, keywords, icon}, ...]`

### 3.4 样例参考
现有 4 preset JSON（`presets/gameplay/{game_flow,red_planet,spawn_enemy}.json` + `presets/ui/hint_breath.json`）作 few-shot，复制到上下文目录。

---

## 4. 使用说明文档（skill-creator 输入素材）

阶段 1 产出**给 skill-creator 的素材文档**，让 skill-creator 据此生成 SKILL.md。

### 4.1 `preset_structure_cheatsheet.md`（preset JSON 结构速查）
从 [55-preset-system-guide](../../user_docs/guides/55-preset-system-guide.md) 提炼，L1/L2 的 JSON 结构 + 字段说明 + 决策树（何时 L1 vs L2）：
- L1：`{format_version, level:"L1", display_name, category, description, icon_name, variables, instructions:[...]}`
- L2：+ `event_json:{type,参数}` + `trigger_config:{trigger_once, cooldown_mode, cooldown_time}`
- 组件对象结构：`{type: class_name, 参数名: 值, ...}`
- NodePath 用相对路径占位符（`../Player`）

### 4.2 `skill_workflow_brief.md`（工作流描述，给 skill-creator）
描述目标 skill 的工作流（skill-creator 据此设计 SKILL.md）：
1. 输入：用户自然语言描述
2. 读上下文：3 JSON + 样例
3. AI 决策：选 level（L1/L2）+ 组件（components.json）+ 参数（schemas.json）+ 枚举（enums.json）
4. 产 JSON 落盘 `presets/<category>/<name>.json`
5. 提示用户 import + 验证

### 4.3 上下文清单（skill-creator 组织）
- `context/fuse_component_schemas.json`
- `context/fuse_enums.json`
- `context/fuse_components.json`
- `context/sample_presets/`（4 样例副本）
- `context/preset_structure_cheatsheet.md`

---

## 5. 数据流

**阶段 1**（本 spec）：ComponentRegistry.get_parameter_schema → dump 工具 → 3 JSON + 文档 → 素材就绪

**阶段 2**（skill-creator）：素材 + skill-creator → fuse-preset-generator skill

**skill 运行时**：用户描述 → skill（读上下文）→ AI 选组件/参数/枚举 → preset JSON → 落盘 → 用户 import → NodePathResolver 映射 → 实例化

---

## 6. 验证（阶段 1）
- `get_parameter_schema(type)` 返回过滤后 schema（无基类，嵌套标记正确）
- dump 工具产 3 JSON，组件更新重跑同步
- 文档（cheatsheet + workflow brief）完整，含 L1/L2 结构 + 决策树 + 上下文清单
- skill-creator 读素材能理解目标 skill（人工审文档清晰度）

---

## 7. L3-L4 扩展（spec 说明，二期能力成熟后）

### 7.1 schema 覆盖
- L3：`signal_binding` + `__target_node__` mapping
- L4：`event_bindings_json` 数组（每 binding：event/action_runner/conditions/binding_config）+ `trigger_config.use_parallel_condition_evaluation`

### 7.2 skill 决策树
- L3 分支（Runner 信号触发）/ L4 分支（MultiEventTrigger 多事件）

### 7.3 嵌套指令递归
schema 已标记嵌套，扩展时 skill 支持递归构造（ForEach body / If-Then-Else / While loop）。

---

## 8. 实现规格（阶段 1）

### 8.1 ComponentRegistry 改动
- `get_parameter_schema(type_name) -> Array[Dictionary]` + `get_all_parameter_schemas() -> Dictionary`
- 位置：`addons/fuse/editor/component_registry.gd`（或独立 `addons/fuse/editor/preset_ai/schema_extractor.gd`）

### 8.2 dump 工具
- `addons/fuse/editor/preset_ai/dump_context.gd`（@tool）
- 产物到 `addons/fuse/preset_ai_context/`（git 跟踪）

### 8.3 使用说明文档
- `addons/fuse/preset_ai_context/preset_structure_cheatsheet.md`
- `addons/fuse/preset_ai_context/skill_workflow_brief.md`
- `addons/fuse/preset_ai_context/sample_presets/`（4 样例副本）

---

## 9. 验收标准（阶段 1）

- [ ] `get_parameter_schema(type)` 返回过滤后参数 schema（无基类属性，嵌套指令标记正确）
- [ ] `get_all_parameter_schemas()` dump 全组件
- [ ] dump 工具生成 3 JSON（schemas/enums/components），组件更新重跑同步
- [ ] `preset_structure_cheatsheet.md` 含 L1/L2 JSON 结构 + 字段 + L1-vs-L2 决策树
- [ ] `skill_workflow_brief.md` 含工作流 5 步 + 上下文清单
- [ ] 4 样例 preset 复制到 sample_presets/
- [ ] 文档经人工审，skill-creator 能据此理解目标 skill
- [ ] spec §7 L3-L4 扩展段完整
- [ ] skill 本身**不在本 spec**（§10 skill-creator 创建）

---

## 10. 最后一步：skill-creator 创建 skill（阶段 2，本 spec 后）

阶段 1 素材就绪后，调用官方 **skill-creator** 技能：
- 输入：`preset_ai_context/`（3 JSON + 样例 + cheatsheet + workflow brief）
- skill-creator 产出：`.claude/skills/fuse-preset-generator/SKILL.md` + context 组织
- 验证：skill-creator 生成的 skill 能据用户描述产 L1/L2 preset JSON，编辑器 import 成功

阶段 2 不在本 spec/plan 实现，作为独立步骤（skill-creator 流程）。

---

**下一步**：用户审 spec → writing-plans（阶段 1 实现计划）。
