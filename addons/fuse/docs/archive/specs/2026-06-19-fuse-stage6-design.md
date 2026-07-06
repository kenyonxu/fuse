# Fuse Stage 6: 多层级 Preset (L1-L4) 设计文档

**日期:** 2026-06-19
**状态:** ✅ 已完成（2026-06-19）
**关联:** [Fuse 推进路线图](../roadmap/2026-06-16-fuse-development-roadmap.md) Stage 6
**Brainstorm 会话:** 2026-06-19

---

## 1. 核心目标

将预设系统从 V1 的 ActionRunner (L1) 扩展到 Trigger (L2)、Runner (L3)、MultiEventTrigger (L4) 四个层级。用户可导出任意 Fuse 节点为预设模板，导入时自动创建对应节点结构。

### 四层定义

| 层级 | 节点类型 | 核心内容 | 典型场景 |
|------|---------|---------|---------|
| **L1** | `ActionRunner` (Resource) | 指令数组 + 执行模式 | 纯指令序列复用 |
| **L2** | `Trigger` (Node) | event_definition + action_runner + 冷却配置 | 碰撞检测、定时触发 |
| **L3** | `Runner` (Node) | action_runner + 信号绑定 | 按钮行为、信号适配 |
| **L4** | `MultiEventTrigger` (Node) | event_bindings[] (含 event + action_runner + conditions + 配置) | Boss 多阶段行为 |

---

## 2. 架构概览

```
导出方向:                              导入方向:
节点 → FusePresetSerializer           JSON → FusePresetDeserializer
        ├── serialize_action_runner()         ├── deserialize_action_runner()
        ├── serialize_event()                 ├── deserialize_event()
        ├── serialize_condition()             ├── deserialize_condition()
        ├── serialize_trigger_config()        └── deserialize_binding()
        └── serialize_signal_binding()              │
              │                                     ▼
              ▼                              创建节点 → 挂到场景
        FusePreset.to_json()
              │
              ▼
        .tres + .json 双文件
```

核心原则：JSON 结构直接映射 Godot 对象图。所有层级都包含 `action_runner`，指令始终在 `action_runner.instructions` 内。`target_node`/`NodePath` 不序列化，导入时由用户映射。

---

## 3. 数据模型

### 3.1 FusePreset Resource 扩展

```gdscript
# 新增字段 — 加在现有字段之后
@export var level: String = "L1"              # "L1"|"L2"|"L3"|"L4"

# L2/L3/L4 专用字段（按层级条件存在）
@export var event_json: Dictionary = {}        # L2/L4: BaseEvent 的序列化数据
@export var trigger_config: Dictionary = {}     # L2/L4: trigger_once, cooldown_mode, cooldown_time
@export var signal_binding: Dictionary = {}     # L3: signal_name
@export var event_bindings_json: Array = []     # L4: EventBinding 数组
```

### 3.2 L1 格式（ActionRunner，保持 V1 语义嵌套）

```json
{
  "format_version": "2.0",
  "level": "L1",
  "display_name": "弹幕生成器",
  "category": "combat",
  "action_runner": {
    "execution_mode": 0,
    "instructions": [
      {"type": "Instantiate", "scene": "uid://bullet_scene"},
      {"type": "Wait", "duration": 0.5}
    ]
  },
  "variables": {"local": [], "scope": [], "global": []}
}
```

### 3.3 L2 格式（Trigger）

```json
{
  "format_version": "2.0",
  "level": "L2",
  "display_name": "碰撞伤害触发器",
  "category": "combat",
  "action_runner": {
    "execution_mode": 0,
    "instructions": [
      {"type": "ApplyDamage", "amount": 10},
      {"type": "CameraShake", "intensity": 0.5}
    ]
  },
  "event": {
    "type": "OnCollisionEntered",
    "target_node": "../HitBox",
    "layer": 1
  },
  "trigger_config": {
    "trigger_once": false,
    "cooldown_mode": 1,
    "cooldown_time": 2.0
  },
  "variables": {"local": [], "scope": [], "global": []}
}
```

### 3.4 L3 格式（Runner）

