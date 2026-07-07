# FuseComponentScanner 组件扫描器开发指南

> **目标**: 为开发者提供 FuseComponentScanner 组件扫描注册机制的完整开发指引，包括扫描、注册、元数据验证和撤销注册。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-07-07

---

## 📋 目录

1. [系统概述](#系统概述)
2. [架构设计](#架构设计)
3. [FuseComponentScanner API](#fusecomponentscanner-api)
4. [ComponentRegistry API](#componentregistry-api)
5. [专用 Registry API](#专用-registry-api)
6. [注册流程详解](#注册流程详解)
7. [使用指南](#使用指南)
8. [最佳实践](#最佳实践)
9. [常见陷阱](#常见陷阱)

---

## 系统概述

`FuseComponentScanner` 是 Fuse 的**组件扫描注册引擎**，负责扫描 `instructions/`、`events/`、`conditions/` 目录下的 GDScript 脚本文件，验证元数据后通过 `ComponentRegistry` 及其三个专用 Registry 完成注册。

### 核心文件

| 文件 | 类名 | 用途 |
|------|------|------|
| `editor/bootstrap/fuse_component_scanner.gd` | `FuseComponentScanner` | 扫描引擎（RefCounted） |
| `editor/component_registry.gd` | `ComponentRegistry` | 通用注册器 |
| `editor/instruction_selector/instruction_registry.gd` | `InstructionRegistry` | 指令注册器 |
| `editor/event_registry.gd` | `EventRegistry` | 事件注册器 |
| `editor/condition_registry.gd` | `ConditionRegistry` | 条件注册器 |
| `editor/preset_registry.gd` | `PresetRegistry` | 预设注册器 |

### 设计目标

- **自动化注册**: 启动时自动扫描目录，无需手动注册每个组件
- **泛型扫描**: 同一套扫描逻辑用于指令、事件、条件三种组件
- **元数据验证**: 扫描时验证每个组件是否实现了必需的元数据方法
- **重复检测**: 自动检测重复的 identifier 并去重更新
- **可撤销**: 插件停用时通过 `teardown()` 清空所有注册表

---

## 架构设计

```
FuseComponentScanner._init(plugin: EditorPlugin)
        │
        │ setup()
        ▼
├── _register_all_instructions()
│       └── _register_components_from_folders(
│               folders, "_get_instruction_metadata",
│               "InstructionRegistry", ...)
│
├── _register_events()
│       └── _register_components_from_folders(
│               folders, "_get_event_metadata",
│               "EventRegistry", ...)
│
├── _register_conditions()
│       └── _register_components_from_folders(
│               folders, "_get_condition_metadata",
│               "ConditionRegistry", ...)
│
└── PresetRegistry.scan_presets()

        │ 扫描结果
        ▼
┌──────────────────────────────────────────────────┐
│               ComponentRegistry                   │
│                                                   │
│  _instructions: Array[Dictionary]                 │
│  _instruction_map: Dictionary (name → info)       │
│  _events: Array[Dictionary]                       │
│  _event_map: Dictionary                           │
│  _conditions: Array[Dictionary]                   │
│  _condition_map: Dictionary                       │
│                                                   │
│  _duplicate_counts: Dictionary                    │
│  (ComponentType → int, 用于扫描可观测性)           │
└──────────────────────────────────────────────────┘
        ↕                      ↕                    ↕
InstructionRegistry      EventRegistry       ConditionRegistry
(专用注册器)             (专用注册器)         (专用注册器)
```

---

## FuseComponentScanner API

**文件位置**: `addons/fuse/editor/bootstrap/fuse_component_scanner.gd`

**类定义**:
```gdscript
class_name FuseComponentScanner extends RefCounted
```

### 构造函数

```gdscript
func _init(plugin: EditorPlugin) -> void
```

### 核心方法

```gdscript
## 扫描并注册所有指令/事件/条件/预设
func setup() -> void

## 清空所有注册表（插件停用时调用）
func teardown() -> void
```

### 内部方法

```gdscript
func _register_all_instructions() -> void     # 扫描 instructions/
func _register_events() -> void               # 扫描 events/
func _register_conditions() -> void            # 扫描 conditions/

## 泛型组件注册方法（三类组件共享同一逻辑）
func _register_components_from_folders(
    folders: Array[String],          # 扫描目录列表
    metadata_method: String,         # 元数据方法名
    registry_name: String,           # 注册器名称（字符串引用）
    register_method: String,         # 注册方法名
    skip_prefix: String,             # 跳过前缀（如 "base_"、"instructions_"）
    component_label: String          # 组件标签（用于日志）
) -> void

## 递归扫描文件夹中的 GDScript 文件
func _scan_scripts_recursive(folder: String, skip_prefix: String = "") -> Array[String]
```

### 扫描目录

| 组件类型 | 扫描目录 |
|---------|---------|
| 指令 | `res://addons/fuse/instructions/`、`res://addons/fuse/integration/`、`res://fuse_generated/instructions/` |
| 事件 | `res://addons/fuse/events/` |
| 条件 | `res://addons/fuse/conditions/` |

### 跳过规则

- 跳过以 `"instructions_"` 开头的文件（指令组）
- 跳过以 `"base_"` 开头的文件（事件、条件基类）
- 跳过的文件不参与注册（基类文件如 `base_event.gd`、`base_condition.gd`）

### 泛型注册流程

```gdscript
_register_components_from_folders(folders, metadata_method, registry_name, ...):
    1. 遍历所有目录，收集 .gd 文件（递归）
    2. 跳过以 skip_prefix 开头的文件
    3. 重置该类型的重复计数
    4. 对每个文件：
        a. load(script) → GDScript
        b. 验证 script.has_method(metadata_method)
        c. 调用 script.call(metadata_method) → 获取 metadata
        d. 验证 metadata 有标识符 (name_key / name)
        e. 通过字符串 match 调用对应的 Registry
            "InstructionRegistry" → InstructionRegistry.register_instruction(script)
            "EventRegistry"       → EventRegistry.register_event(script)
            "ConditionRegistry"   → ConditionRegistry.register_condition(script)
    5. 输出统计：成功数、失败文件、重复 identifier 数
```

---

## ComponentRegistry API

**文件位置**: `addons/fuse/editor/component_registry.gd`

**类定义**:
```gdscript
class_name ComponentRegistry extends RefCounted
```

### 枚举

```gdscript
enum ComponentType {
    INSTRUCTION,
    EVENT,
    CONDITION
}
```

### 静态注册方法

```gdscript
## 注册组件
static func register(component_type: ComponentType, component_class: GDScript, metadata_method: String) -> bool

## 重置某类型的重复计数（扫描前调用）
static func reset_duplicate_count(component_type: ComponentType) -> void

## 获取某类型的重复计数
static func get_duplicate_count(component_type: ComponentType) -> int
```

### 静态查询方法

```gdscript
## 获取所有已注册组件
static func get_all(component_type: ComponentType) -> Array[Dictionary]

## 通过名称查找组件
static func get_by_name(component_type: ComponentType, name: String) -> Dictionary

## 获取注册数量
static func get_count(component_type: ComponentType) -> int

## 搜索组件（按指定字段匹配）
## search_by: "name" / "category" / "keywords" / ""（全部字段）
static func search(component_type: ComponentType, query: String, search_by: String = "") -> Array[Dictionary]
```

---

## 专用 Registry API

### InstructionRegistry

**文件位置**: `addons/fuse/editor/instruction_selector/instruction_registry.gd`

```gdscript
static func register_instruction(instruction_class: GDScript) -> void
static func get_all_instructions() -> Array
static func get_instruction_by_name(name: String) -> Dictionary
static func get_instruction_count() -> int
static func search_instructions(query: String, search_by: String = "") -> Array[Dictionary]
static func clear_all() -> void
```

### EventRegistry

**文件位置**: `addons/fuse/editor/event_registry.gd`

```gdscript
static func register_event(event_class: GDScript) -> bool
static func get_all_events() -> Array
static func get_event_by_name(name: String) -> Dictionary
static func get_event_count() -> int
static func search_events(query: String, search_by: String = "") -> Array[Dictionary]
static func clear_all_events() -> void
```

### ConditionRegistry

**文件位置**: `addons/fuse/editor/condition_registry.gd`

```gdscript
static func register_condition(condition_class: GDScript) -> bool
static func get_all_conditions() -> Array
static func get_condition_by_name(name: String) -> Dictionary
static func get_condition_count() -> int
static func search_conditions(query: String, search_by: String = "") -> Array[Dictionary]
static func clear_all_conditions() -> void
```

---

## 注册流程详解

### 完整注册序列

```
plugin.gd _enter_tree()
    │
    ├── FuseIconManager.init()          # 初始化图标系统
    │
    └── scanner = FuseComponentScanner.new(plugin)
        └── scanner.setup()
            │
            ├── _register_all_instructions()
            │   └── 扫描 3 个指令目录
            │       └── 每个 .gd 文件 → load → 验证元数据 → InstructionRegistry
            │
            ├── _register_events()
            │   └── 扫描 events/ 目录
            │
            ├── _register_conditions()
            │   └── 扫描 conditions/ 目录
            │
            └── PresetRegistry.scan_presets()  # Stage 2.2
```

### 元数据验证规则

```gdscript
# 扫描器验证每个组件是否满足以下条件：
# 1. 脚本可加载（load() 返回 GDScript）
# 2. 实现了元数据方法（如 _get_instruction_metadata）
# 3. 元数据不为空
# 4. 有标识符（name_key 或 name 字段非空）
```

### 撤销注册序列

```
plugin.gd _exit_tree()
    │
    └── scanner.teardown()
        ├── InstructionRegistry.clear_all()
        ├── EventRegistry.clear_all_events()
        ├── ConditionRegistry.clear_all_conditions()
        └── (PresetRegistry 不在此清理)
```

---

## 使用指南

### 在 plugin.gd 中使用

```gdscript
# 插件入口
var _component_scanner: FuseComponentScanner = null

func _enter_tree():
    if Engine.is_editor_hint():
        FuseIconManager.init()
        
        _component_scanner = FuseComponentScanner.new(self)
        _component_scanner.setup()

func _exit_tree():
    if _component_scanner:
        _component_scanner.teardown()
        _component_scanner = null
    
    FuseIconManager.cleanup()
```

### 组件注册要求

每个可注册的组件（指令/事件/条件）必须实现对应的静态元数据方法：

```gdscript
# 指令必须实现
static func _get_instruction_metadata() -> InstructionMetadata

# 事件必须实现
static func _get_event_metadata() -> EventMetadata

# 条件必须实现
static func _get_condition_metadata() -> ConditionMetadata
```

### 跳过基类文件

以 `base_` 或 `instructions_` 开头的文件不会被注册。这确保了基类文件不会被错误地注册为可用组件。

---

## 最佳实践

### 1. 元数据必须有标识符

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_MY_NAME"  # 必须有
    # metadata.name = "Fallback Name"                # 或使用 name 字段
    return metadata
```

### 2. 添加新指令后确认注册

```gdscript
# 在 Godot 编辑器中检查
var instructions = InstructionRegistry.get_all_instructions()
print("已注册指令: %d" % instructions.size())
```

### 3. 插件 reload 时注意状态

```gdscript
# _exit_tree 必须完整清理，否则下次 _enter_tree 时可能重复注册
# ComponentRegistry 的 register 实现中会处理重复检测
```

### 4. 组织指令到子目录

指令可以放到子目录中（如 `instructions/movement/`），`_scan_scripts_recursive` 支持递归扫描。

---

## 常见陷阱

### 陷阱 1：基类文件被错误注册

**问题**: `base_instruction.gd` 等基类文件被扫描到并尝试注册，但缺少元数据方法。

**解决方案**: 扫描器通过 `skip_prefix` 参数跳过以 `"instructions_"` 和 `"base_"` 开头的文件。

### 陷阱 2：元数据方法不是 static

**问题**: `_get_instruction_metadata()` 方法必须是 `static` 的。如果定义为普通方法，`script.call(metadata_method)` 会报错。

**解决方案**: 始终使用 `static func` 定义元数据方法。

### 陷阱 3：int 类型限制导致文件不完整

**问题**: ComponentScanner 在扫描时逐个 `load()` 每个 GDScript，如果脚本有编译错误，`load()` 返回 null，该文件被跳过。

**解决方案**: 在 Godot 编辑器中检查文件是否有编译错误。

### 陷阱 4：重复注册同一组件

**问题**: 如果 `teardown()` 未正常调用，下次 `setup()` 时组件会重复注册。

**解决方案**: ComponentRegistry 的 `register` 方法检测到重复的 identifier 时会更新而非追加，并通过 `_duplicate_counts` 记录。扫描时无需手动去重。

### 陷阱 5：目录不存在

**问题**: 扫描的目录不存在（如 `res://fuse_generated/instructions/`）。

**解决方案**: `_scan_scripts_recursive` 中 `DirAccess.open()` 失败时返回空数组，不影响其他目录。

---

## 参考文档

- [指令创建指南](instruction_creation_guide.md)
- [事件创建指南](event_creation_guide.md)
- [条件创建指南](condition_creation_guide.md)
- [图标系统指南](icon_system.md)
- [FuseEventBus 开发指南](event_bus_guide.md)

---

**文档维护**: Fuse 开发团队 | **最后更新**: 2026-07-07 | **Godot 版本**: 4.7
