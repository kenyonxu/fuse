# Fuse 图标系统开发指南

> **目标**: 为开发者提供完整的 Fuse 图标系统使用指引，包括图标注册、配置、内置图标引用和自定义图标库管理。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-07-07

---

## 📋 目录

1. [系统概述](#系统概述)
2. [架构设计](#架构设计)
3. [核心组件 API](#核心组件-api)
4. [图标配置方式](#图标配置方式)
5. [内置图标参考](#内置图标参考)
6. [自定义图标库](#自定义图标库)
7. [在插件生命周期中管理](#在插件生命周期中管理)
8. [最佳实践](#最佳实践)
9. [常见陷阱](#常见陷阱)
10. [迁移指南](#迁移指南)

---

## 系统概述

Fuse 图标管理系统提供一个统一的图标获取和管理解决方案，支持**四级回退**机制：

1. 本地 `builtin/` 目录 SVG/PNG 文件（最高优先级）
2. `EditorTheme` 内置图标
3. 自定义图标库 `Resource` 中的图标
4. 占位图标（自动生成）

### 核心文件

| 文件 | 用途 |
|------|------|
| `addons/fuse/core/utils/fuse_icon_manager.gd` | 图标管理器（RefCounted，全静态方法） |
| `addons/fuse/editor/metadata/fuse_metadata.gd` | FuseMetadata 基类中的图标字段（InstructionMetadata 的父类） |
| `addons/fuse/core/resources/default_icon_library.tres` | 自定义图标库资源文件 |

---

## 架构设计

```
Fuse 指令/条件/事件 (Instruction/Condition/Event)
        │
        │ get_icon()
        ▼
InstructionMetadata
  ├─ icon_name: String        ← 推荐：Godot 内置图标名称
  ├─ icon: Texture2D          ← 向后兼容：直接纹理
  ├─ builtin_icon: String     ← Phase 2：经过验证的图标名
  └─ custom_icon: String      ← Phase 2：自定义图库名称
        │
        │ get_icon_texture()
        ▼
FuseIconManager (RefCounted, 静态方法)
  ├─ get_builtin_icon(name)       → 本地文件 > EditorTheme > 占位图标
  ├─ get_custom_icon(name)        → 自定义图标库查询
  ├─ get_icon(spec)               → 智能路由（Texture2D / 路径 / 名称）
  ├─ has_builtin_icon(name)       → 检查图标存在性
  └─ has_custom_icon(name)        → 检查自定义图标存在性
        │
        ▼
加载优先级:
  1. res://addons/fuse/icons/builtin/<name>.svg/.png
  2. EditorInterface.get_editor_theme().get_icon(name, "EditorIcons")
  3. _custom_icon_library.get("icons")[name]
  4. _create_placeholder_icon(name) —— 16×16 灰色方块 + 红点标记
```

---

## 核心组件 API

### FuseIconManager

**文件位置**: `addons/fuse/core/utils/fuse_icon_manager.gd`

**类定义**:
```gdscript
class_name FuseIconManager extends RefCounted
```

所有方法均为 **静态方法**，无需实例化即可调用。

#### 初始化与清理

```gdscript
## 初始化图标管理器，获取编辑器主题和加载自定义图标库
static func init() -> void
```

- 内部使用 `_is_initialized` 标志保证只初始化一次
- 仅在 `Engine.is_editor_hint()` 为 true 时获取 `EditorInterface.get_editor_theme()`
- 同时调用 `_load_custom_icon_library()` 加载自定义图标库

```gdscript
## 清理图标缓存和主题引用
static func cleanup() -> void
```

- 清空 `_icon_cache` 字典
- 置空 `_editor_theme`
- 重置 `_is_initialized = false`

#### 图标获取方法

```gdscript
## 获取 Godot 内置图标（四级回退）
static func get_builtin_icon(icon_name: String) -> Texture2D
```

**回退顺序**:
1. 检查 `_icon_cache` 缓存
2. 本地 `res://addons/fuse/icons/builtin/<name>.svg`（若存在）
3. 本地 `res://addons/fuse/icons/builtin/<name>.png`（若存在）
4. `_editor_theme.get_icon(icon_name, "EditorIcons")`
5. `_create_placeholder_icon(icon_name)` —— 16×16 灰色方块 + 中心红点

```gdscript
## 智能获取图标（支持多种输入类型）
static func get_icon(icon_spec: Variant) -> Texture2D
```

**输入类型分支**:
- `Texture2D` → 直接返回（向后兼容）
- `String` 以 `"res://"` 开头 → 调用 `_load_custom_icon(icon_spec)` 加载文件
- `String` → 按序尝试: `get_builtin_icon()` → `get_custom_icon()` → `_create_placeholder_icon()`
- `null` 或空字符串 → 返回 `null`

```gdscript
## 获取自定义图标库中的图标
static func get_custom_icon(icon_name: String) -> Texture2D

## 检查内置图标是否存在
static func has_builtin_icon(icon_name: String) -> bool

## 检查自定义图标是否存在
static func has_custom_icon(icon_name: String) -> bool
```

#### 内部方法

```gdscript
static func _load_custom_icon_library() -> void
## 从 _custom_icon_library_path 加载自定义图标库 Resource
## 默认路径: "res://addons/fuse/core/resources/default_icon_library.tres"

static func _load_custom_icon(icon_path: String) -> Texture2D
## 加载文件路径指定的图标（支持 res:// 路径），有缓存

static func _create_placeholder_icon(icon_name: String) -> Texture2D
## 生成 16×16 占位图标（半透明灰底 + 红点标记）
```

### FuseMetadata（基类）图标字段

**文件位置**: `addons/fuse/editor/metadata/fuse_metadata.gd`  
**说明**: InstructionMetadata/EventMetadata/ConditionMetadata 均继承自 FuseMetadata，图标字段定义在基类中。

```gdscript
## 图标名称（推荐使用 Godot 内置图标名称）
@export var icon_name: String = ""

## 自定义图标名称（从自定义图标库获取）
@export var custom_icon: String = ""

## 向后兼容：直接指定 Texture2D
@export var icon: Texture2D = null

## 获取图标纹理
func get_icon_texture() -> Texture2D:
    # 优先使用 icon_name（新的推荐方式）
    if not icon_name.is_empty():
        return FuseIconManager.get_builtin_icon(icon_name)

    # 其次使用 custom_icon
    if not custom_icon.is_empty():
        return FuseIconManager.get_custom_icon(custom_icon)

    # 回退到 icon 字段（向后兼容）
    if icon != null:
        return icon

    return null
```

---

## 图标配置方式

### 推荐方式：内置图标名称

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_MY_NAME"
    metadata.category_key = "FUSE_CATEGORY_MY_CATEGORY"
    metadata.description_key = "FUSE_INSTRUCTION_MY_DESC"
    metadata.icon_name = "Script"   # 一行搞定
    return metadata
```

### 方式二：自定义图标库

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.custom_icon = "my_special_icon"
    return metadata
```

### 方式三：直接指定纹理（向后兼容）

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.icon = preload("res://addons/fuse/icons/instruction.svg")
    return metadata
```

### 方式四：使用 `@icon` 装饰器（类级别）

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseInstruction
class_name MyInstruction
```

**注意**: `@icon` 装饰器仅用于 Godot 编辑器中显示，建议同时设置 `metadata.icon_name` 确保 Fuse 系统中正确显示。

---

## 内置图标参考

完整列表（1011 个 Godot 4.5+ 内置图标）见原文档。常用分类：

| 分类 | 推荐图标 | 适用场景 |
|------|---------|---------|
| 流程控制 | `Branch`, `Loop`, `Time`, `Clock` | If/Else, For, Wait, Timer |
| 变量操作 | `Array`, `New`, `Remove`, `Add`, `View` | Set/Get Variable, Create, Delete |
| 节点操作 | `Node`, `Node2D`, `Node3D`, `Edit`, `Call`, `Signal` | Find, Set Property, Call Method |
| 调试 | `Debug`, `Print`, `Error`, `Warning`, `Info` | Break, Print, Log |
| 播放 | `Play`, `Stop`, `Pause`, `Save`, `Load` | Play Animation, Save Game |
| 输入 | `Keyboard`, `Mouse`, `Gamepad` | Input Events |
| 数学 | `Math`, `Vector3`, `Rotate`, `Scale` | Math Operations |
| 物理 | `PhysicsBody`, `CollisionShape` | Physics Operations |

---

## 自定义图标库

FuseIconManager 支持加载一个自定义图标库 Resource 文件，存放 Fuse 特有的图标。

### 配置路径

```gdscript
static var _custom_icon_library_path: String = "res://addons/fuse/core/resources/default_icon_library.tres"
```

### 使用方式

```gdscript
# 在元数据中指定自定义图标名称
metadata.custom_icon = "my_icon"

# 代码中直接获取
var icon = FuseIconManager.get_custom_icon("my_icon")
if icon != null:
    button.icon = icon
```

### 创建自定义图标库

自定义图标库是一个 Resource，包含一个 `icons: Dictionary` 属性（`String -> Texture2D`）：

```gdscript
# 创建脚本
extends Resource
class_name FuseIconLibrary

@export var icons: Dictionary = {}
```

在编辑器中创建 `.tres` 文件，填入图标名称与纹理的映射。

---

## 在插件生命周期中管理

### plugin.gd 中的初始化和清理

```gdscript
func _enter_tree():
    if Engine.is_editor_hint():
        FuseIconManager.init()

func _exit_tree():
    FuseIconManager.cleanup()
```

### 缓存的自动冷启动

如果未调用 `init()` 就调用 `get_builtin_icon()`，管理器会自动调用 `init()`：

```gdscript
static func get_builtin_icon(icon_name: String) -> Texture2D:
    # ...
    if not _is_initialized:
        init()  # 自动初始化
    # ...
```

---

## 最佳实践

### 1. 图标选择原则

```gdscript
# ✅ 好的选择
metadata.icon_name = "Print"      # 打印/输出指令
metadata.icon_name = "Debug"      # 调试指令
metadata.icon_name = "Node"       # 节点操作
metadata.icon_name = "Branch"     # 条件分支

# ❌ 避免语义不匹配
metadata.icon_name = "Script"     # 用于非脚本相关指令
metadata.icon_name = "File"       # 用于非文件操作
```

### 2. 始终检查图标存在性

```gdscript
var icon_name = "CustomIcon"
if FuseIconManager.has_builtin_icon(icon_name):
    metadata.icon_name = icon_name
else:
    metadata.icon_name = "Script"  # 回退
```

### 3. 避免在循环中重复查询

FuseIconManager 已有内部缓存（`_icon_cache: Dictionary`），但应避免在编辑器绘制中每帧调用：

```gdscript
# ✅ 只获取一次，复用引用
var cached_icon = FuseIconManager.get_builtin_icon("Play")
for item in items:
    item.set_icon(0, cached_icon)
```

### 4. 图标名称大小写敏感

Godot 内置图标名称区分大小写，如 `"Script"` ≠ `"script"`。使用 `has_builtin_icon()` 验证。

---

## 常见陷阱

### 陷阱 1：在运行时调用 get_builtin_icon

**问题**: 非编辑器上下文中 `EditorInterface.get_editor_theme()` 返回 `null`。

**解决方案**: FuseIconManager 自动处理了此情况——`init()` 中检查 `Engine.is_editor_hint()`。但图标只会在编辑器中完整显示，运行时需确保通过其他方式提供图标。

### 陷阱 2：自定义图标库文件缺失

**问题**: 默认加载路径 `res://addons/fuse/core/resources/default_icon_library.tres` 不存在。

**表现**: 控制台输出 `WARNING: 自定义图标库文件不存在: ...`，`get_custom_icon()` 返回 `null`。

**解决方案**: 创建该资源文件，或使用 `get_icon()` 的智能回退机制。

### 陷阱 3：@icon 装饰器与 metadata.icon_name 冲突

如果同时设置 `@icon` 和 `metadata.icon_name`，Fuse 内部使用 `metadata.get_icon_texture()` 获取图标（优先 `icon_name`），而 Godot 编辑器使用 `@icon`。建议保持一致。

### 陷阱 4：误用已废弃的 icon 字段

旧代码使用 `metadata.icon = preload("...")` 直接设置纹理，新代码应优先使用 `metadata.icon_name` 字符串方式。`metadata.icon` 作为回退保留但不推荐。

---

## 迁移指南

### 从旧系统迁移到新系统

**旧方式**:
```gdscript
metadata.icon = preload("res://addons/fuse/icons/instruction.svg")
```

**新方式**:
```gdscript
metadata.icon_name = "Script"
```

### 批量迁移辅助

可使用 `EditorScript` 批量扫描和替换指令文件中的图标引用（参考原文档中的 `migrate_icons.gd` 模板）。

### 迁移检查清单

- [ ] `plugin.gd` 中调用 `FuseIconManager.init()` / `cleanup()`
- [ ] 现有指令逐步迁移到 `icon_name`
- [ ] 自定义图标库 `.tres` 文件就位
- [ ] 测试各指令图标在编辑器选择器中正确显示
- [ ] 测试向后兼容性（旧 `metadata.icon` 仍有效）

---

## 参考文档

- [指令创建指南](instruction_creation_guide.md)
- [事件创建指南](event_creation_guide.md)
- [条件创建指南](condition_creation_guide.md)
- [Fuse 架构总览](../../system_docs/architecture/visual_programming_system_architecture.md)

---

**文档维护**: Fuse 开发团队 | **最后更新**: 2026-07-07 | **Godot 版本**: 4.7