```json
{
  "format_version": "2.0",
  "level": "L3",
  "display_name": "按钮提交行为",
  "category": "ui",
  "action_runner": {
    "instructions": [
      {"type": "SetVariable", "variable_name": "submitted", "value": true},
      {"type": "LoadScene", "scene_path": "res://scenes/game.tscn"}
    ]
  },
  "signal_binding": {
    "signal_name": "pressed"
  },
  "variables": {"local": ["submitted"], "scope": [], "global": []}
}
```

### 3.5 L4 格式（MultiEventTrigger）

```json
{
  "format_version": "2.0",
  "level": "L4",
  "display_name": "Boss 阶段控制器",
  "category": "boss",
  "trigger_config": {
    "use_parallel_condition_evaluation": true
  },
  "event_bindings": [
    {
      "event": {"type": "OnInterval", "interval_seconds": 3.0},
      "action_runner": {
        "instructions": [{"type": "SpawnEnemy", "enemy_type": "minion"}]
      },
      "conditions": [
        {"type": "CheckHealthPercentage", "threshold": 0.5, "comparison": 0}
      ],
      "binding_config": {
        "enabled": true,
        "trigger_once": false,
        "cooldown_mode": 0,
        "cooldown_time": 0.0
      }
    },
    {
      "event": {"type": "OnHealthBelow", "threshold": 0.25},
      "action_runner": {
        "instructions": [{"type": "SetAnimationParameter", "param": "phase", "value": 2}]
      },
      "conditions": [],
      "binding_config": {"enabled": true, "trigger_once": true}
    }
  ],
  "variables": {"local": [], "scope": [], "global": []}
}
```

### 3.6 Event/Condition 序列化策略

与指令序列化一致：`type` = 类名（`get_global_name()`），其余字段遍历 `get_property_list()`，过滤 `_` 前缀和非 STORAGE 属性，NodePath→字符串，Resource→路径。

### 3.7 变量收集

递归扫描 `action_runner` 子树（所有层级统一），保持 V1 的三层作用域分类：`local`、`scope`、`global`。

---

## 4. 导出流程

### 4.1 入口点

| 节点类型 | Inspector 位置 | 检测为 |
|---------|--------------|--------|
| `ActionRunner` (Resource) | `instructions_array_property.gd` 现有按钮 | L1 |
| `Trigger` (Node) | `fuse_inspector_plugin.gd` — "导出为预设"按钮 | L2 |
| `Runner` (Node) | 同上 | L3 |
| `MultiEventTrigger` (Node) | 同上 | L4 |

### 4.2 自动检测

```gdscript
func detect_level(node: Object) -> String:
    if node is MultiEventTrigger:  return "L4"
    if node is Trigger:            return "L2"
    if node is Runner:             return "L3"
    if node is ActionRunner:       return "L1"
    return ""
```

### 4.3 序列化管道（FusePresetSerializer）

所有层级共用底层函数，按对象图递归：

```
FusePresetSerializer (新增静态类)
├── serialize_action_runner(runner) → {execution_mode, instructions: [...]}
├── serialize_event(event)           → {type, properties...}
├── serialize_condition(cond)        → {type, properties...}
├── serialize_trigger_config(node)   → {trigger_once, cooldown_mode, cooldown_time}
│                                       L4 额外: {use_parallel_condition_evaluation}
├── serialize_signal_binding(node)   → {signal_name}
└── serialize_binding_config(binding) → {enabled, trigger_once, cooldown_mode, cooldown_time}

顶层入口:
├── serialize_l1(runner)  → {level: "L1", action_runner, variables}
├── serialize_l2(trigger) → {level: "L2", action_runner, event, trigger_config, variables}
├── serialize_l3(runner)  → {level: "L3", action_runner, signal_binding, variables}
└── serialize_l4(multi)   → {level: "L4", trigger_config, event_bindings[], variables}
```

`serialize_action_runner()` 复用在所有四个层级。`serialize_event()` 复用在 L2 和 L4。

### 4.4 导出对话框扩展

`PresetExportDialog` 改为接受节点本身（而非指令数组）：

```gdscript
func _init(source_node: Node) -> void:
    _level = FusePresetSerializer.detect_level(source_node)
    match _level:
        "L1": _data = FusePresetSerializer.serialize_l1(source_node)
        "L2": _data = FusePresetSerializer.serialize_l2(source_node)
        "L3": _data = FusePresetSerializer.serialize_l3(source_node)
        "L4": _data = FusePresetSerializer.serialize_l4(source_node)
```

