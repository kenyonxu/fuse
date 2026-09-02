> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/53-icon-manager-guide.md)

# Fuse 图标管理器使用指南

想让你的指令在编辑器中显示正确的图标？FuseIconManager 让这件事变得简单。我们提供了两种图标系统：**内置图标**（Godot 自带）和**自定义图标库**（你的专属图标）。

## 快速开始

### 方式 1：使用内置图标（推荐）

```gdscript
@tool
extends BaseInstruction
class_name MyInstruction

static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_MY_NAME"
    metadata.category_key = "FUSE_CATEGORY_CUSTOM"
    metadata.builtin_icon = "Play"  # 使用 Godot 内置图标
    return metadata
```

### 方式 2：使用自定义图标库

```gdscript
@tool
extends BaseInstruction
class_name MyInstruction

static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_MY_NAME"
    metadata.category_key = "FUSE_CATEGORY_CUSTOM"
    metadata.custom_icon = "my_custom_icon"  # 使用你的自定义图标
    return metadata
```

### 方式 3：向后兼容（旧代码）

```gdscript
metadata.icon_name = "Play"  # 仍然有效，但推荐使用 builtin_icon
```

## 常用内置图标名称

这些图标可以直接用在 `builtin_icon` 字段：

**流程控制**
- `Loop` - 循环
- `Branch` - 分支/if-else
- `Time` - 时间/等待

**变量操作**
- `Array` - 数组
- `New` - 新建/创建
- `View` - 查看/打印

**节点操作**
- `Node` - 节点
- `Edit` - 编辑/修改
- `Call` - 调用方法

**调试**
- `Debug` - 调试
- `Print` - 打印

**通用图标**
- `Script`, `Play`, `Stop`, `Pause`
- `Add`, `Remove`, `Save`, `Load`
- `File`, `Folder`, `Search`, `Tools`, `Settings`

完整列表有 1,011 个图标，参考 [icon-system-guide.md](../../dev_docs/guides/icon-system-guide.md)。

## 自定义图标库

### 什么是图标库？

FuseIconLibrary 是一个集中管理所有自定义图标的资源文件，包含：
- **统一存储**：所有自定义图标在一个 `.tres` 文件中
- **可视化管理**：在 Inspector 中直接编辑 Dictionary
- **可版本控制**：`.tres` 文件可以提交到 Git
- **名称索引**：通过字符串名称访问图标

### 使用自定义图标的三种方式

#### 方式 A：通过工具脚本批量导入（推荐）

```bash
# 1. 运行导入工具
Project → Tools → Execute Script → import_custom_icons.gd

# 2. 选择包含图标文件的目录
# 支持：.svg, .png, .jpg, .webp 等

# 3. 图标自动导入到 default_icon_library.tres
```

**示例**：
```
图标文件: icons/custom/count.svg
导入后名称: count

使用: metadata.custom_icon = "count"
```

#### 方式 B：在 Inspector 中手动添加

1. 在编辑器中打开 `addons/fuse/core/resources/default_icon_library.tres`
2. 在 `icons` 字典中添加项：
   - **Key**: `my_custom_icon`
   - **Value**: 拖入图标文件（Texture2D）

#### 方式 C：代码中动态添加

```gdscript
var library = load("res://addons/fuse/core/resources/default_icon_library.tres")
if library and library.has_method("add_icon"):
    library.add_icon("my_icon", preload("res://icons/my_icon.svg"))
```

## 图标在两个地方显示

### 1. 指令选择器（Instruction Selector）

指令选择器会自动使用你的图标配置，无需额外操作：

**使用内置图标：**
```gdscript
metadata.builtin_icon = "Print"
```

**使用自定义图标库：**
```gdscript
metadata.custom_icon = "my_custom_icon"
```

指令选择器会显示相应的图标。

### 2. Inspector 面板（Array[BaseInstruction]）

Inspector 使用 `@icon` 装饰器显示图标。你需要运行工具来同步：

```bash
# 步骤 1: 提取 Godot 内置图标（一次性，使用内置图标时需要）
Project → Tools → Execute Script → generate_builtin_icons.gd

# 步骤 2: 更新指令文件的 @icon（每次修改图标配置后）
Project → Tools → Execute Script → update_instruction_icon_decorators.gd

# 步骤 3: 重启编辑器
```

工具会自动在你的指令文件顶部添加：

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Print.png")  # 自动添加（内置图标）
# 或
@icon("res://addons/fuse/icons/custom/my_icon.svg")  # 自动添加（自定义图标）
extends BaseInstruction
class_name MyInstruction
```

现在 Inspector 也会显示正确的图标。

**注意**：对于 custom_icon，图标文件必须已存在于 `addons/fuse/icons/custom/` 目录。

## 使用工具脚本

### 提取内置图标

`generate_builtin_icons.gd` 从 Godot 编辑器主题提取图标并保存为 PNG 文件。

**智能扫描特性：**
- 自动扫描 `events/` 和 `instructions/` 目录
- 收集所有实际使用的 `builtin_icon` 值
- 只提取需要的图标，节省空间
- 自动去重和排序

**什么时候用：**
- 第一次使用图标系统
- 添加了新的 `builtin_icon` 配置后
- 需要更新图标库时

**结果：**
- 图标保存到 `addons/fuse/icons/builtin/`
- 同时导入到 `default_icon_library.tres`（如果启用 IMPORT_TO_LIBRARY）
- 只提取实际使用的图标

**运行：**
```
Project → Tools → Execute Script
选择 generate_builtin_icons.gd → 点击 Run
```

**输出示例：**
```
============================================================
提取 Godot 内置图标（自动扫描）
============================================================

