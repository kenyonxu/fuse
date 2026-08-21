# Fuse Preset JSON 结构速查（skill-creator 素材）

> 本文档面向 **AI skill 作者**，描述 L1-L4 preset JSON 的真实结构（基于 `FusePreset.from_json` + 现有样例 dump）。
> L1-L4 均在 skill 支持范围内；L3/L4 结构见末尾专节。
>
> 数据源：`addons/fuse/core/resources/fuse_preset.gd`（`from_json` / `to_json`）、
> `addons/fuse/presets/**/*.json`（现有样例）。

---

## 1. L1 JSON 结构（ActionRunner 指令序列）

L1 = 纯指令组合，无触发器。挂在 `ActionRunner` 节点（或被 Runner/Trigger 内嵌的 ActionRunner 复用）。

```json
{
    "format_version": "2.0",
    "level": "L1",
    "display_name": "spawn-enemy",
    "category": "gameplay",
    "description": "刷怪序列：发事件 → 遍历位置 → 计数 → 关闭",
    "icon_name": "",
    "variables": {
        "local": [],
        "scope": [],
        "global": []
    },
    "action_runner": {
        "execution_mode": 0,
        "instructions": [
            { "type": "SendEvent", "event_name": "ShowWave", "event_args": {}, "deferred": false },
            { "type": "ForEach", "sequence_mode": 1, "loop_instructions": [ /* ... */ ] }
        ]
    }
}
```

**字段说明**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `format_version` | String `"2.0"` | 是 | 当前序列化版本 |
| `level` | `"L1"` | 是 | 层级标识 |
| `display_name` | String | 是 | 面板显示名（建议 PascalCase 或 snake_case） |
| `category` | String | 是 | 分类，自动从落盘目录继承（如 `gameplay` / `ui`） |
| `description` | String | 否 | 用途说明 |
| `icon_name` | String | 否 | FuseIconManager builtin_icon 名（可空） |
| `variables` | Object | 否 | 变量声明（见 §6） |
| `action_runner.instructions` | Array | 是 | 指令序列（见 §3） |
| `action_runner.execution_mode` | int | 否 | 见 `ExecutionMode`（0=SEQUENTIAL，1=PARALLEL） |

---

## 2. L2 JSON 结构（Trigger：事件 + 指令）

L2 = L1 + 事件触发器。挂在 `Trigger` 节点。

```json
{
    "format_version": "2.0",
    "level": "L2",
    "display_name": "HintBreath",
    "category": "ui",
    "description": "1.3s 周期呼吸：淡入 0.5s → 淡出 0.5s",
    "icon_name": "",
    "variables": { "local": [], "scope": [], "global": [] },
    "action_runner": {
        "execution_mode": 0,
        "instructions": [
            { "type": "TweenFadeIn", "duration": 0.5, "from_alpha": 0.0, "to_alpha": 1.0, "target_node": "..", "trans_type": 1, "easing_type": 1 },
            { "type": "TweenFadeOut", "duration": 0.5, "target_node": "..", "auto_free": false, "trans_type": 3, "easing_type": 1 }
        ]
    },
    "event": {
        "type": "OnInterval",
        "interval_seconds": 1.3,
        "auto_start": true,
        "trigger_on_start": false,
        "emit_repeat_count": true,
        "use_random_interval": false,
        "min_interval_seconds": 0.5,
        "max_interval_seconds": 2.0,
        "max_repeats": 0,
        "stop_condition": null
    },
    "trigger_config": {
        "trigger_once": false,
        "cooldown_mode": 0,
        "cooldown_time": 1.0
    }
}
```

**L2 在 L1 基础上新增字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `event` | Object | 是 | 事件对象（注意：JSON 键名是 `event`，不是 `event_json`；后者是资源属性名） |
| `trigger_config` | Object | 是 | 触发配置 |

**`trigger_config` 字段**：

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `trigger_once` | bool | `false` | 是否仅触发一次 |
| `cooldown_mode` | int | `0` | 见 `CooldownMode`（0=NONE，1=GLOBAL_COOLDOWN，2=PER_OBJECT_COOLDOWN） |
| `cooldown_time` | float | `1.0` | 冷却秒数 |

---

## 3. 组件对象结构（指令 / 事件 / 条件）

每个指令、事件、条件都是一个 JSON 对象：

```json
{ "type": "<ClassName>", "<参数名>": <值>, ... }
```

- `type` — Godot `class_name`（如 `SendEvent` / `OnInterval` / `TweenMoveTo`）
- 其余键 — 该组件的属性，**全部来自 schema**（见 `fuse_component_schemas.json`）

**查参流程**：
1. 在 `fuse_components.json`（list）按 `type` 找到组件元数据（category、keywords、name_key、description_key），确认用对组件
2. 在 `fuse_component_schemas.json`（dict，键 = class_name）找到参数列表，每个参数提供：
   - `name` — JSON 键名
   - `type_name` — 类型（`String` / `int` / `float` / `bool` / `NodePath` / `Dictionary` / `Array` / `Vector2` ...）
   - `default` — 默认值
   - `hint` + `hint_string` — 枚举提示（如 `"Synchronous:0,Asynchronous:1"`）
   - `is_nested_instructions` — **是否为嵌套指令数组**（见 §8）

