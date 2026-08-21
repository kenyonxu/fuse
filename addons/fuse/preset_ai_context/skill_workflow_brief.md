# Skill Workflow Brief — Fuse Preset Generator（给 skill-creator）

> 本文档面向 **skill-creator**，描述要构造的 AI skill 的工作流、上下文清单与产物规范。
> skill 目标：根据用户自然语言描述，产出**可直接 import 的 Fuse L1-L4 preset JSON**。

---

## 1. Skill 目标

**输入**：用户自然语言描述（例如"攻击序列：扣血 + 播放动画 + 发事件"、"定时呼吸：每 1.3s 淡入淡出循环"）

**输出**：写入磁盘的 `.json` 文件，结构兼容 `FusePreset.from_json()`（见 `preset_structure_cheatsheet.md`），用户在 Godot 编辑器内 import 后即可用。

**支持范围**：L1（指令序列）/ L2（事件触发）/ L3（信号绑定）/ L4（多事件绑定）。

---

## 2. 工作流（5 步）

### 步骤 1 — 接收用户描述

提取关键信息：
- 触发方式？（→ 决定 level：无触发 L1 / 事件触发 L2 / 挂信号 L3 / 多事件绑定 L4，以及 `event.type`）
- 动作步骤？（→ 选 instructions 组件）
- 涉及哪些节点 / 变量？（→ NodePath 占位 + 变量声明）

### 步骤 2 — 读上下文素材

按需读取以下 5 份素材（路径相对于 `addons/fuse/preset_ai_context/`）：

| 素材 | 用途 | 何时读 |
|------|------|--------|
| `preset_structure_cheatsheet.md` | 整体 JSON 结构 + 决策树 + NodePath 约定 | 起手必读 |
| `fuse_components.json` | 组件清单（list，含 type / category / keywords / name_key / description_key） | 选组件时读 |
| `fuse_component_schemas.json` | 组件参数 schema（dict，键 = class_name） | 填参数时读 |
| `fuse_enums.json` | 5 个枚举（VariableScope / ExecutionMode / SequenceMode / CooldownMode / ScopeSource） | 填枚举值时读 |
| `sample_presets/*.json` | 4 个真实样例（few-shot 示例） | 不确定结构时参考 |

### 步骤 3 — AI 决策

按以下顺序做选型：

1. **选 level**（决策树见 cheatsheet §4）
   - 无触发 → `L1`
   - 有触发 → `L2` + 选 `event.type`
   - 需要挂信号触发 → `L3`（+ `signal_binding`）
   - 多事件绑定 → `L4`（`trigger_config` + `event_bindings`）
2. **选 instructions 组件**（从 `fuse_components.json` 的 `category == "instruction"` 项中选）
3. **填每个组件的参数**（从 `fuse_component_schemas.json[<ClassName>]` 取参数列表）
   - 必填项优先（无默认值的）
   - 枚举值查 `fuse_enums.json` 或 schema 的 `hint_string`
   - 嵌套指令字段（schema 中 `is_nested_instructions: true`）递归填子指令
   - 参数清单以 schemas JSON + 组件源码为准（个别组件按条件注册的动态参数未收录进 schema，如 `MathOperation.operand_a_variable`）
4. **NodePath 写相对占位**（见 cheatsheet §5）：`..` / `../Player` / `../../GameSceneCanvas` / `./HUD/Score`
5. **变量声明**（`variables.local` / `scope` / `global`，见 cheatsheet §6）；不确定就留空数组让 import 时 collect

### 步骤 4 — 产 JSON

输出结构必须满足 `FusePreset.from_json()` 兼容（详见 cheatsheet §1 / §2）：

**L1 最小骨架**：
```json
{
    "format_version": "2.0",
    "level": "L1",
    "display_name": "<PascalCase>",
    "category": "<category>",
    "description": "<用户意图简述>",
    "icon_name": "",
    "variables": { "local": [], "scope": [], "global": [] },
    "action_runner": {
        "execution_mode": 0,
        "instructions": [ /* 组件对象 */ ]
    }
}
```

**L2 在 L1 基础上加 `event` + `trigger_config`**：
```json
{
    /* ...L1 字段... */
    "level": "L2",
    "action_runner": { "execution_mode": 0, "instructions": [ ... ] },
    "event": { "type": "<EventClass>", /* 事件参数 */ },
    "trigger_config": { "trigger_once": false, "cooldown_mode": 0, "cooldown_time": 1.0 }
}
```

**L3** = L1 + `"signal_binding": {"signal_name": "<信号名>"}`；**L4** = `"trigger_config": {"use_parallel_condition_evaluation": <bool>}` + `"event_bindings": [...]`（完整结构见 cheatsheet 末尾 L3/L4 专节）。

**关键 JSON 键名**（易错点）：
- 事件对象的键是 **`event`**（不是 `event_json`；后者是 `.tres` 资源属性名）
- 指令序列嵌套在 **`action_runner.instructions`** 下（不是顶层 `instructions`）
- `format_version` 当前为 **`"2.0"`**
- 条件字段（`IfThen.condition` / `IfElse.condition`）用 **inline dict**：`"condition": {"type": "<ConditionClass>", ...}`；禁止 `".tscn::Resource_*"` 引用字符串（校验器报 `E_SCENE_PRIVATE_REF`）
- Vector2/Color 等引擎值类型唯一规范表示为**字符串**：`"(100.0, 0.0)"`；数组/字典形式无法导入（校验器报 `E_REPR_NONCANONICAL`）

### 步骤 5 — 落盘 + 提示

