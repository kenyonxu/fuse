# 预设系统使用指南

Fuse 预设系统提供**工作流复用 + 跨项目分享**的一体化方案，覆盖从编辑器导出到 JSON/`.tres` 文件再到导入还原的完整管道。系统由以下组件构成：

| 组件 | 类型 | 路径 | 用途 |
|------|------|------|------|
| FusePreset | 资源 (Resource) | `core/resources/fuse_preset.gd` | 预设数据结构，四层(L1-L4)表达 |
| PresetRegistry | 单例 (RefCounted) | `editor/preset_registry.gd` | 扫描 `presets/` 目录，分类缓存 |
| PresetExportDialog | 对话框 | `editor/preset_export_dialog.gd` | 导出预设 UI（选择层级/名称/文件夹） |
| PresetImportDialog | 对话框 | `editor/preset_import_dialog.gd` | 导入预设 UI（节点创建 + 映射确认） |
| FusePresetSerializer | 工具类 | `editor/serialization/fuse_preset_serializer.gd` | 节点/资源 → JSON 序列化 |
| FusePresetDeserializer | 工具类 | `editor/serialization/fuse_preset_deserializer.gd` | JSON → 节点/资源 反序列化 |
| NodePathResolver | 工具类 | `editor/serialization/nodepath_resolver.gd` | NodePath 提取与自动匹配 |
| NodePathMappingDialog | 对话框 | `editor/serialization/nodepath_mapping_dialog.gd` | 映射确认用户界面 |

---

## 概念准备：预设资源结构

`FusePreset` 是一个 `Resource`，包含通用元数据和按**层级(Level)** 组织的数据。

### 通用属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `display_name` | String | `""` | 预设名称（面板中显示） |
| `category` | String | `""` | 分类标识 |
| `description` | String | `""` | 描述文本 |
| `icon_name` | String | `""` | 图标（FuseIconManager builtin_icon 名称，如 `Bullet`、`Sprite2D`） |
| `version` | String | `"1.0"` | 版本号 |
| `level` | String | `"L1"` | 预设层级：L1 ∥ L2 ∥ L3 ∥ L4 |
| `variables` | Dictionary | `{}` | 变量声明（见下文） |
| `instructions` | Array[BaseInstruction] | `[]` | 指令序列 |

### 四层结构

预设系统按 **LR-BOM**（Logical Run — 逻辑运行单元）中的节点类型定义了四个层级的适用场景：

| 层级 | 对应节点 | 包含内容 | 序列化数据 |
|------|----------|----------|-----------|
| **L1** | ActionRunner | 指令序列 | `action_runner.instructions` |
| **L2** | Trigger | 事件 + 指令 | `event_json` + `trigger_config` + `action_runner.instructions` |
| **L3** | Runner | 信号绑定 + 指令 | `signal_binding` + `action_runner.instructions` |
| **L4** | MultiEventTrigger | 多事件绑定 | `event_bindings_json` + `trigger_config` |

各层在 `to_json()` / `from_json()` 中按 `level` 字段分支序列化：

```gdscript
match level:
    "L1":
        data["action_runner"] = {"instructions": _serialize_instructions()}
    "L2":
        data["action_runner"] = {"instructions": _serialize_instructions()}
        data["event"] = event_json
        data["trigger_config"] = trigger_config
    "L3":
        data["action_runner"] = {"instructions": _serialize_instructions()}
        data["signal_binding"] = signal_binding
    "L4":
        data["trigger_config"] = trigger_config
        data["event_bindings"] = event_bindings_json
```

### 变量声明格式

`variables` 字典包含三个键，分别描述指令序列中引用的变量：

```json
{
    "local": ["n1", "temp_value"],
    "scope": [
        {"name": "hp", "container": "../Player"},
        {"name": "mana", "container": ""}
    ],
    "global": ["level", "score"]
}
```

