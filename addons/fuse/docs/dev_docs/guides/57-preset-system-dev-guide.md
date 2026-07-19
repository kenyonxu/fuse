# 预设系统开发者指南

> **目标**: 为开发者提供 Fuse 预设系统的完整架构说明与扩展指引，覆盖 `FusePreset` 资源定义、序列化/反序列化管道、`PresetRegistry` 注册表、NodePath 映射以及与全局变量系统的交互。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-07-19

**配套用户文档**: [55-preset-system-guide.md](../../user_docs/guides/55-preset-system-guide.md)

---

## 📋 目录

1. [系统架构总览](#系统架构总览)
2. [FusePreset 资源定义](#fusepreset-资源定义)
3. [序列化管道（FusePresetSerializer）](#序列化管道fusepresetsSerializer)
4. [反序列化管道（FusePresetDeserializer）](#反序列化管道fusepresetdeserializer)
5. [PresetRegistry 注册表](#presetregistry-注册表)
6. [NodePath 解析（NodePathResolver）](#nodepath-解析nodepathresolver)
7. [预设创建流程](#预设创建流程)
8. [与全局变量系统的交互](#与全局变量系统的交互)
9. [加载与保存](#加载与保存)
10. [最佳实践](#最佳实践)
11. [常见陷阱](#常见陷阱)

---

## 系统架构总览

预设系统由 **数据层（Resource）→ 序列化层（Serializer/Deserializer）→ 注册层（Registry）→ UI 层（Dialog）** 四层构成：

| 组件 | 类型 | 路径 | 职责 |
|------|------|------|------|
| FusePreset | Resource | `core/resources/fuse_preset.gd` | 预设数据结构，L1-L4 四层表达，`to_json()` / `from_json()` |
| FusePresetSerializer | RefCounted 工具类 | `editor/serialization/fuse_preset_serializer.gd` | 节点/资源 → JSON（全静态方法） |
| FusePresetDeserializer | RefCounted 工具类 | `editor/serialization/fuse_preset_deserializer.gd` | JSON → 节点/资源（全静态方法） |
| NodePathResolver | RefCounted 工具类 | `editor/serialization/nodepath_resolver.gd` | NodePath 提取与三级匹配 |
| PresetRegistry | RefCounted 单例 | `editor/preset_registry.gd` | 扫描 `presets/` 目录，分类缓存（全静态方法） |
| PresetExportDialog | AcceptDialog | `editor/preset_export_dialog.gd` | 导出 UI，`get_preset()` 产出 FusePreset |
| PresetImportDialog | AcceptDialog | `editor/preset_import_dialog.gd` | 导入 UI，变量依赖展示 |
| NodePathMappingDialog | AcceptDialog | `editor/serialization/nodepath_mapping_dialog.gd` | 映射确认 UI |

**数据流向**：

```
导出: 场景节点 → Serializer.serialize() → Dictionary
                                    ↓
                    PresetExportDialog.get_preset() → FusePreset
                                    ↓
              ┌─ ResourceSaver → {name}.tres（Godot 资源）
              └─ JSON.stringify → {name}.json（可读/版本控制）
                                    ↓
                    PresetRegistry.scan_presets()（刷新缓存）

导入: .tres/.json → FusePreset
                    ↓
      NodePathResolver.extract_nodepaths() → resolve_mapping()
                    ↓
      NodePathMappingDialog（用户确认映射）
                    ↓
      Deserializer.deserialize(preset, mapping) → 场景节点
```

---

## FusePreset 资源定义

`FusePreset` 是预设的核心数据载体（`core/resources/fuse_preset.gd`），继承 `Resource`。

### 导出属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `display_name` | String | `""` | 预设显示名 |
| `category` | String | `""` | 分类标识（通常取文件夹名） |
| `description` | String | `""` | 描述文本 |
| `icon_name` | String | `""` | FuseIconManager 内置图标名 |
| `version` | String | `"1.0"` | 版本号 |
| `variables` | Dictionary | `{}` | 变量声明（`local`/`scope`/`global` 三键） |
| `level` | String | `"L1"` | 层级：L1 ∥ L2 ∥ L3 ∥ L4 |
| `event_json` | Dictionary | `{}` | L2 事件序列化数据 |
| `trigger_config` | Dictionary | `{}` | L2/L4 触发器配置 |
| `signal_binding` | Dictionary | `{}` | L3 信号绑定 |
| `event_bindings_json` | Array | `[]` | L4 多事件绑定 |
| `instructions` | Array[BaseInstruction] | `[]` | 指令序列 |

### 层级与序列化字段对应

| 层级 | 对应节点 | `to_json()` 输出的关键字段 |
|------|----------|---------------------------|
| **L1** | ActionRunner | `action_runner.instructions` |
| **L2** | Trigger | `action_runner.instructions` + `event` + `trigger_config` |
| **L3** | Runner | `action_runner.instructions` + `signal_binding` |
| **L4** | MultiEventTrigger | `trigger_config` + `event_bindings` |

### 关键方法

```gdscript
## 序列化为 JSON 字典（按 level 分支）
func to_json() -> Dictionary

## 从 JSON 字典构建预设（静态工厂）
static func from_json(data: Dictionary) -> FusePreset

## 提取指令树中所有去重 NodePath
func collect_unique_nodepaths() -> Array[NodePath]

## 应用 NodePath 映射（导入时重写指令中的路径）
func apply_nodepath_mapping(mapping: Dictionary) -> void

## 收集变量声明 → {"local": [...], "scope": [...], "global": [...]}
func collect_variables() -> Dictionary
```

### 指令序列化的属性过滤

序列化指令时会跳过基类公共属性，避免冗余：

```gdscript
const _BASE_PROPERTIES := ["log_level", "completion_timing", "execution_mode",
    "script", "resource_local_to_scene", "resource_name", "metadata"]
```

> **注意**: 新指令的自定义属性会**自动**被序列化（通过反射遍历属性列表），无需在预设系统中注册。但属性必须是 Godot 可序列化的 Variant 类型。

---

## 序列化管道（FusePresetSerializer）

`FusePresetSerializer`（`editor/serialization/fuse_preset_serializer.gd`）是纯静态工具类，负责**节点 → JSON** 方向。

### 核心 API

| 方法 | 返回 | 说明 |
|------|------|------|
| `detect_level(node)` | String | 根据节点类型自动检测层级（`"L1"`-`"L4"`） |
| `serialize(node)` | Dictionary | 通用入口，内部按 `detect_level` 分发 |
| `serialize_l1(runner)` | Dictionary | 序列化 ActionRunner |
| `serialize_l2(trigger)` | Dictionary | 序列化 Trigger（事件 + 配置 + 指令） |
| `serialize_l3(runner)` | Dictionary | 序列化 Runner（信号绑定 + 指令） |
| `serialize_l4(multi)` | Dictionary | 序列化 MultiEventTrigger（多事件绑定） |
| `serialize_action_runner(runner)` | Dictionary | 仅指令序列部分 |
| `serialize_event(event)` | Dictionary | 单个事件资源 → JSON |
| `serialize_condition(cond)` | Dictionary | 单个条件资源 → JSON |
| `serialize_trigger_config(node)` | Dictionary | 触发器公共配置（trigger_once/cooldown 等） |
| `serialize_signal_binding(node)` | Dictionary | L3 信号绑定配置 |
| `serialize_binding(binding)` | Dictionary | 单个 EventBinding → JSON |

### 指令序列化细节

```gdscript
static func _serialize_instructions(instructions: Array[BaseInstruction]) -> Array:
	# 每条指令输出 {"type": <类名>, ...属性键值对}
	# 嵌套指令（if/else/loop 的子指令数组）递归序列化
```

- 指令类型以 **`type` 字段（类名字符串）** 记录，反序列化时按类名重新加载脚本
- `_serialize_resource_properties(res)` 通过反射导出 Resource 属性，跳过 `_BASE_PROPERTIES`

### 变量收集

`_collect_all_variables(instructions)` 扫描指令序列，按 `variable_scope` 整数归类：

```gdscript
match scope:
	0:  # LOCAL  → result["local"].append(name)
	1:  # SCOPE  → result["scope"].append({"name": name, "container": target_node})
	2:  # GLOBAL → result["global"].append(name)
```

> **要点**: 该扫描仅识别实现了 `variable_name` + `variable_scope` 属性的指令。自定义指令若引用变量，应遵循同一属性命名约定，否则预设的变量依赖声明会缺失。

---

## 反序列化管道（FusePresetDeserializer）

`FusePresetDeserializer`（`editor/serialization/fuse_preset_deserializer.gd`）负责**JSON → 节点** 方向。

### 核心 API

| 方法 | 返回 | 说明 |
|------|------|------|
| `deserialize(preset, mapping)` | Object | 通用入口，按 `preset.level` 分发，应用 NodePath 映射 |
| `validate_imported_node(node, level)` | Array[String] | 导入后验证，返回错误列表 |

内部分发（私有静态方法）：

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `_import_l1(preset, _mapping)` | ActionRunner | 创建 ActionRunner + 指令 |
| `_import_l2(preset, mapping)` | Trigger | 创建 Trigger + 事件 + 指令 |
| `_import_l3(preset, mapping)` | Runner | 创建 Runner + 信号绑定 + 指令 |
| `_import_l4(preset, mapping)` | MultiEventTrigger | 创建 MultiEventTrigger + 事件绑定 |

### 脚本缓存机制

反序列化按 `type` 字段加载对应类脚本，并做缓存避免重复 IO：

```gdscript
static func _cache_instruction_script(type_name: String) -> GDScript
static func _cache_event_script(type_name: String) -> GDScript
static func _cache_condition_script(type_name: String) -> GDScript
```

### 属性写回与映射

```gdscript
## 设置属性值（处理类型转换）
static func _set_property_value(obj: Object, key: String, val) -> void

## 对节点及其指令递归应用 NodePath 映射
static func _apply_nodepath_mapping_node(node: Node, mapping: Dictionary) -> void
static func _apply_mapping_recursive(obj: Object, mapping: Dictionary) -> void
```

**导入后必须调用** `validate_imported_node()` 做完整性检查（如 L2 是否有事件、L4 是否有启用的绑定）。

---

## PresetRegistry 注册表

`PresetRegistry`（`editor/preset_registry.gd`）是预设的中央缓存，**全部为静态方法**，无需实例化。

### API

| 方法 | 返回 | 说明 |
|------|------|------|
| `scan_presets()` | void | 递归扫描 `res://addons/fuse/presets/`，加载所有 `.tres` |
| `get_all()` | Array[FusePreset] | 所有已注册预设 |
| `get_by_category(category)` | Array[FusePreset] | 按分类筛选 |
| `get_categories()` | Array[String] | 所有分类名 |
| `clear()` | void | 清空缓存 |

### 调用时机

```gdscript
# 1. 插件初始化时自动扫描
# 2. 每次导出预设后自动重新扫描
# 3. 手动添加 .tres 文件后必须手动刷新：
PresetRegistry.scan_presets()
```

> **注意**: 注册表只扫描 `.tres` 文件。`.json` 文件仅供跨项目分享/版本对比，不参与注册表。

---

## NodePath 解析（NodePathResolver）

`NodePathResolver`（`editor/serialization/nodepath_resolver.gd`）处理预设跨场景复用时最核心的痛点：**原场景的 NodePath 在新场景中失效**。

### 提取

```gdscript
## 从指令序列提取所有 NodePath（去重，递归嵌套指令和 condition）
static func extract_nodepaths(instructions: Array) -> Array[String]
```

嵌套指令通过 `_SUB_INSTRUCTIONS` 常量声明子指令属性名：

```gdscript
const _SUB_INSTRUCTIONS := ["instructions", "else_instructions", "loop_instructions"]
```

> **扩展要点**: 若新指令包含子指令数组且属性名不在上表，需将其加入 `_SUB_INSTRUCTIONS`，否则嵌套指令中的 NodePath 不会被提取和映射。

### 三级匹配策略

```gdscript
## 生成映射建议
## 返回 {old_np: {"new": NodePath, "matched": bool, "suggestions": Array[String]}}
static func resolve_mapping(...) -> Dictionary
```

| 优先级 | 策略 | 实现 |
|--------|------|------|
| 1 | 相对路径结构匹配 | `_match_relative()` — 从目标节点（及其父节点）按原路径解析 |
| 2 | 全局同名匹配 | `_find_node_by_name()` — 提取路径最后一段节点名，广度优先搜索 |
| 3 | 手动选择 | `_collect_node_suggestions()` — 收集场景全部节点路径供用户挑选 |

另提供独立解析入口：

```gdscript
## 尝试所有策略解析 NodePath 字符串，失败返回 null
static func resolve_or_null(np_str: String, scene_root: Node) -> Node
```

---

## 预设创建流程

### 方式一：代码创建（推荐用于测试/工具链）

```gdscript
# 1. 构建预设资源
var preset := FusePreset.new()
preset.display_name = "Patrol_Guard"
preset.category = "gameplay"
preset.description = "巡逻守卫行为"
preset.level = "L2"
preset.icon_name = "Bullet"

# 2. 填充指令
var move := TweenMoveTo.new()
move.target_node = NodePath("./Player")
move.duration = 3.0
preset.instructions = [move]

# 3. 填充 L2 事件数据（可由 FusePresetSerializer.serialize_event 生成）
preset.event_json = {"type": &"OnInterval", "interval_seconds": 2.0, "auto_start": true}
preset.trigger_config = {"trigger_once": false, "cooldown_mode": 0, "cooldown_time": 1.0}

# 4. 收集变量声明
preset.variables = preset.collect_variables()

# 5. 保存（双格式）
ResourceSaver.save(preset, "res://addons/fuse/presets/gameplay/patrol_guard.tres")
var json_text := JSON.stringify(preset.to_json(), "\t")
var file := FileAccess.open("res://addons/fuse/presets/gameplay/patrol_guard.json", FileAccess.WRITE)
file.store_string(json_text)
file.close()

# 6. 刷新注册表
PresetRegistry.scan_presets()
```

### 方式二：从场景节点创建（导出对话框路径）

```
1. 选中场景中的 Trigger/Runner/MultiEventTrigger
2. FusePresetSerializer.detect_level(node)   → 自动检测层级
3. FusePresetSerializer.serialize(node)      → Dictionary
4. PresetExportDialog._init(source)          → 填充 UI 字段
5. 用户确认名称/描述/图标/目标文件夹
6. PresetExportDialog.get_preset()           → FusePreset
7. Inspector 插件保存 .tres + .json → PresetRegistry.scan_presets()
```

`get_preset()` 是对话框对外的产出接口——**对话框本身不写盘**，写盘由调用方（`fuse_inspector_plugin.gd`）完成，便于单元测试。

### 导出前置验证

导出按钮显示前的层级检查（未通过则隐藏按钮）：

| 层级 | 检查条件 |
|------|----------|
| L2 | `event_definition` 已配置 |
| L3 | `action_runner` 已配置 |
| L4 | 至少一个 `enabled = true` 的事件绑定 |

---

## 与全局变量系统的交互

预设系统与全局变量系统是**声明-依赖**关系，而非存储关系。

### 变量声明的生成

导出时 `collect_variables()` 扫描指令序列，将 `variable_scope == 2`（GLOBAL）的变量名写入 `variables["global"]`：

```json
"variables": {
    "local": ["cooldown", "damage"],
    "scope": [{"name": "hp", "container": "../Player"}],
    "global": ["score", "level"]
}
```

### 导入时的处理原则

| 作用域 | 导入时行为 |
|--------|-----------|
| `local` | 无需处理 — 运行时由 ExecutionContext 自动创建 |
| `scope` | 依赖展示 — 目标节点需有 ScopeVariableContainer，运行时注入 |
| `global` | 依赖展示 — **不会自动创建**，需项目中已通过 GlobalVariableManager 注册 |

**关键设计决策**：预设导入**不调用** `GlobalVariableManager.add_variable()`。原因：

1. 全局变量属于**项目级状态**，预设只声明"我需要这些变量存在"
2. 自动创建会覆盖项目已有的同名变量值
3. 变量的初始值、类型、`persistent` 标记应由项目侧决定（通常在游戏初始化 Trigger 中用 SetVariable 建立）

### 开发者接入建议

若需在导入后为预设补齐全局变量，推荐模式：

```gdscript
# 导入完成后，检查缺失的全局变量并提示/初始化
var gvm := GlobalVariableManager.get_instance()
var deps: Dictionary = preset.collect_variables()
for var_name in deps.get("global", []):
	if not gvm.has_variable(var_name):
		var v := BaseVariable.new()
		v.variable_name = var_name
		v.value = 0           # 项目决定的默认值
		v.persistent = true
		gvm.add_variable(var_name, v)
		push_warning("预设依赖的全局变量已自动初始化: %s" % var_name)
```

详细全局变量机制见 [59-global-variables-dev-guide.md](59-global-variables-dev-guide.md)。

---

## 加载与保存

### .tres 格式（运行时/编辑器加载）

```gdscript
# 加载
var preset := load("res://addons/fuse/presets/gameplay/patrol_guard.tres") as FusePreset

# 保存
ResourceSaver.save(preset, path)
```

### .json 格式（跨项目/版本控制）

```gdscript
# 导出 JSON
var data: Dictionary = preset.to_json()
var text := JSON.stringify(data, "\t")

# 导入 JSON
var parsed: Variant = JSON.parse_string(file.get_as_text())
var preset := FusePreset.from_json(parsed)
```

### 反序列化为场景节点

```gdscript
# 完整导入管道
var nodepaths := NodePathResolver.extract_nodepaths(preset.instructions)
var mapping := {}
if not nodepaths.is_empty():
	mapping = NodePathResolver.resolve_mapping(...)   # 三级匹配
	# → NodePathMappingDialog 用户确认 → dialog.get_final_mapping()

var node: Object = FusePresetDeserializer.deserialize(preset, mapping)
var errors := FusePresetDeserializer.validate_imported_node(node, preset.level)
if errors.is_empty():
	target_node.add_child(node)
	node.owner = get_tree().edited_scene_root   # 编辑器中必须设置 owner 才能保存
```

> **编辑器要点**: 导入创建的节点必须设置 `owner` 为场景根，否则不会随场景保存。

---

## 最佳实践

### 1. 始终生成双格式

- `.tres` — 供 `load()` 与 PresetRegistry 使用
- `.json` — 供版本控制 diff 与跨项目分享
- 两者内容必须一致（同一 `FusePreset` 实例产出）

### 2. 变量声明保持最新

修改 `instructions` 后重新调用 `collect_variables()`：

```gdscript
preset.instructions = new_instructions
preset.variables = preset.collect_variables()  # 必须刷新
```

### 3. NodePath 使用相对路径

- ✅ `../Player`、`./HUD/ScoreLabel`
- ❌ `/root/Game/Player`（跨场景必失效，三级匹配也无法挽回）

### 4. 新指令遵循变量属性命名约定

自定义指令引用变量时使用 `variable_name` + `variable_scope` 属性名，预设系统才能自动收集依赖。

### 5. 版本字段语义化

修改预设结构（增删字段）时递增 `version`，`from_json()` 中可按版本做兼容分支。

---

## 常见陷阱

### 陷阱 1: 忘记刷新 PresetRegistry

**问题**: 手动复制 `.tres` 到 `presets/` 后面板不显示。

**解决**: 调用 `PresetRegistry.scan_presets()`。

### 陷阱 2: 嵌套指令的 NodePath 未被映射

**问题**: 自定义指令的子指令数组属性名不在 `_SUB_INSTRUCTIONS` 中。

**解决**: 将属性名加入 `NodePathResolver._SUB_INSTRUCTIONS` 常量。

### 陷阱 3: 导入节点未设置 owner

**问题**: 导入的 Trigger 在编辑器中可见，但保存场景后消失。

**解决**: `node.owner = get_tree().edited_scene_root`。

### 陷阱 4: 指令属性使用不可序列化类型

**问题**: 指令属性为节点引用/对象引用，序列化后丢失或报错。

**解决**: 资源中只存 NodePath/字符串路径，运行时用 `context.get_node()` 解析（与指令开发规范一致）。

### 陷阱 5: 期望导入自动创建全局变量

**问题**: 导入预设后 `GetVariable [GLOBAL]` 报变量未找到。

**解决**: 全局变量是项目级依赖，需在游戏初始化流程中注册；参考[与全局变量系统的交互](#与全局变量系统的交互)。

### 陷阱 6: JSON 中枚举存储为整数

**问题**: 手动编辑 JSON 时把枚举写成字符串（如 `"variable_scope": "GLOBAL"`），反序列化类型不匹配。

**解决**: JSON 中枚举一律为整数（LOCAL=0, SCOPE=1, GLOBAL=2），与 `collect_variables()` 的 match 分支一致。

---

## 总结

预设系统开发核心要点：

1. ✅ **四层架构清晰分工** — FusePreset（数据）→ Serializer/Deserializer（管道）→ PresetRegistry（缓存）→ Dialog（UI）
2. ✅ **序列化全静态** — `FusePresetSerializer` / `FusePresetDeserializer` 无需实例化
3. ✅ **指令类型即类名** — `type` 字段驱动脚本缓存加载，新指令自动支持
4. ✅ **变量是依赖声明** — `collect_variables()` 生成 local/scope/global 三键声明，导入不自动创建全局变量
5. ✅ **NodePath 三级匹配** — 相对结构 → 同名搜索 → 手动选择，扩展点 `_SUB_INSTRUCTIONS`
6. ✅ **双格式持久化** — `.tres` 供加载，`.json` 供版本控制

**参考文档**:
- [预设系统使用指南](../../user_docs/guides/55-preset-system-guide.md)
- [全局变量开发指南](59-global-variables-dev-guide.md)
- [变量监视器开发指南](58-variable-watcher-dev-guide.md)
- [指令创建指南](instruction_creation_guide.md)

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-19