1. 写入路径：`res://addons/fuse/presets/<category>/<name>.json`
   - `<category>` — 与用户意图匹配的目录（`gameplay` / `ui` / `audio` / ...）
   - `<name>` — snake_case 文件名
2. 提示用户：
   - 文件已落盘路径
   - "在 Godot 编辑器内选中 ActionRunner（L1）/ Trigger（L2）/ Runner（L3）/ MultiEventTrigger（L4）节点，Inspector 底部 → 导入预设 → 选择此 .json"
   - 若包含 NodePath，提示用户在 `NodePathMappingDialog` 内确认映射
3. （可选）跑 headless 校验自检（命令见 §5），失败则按错误码修正后重写

---

## 3. 上下文素材清单（路径相对于 `addons/fuse/preset_ai_context/`）

```
preset_ai_context/
├── fuse_component_schemas.json   # 306 组件参数 schema（dict，键=ClassName）（以 fuse_components.json 实际条目数为准，dump 后同步本文件）
├── fuse_components.json          # 306 组件元数据（list，含 category/keywords）（以实际条目数为准）
├── fuse_enums.json               # 5 个枚举（VariableScope/ExecutionMode/SequenceMode/CooldownMode/ScopeSource）
├── preset_structure_cheatsheet.md # 本 skill 的 JSON 结构参考（L1-L4 决策树 + NodePath 约定）
└── sample_presets/               # 4 个真实样例（few-shot）
    ├── game_flow.json            # L4 — 多事件触发器（干净样例，推荐参考）
    ├── hint_breath.json          # L2 — OnInterval + TweenFadeIn/Out（推荐参考）
    ├── red_planet.json           # L2 — OnInterval + TweenMoveTo
    └── spawn_enemy.json          # L1 — SendEvent + ForEach + GetGroupCount + ResumeGame
```

**Skill SKILL.md 中的 reference 段建议直接引用以上路径**，让 AI 在需要时按需读取（避免一次塞满 context）。

---

## 4. 产物路径约定

- 默认目录：`res://addons/fuse/presets/<category>/`
- 文件名：`snake_case.json`
- `category` 字段自动从目录名继承
- 同时生成 `.tres`（Godot 原生，由 PresetExportDialog 处理；AI 不直接产 `.tres`）

---

## 5. 验证约定（可选 headless 校验）

JSON 落盘后，用户在编辑器 import 时由以下机制兜底：

1. **`FusePresetDeserializer.deserialize()`** — 解析 JSON → 节点树
2. **`validate_imported_node()`** — 检查 NodePath 有效性 / 变量依赖 / 组件类型是否注册，以**警告**形式展示在 Inspector
3. **`NodePathResolver`** — 三级匹配（相对路径 → 全局同名 → 手动选择），帮用户补齐 NodePath 映射

**可选 headless 校验**（skill 可在落盘后自检，含 `E_REPR_NONCANONICAL` / `E_SCENE_PRIVATE_REF` 等错误码检查）：

```bash
Godot --headless --path <项目路径> res://addons/fuse/editor/preset_ai/validate_preset.tscn -- <file-or-dir> [--report <out>]
```

退出码：`0` = 通过，`1` = 校验失败，`2` = 运行错误。

因此 skill **不强制跑验证**；只需保证：
- JSON 结构对齐 cheatsheet §1 / §2
- 每个组件的 `type` 是合法 class_name（来自 `fuse_components.json`）
- 每个组件的参数键名来自 `fuse_component_schemas.json`（多余键不会报错，但应避免）
- 枚举整数来自 `fuse_enums.json`

---

## 6. 反例：什么样的描述应该拒绝 / 澄清

| 用户描述 | 问题 | 处理 |
|----------|------|------|
| "做一个 RPG 对话系统" | 太大，超出单 preset 范畴 | 拆解为多个 preset，请用户细化 |
| "用 L4 多事件触发器..." | 支持 | 按 cheatsheet L4 结构生成 |
| "用 OnReceiveEvent 触发..." | 需明确 `event_name` + 是否 `store_args_to_local` | 询问用户事件名 |

> 注：条件分支（`IfElse` / `IfThen`）已完全支持——`condition` 用 inline dict 构造（写法见 cheatsheet "条件字段写法"），不再是反例。

---

## 7. few-shot 引用建议

在 skill 的 `reference` 段或动态 reference 中，建议引用以下样例：

| 场景 | 参考样例 | 关键组件 |
|------|----------|----------|
| 定时循环动画（L2） | `sample_presets/hint_breath.json` | OnInterval + TweenFadeIn/Out |
| 定时移动（L2） | `sample_presets/red_planet.json` | OnInterval + TweenMoveTo |
| 复杂指令序列（L1） | `sample_presets/spawn_enemy.json` | SendEvent + ForEach + GetGroupCount + ResumeGame |
| 多事件触发器（L4） | `sample_presets/game_flow.json` | OnInterval/OnReady/OnReceiveEvent + 多绑定 |

---

## 8. Skill 输入输出契约

**输入**（用户 prompt）：
```
<意图描述> [可选：触发方式 / 涉及节点 / 变量]
```

**输出**（skill 动作）：
1. 调用 Write 工具落盘 `<category>/<name>.json`
2. （可选）跑 headless 校验（见 §5），失败则修正后重写
3. 返回简短摘要：
   - 落盘路径
   - level（L1-L4）
   - 组件数 / 关键组件名
   - 用户 import 指引（一句话）
   - 若有 NodePath，列出占位清单 + 提示映射

**禁止**：
- 不要生成 `.tres`（二进制/文本资源，由编辑器导出）
- 不要跳过结构自查（headless 校验可选，编辑器 import 时也会自动兜底）
- 不要塞无关字段（只填 schema 中的参数 + `type`）