步骤 1: 扫描 events 和 instructions 目录...
  发现 8 个使用的图标

  使用的图标:
    - Branch
    - Debug
    - Loop
    - Node
    - Print
    - Script
    - ZoomReset
    - ...

步骤 2: 提取图标...
✓ 已保存: Branch → res://addons/fuse/icons/builtin/Branch.png
✓ 已保存: Debug → res://addons/fuse/icons/builtin/Debug.png
...

============================================================
完成！成功: 8, 失败: 0
图标保存位置: res://addons/fuse/icons/builtin/
导入到图标库: 8 个
============================================================
```

### 导入自定义图标

`import_custom_icons.gd` 批量导入图标文件到 FuseIconLibrary。

**什么时候用：**
- 需要使用自定义图标
- 有一批图标文件需要导入

**结果：**
- 图标自动导入到 `default_icon_library.tres`
- 文件名自动转换为图标名称（去扩展名）
- 支持递归扫描子目录

**运行：**
```
Project → Tools → Execute Script
选择 import_custom_icons.gd → 点击 Run
选择包含图标文件的目录
```

**支持格式：** .png, .svg, .jpg, .jpeg, .webp, .tga, .bmp

**示例：**
```
图标文件: icons/custom/my_icon.svg
导入后名称: my_icon
使用: metadata.custom_icon = "my_icon"
```

### 更新 @icon 装饰器

`update_instruction_icon_decorators.gd` 扫描所有指令文件，根据图标配置更新 `@icon`。

**什么时候用：**
- 修改了指令的 `builtin_icon`、`custom_icon` 或 `icon_name`
- 添加了新指令并设置了图标配置

**结果：**
- 自动更新所有指令文件的 `@icon` 装饰器
- 按优先级查找图标配置：builtin_icon > custom_icon > icon_name
- 跳过没有任何图标配置的指令
- 保留现有的自定义 `@icon`（如果已存在且路径正确）

**运行：**
```
Project → Tools → Execute Script
选择 update_instruction_icon_decorators.gd → 点击 Run
```

**示例输出：**
```
✓ 已更新: print.gd → builtin_icon = Print
✓ 已更新: custom_instruction.gd → custom_icon = my_icon (custom)
✓ 已更新: old_instruction.gd → icon_name = Debug (legacy)
✓ 跳过: no_icon_instruction.gd (没有图标配置)
```

**优先级说明：**
工具会按以下顺序查找图标配置：
1. `builtin_icon` - Godot 内置图标
2. `custom_icon` - 自定义图标库
3. `icon_name` - 向后兼容字段

## 完整工作流

创建一个带图标的新指令：

### 使用内置图标

```gdscript
# 1. 创建指令文件
@tool
extends BaseInstruction
class_name DebugPrint

static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_DEBUG_PRINT_NAME"
    metadata.category_key = "FUSE_CATEGORY_DEBUG"
    metadata.builtin_icon = "Debug"  # 使用 Godot 内置图标
    return metadata

func execute(context: ExecutionContext):
    print("Debug output!")
    finished.emit()
```

```bash
# 2. 运行工具更新 @icon（如果需要在 Inspector 中显示）
Project → Tools → Execute Script → update_instruction_icon_decorators.gd

# 3. 重启编辑器
```

### 使用自定义图标库

```gdscript
# 1. 导入自定义图标（如果还没导入）
Project → Tools → Execute Script → import_custom_icons.gd
# 选择包含图标的目录

# 2. 创建指令文件
@tool
extends BaseInstruction
class_name MyCustomInstruction

static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_MY_NAME"
    metadata.category_key = "FUSE_CATEGORY_CUSTOM"
    metadata.custom_icon = "my_custom_icon"  # 使用自定义图标库
    return metadata

func execute(context: ExecutionContext):
    print("Custom instruction!")
    finished.emit()
```

```bash
# 3. 运行工具更新 @icon（如果需要在 Inspector 中显示）
Project → Tools → Execute Script → update_instruction_icon_decorators.gd