- **`local`** — 本地变量名列表
- **`scope`** — 作用域变量列表，每项包含 `name` 和可选的 `container`（NodePath）
- **`global`** — 全局变量名列表

通过 `collect_variables()` 方法自动从指令序列中提取。

---

## 预设面板操作

预设的导出和导入入口位于 **Inspector 面板**，当选中 `Trigger`、`Runner` 或 `MultiEventTrigger` 节点时自动出现。

### 导出预设（L2 ∥ L3 ∥ L4）

1. 在场景中选中要导出的节点（`Trigger` / `Runner` / `MultiEventTrigger`）
2. Inspector 底部显示一行操作按钮：
   - **📦 导出 (Trigger/触发器)** — 点击后弹出导出对话框
   - **📥 导入预设** — 点击后弹出文件选择器
3. 导出对话框包含以下字段：

| 字段 | 说明 |
|------|------|
| 层级 | 自动检测（只读），如 `L2 · Trigger（事件 + 指令）` |
| 名称 | 预设显示名，默认取节点名 |
| 目标文件夹 | 保存路径（如 `res://addons/fuse/presets/my_category/`） |
| 描述 | 预设用途说明 |
| 图标 | FuseIconManager 内置图标名（可选） |
| 信息 | 自动检测的 NodePath 数量和变量数量 |

4. 点击 **导出** 后同时生成两个文件：
   - `{name}.tres` — Godot 资源文件（可直接 `load()`）
   - `{name}.json` — 可读的 JSON 格式（适合跨项目分享或版本控制）

5. 导出后自动调用 `PresetRegistry.scan_presets()` 刷新注册表。

**验证规则**：导出前会做前置检查，未通过则不显示导出按钮：

| 层级 | 检查条件 |
|------|----------|
| L2 | `event_definition` 已配置 |
| L3 | `action_runner` 已配置 |
| L4 | 至少有一个启用(`enabled=true`)的事件绑定 |

### 导入预设

1. 点击 Inspector 底部的 **📥 导入预设** 按钮
2. 文件选择器过滤 `.tres` 和 `.json` 文件，默认目录 `res://addons/fuse/presets/`
3. 选择文件后显示 **PresetImportDialog**：

```
+------------------------------------------+
| 应用预设: RedPlanetAttack [L2]           |
|                                          |
| L2 · Trigger（将创建 Trigger 节点）       |
|                                          |
| gameplay · RedPlanetAttack               |
| 周期发动对红色星球的上攻击                |
|                                          |
| 变量依赖:                                |
|   [local] cooldown, damage               |
|   [scope] hp — 由指令运行时注入          |
|   [global] score — 项目级存在            |
|                                          |
|                [创建节点]                 |
+------------------------------------------+
```

4. **NodePath 映射**：若预设中包含 NodePath 引用，会弹出 **NodePathMappingDialog**：

```
+------------------------------------------+
| NodePath 映射                            |
|                                          |
| 以下路径需要映射到当前场景的节点：         |
|                                          |
| ../Player          → [✓ /root/Player ]  v|
| ../EnemySpawner    → [⚠ 请选择节点...]  v|
|                                          |
|         [确认导入]                        |
+------------------------------------------+
```

5. 确认后创建对应节点并挂到场景树（选中的节点下，或场景根节点）

---

## NodePath 映射机制

预设导入时，原场景中的 NodePath 在新场景中不再有效，需要进行映射。`NodePathResolver` 实现了三级匹配策略：

### 策略 1：相对路径结构匹配

尝试从**目标节点**（选中作为父节点的节点）按原路径解析：

```gdscript
var found = target_node.get_node_or_null(old_np)  # 原样解析
```

若失败，再尝试从**父节点**解析（预设可能在 Trigger 父节点下创建）。

### 策略 2：全局同名匹配

提取原路径的**最后一段节点名**，在新场景中广度优先搜索同名节点：

