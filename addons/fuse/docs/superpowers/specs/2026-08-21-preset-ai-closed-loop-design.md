# Preset AI 管线闭环设计

**日期：** 2026-08-21
**状态：** 设计已批准，待实现
**上下文：** 落实《AI 编程时代 Fuse 插件价值评估》（`2026-08-15-ai-era-value-assessment.md`）§5 建议 3「把 preset AI 管线补成闭环」——让「可静态验证」从潜能变成显式卖点，并扩大 AI 可覆盖的 preset 空间。

---

## 1. 目标与范围

**目标：** 建立「生成 → 离线校验 → 自动评分 → 回归门禁」的闭环，使每一份 AI 生成的 preset JSON 都能离线验证、可打分、可回归。

**三个模块（单 spec，按里程碑顺序实施）：**

| 模块 | 内容 | 依赖 |
|------|------|------|
| A 离线校验器 | headless Godot 校验器，结构化报告 + 退出码 | 无 |
| B eval runner + 回归 | 回放评测、规则评分、baseline 门禁 | A（评分信号来源） |
| C 覆盖扩展 | L3/L4 文档化与样例、IfThen 条件构造解禁、导出器修复 | A（新构造需校验规则认可） |

**Non-goals：**

- LLM-as-judge 语义评分（规则评分先行，后续需要再单独立项）
- `trigger_eval.json`（20 条触发判定）的迁移——它由仓库外 skill-creator 的 `scripts.run_loop` 消费，维持现状
- CI 流水线搭建（仓库当前无 `.github`；本 spec 只保证所有命令可进 CI）
- StateTree 类组件的评测扩展（见价值评估文档 §7，另案）

## 2. 关键背景发现（设计依据）

探索确认了四个直接影响设计的事实：

1. **Vector2 疑案（重要纠错）。** 价值评估文档 §3.1 的 A/B 对比称「with_skill 把 Vector2 写成数组 `[0.0, 0.0]` 是正确写法，无 skill 的字符串 `"(100.0, 0.0)"` 无效」。但阅读 `PresetValueCodec.deserialize_value()`（`addons/fuse/core/serialization/preset_value_codec.gd:94`）发现：Vector2 无特判，靠 `Object.set()` 的 Variant 隐式转换——**字符串形式可能可转，数组形式反而不行**。现有导出样例（`red_planet.json`）用的正是字符串形式。也就是说，当时的人工 A/B 评测从未真正回导过产物，可能把错误结论写进了评估文档。**教训：表示法的裁决权必须交给真实 codec 实测，这是模块 A 的验收门槛之一。** 本 spec 记录该纠错，cheatsheet 在模块 C 中改正，历史评估文档保持原样不动。

2. **现有导出样例不可完全回导（语料污染）。** `game_flow.json` / `spawn_enemy.json` 中 `IfThen.instructions` 等嵌套指令被序列化成显示字符串（形如 `"发送事件: AllEnemyDied (res://...::Resource_5y4ic):<Resource#...>"`），反序列化时 `PresetValueCodec` 对非 dict 项只 `push_warning` 跳过——嵌套指令静默丢失。git 考古（样例导出于 2026-07-08 commit 1fde87f，递归 serde codec 于 2026-08-10 commit 4452091 才引入）表明**导出器当前并无此 bug，样例只是早于 codec 的过期产物**。模块 C 真正要修的是另一处：`_serialize_value()` 对场景内嵌资源（`resource_path` 含 `::`）输出无意义的私有引用字符串（`hint_breath.json` 的 `stop_condition` 即此类），应改为 inline dict，再从源场景重导样例。

3. **IfThen/IfElse 的 condition 构造其实已被 codec 支持。** `deserialize_value()` 第 120-122 行：目标属性为 object 且 raw 是 Dictionary 时递归 `_deserialize_resource()`；`tests/serialization/test_preset_nested_serde.gd` 已证明 inline dict 往返 + 执行通过。「AI 无法构造 condition」的真正障碍是：现有导出样例全是场景私有引用字符串（`xxx.tscn::Resource_xxx`），且 cheatsheet/brief 把整条路标为禁区。模块 C 的解禁是文档 + 样例 + 校验规则工作，不是序列化能力建设。