# 4. 重启编辑器
```

完成！你的指令现在在指令选择器和 Inspector 中都显示正确的图标。

## 向后兼容

旧的图标配置方式仍然有效，确保现有代码无需修改即可继续工作。

### 支持的旧字段

**1. icon_name 字段（向后兼容）**
```gdscript
metadata.icon_name = "Debug"  # 仍然有效
```
- 会先检查自定义图标库
- 如果不存在，作为内置图标查找

**2. icon 字段（Texture2D 资源）**
```gdscript
metadata.icon = preload("res://custom_icon.svg")  # 仍然有效
```
- 直接使用纹理资源
- 兼容旧的直接指定方式

**3. @icon 装饰器（文件级）**
```gdscript
@icon("res://path/to/icon.svg")
@tool
extends BaseInstruction
```
- Inspector 面板使用
- 可以与 metadata 配置共存

### 新的优先级规则

系统按以下优先级查找图标：

1. **builtin_icon** - Godot 内置图标（推荐用于标准图标）
2. **custom_icon** - 自定义图标库（推荐用于项目专属图标）
3. **icon_name** - 向后兼容字段（自动检测类型）
4. **icon** - Texture2D 资源（旧方式）
5. **@icon 装饰器** - Inspector 使用（文件级装饰器）

如果以上所有字段都为空或无效，指令使用 Godot 默认的脚本图标。

## 检查图标是否存在

不确定图标名称是否正确？可以使用这些方法检查：

### 检查内置图标

```gdscript
if FuseIconManager.has_builtin_icon("MyIcon"):
    metadata.builtin_icon = "MyIcon"
else:
    print("内置图标不存在，使用默认图标")
    metadata.builtin_icon = "Script"
```

### 检查自定义图标

```gdscript
if FuseIconManager.has_custom_icon("my_custom_icon"):
    metadata.custom_icon = "my_custom_icon"
else:
    print("自定义图标不存在，使用内置图标")
    metadata.builtin_icon = "Script"
```

### 动态选择图标

```gdscript
# 先尝试自定义图标，如果不存在则使用内置图标
if FuseIconManager.has_custom_icon("my_icon"):
    metadata.custom_icon = "my_icon"
elif FuseIconManager.has_builtin_icon("MyIcon"):
    metadata.builtin_icon = "MyIcon"
else:
    metadata.builtin_icon = "Script"  # 默认图标
```

## 常见问题

### Q: 指令选择器显示正确图标，但 Inspector 显示旧图标？

A: Inspector 使用 `@icon` 装饰器，需要运行 `update_instruction_icon_decorators.gd` 来同步，然后重启编辑器。

### Q: 图标名称拼写错误会怎样？

A: 系统会显示占位图标（灰色方块带红点）。检查图标名称拼写，或使用 `has_builtin_icon()` / `has_custom_icon()` 验证。

### Q: builtin_icon 和 custom_icon 应该选择哪个？

A:
- **builtin_icon** - 用于 Godot 编辑器的标准图标（Script, Node, Play, Debug 等）
- **custom_icon** - 用于项目专属的自定义图标（品牌、特殊功能图标等）

### Q: 如何将自定义图标添加到图标库？

A: 有三种方式：
1. **推荐**：运行 `import_custom_icons.gd` 工具批量导入
2. 在 Inspector 中打开 `default_icon_library.tres` 手动添加
3. 代码中调用 `FuseIconLibrary.add_icon()` 动态添加

### Q: 自定义图标文件应该放在哪里？

A:
- 如果使用 `import_custom_icons.gd`，图标可以放在任何目录
- 如果手动添加到 `default_icon_library.tres`，建议放在 `addons/fuse/icons/custom/`
- 如果使用 `metadata.icon`，图标可以放在项目的任何位置

### Q: 可以使用自定义图标文件吗？

A: 可以，有多种方式：
- 使用图标库（推荐）：`metadata.custom_icon = "my_icon"`
- 直接指定纹理（旧方式）：`metadata.icon = preload("res://path/to/icon.svg")`
- 使用 @icon 装饰器：`@icon("res://path/to/icon.svg")`

### Q: 工具脚本找不到？

A: 确保文件在 `tools/` 目录：
- `tools/generate_builtin_icons.gd`
- `tools/import_custom_icons.gd`
- `tools/update_instruction_icon_decorators.gd`

### Q: 更新工具提示 "custom_icon 文件不存在"？

A: 这表示 `update_instruction_icon_decorators.gd` 找不到对应的图标文件。解决方法：
1. 确保已运行 `import_custom_icons.gd` 导入图标
2. 或者手动将图标文件放到 `addons/fuse/icons/custom/` 目录
3. 检查图标名称是否正确（不包含扩展名）

### Q: 图标库可以共享给其他项目吗？

A: 可以！`default_icon_library.tres` 是标准的 Godot Resource 文件：
- 可以直接复制到其他项目
- 可以提交到 Git 进行版本控制
- 可以在 Inspector 中可视化编辑

## 下一步

- [icon-system-guide.md](../../dev_docs/guides/icon-system-guide.md) - 完整的技术文档和 API 参考
- [custom_instruction.md](../best_practices/custom_instruction.md) - 创建自定义指令
- [custom_event.md](../best_practices/custom_event.md) - 创建自定义事件