> **引擎值类型（Vector2/Color 等）唯一规范表示为字符串**，如 `"(100.0, 0.0)"`。数组 `[100.0, 0.0]` 与字典 `{"x": ...}` 形式无法导入，校验器报 `E_REPR_NONCANONICAL`。
> 参数清单以 schemas JSON + 组件源码为准：个别条件组件的动态参数（如 `operand_a_source == VARIABLE` 时注册的 `operand_a_variable`）未收录进 schema，拼写以组件源码为准。

**示例**（`SendEvent` 的 schema → JSON）：

schema:
```json
[
    { "name": "event_name",  "type_name": "String",    "default": "" },
    { "name": "event_args",  "type_name": "Dictionary","default": {} },
    { "name": "deferred",    "type_name": "bool",      "default": false }
]
```

对应 JSON:
```json
{ "type": "SendEvent", "event_name": "ScoreUpdate", "event_args": { "score": "$c_score" }, "deferred": false }
```

> 事件参数 `$c_score` 是变量引用约定（`$` 前缀取作用域/本地变量），由指令运行时解析。

---

## 4. level 决策树（L1-L4）

```
用户描述的需求
    │
    ├─ 是否需要"在某个时机/事件触发"？
    │     │
    │     ├─ 否（纯动作序列，由调用方手动 run）  → L1
    │     │      例如：刷怪序列、伤害计算步骤、UI 刷新步骤
    │     │
    │     └─ 是（由事件驱动：定时器 / 输入 / 碰撞 / 自定义事件）
    │            → L2
    │            需要选 `event.type`（OnInterval / OnReady / OnReceiveEvent / OnButtonPressed / ...）
    │            例如：呼吸动画、周期攻击、按键响应、收到事件加分
    │
    └─ L3（信号绑定）/ L4（多事件绑定）→ 生成对应结构（见末尾专节）
```

**常见事件类型（`event.type`）速查**（完整列表见 `fuse_components.json` 中 `category == "event"` 的项）：

| event.type | 触发时机 |
|------------|----------|
| `OnReady` | 节点 `_ready()` |
| `OnInterval` | 定时循环 |
| `OnReceiveEvent` | 收到自定义事件（配 `event_name` + `local_var_prefix`） |
| `OnButtonPressed` | UI 按钮按下 |
| `OnInputKey` / `OnInputAction` | 输入 |
| `OnArea2DEnter` / `OnBodyEntered` | 碰撞 |
| `OnAnimationFinished` | 动画结束 |
| `OnTimer` / `OnCountdown` | 计时 |

---

## 5. NodePath 约定

**必须使用相对路径占位符**，避免硬编码绝对路径：

| 占位符 | 含义 | 例子 |
|--------|------|------|
| `".."` | 父节点（通常是挂载节点本身，如 Trigger 所在节点） | `target_node: ".."` |
| `"../Player"` | 父节点的兄弟节点 | 从 Trigger 取兄弟 Player |
| `"../../GameSceneCanvas"` | 上两层的某节点 | UI 容器 |
| `"./HUD/ScoreLabel"` | 子节点路径 | 自身子树 |

**import 时 `NodePathResolver` 三级匹配兜底**（用户导入新场景时自动建议）：

1. **相对路径结构匹配** — 从目标父节点按原路径 `get_node_or_null` 解析；失败再从父节点解析
2. **全局同名匹配** — 取原路径最后一段（`../Player/HUD` → 搜 `HUD`），广度优先搜全场景
3. **手动选择** — 在 `NodePathMappingDialog` 下拉全场景节点供用户确认

> 因此 AI 产 JSON 时，NodePath 写**相对占位**即可，无需关心目标场景的具体结构。

---

## 6. 变量声明（`variables` 字段）

`preset.variables` 结构：

```json
{
    "local":  ["index", "temp_value"],
    "scope":  [
        { "name": "hp", "container": "../Player" },
        { "name": "mana", "container": "" }
    ],
    "global": ["level", "score"]
}
```

| 键 | 类型 | 说明 |
|----|------|------|
| `local` | Array[String] | 本地名列表（运行时由 ExecutionContext 自动创建） |
| `scope` | Array[Object] | 作用域变量，每项 `{name, container}`；`container` 为 NodePath（可空） |
| `global` | Array[String] | 全局变量名列表（需项目级 `GlobalVariableManager` 存在） |

**省略策略**：可以全部留空 `{"local":[],"scope":[],"global":[]}`，让 import 时 `collect_variables()` 从指令序列自动收集。但当 `scope` 变量需要指定 `container` 时必须显式声明。

---

## 7. 枚举值引用

所有整数枚举值 → 见 `fuse_enums.json`：