- `../Player/HUD` → 搜索名为 `HUD` 的节点
- `../Enemies/Boss` → 搜索名为 `Boss` 的节点

### 策略 3：手动选择

当以上策略均未匹配时，在 NodePathMappingDialog 中展示**场景所有节点路径**供用户手动选择。

### 映射处理流程

完整流程如下（`fuse_inspector_plugin.gd:_apply_preset_to_node`）：

```
1. NodePathResolver.extract_nodepaths()   ← 从指令树提取所有 NodePath
2. if 无 NodePath → 直接导入
3. NodePathResolver.resolve_mapping()     ← 三级匹配生成建议
4. NodePathMappingDialog                  ← 用户确认 / 手动修正
5. dialog.get_final_mapping()             ← 确认后取最终映射表
6. FusePresetDeserializer.deserialize()   ← 应用映射 + 反序列化
7. 刷新指令 resource_name（NodePath 映射后显示名）
```

---

## 附赠样本预设

Fuse 内置 4 个样本预设，位于 `addons/fuse/presets/`：

### gameplay（游戏玩法）

| 预设 | 层级 | 说明 |
|------|------|------|
| `red_planet.tres` | L2 | 每 50 秒将节点移动到 `(0, 900)`，模拟"红色星球"周期下沉效果 |
| `spawn_enemy.tres` | L2 | 用于敌人刷新的触发预设（含实例化子场景 + 位置设置指令） |
| `game_flow.tres` | L2 | 游戏流程控制预设，管理关卡阶段的过渡逻辑 |

### ui（用户界面）

| 预设 | 层级 | 说明 |
|------|------|------|
| `hint_breath.tres` | L2 | 1.3 秒周期的 UI 呼吸效果：淡入（0.5s）→ 淡出（0.5s）循环，适用于提示文字闪烁 |

样本预设的完整 `.tres` 结构示例（`hint_breath.tres` 简化）：

```gdscript
[resource]
display_name = "HintBreath"
category = "ui"
level = "L2"
event_json = {
    "type": &"OnInterval",
    "interval_seconds": 1.3,
    "auto_start": true,
    "trigger_on_start": false
}
trigger_config = {
    "trigger_once": false,
    "cooldown_mode": 0,
    "cooldown_time": 1.0
}
# 指令：淡入（0.5s）→ 淡出（0.5s）
instructions =
    [TweenFadeIn: from_alpha=0.0, to_alpha=1.0, duration=0.5, target=..]
    [TweenFadeOut: duration=0.5, target=..]
```

---

## PresetRegistry 注册表

`PresetRegistry` 是预设的中央注册表，提供分类查询能力：

| 方法 | 返回 | 说明 |
|------|------|------|
| `scan_presets()` | void | 扫描 `res://addons/fuse/presets/` 目录，递归加载所有 `.tres` |
| `get_all()` | Array[FusePreset] | 获取所有已注册预设 |
| `get_by_category(category)` | Array[FusePreset] | 按分类筛选 |
| `get_categories()` | Array[String] | 获取所有存在的分类名 |
| `clear()` | void | 清空缓存 |

**调用时机**：
- 插件初始化时自动扫描
- 每次导出预设后自动重新扫描
- 手动添加 `.tres` 文件到 `presets/` 后需调用 `scan_presets()`

---

## 变量依赖检查

导入对话框中会展示预设指令序列所引用的变量依赖（`collect_variables()` 结果）：

```
变量依赖:
  [local] cooldown, damage — 运行时自动创建
  [global] score — 项目级存在
```

- **local 变量**：运行时由 ExecutionContext 自动创建，无需手动声明
- **scope 变量**：需要确保目标节点有 ScopeVariableContainer
- **global 变量**：需要在项目中存在（通过 GlobalVariableManager 管理）

---

## 完整工作流：从创建到复用