4. **L3/L4 的反序列化器已存在**（`_import_l3` / `_import_l4`），扩展主要是文档、样例与校验规则。

## 3. 已确认的架构决策

| 决策点 | 结论 | 理由 |
|--------|------|------|
| 校验器形态 | Godot headless GDScript 场景（`dump_context.tscn` 模式） | 只有真实 codec 能裁决表示法；顺带实测导入路径 |
| eval 模式 | 回放优先，live 可选 | 回放确定性、可进 CI；live 需 API 配置且非确定 |
| 评分方式 | 纯规则评分 | 确定性可回归；LLM 评审列入 non-goal |
| 范围 | 单 spec 三里程碑 A → B → C | 依赖链：B 的评分依赖 A，C 需要 A 扩展规则 |

## 4. 模块 A：离线校验器

### 4.1 位置与入口

- `addons/fuse/editor/preset_ai/preset_validator.gd` — 静态 API：`static func validate_preset(path: String) -> Dictionary`（返回结构化报告，见 4.4）
- `addons/fuse/editor/preset_ai/validate_preset.tscn` — headless 入口场景，`_ready()` 中解析参数、调用 API、`get_tree().quit(exit_code)`

**用法：**

```bash
# 校验单个文件或目录（目录递归收集 *.json；只校验含 format_version 字段的 preset 文件，其余 JSON 跳过并计入 info）
Godot --headless --path <项目路径> res://addons/fuse/editor/preset_ai/validate_preset.tscn -- <file-or-dir> [--report <out.json>]

# 退出码：0 = 无 error；1 = 存在 error finding；2 = 参数/IO 错误
```

（首次运行前需 `Godot --headless --import --path <项目路径>` 生成类缓存，与 dump_context 相同。）

### 4.2 四层校验

每层产出 findings：`{code, severity, json_path, message}`。severity ∈ `error` / `warning` / `info`。

**第 1 层：结构层**

| code | severity | 条件 |
|------|----------|------|
| `E_PARSE` | error | JSON 解析失败 |
| `E_FORMAT_VERSION` | error | `format_version` 缺失或不等于 `"2.0"` |
| `E_LEVEL_MISMATCH` | error | `level` 字段与实际存在的字段集合不一致（如声明 L2 但无 `event`）——判定逻辑复用 `FusePresetSerializer.detect_level()` 的规则 |
| `E_LEVEL_UNKNOWN` | error | `level` 不在 L1/L2/L3/L4 中 |

**第 2 层：schema 层**（对照 `fuse_component_schemas.json`，沿 `is_nested_instructions: true` 的字段递归下钻指令树；condition 字段见第 4 层）

| code | severity | 条件 |
|------|----------|------|
| `E_UNKNOWN_COMPONENT` | error | 组件 `type` 不在 schemas dump 的键集合中 |
| `E_UNKNOWN_PARAM` | error | 参数键既非 `type` 也不在该组件 schema 参数列表中（即 A/B 测试中发现的幻觉参数名类错误） |
| `E_ENUM_RANGE` | error | 枚举参数（`hint_string` 含 `"Name:Value,..."` 对）的值不在声明范围内 |
| `E_TYPE_MISMATCH` | error | JSON 值类型与 schema `type_name` 不兼容，按兼容表判定（见下） |
| `W_MISSING_PARAM` | warning | 参数缺失但 schema 有默认值兜底（AI 可依赖默认值，但显式写出更稳） |

类型兼容表（schema `type_name` → 接受的 JSON 类型）：

| type_name | 接受 | 备注 |
|-----------|------|------|
| `String` | string | |
| `int` | number（整数） | |
| `float` | number | |
| `bool` | bool | |
| `NodePath` | string | 另过第 4 层 NodePath 检查 |
| `Dictionary` | object | |
| `Array` | array | |
| `Vector2` / `Vector3` / `Color` 等引擎值类型 | **以 4.5 裁定实验结果为准** | 裁定前统一发 `W_REPR_NONCANONICAL`，不当 error |
| Object（`hint_string` 为 `BaseCondition` / `BaseInstruction` 等资源类） | object（inline dict） | string 形式转第 4 层资源引用检查 |