| 枚举 | 用途 | 关键映射 |
|------|------|----------|
| `VariableScope` | 变量作用域 | 0=LOCAL, 1=SCOPE, 2=GLOBAL |
| `ExecutionMode` | `action_runner.execution_mode` | 0=SEQUENTIAL, 1=PARALLEL |
| `SequenceMode` | 嵌套指令执行模式（`ForEach`/`IfElse` 等） | 0=SYNCHRONOUS, 1=ASYNCHRONOUS |
| `CooldownMode` | `trigger_config.cooldown_mode` | 0=NONE, 1=GLOBAL_COOLDOWN, 2=PER_OBJECT_COOLDOWN |
| `ScopeSource` | 作用域变量来源选择 | 0=NEAREST, 1=CUSTOM_ID, 2=TRIGGER_SCOPE, 3=TARGET_NODE |

也可通过 schema 的 `hint_string`（如 `"Local,Scope,Global"`）反查序号映射。

---

## 8. 嵌套指令（递归）

部分指令在参数中持有子指令数组，schema 中以 `is_nested_instructions: true` 标记：

| 指令 | 嵌套字段 | 说明 |
|------|----------|------|
| `ForEach` | `loop_instructions` | 遍历数组/分组，每项执行 |
| `ForLoop` | `loop_instructions` | 计数循环 |
| `WhileLoop` | `loop_instructions` | 条件循环 |
| `IfThen` | `instructions` | 条件为真时执行 |
| `IfElse` | `true_instructions` / `false_instructions` | 双分支 |
| `OnInterval.stop_condition` 等 | （条件资源引用，非嵌套指令） | — |

**递归规则**：嵌套字段是 `Array[BaseInstruction]`，每个元素结构与顶层指令完全相同（`{type, 参数...}`，可继续递归）。

**示例**（`IfElse` 嵌套）：

```json
{
    "type": "IfElse",
    "sequence_mode": 1,
    "condition": { "type": "CheckScopeVariable", "variable_name": "is_paused", "comparison_operator": 0, "expected_value": false },
    "true_instructions": [
        { "type": "PauseGame", "show_pause_menu": false, "ui_node_path": "../../GameSceneCanvas" },
        { "type": "RunRunner", "target_runner": "../SpawnEnemy", "wait_for_completion": true }
    ],
    "false_instructions": [
        { "type": "SendEvent", "event_name": "GameEnd", "event_args": {}, "deferred": false }
    ]
}
```

> **条件字段写法**：`IfThen.condition` / `IfElse.condition` 支持 **inline dict** —— `"condition": {"type": "CheckScopeVariable", ...}`（参数按 `fuse_component_schemas.json` 中该条件的条目填）。复合条件的 `conditions` 数组同法嵌套。禁止输出 `".tscn::Resource_*"` 形式的引用字符串（校验器报 `E_SCENE_PRIVATE_REF`）。

---

## L3 / L4 结构（skill 支持范围）

skill 可直接产出 L3 / L4 preset：

| 层级 | 节点 | 额外字段 |
|------|------|----------|
| **L3** | `Runner` | `signal_binding`（信号→指令桥接） |
| **L4** | `MultiEventTrigger` | `event_bindings`（多事件数组，每项含 `event` + `binding_config` + `action_runner`） |

**字段说明**：

- **L3** = L1 + `"signal_binding": {"signal_name": "<信号名>"}`；导入时通过 `__target_node__` 映射挂载信号源节点
- **L4** = `"trigger_config": {"use_parallel_condition_evaluation": <bool>}` + `"event_bindings": [{"event": {...}, "binding_config": {"enabled": <bool>, "trigger_once": <bool>, "cooldown_mode": <int>, "cooldown_time": <float>}, "action_runner": {...}, "conditions": [...](可选)}]`
- L4 干净样例：`sample_presets/game_flow.json`（多事件触发器，重导后无内嵌资源引用）

---

## 产物落盘约定

- 路径：`res://addons/fuse/presets/<category>/<name>.json`
- 命名：`snake_case` 文件名（如 `patrol_guard.json`）
- category 自动从目录名继承（`gameplay` / `ui` / `audio` / ...）
- 同时生成 `.tres`（Godot 原生资源）供 `load()`，`.json` 供版本对比 / AI 编辑 / 跨项目分享

---

## 验证约定

JSON 落盘后，用户在 Godot 编辑器内通过 Inspector → "导入预设" 触发：

1. `FusePresetDeserializer.deserialize()` — 反序列化为节点树
2. `validate_imported_node()` — 检查 NodePath 有效性、变量依赖、组件类型注册，以**警告**形式展示
3. `NodePathResolver` 三级匹配 → `NodePathMappingDialog` 人工确认

**（可选）headless 校验**：落盘后可跑独立校验器自检（含 `E_REPR_NONCANONICAL` / `E_SCENE_PRIVATE_REF` 等错误码检查）：

```bash
Godot --headless --path <项目路径> res://addons/fuse/editor/preset_ai/validate_preset.tscn -- <file-or-dir> [--report <out>]
```

退出码：`0` = 通过，`1` = 校验失败，`2` = 运行错误。

AI 不强制在生成时跑验证（headless 校验可选）；只需保证 JSON 结构与 schema 对齐。
