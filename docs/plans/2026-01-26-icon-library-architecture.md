# Bricks 图标系统架构改进

## 架构改进概述

**目标**：创建统一的图标管理系统，区分内置图标和自定义图标。

**核心改进**：
1. ✅ 创建 BricksIconLibrary 资源库 - 集中管理自定义图标
2. ✅ 扩展 BricksIconManager - 支持从图标库获取图标
3. ⏳ 更新 InstructionMetadata - 添加 builtin_icon 和 custom_icon 字段（待完成）
4. ⏳ 创建工具脚本 - 批量导入图标到库（待完成）

## 新架构组件

### 1. BricksIconLibrary 资源类

**文件**: `addons/bricks/core/resources/bricks_icon_library.gd`

**功能**：
- 存储 Dictionary[name: String → Texture2D] 的图标映射
- 提供 add_icon(), get_icon(), has_icon(), remove_icon() 方法
- 支持从目录批量导入图标文件
- 可在 Inspector 中可视化编辑

**使用**：
```gdscript
var library = BricksIconLibrary.new()

# 添加图标
library.add_icon("my_count", preload("res://icons/count.svg"))

# 获取图标
var icon = library.get_icon("my_count")

# 批量导入
library.import_from_directory("res://icons/custom/", true)
```

### 2. BricksIconManager 扩展

**新增方法**：
```gdscript
# 获取内置图标（原 get_builtin_icon）
BricksIconManager.get_builtin_icon("Play")

# 获取自定义图标库图标（新增）
BricksIconManager.get_custom_icon("my_count")

# 检查自定义图标是否存在
BricksIconManager.has_custom_icon("my_count")

# 智能获取（更新）
# 查找顺序：文件路径 → builtin → custom → 占位图标
BricksIconManager.get_icon("Play")
```

**优先级**：
1. 文件路径 (`res://...`)
2. Godot 内置图标
3. 自定义图标库
4. 占位图标

### 3. 默认图标库

**文件**: `addons/bricks/core/resources/default_icon_library.tres`

**状态**: 空库（等待导入图标）

## 使用方式

### 方式 A：使用内置图标（推荐用于简单场景）

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.builtin_icon = "Play"  # Godot 内置图标
    return metadata
```

### 方式 B：使用自定义图标库（推荐用于自定义图标）

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.custom_icon = "my_count"  # Bricks 图标库中的名称
    return metadata
```

### 方式 C：混合使用

```gdscript
# 优先使用 builtin，如果不存在则使用 custom
metadata.builtin_icon = "Play"
metadata.custom_icon = "my_play"  # 后备
```

## 工作流程示例

### 场景 1：添加自定义图标到库

```gdscript
# 1. 打开 default_icon_library.tres
# 2. 在 Inspector 的 icons 字典中添加：
#    - Key: "my_count"
#    - Value: preload("res://icons/count.svg")
# 3. 保存

# 在代码中使用：
metadata.custom_icon = "my_count"
```

### 场景 2：批量导入图标（工具脚本）

```bash
# 运行工具（待创建）
Project → Tools → Execute Script → import_custom_icons.gd

# 选择图标目录
# 工具会自动导入所有 .svg/.png 文件到库
```

### 场景 3：创建新指令

```gdscript
@tool
extends BaseInstruction
class_name Count

static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_COUNT_NAME"
    metadata.category_key = "BRICKS_CATEGORY_FLOW_CONTROL"

    # 选项 1: 使用内置图标
    metadata.builtin_icon = "Loop"

    # 选项 2: 使用自定义图标
    metadata.custom_icon = "count_loop"

    return metadata
```

## 向后兼容

**保留旧字段**：
- `icon_name` → 标记为 deprecated，映射到 builtin_icon
- `icon` → 保留，向后兼容

**迁移路径**：
```
旧代码：
  metadata.icon_name = "Play"

新代码：
  metadata.builtin_icon = "Play"  # 推荐使用
  # 或
  metadata.custom_icon = "my_play"  # 自定义库
```

## 文件结构

```
addons/bricks/
├── core/
│   ├── resources/
│   │   ├── bricks_icon_library.gd      # 图标库类
│   │   └── default_icon_library.tres    # 默认库（空）
│   └── utils/
│       └── bricks_icon_manager.gd       # 扩展：支持自定义库
└── icons/
    ├── builtin/                        # Godot 内置图标提取
    └── custom/                         # 自定义图标源文件
```

## 下一步

1. ⏳ 更新 InstructionMetadata 添加新字段
2. ⏳ 创建 import_custom_icons.gd 工具
3. ⏳ 更新现有工具脚本支持新架构
4. ⏳ 更新用户文档
5. ⏳ 创建示例：添加几个自定义图标到库

## 优势总结

**语义清晰**：
- builtin_icon = Godot 内置
- custom_icon = Bricks 库
- icon = 直接 Texture2D（向后兼容）

**统一管理**：
- 所有自定义图标集中在一个 .tres 文件
- 可视化编辑
- 版本控制友好

**可扩展**：
- 支持多个图标库（未来）
- 支持导入/导出
- 支持图标分类

---

**创建时间**: 2026-01-26
**状态**: Phase 1 完成（核心架构）✅
**下一步**: Phase 2 - 元数据更新