**第 3 层：codec 实测层（ground truth）**

真实调用 `FusePreset.from_json()` + `PresetValueCodec` 反序列化，**用结果比对代替日志拦截**（headless 下 push_warning 不易程序化处理，结果比对更可靠）：

| code | severity | 条件 |
|------|----------|------|
| `E_ROUNDTRIP_LOSS` | error | 源 JSON 中的指令 dict 递归计数 > 反序列化后的指令树计数（存在静默丢弃，字符串化嵌套指令必现形） |
| `E_EVENT_NULL` | error | L2 的 `event` 或 L4 的 `event_bindings[].event` 反序列化为 null |
| `E_CONDITION_NULL` | error | condition 字段给出了 inline dict 但反序列化为 null |

**第 4 层：语义层**

| code | severity | 条件 |
|------|----------|------|
| `E_SCENE_PRIVATE_REF` | error | 任何资源字段为含 `::Resource_` 的场景私有引用字符串（离开源场景无意义） |
| `E_RESOURCE_NOT_FOUND` | error | `res://` 普通资源路径在项目中不存在（headless Godot 可用 `ResourceLoader.exists()` 实测） |
| `W_NODEPATH_UNRESOLVED` | warning | NodePath 字段无法离线验证目标存在性（仅做格式检查：非空、无 `::Resource_`） |
| `W_VARIABLE_UNDECLARED` | warning | 指令引用了未在 `variables` 中声明的变量（复用 `InstructionAnalyzer` 的提取逻辑） |

### 4.3 condition 字段的递归校验

任何参数满足以下之一即按 condition 递归校验（回到第 2 层，组件类别换成 condition）：

- `hint_string == "BaseCondition"` 的 Object 参数，值为 inline dict 时；
- 元素为 condition 资源的数组参数（复合条件的嵌套条件数组）。

inline dict 的 `type` 必须是 55 个 condition 组件之一（`E_UNKNOWN_COMPONENT`），参数键名/类型/枚举同样按 schema 检查。

### 4.4 报告格式

stdout 打印人类可读摘要；`--report` 输出机读 JSON：

```json
{
  "files": [
    {
      "path": "iteration-1/attack-l2/with_skill/outputs/attack.json",
      "errors": 0,
      "warnings": 2,
      "findings": [
        {"code": "W_MISSING_PARAM", "severity": "warning",
         "json_path": "action_runner.instructions[0].duration",
         "message": "参数缺失，将使用 schema 默认值 1.0"}
      ]
    }
  ],
  "summary": {"total": 6, "passed": 5, "failed": 1}
}
```

### 4.5 Vector2 等值类型表示法裁定实验（M1 验收门槛）

实现校验器时，用真实 codec 对 Vector2 的三种候选表示做往返实测：字符串 `"(1.0, 2.0)"` / 数组 `[1.0, 2.0]` / 字典 `{"x": 1.0, "y": 2.0}`。**能往返的形式成为规范**，写为测试断言固定下来，并在模块 C 中同步：cheatsheet 改为规范形式、`fuse-preset-generator` skill 文档改为规范形式。Vector3/Color 同法裁定。裁定前校验器对非字符串形式只发 `W_REPR_NONCANONICAL`（warning），裁定为 error 级规则留出 code `E_REPR_NONCANONICAL`。

## 5. 模块 B：eval runner + 回归门禁

### 5.1 目录结构

```
fuse-preset-generator-workspace/
├── trigger_eval.json                  # 现有，不动（外部消费）
├── eval_baseline.json                 # 新增：回归门禁基线
├── evals/
│   └── cases/
│       ├── patrol-sequence-l1.json    # 新增：case 定义
│       ├── attack-sequence-l2.json
│       └── countdown-l2.json
├── iteration-1/                       # 现有产物，保持原位
└── iteration-N/                       # 后续 iteration 沿用现有布局
    └── <case-dir>/<variant>/outputs/*.json
```

