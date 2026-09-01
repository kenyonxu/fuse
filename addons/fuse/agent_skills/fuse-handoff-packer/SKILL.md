# fuse-handoff-packer：Fuse 系统毕业交接打包

把 Fuse 场景中调稳的系统打包为**自包含交接工件包**（handoff bundle），交给 AI agent
编写脱离 Fuse 的工程代码。本 skill 是交互式的：每一步与用户确认后再前进。

**不可破坏的约束**：只读 Fuse 侧资产、只写 `fuse_generated/handoff/<系统名>/`；
不生成游戏代码（那是接包 agent 的事）；不修改源场景与 Trigger。

## 触发词
"毕业这个系统" / "打包 handoff" / "交接 X 系统"

## 前置原料（缺什么补什么，见步骤）
- System 划分定稿：`fuse_generated/systems/<name>.json`（derive_systems CLI 产出）
- 源场景拓扑：`export_topology` CLI 产出
- 行为规格：用户从编辑器导出的 preset JSON（Inspector 选中节点 → 📦 导出）
- 组件 schema：`addons/fuse/preset_ai_context/fuse_component_schemas.json` 等三 JSON
- 本 skill 资产：`assets/`（semantics / README 模板 / 验收指引 / 基建模板）

## 七步流程

### 1 确认目标
问用户三件事：哪个场景、哪个（些）系统、毕业动机（性能接管 / 脱离插件 / 交接给
程序员——动机影响验收重点与模板取舍）。系统名与 `fuse_generated/systems/` 下的
文件名对应。

### 2 备料：System 划分
检查 `fuse_generated/systems/<name>.json` 是否存在且过校验：
- 不存在 → 代跑推导 CLI（输出重定向到文件再查看，Godot console exe 输出接管道会挂死）：
  ```
  <Godot> --headless --path <项目> res://addons/fuse/editor/graduation/derive_systems.tscn \
    -- --scene res://<场景>.tscn > /tmp/derive.log 2>&1
  ```
  然后与用户逐单元确认：划分是否合理、补 description、`_derive_report.json` 的
  warnings_by_unit 是否拷入 acknowledged_warnings（不确认的警告要向用户解释后果）
- 存在 → 代跑校验：
  ```
  <Godot> --headless --path <项目> res://addons/fuse/editor/graduation/validate_system.tscn \
    -- <system.json> > /tmp/validate.log 2>&1
  ```
  有 error（退出码 1）先与用户解决；topology_digest 漂移说明场景改过，需重新 derive。

### 3 行为规格：preset
引导用户提供系统涉及单元的 preset JSON：
- 已导出 → 直接用（通常在用户项目的 preset 目录）
- 未导出 → 指引用户在编辑器中选中对应 Trigger / Runner / MultiEventTrigger 节点，
  点 Inspector 的 **📦 导出** 按钮（详细步骤见 Fuse 的 55 号预设指南）
- 补充路径：需要节点层级 / NodePath 锚点时直接读源 `.tscn` 文本核对
  （preset 是行为规格主体，.tscn 只用于结构核对）

### 4 拓扑快照
代跑（产物名 = 场景文件茎，含 source_scene 溯源）：
```
<Godot> --headless --path <项目> res://addons/fuse/editor/topology/export_topology.tscn \
  -- --scene res://<场景>.tscn > /tmp/topo.log 2>&1
```

### 5 模板确认
扫描 preset JSON 中出现的指令 `type` 集合，按下表推荐基建模板，展示给用户确认增删：
| preset 中出现 | 推荐模板 | 对齐的 Fuse 概念 |
|---------------|----------|------------------|
| SendEvent / OnReceiveEvent | `templates/event_bus.gd` | FuseEventBus 总线 |
| WarmUpPool | `templates/object_pool.gd` | 对象池系统 |
| global 层变量（读写 scope="global"） | `templates/global_state.gd` | global 变量层 / 存读档 |
无匹配依赖则不带 templates/ 目录（向用户说明）。

### 6 打包
逐件落盘到 `fuse_generated/handoff/<系统名>/`：
| 产物 | 来源与做法 |
|------|-----------|
| `system.json` | 拷贝定稿 |
| `topology.json` | 拷贝步骤 4 产物 |
| `presets/*.json` | 拷贝步骤 3 的 preset（多份全拷） |
| `semantics.md` | 拷贝 `assets/semantics.md` |
| `README-for-agent.md` | 按 `assets/README-for-agent.tpl` 填充 `{{占位符}}`（意图/范围/事件变量摘要从 system.json 提取） |
| `acceptance.md` | 按 `assets/acceptance-guide.md` 指引从 preset 现场提炼 |
| `components.json` | 收集 preset 中出现的全部 `type` → 从 `fuse_component_schemas.json` 抽对应条目为 `{组件名: 参数表}`；再从 `fuse_components.json`（list）按 name 过滤出条目数组的说明信息（category / description 键名）；枚举值从 `fuse_enums.json` 抽涉及的枚举。**preset 中出现但 schema 缺失的组件**：照常打包 preset 原文，并在 README-for-agent.md 标注"该组件无 schema，按 JSON 原文理解" |
| `templates/*.gd` | 拷贝用户确认后的模板 |

### 7 交付
向用户报告：bundle 路径、内容摘要（单元/事件/变量/断言数）、下一句提示——
"把该目录交给你的 AI agent；要求它交付前逐条核对 acceptance.md 并回标"。

## 失败分支速查
- derive 校验 error → 与用户解决后重跑（步骤 2）
- 用户不会导出 preset → 指 55 号指南的导出小节
- Godot CLI 无输出/挂起 → 检查是否忘了输出重定向到文件