对话框 UI 增加 level 标签显示（如 "L2 · Trigger"），底部统计卡片不变。

### 4.5 双文件保存（不变）

`.tres` (ResourceSaver) + `.json` (to_json)，写入 `presets/{category}/`。

---

## 5. 导入流程

### 5.1 整体流程

```
预设面板 → 选中预设 → "应用预设"
    │
    ▼
PresetImportDialog (扩展)
    ├── 1. 读取 level, 决定创建什么节点类型
    ├── 2. Event/Condition 反序列化
    ├── 3. NodePath 扫描 + 映射 UI
    ├── 4. L3: target_node 由用户从映射表指定
    ├── 5. 变量依赖检查
    └── 6. 确认 → 创建节点 → 挂到选中节点下
```

### 5.2 节点创建策略

| 层级 | 创建的节点 | 填充内容 |
|------|-----------|---------|
| L1 | 创建 ActionRunner Resource（不创建节点） | instructions + execution_mode |
| L2 | `Trigger` (new) | event_definition + action_runner + trigger_config |
| L3 | `Runner` (new) | action_runner + signal_name; target_node 由用户映射 |
| L4 | `MultiEventTrigger` (new) | event_bindings[]; 每项含 event + action_runner + conditions |

节点挂在当前 Editor Selection 选中的 Node 下；若选中的是 Resource 或未选中，则挂到场景根节点。

### 5.3 反序列化管道（FusePresetDeserializer）

```
FusePresetDeserializer (新增静态类)
├── deserialize_action_runner(json) → ActionRunner
│       (复用 FusePreset._deserialize_instructions 逻辑)
├── deserialize_event(json)         → BaseEvent
│       (查 EventRegistry → script.new() → 遍历属性 set)
├── deserialize_condition(json)     → BaseCondition
│       (查 ConditionRegistry → script.new() → 遍历属性 set)
├── deserialize_binding(json)       → EventBinding

顶层入口:
├── import_l1(preset, mapping) → 填充现有 ActionRunner
├── import_l2(preset, mapping) → 创建 Trigger 节点
├── import_l3(preset, mapping) → 创建 Runner 节点
└── import_l4(preset, mapping) → 创建 MultiEventTrigger 节点
```

### 5.4 NodePath 映射扩展

V1 只在 `instructions` 中扫描 NodePath。V2 递归扫描整个对象图：

```
扫描范围:
├── action_runner.instructions[*].properties[*]   (L1-L4)
├── event.properties[*]                           (L2/L4)
├── event_bindings[*].conditions[*].properties[*] (L4)
└── signal_binding.target_node                     (L3 — 标记为"信号源")
```

映射对话框对每个 NodePath 展示：原始路径 → 自动匹配（同名节点）→ 可选手动调整。L3 的 `target_node` 显示为「信号源节点」，其他显示为「指令目标」。

### 5.5 变量检查（与 V1 一致）

| 作用域 | 导入行为 |
|--------|---------|
| Local | 提示"运行时自动创建，无需处理" |
| Scope | 检查容器节点是否在映射表中 → 存在✅ / 不存在⚠ |
| Global | 提示"项目级存在，无需处理" |

---

## 6. Inspector 集成

### 6.1 布局

在 `fuse_inspector_plugin.gd` 的 `_parse_end()` 中，对 BaseTrigger/Runner 节点在数据流卡片上方加"导出为预设"按钮：

```
Inspector 布局（Trigger/MultiEventTrigger/Runner 节点）:
┌─────────────────────────────────┐
│ 节点属性（原生编辑器）           │
├─────────────────────────────────┤
│ [📦 导出为预设]  ← 新增按钮     │
├─────────────────────────────────┤
│ 📊 数据流: ...     ← 已有卡片   │
│   └── 事件/节点/变量/指令链     │
└─────────────────────────────────┘
```

### 6.2 按钮逻辑

```gdscript
func _on_export_preset_pressed(node: Node) -> void:
    var level := FusePresetSerializer.detect_level(node)
    if level.is_empty():
        return
    var dialog := PresetExportDialog.new(node)
    EditorInterface.get_base_control().add_child(dialog)
    dialog.confirmed.connect(_on_export_confirmed.bind(dialog))
    dialog.popup_centered()
```