### 5.2 case 定义格式

case 与生成产物分离——case 声明 prompt 与结构断言，产物路径显式列出（不做目录名模糊匹配，iteration-1 的目录名与 case 名并不一致）：

```json
{
  "name": "patrol-sequence-l1",
  "level": "L1",
  "prompt": "帮我做一个巡逻 preset：……",
  "must_include": [
    {"kind": "component", "type": "MoveToPosition"},
    {"kind": "param", "component": "Wait", "key": "duration"}
  ],
  "must_not_include": [
    {"kind": "component", "type": "SendEvent"}
  ],
  "variables_required": [],
  "outputs": {
    "iteration-1": [
      "patrol-l1/with_skill/outputs/patrol_a_wait_b_wait.json",
      "patrol-l1/without_skill/outputs/patrol.json"
    ]
  }
}
```

- `must_include[].kind`：`component`（指令树中出现该 type）/ `param`（某组件出现某参数键）/ `event`（L2/L4 事件为该 type）
- `variables_required[]`：`{name, scope}`，须出现在 `variables` 声明中
- 上面示例中的组件名仅为格式示意——种子 case 的断言必须从 iteration-1 实际产物中提取，不得凭记忆编写

### 5.3 回放模式（默认）

入口：`addons/fuse/editor/preset_ai/eval_runner.gd` + `eval_runner.tscn`。

```bash
Godot --headless --path <项目路径> res://addons/fuse/editor/preset_ai/eval_runner.tscn -- \
  --workspace fuse-preset-generator-workspace --iteration iteration-1 [--report <dir>]
```

流程：加载 `evals/cases/*.json` → 对每个 case 在指定 iteration 下的每个产物：调用模块 A 校验（`preset_validator.validate_preset`）→ 跑结构断言 → 计算分数。

**分数定义（确定性）：**

- `validation_errors` / `validation_warnings`：来自模块 A
- `assertions_passed` / `assertions_total`：must_include / must_not_include / variables_required 逐项判定
- `pass` = `validation_errors == 0` 且断言全部通过

**报告：** 写入 `--report` 指定目录（默认 `<workspace>/<iteration>/`）下的 `report.json`（机读全量）与 `report.md`（人读表格：case × variant × 分数）。报告纳入 git，形成回归历史。

### 5.4 回归门禁

`eval_baseline.json` 记录每个产物应达的最低标准：

```json
{
  "patrol-sequence-l1": {
    "patrol-l1/with_skill/outputs/patrol_a_wait_b_wait.json": {"pass": true}
  }
}
```

runner 对照 baseline：任何产物的实际结果低于基线（应过实败）→ 退出码 1，报告中高亮回归项。基线初始值按 iteration-1 回放实测结果录入。计划阶段核实代码后的预判：attack with_skill 通过、attack without_skill 失败（幻觉参数名 `operand_a_variable`/`operand_a_scope`）；patrol with_skill **失败**（Vector2 用了数组形式，实为不可导入——A/B 结论反转）、patrol without_skill 失败（幻觉参数 `time_scope`）；countdown 两版待实测。多数产物飘红正是闭环价值的即时演示。

### 5.5 live 模式（可选，标记 experimental）

`--live` 时：读 case prompt，用 `HTTPRequest` POST 到 OpenAI 兼容端点（env：`FUSE_EVAL_API_BASE` / `FUSE_EVAL_API_KEY` / `FUSE_EVAL_MODEL`），system prompt 由可配置的文件列表拼接（SKILL.md + cheatsheet + brief + 3 个 schema JSON），产物落盘到新 iteration 目录再走回放评分。网络失败计入报告并使退出码为 1。明确标注：live 模式的 prompt 组装是近似，不等价于任何特定 agent harness 的真实上下文组装。

## 6. 模块 C：L3/L4 + IfThen 条件构造覆盖扩展