```
# 项目 A：创建并导出

1. 配置 Trigger 节点：
   - 设置 OnInterval 事件，间隔 2 秒
   - 添加 TweenMoveTo 指令，目标路径 ./Player
   - 添加 SetVariable 指令，设置 scope:score

2. 选中 Trigger → Inspector 底部点击 📦 导出 (Trigger)
3. 填写名称 "Patrol_Guard"、描述 "巡逻守卫行为"
4. 目标文件夹: res://addons/fuse/presets/gameplay/
5. 导出 → 生成 Patrol_Guard.tres + Patrol_Guard.json
```

```
# 项目 B：导入并适配

1. 选中空节点作为挂载点
2. Inspector 底部点击 📥 导入预设
3. 选择 Patrol_Guard.tres
4. 查看信息：L2 Trigger，含 1 个 NodePath (./Player)
5. NodePathMappingDialog：
   - ./Player → ✓ /root/Player (自动匹配)
   - 确认导入
6. Trigger 节点创建完成，接上自己的 Player 即可运行
```

---

## 文件格式

### .tres 格式

Godot 原生资源格式，可直接 `load()` 获取 `FusePreset` 实例。包含完整的类型信息和子资源引用。

### .json 格式

跨平台可读格式，适合手动编辑、版本对比或从外部工具生成：

```json
{
    "format_version": "1.0",
    "level": "L2",
    "display_name": "Patrol_Guard",
    "category": "gameplay",
    "description": "巡逻守卫行为",
    "icon_name": "Bullet",
    "variables": {
        "local": ["patrol_index"],
        "scope": [{"name": "alert_level", "container": ""}],
        "global": []
    },
    "event": {
        "type": "OnInterval",
        "interval_seconds": 2.0,
        "auto_start": true
    },
    "trigger_config": {
        "trigger_once": false,
        "cooldown_mode": 0,
        "cooldown_time": 1.0
    },
    "action_runner": {
        "instructions": [
            {"type": "TweenMoveTo", "target_node": "./Player", "duration": 3.0},
            {"type": "SetVariable", "variable_name": "alert_level", "variable_scope": 1, "value": 50}
        ]
    }
}
```

---

## 最佳实践

### 命名与分类
- 使用 `snake_case` 作为文件名：`patrol_guard.tres`
- 按游戏系统组织目录：`presets/gameplay/`、`presets/ui/`、`presets/audio/`
- `category` 自动从文件夹名提取

### 导出策略
- **功能片段导出 L1**：纯指令组合，可拖入任意 ActionRunner
- **完整触发器导出 L2**：包含事件配置，即导即用
- **信号适配器导出 L3**：用于自定义信号到指令的桥接
- **复合触发器导出 L4**：多事件绑定 + 条件组合

### NodePath 规范
- 使用相对路径 (`../Player`、`./HUD/ScoreLabel`)
- 避免硬编码绝对路径 (`/root/Game/Player`)
- 目标节点在场景树中保持稳定名称

### 版本管理
- 建议将 `.json` 文件纳入版本控制（便于 diff）
- `.tres` 文件可提交但不易对比差异
- `version` 字段用于向前兼容判断

---

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 导出按钮不显示 | 未通过前置验证 | 检查 event_definition / action_runner 配置 |
| 导入后 NodePath 丢失 | 映射未正确配置 | 检查 NodePathMappingDialog 中每项映射 |
| 指令类型找不到 | `FusePreset` 依赖 `InstructionRegistry` | 确保 Fuse 插件已完全加载 |
| JSON 解析失败 | 格式错误或版本不兼容 | 用 `.tres` 格式导入或手动修正 JSON |

---

**相关文档:**
- [变量系统指南](01-variable_system_guide.md)
- [编辑器面板总览](00-editor-panels-overview.md)
- [触发器选择指南](02-trigger-selection-guide.md)
- [Runner 指南](03-runner-guide.md)
- [多事件触发器指南](04-multi-event-trigger-guide.md)