### 6.3 预设面板显示增强

`PresetPanel` 中每个预设项显示 level 标签（如 `[L2]` 标签），帮助用户识别预设类型。

---

## 7. 文件结构

### 新增文件

```
addons/fuse/editor/serialization/
├── fuse_preset_serializer.gd       # 序列化管道（export 方向）
└── fuse_preset_deserializer.gd     # 反序列化管道（import 方向）
```

### 修改文件

| 文件 | 改动 |
|------|------|
| `core/resources/fuse_preset.gd` | +level, +event_json, +trigger_config, +signal_binding, +event_bindings_json 字段；to_json/from_json 按 level 分派 |
| `editor/fuse_inspector_plugin.gd` | +导出按钮（L2/L3/L4 入口），在数据流卡片上方 |
| `editor/preset_export_dialog.gd` | 构造函数改为接受 Node；UI 展示 level 标签 |
| `editor/preset_import_dialog.gd` | 按 level 创建对应节点类型；NodePath 扫描扩展至 event/conditions |
| `editor/preset_panel.gd` | 每条显示 level 标签 |
| `editor/preset_registry.gd` | 不变（只需扫描 .tres） |

---

## 8. 序列化/反序列化关键实现细节

### 8.1 指令反序列化缓存

`_cache_type_script(type_name)` 遍历 `InstructionRegistry.get_all_instructions()` 查找匹配的 GDScript。反序列化时用 `script.new()` 创建实例，遍历 JSON keys 调 `inst.set(key, value)`。

### 8.2 Event/Condition 反序列化（新增）

与指令反序列化同模式：
- Event: 查 `EventRegistry.get_all_events()` → `script.new()` → set 属性
- Condition: 查 `ConditionRegistry.get_all_conditions()` → `script.new()` → set 属性

### 8.3 Resource 引用还原

JSON 中 `"uid://..."` 或 `"res://..."` 格式的字符串 → `load(path)` 还原为 Resource。

### 8.4 NodePath 字符串处理

JSON 中 NodePath 属性序列化为字符串（如 `"../Player"`）。导入时不自动还原为 NodePath，而是通过映射对话框让用户指定场景中的实际路径。映射完成后统一调用 `apply_nodepath_mapping()`。

---

## 9. 设计审查与防御策略

以下来自 Pre-mortem + Second-Order + Inversion 三轮模型审查。

### 9.1 反序列化后校验

**风险：** `inst.set(key, val)` 类型不匹配时 Godot 静默吞掉，导入后看似正常但属性值不对。

**防御：** 反序列化完成后对关键资源调 `validate()`。发现空 `event_definition`、空 `instructions`、空 `event_bindings` 时弹出 Warning 对话框：

```gdscript
func _validate_imported_node(node: Node, level: String) -> Array[String]:
    var warnings: Array[String] = []
    match level:
        "L2":
            var trigger := node as Trigger
            if trigger and not trigger.event_definition:
                warnings.append("事件定义未能还原，请手动配置")
            if trigger and (not trigger.action_runner or trigger.action_runner.instructions.is_empty()):
                warnings.append("指令列表为空")
        "L3":
            var runner := node as Runner
            if runner and (not runner.action_runner or runner.action_runner.instructions.is_empty()):
                warnings.append("指令列表为空")
        "L4":
            var multi := node as MultiEventTrigger
            if multi and multi.event_bindings.is_empty():
                warnings.append("事件绑定列表为空，请手动配置")
    return warnings
```

### 9.2 属性填充顺序

**风险：** 属性之间存在隐式依赖，填充顺序不对导致状态不一致或值被覆盖。

**防御：** 各层级按固定顺序填充：

| 层级 | 填充顺序 |
|------|---------|
| L2 | ① `trigger_config` → ② `event_definition` → ③ `action_runner` → ④ `name` |
| L3 | ① `action_runner` → ② 设置 `target_node`（来自映射）→ ③ `signal_name`（因为 `_get_property_list` 依赖 `target_node`）→ ④ `call_deferred("notify_property_list_changed")` |
| L4 | ① 逐个构建完整 `EventBinding`（含 event + action_runner + conditions + binding_config）→ ② 一次性赋值 `event_bindings`（触发 setter 里的 `notify_property_list_changed`）→ ③ `trigger_config` |