1. **修导出器场景内嵌资源序列化。** 嵌套指令序列化自 commit 4452091 起已正确（现有样例的字符串化嵌套是 2026-07-08 的旧导出产物，非当前 bug）。真正要修的是 `PresetValueCodec._serialize_value()`：Resource 的 `resource_path` 含 `::`（`.tscn` 内嵌 sub-resource）时，输出的引用字符串离开源场景无意义——改为序列化 inline dict。用导出侧测试固定（给 condition 设置含 `::` 的 resource_path，断言序列化为 dict 而非字符串）。随后从源场景重导被污染的样例：`addons/fuse/presets/gameplay/game_flow.json`（源：`demos/fuse/brickian/game_scene.tscn` 的 `GameManager/GameFlow`）、`spawn_enemy.json`（同场景 `GameManager/SpawnEnemy`）、`addons/fuse/presets/ui/hint_breath.json`（`demos/fuse/brickian/title_scene.tscn` 的 `Control/TitleHint/HintBreath`）及 `preset_ai_context/sample_presets/` 中的副本——修复后的验收标准是这四个样例全部通过模块 A 校验。

2. **文档解禁 condition 构造。** 改 `preset_structure_cheatsheet.md` 与 `skill_workflow_brief.md`：IfThen/IfElse 的 `condition` 字段从「禁区」改为支持 inline dict 形式——`"condition": {"type": "CheckScopeVariable", ...按 schema 填参}`；复合条件的嵌套条件数组同法。同时删除/更新「IfThen 条件无法构造」的已知限制条目。

3. **补 L3/L4 文档与样例。** cheatsheet 补 L3（`signal_binding{signal_name}`，导入时 `__target_node__` 映射）与 L4（`trigger_config.use_parallel_condition_evaluation`、`event_bindings[]{event, binding_config{enabled, trigger_once, cooldown_mode, cooldown_time}, action_runner, conditions?}`）结构说明；手工各写一个 L3、L4 样例放入 `sample_presets/`，验收标准为通过模块 A 校验；相应更新 `fuse-preset-generator` SKILL.md 的 MVP 范围声明（✅L1-L4）。

4. **校验器规则同步。** L3/L4 字段纳入第 1/2 层校验（signal_name 非空、event_bindings 结构、binding_config 枚举值合法）；condition inline dict 递归校验（4.3）随本模块的负例 fixture 一并落地。

5. **顺手修正过期数字。** `skill_workflow_brief.md` 的「296 组件」改为与最新 dump 一致（306），并注明「以 `fuse_components.json` 实际条目数为准，dump 后需同步」。

## 7. 错误处理

- 校验器对任何畸形输入不 crash：JSON 解析失败、文件不存在、字段类型整体错误，全部转为 finding（`E_PARSE` / `E_TYPE_MISMATCH` 等），继续处理后续文件。
- eval runner 对缺失产物文件标记 `missing` 计入报告，不中断其余 case。
- live 模式网络/鉴权失败按 case 记入报告，退出码 1。

## 8. 测试计划（遵循 AGENTS.md：测试场景 + `_ready()` 运行，无外部框架）

新增 `addons/fuse/tests/preset_ai/`：

- `test_preset_validator.tscn/.gd`
  - 正例（M1 阶段）：`red_planet.json` 通过；`hint_breath.json` 正确报出 `E_SCENE_PRIVATE_REF`（其 `stop_condition` 是场景私有引用）；
  - 正例（M3 阶段追加）：重导修复后的 `hint_breath.json` / `game_flow.json` / `spawn_enemy.json` 通过（M1 阶段后两者必须正确报出 `E_ROUNDTRIP_LOSS`，这是校验器在工作的证据，不是测试失败）；
  - 负例 fixture（埋入单一缺陷，断言触发特定 code）：未知组件 type → `E_UNKNOWN_COMPONENT`；幻觉参数名 → `E_UNKNOWN_PARAM`；枚举越界 → `E_ENUM_RANGE`；字符串化嵌套指令 → `E_ROUNDTRIP_LOSS`；场景私有 condition 引用 → `E_SCENE_PRIVATE_REF`；错误 level 声明 → `E_LEVEL_MISMATCH`；
  - Vector2 裁定断言（4.5 的实测结论固化为测试）。
- `test_eval_runner.tscn/.gd`：迷你 fixture workspace（1 case + 2 产物，一过一败）→ 报告生成正确；抬高 baseline 后回归门禁触发退出码 1。

## 9. 里程碑与验收

| 里程碑 | 内容 | 验收 |
|--------|------|------|
| M1 | 模块 A 校验器 | 4 个现有样例 + iteration-1 全部 6 份产物完成校验并产出结构化报告；预期结果明确：`red_planet` 通过；`hint_breath` 正确报出 `E_SCENE_PRIVATE_REF`（其 `stop_condition` 是场景私有引用，M3 重导后转绿）；`game_flow` / `spawn_enemy` 正确报出 `E_ROUNDTRIP_LOSS`（M3 修复后转绿）；without_skill 产物正确报出幻觉参数名；Vector2 表示法裁定完成并写入测试；校验器测试场景通过 |
| M2 | 模块 B runner | iteration-1 回放出 report.md/json；baseline 录入；抬高 baseline 实验触发退出码 1；runner 测试通过 |
| M3 | 模块 C 覆盖 | 导出器修复 + 4 样例重导并校验通过；cheatsheet/brief/SKILL.md 更新（condition 解禁、L3/L4、296→306）；新 L3/L4 样例校验通过并各加 1 个 eval case |

## 10. 文件清单

**新增：**

- `addons/fuse/editor/preset_ai/preset_validator.gd`
- `addons/fuse/editor/preset_ai/validate_preset.tscn`（含根脚本）
- `addons/fuse/editor/preset_ai/eval_runner.gd`
- `addons/fuse/editor/preset_ai/eval_runner.tscn`（含根脚本）
- `addons/fuse/editor/preset_ai/regen_samples.tscn`（含根脚本，M3 样例重导）
- `fuse-preset-generator-workspace/evals/cases/{patrol-sequence-l1,attack-sequence-l2,countdown-l2,l3-runner-sample,l4-multi-sample}.json`
- `fuse-preset-generator-workspace/eval_baseline.json`
- `addons/fuse/tests/preset_ai/test_preset_validator.{gd,tscn}`
- `addons/fuse/tests/preset_ai/test_eval_runner.{gd,tscn}`（含迷你 fixture workspace）
- `addons/fuse/tests/preset_ai/test_codec_inline_export.{gd,tscn}`
- `addons/fuse/preset_ai_context/sample_presets/sample_l3_runner.json`、`sample_l4_multi.json`

**修改：**

- `addons/fuse/core/serialization/preset_value_codec.gd`（`_serialize_value`：场景内嵌资源改为 inline dict）
- `addons/fuse/presets/gameplay/{game_flow,spawn_enemy}.json`、`addons/fuse/presets/ui/hint_breath.json` + `preset_ai_context/sample_presets/` 副本（从源场景重导）
- `addons/fuse/preset_ai_context/preset_structure_cheatsheet.md`（Vector2 规范、condition 解禁、L3/L4 结构）
- `addons/fuse/preset_ai_context/skill_workflow_brief.md`（同上 + 296→306 + MVP 范围 L1-L4）
- `.claude/skills/fuse-preset-generator/SKILL.md`（MVP 范围 L1-L4、Vector2 规范、condition 指引）

## 11. 风险与开放问题

1. **Vector2 裁定结果可能影响面大。** 若实测证明数组形式不可用而 cheatsheet 此前推荐数组，则 iteration-1 的 with_skill 产物也需修正重录 baseline——这正是闭环的价值，但要做好 baseline 初始值「全线飘红」的心理准备。
2. **live 模式的保真度有限。** 单轮 chat completion 的 prompt 组装只是真实 agent harness（含 skill 加载、多轮工具调用）的近似，live 分数不与回放分数直接可比，报告中分开呈现。
3. **校验规则与运行时漂移。** 校验器读 dump 出的 schemas JSON，组件变更后若忘重 dump，校验器会以过期 schema 报错——缓解：AGENTS.md 已有强制 dump 纪律，校验器报告中附带 schemas JSON 的组件计数，便于肉眼发现过期。