### 9.3 导出前最小校验

**风险：** 用户在关键属性为空时导出，生成破损预设。

**防御：** 导出前校验，不满足条件时阻止导出并弹提示：

| 层级 | 最小校验条件 | 阻止信息 |
|------|------------|---------|
| L1 | `instructions` 非空 | "指令列表为空，无法导出" |
| L2 | `event_definition` 不为 null | "事件定义未配置，无法导出" |
| L3 | `action_runner` 不为 null | "ActionRunner 未配置，无法导出" |
| L4 | 至少一个 `event_bindings` 且 `enabled = true` | "没有启用的事件绑定，无法导出" |

### 9.4 PresetExportDialog API 兼容

**风险：** 现有 L1 调用路径（`instructions_array_property.gd`）传 `Array[BaseInstruction]`，改构造函数参数类型会断裂。

**防御：** 构造函数接受 Variant，内部区分：

```gdscript
func _init(source: Variant) -> void:
    if source is Node:
        _level = FusePresetSerializer.detect_level(source)
        # 走序列化管道
    elif source is Array:
        _level = "L1"
        _instructions = source  # 兼容 L1 旧路径
```

---

## 10. 不做什么（V2 范围外）

- ❌ 预设版本自动迁移（只做 `format_version` 校验 + 提示）
- ❌ 在线预设商店/分享
- ❌ Behavior Pack（参数映射 + 嵌套预设）
- ❌ 预设预览（执行前预览）
- ❌ 历史/最近使用(MRU)
- ❌ 预设合并/部分应用
- ❌ 条件表达式的可视化编辑

---

## 11. 任务拆分

| # | 任务 | 工时 | 产出 | 依赖 |
|---|------|:--:|------|------|
| 6a | 数据模型扩展 + 序列化引擎 | 1-1.5天 | FusePreset 新字段 + FusePresetSerializer + FusePresetDeserializer | — |
| 6b | 多层级导出 | 0.5-1天 | Inspector 按钮 + PresetExportDialog 改造 + 自动检测 | 6a |
| 6c | 多层级导入 | 1天 | PresetImportDialog 改造 + 节点创建 + NodePath 扩展扫描 | 6a |

**依赖关系：** 6a → 6b, 6c（6b 和 6c 可并行）

---

## 12. 验收标准

- [ ] `FusePreset` 支持 `level` 字段，to_json/from_json 按层级正确分派
- [ ] `FusePresetSerializer` 可序列化 Trigger/Runner/MultiEventTrigger 为统一 JSON 格式
- [ ] `FusePresetDeserializer` 可从 JSON 创建对应节点（Trigger/Runner/MultiEventTrigger）
- [ ] 反序列化后调 `validate()` 校验，空关键属性时弹出 warning
- [ ] 属性填充遵循固定顺序（§9.2），避免隐式依赖导致状态不一致
- [ ] 导出前最小校验（§9.3），关键属性为空时阻止导出并弹提示
- [ ] `PresetExportDialog` 兼容 Variant 参数，L1 旧路径不断裂
- [ ] Trigger 节点 Inspector 中出现"导出为预设"按钮
- [ ] Runner 节点 Inspector 中出现"导出为预设"按钮
- [ ] MultiEventTrigger 节点 Inspector 中出现"导出为预设"按钮
- [ ] 导入 L2 时场景中创建完整的 Trigger 节点（event + action_runner + config）
- [ ] 导入 L3 时先设 target_node 再设 signal_name，call_deferred 刷新属性列表
- [ ] 导入 L4 时创建 MultiEventTrigger 节点，含完整 event_bindings + conditions
- [ ] NodePath 映射扫描扩展到 event 和 conditions 中的路径
- [ ] 预设面板显示 level 标签
- [ ] 变量检查覆盖所有层级
- [ ] 现有 L1 预设（V1 格式）仍可正常导入
- [ ] 双文件输出（.tres + .json）在所有层级正常工作

---

**文档版本:** 2.0（通过 Pre-mortem + Second-Order + Inversion 审查）
**最后更新:** 2026-06-19
**审核状态:** ✅ 验收通过（2026-06-19）
