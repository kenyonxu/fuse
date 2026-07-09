# Fuse 编辑器工具设计

## 概述

Fuse 编辑器工具是一套集成在 Godot Inspector 和场景树中的编辑器增强系统。它采用 **Inspector 插件 + 选择器对话框 + 右键菜单** 的架构模式，为用户提供组件创建、搜索、调试、静态分析和代码生成等功能。

与最初设想的可视化节点图编辑器不同，当前实现聚焦于 **Inspector 驱动的编辑体验**，利用 Godot 原生的 Inspector 面板作为主交互入口，通过自定义按钮和弹窗扩展编辑能力。这种设计避免了维护独立可视化编辑器的复杂性，同时充分利用了 Godot 编辑器的基础设施。

编辑器工具体系包含 8 个功能模块：

1. Inspector 集成
2. 组件注册系统
3. 指令选择器
4. 组件选择器
5. 按键选择器
6. 调试工具
7. 静态分析
8. 指令生成器
9. 右键菜单工具
10. 元数据系统

## 核心架构

### Inspector 集成

Inspector 集成是 Fuse 编辑器工具的核心入口，通过 Godot 的 `EditorInspectorPlugin` 机制对 Fuse 相关属性进行增强。

#### FuseInspectorPlugin

**文件：** `addons/fuse/editor/fuse_inspector_plugin.gd`
**继承：** `EditorInspectorPlugin`

统一的 Inspector 插件，处理三种 Fuse 属性类型的增强编辑：

- **`Array[BaseInstruction]`** -- 为指令数组属性添加「点击以添加指令」按钮，打开 `InstructionSelector` 对话框
- **`BaseEvent`** -- 为事件资源属性添加「点击以选择事件」按钮，打开 `ComponentSelector` 对话框
- **`BaseCondition`** -- 为条件资源属性添加「点击以选择条件」按钮，打开 `ComponentSelector` 对话框

核心设计原则：**装饰器模式**。通过 `add_custom_control()` 添加增强按钮，**不屏蔽** Godot 原生属性编辑器，保留原生数组和资源编辑能力。

属性类型检测逻辑：
- 指令数组：通过 `TYPE_ARRAY` + `hint_string` 中的 `BaseInstruction` 关键字或属性名称匹配（`instructions`、`*_instructions`）
- 事件资源：通过 `TYPE_OBJECT` + `PROPERTY_HINT_RESOURCE_TYPE` + `hint_string` 中的 `BaseEvent` 或属性名称匹配（`event`、`*_event`）
- 条件资源：通过 `TYPE_OBJECT` + `PROPERTY_HINT_RESOURCE_TYPE` + `hint_string` 中的 `BaseCondition` 或属性名称匹配（`condition`、`*_condition`）

#### ScopeVariableContainerPlugin

**文件：** `addons/fuse/editor/scope_variable_container_plugin.gd`
**继承：** `EditorInspectorPlugin`

为 `ScopeVariableContainer` 节点提供自定义 Inspector 面板，允许在编辑器中查看和编辑作用域变量。

**主要功能：**
- 以 `ItemList` 展示当前作用域中的所有变量及值
- 支持添加、删除和刷新变量操作
- 通过 `notify_property_list_changed()` 通知编辑器更新

### 组件注册系统

组件注册系统采用 **统一注册器 + 类型专用外观** 的分层架构。

#### ComponentRegistry（统一注册器）

**文件：** `addons/fuse/editor/component_registry.gd`
**class_name：** `ComponentRegistry`
**继承：** `RefCounted`

所有组件（Instruction / Event / Condition）的统一注册中心，提供注册、查询、搜索功能。

**核心设计：**
- 使用 `static var` 存储三种组件的数据（`_instructions`、`_events`、`_conditions`）
- 使用 `Dictionary` 映射表实现 O(1) 的按名称查找（`_instruction_map`、`_event_map`、`_condition_map`）
- 通过 `ComponentType` 枚举（`INSTRUCTION`、`EVENT`、`CONDITION`）区分组件类型
- 元数据方法名约定：`_get_instruction_metadata`、`_get_event_metadata`、`_get_condition_metadata`

**注册流程：**
1. 检查组件类是否具有指定的元数据方法
2. 调用元数据方法获取元数据对象
3. 优先使用 `name_key` 作为标识符，回退到 `name`
4. 将组件信息（`{"class": ..., "metadata": ...}`）存入数组和映射表

**搜索机制：**
- 支持按 `name`、`category`、`keywords` 三个维度进行搜索
- 同时兼容新的 Resource 元数据格式（`get_localized_name()`）和旧的 Dictionary 元数据格式
- 未指定搜索字段时搜索所有维度

#### InstructionRegistry / EventRegistry / ConditionRegistry（类型专用外观）

**文件：**
- `addons/fuse/editor/instruction_selector/instruction_registry.gd`
- `addons/fuse/editor/event_registry.gd`
- `addons/fuse/editor/condition_registry.gd`

三个类型专用的外观类，提供类型安全的便捷 API，内部全部委托给 `ComponentRegistry`。

| 方法 | InstructionRegistry | EventRegistry | ConditionRegistry |
|------|---------------------|---------------|-------------------|
| 注册 | `register_instruction()` | `register_event()` | `register_condition()` |
| 获取全部 | `get_all_instructions()` | `get_all_events()` | `get_all_conditions()` |
| 按名查找 | `get_instruction_by_name()` | `get_event_by_name()` | `get_condition_by_name()` |
| 搜索 | `search_instructions()` | `search_events()` | `search_conditions()` |
| 清空 | `clear_all()` | `clear_all_events()` | `clear_all_conditions()` |

## 编辑器工具模块

### 1. 指令选择器 (Instruction Selector)

**目录：** `addons/fuse/editor/instruction_selector/`

指令选择器负责从已注册的指令中选择并添加到目标对象的指令数组中。

#### InstructionSelector

**文件：** `instructions_selector.gd`
**class_name：** `InstructionSelector`
**继承：** `AcceptDialog`

指令选择器的 UI 对话框，采用 **搜索框 + 分类树** 的布局。

**核心行为：**
- **多选添加模式**：每个指令项右侧有独立的加号按钮，点击即可添加到指令数组
- **分类树结构**：按元数据的 `category` 字段分组显示指令
- **搜索过滤**：搜索框实时过滤，委托给 `InstructionSearch` 处理
- **延迟更新**：使用 `call_deferred()` 更新 Tree 控件，避免在信号处理期间操作 blocked 状态的控件

**添加指令流程：**
1. 用户点击指令项右侧的加号按钮
2. 实例化指令类：`instruction_class.new()`
3. 追加到目标对象的指令数组
4. 等待一帧后验证写入
5. 通知编辑器刷新（`notify_property_list_changed()`、`emit_changed()`）

**本地化支持：**
- 打开时自动检测编辑器语言（`editor_language` 设置）
- 强制刷新所有指令元数据的本地化缓存
- 所有 UI 文本通过 `FuseLocalization` 翻译

#### InstructionSearch

**文件：** `instructions_search.gd`
**class_name：** `InstructionSearch`
**继承：** `RefCounted`

指令搜索的核心算法，采用三级权重匹配机制：

| 匹配层级 | 搜索字段 | 权重 |
|----------|----------|------|
| 一级 | 名称（name） | 100 |
| 二级 | 分类（category） | 50 |
| 三级 | 关键词（keywords） | 30 |

搜索结果按权重降序排列。当查询为空时返回所有指令（权重为 0）。

### 2. 组件选择器 (Component Selector)

**文件：** `addons/fuse/editor/component_selector/component_selector.gd`
**class_name：** `ComponentSelector`
**继承：** `AcceptDialog`

统一的组件选择器，支持 Event 和 Condition 两种组件类型的选择操作。

**核心行为：**
- **单选替换模式**：双击或按 Enter 键选中组件，替换目标属性并关闭对话框
- 组件选中后直接实例化并设置到目标属性
- 通过 `ComponentRegistry.search()` 进行搜索过滤
- 空结果显示本地化提示文本

**与 InstructionSelector 的区别：**

| 特性 | InstructionSelector | ComponentSelector |
|------|---------------------|-------------------|
| 选择模式 | 多选（追加到数组） | 单选（替换属性） |
| 添加方式 | 右侧加号按钮 | 双击/Enter |
| 适用类型 | Instruction | Event / Condition |
| Tree 列数 | 2（名称 + 按钮） | 1（名称） |

### 3. 按键选择器 (Input Key Selector)

**目录：** `addons/fuse/editor/input_key_selector/`

为输入相关的指令提供按键捕获编辑能力。

#### InputKeySelector

**文件：** `input_key_selector.gd`
**class_name：** `InputKeySelector`
**继承：** `EditorProperty`

Inspector 属性编辑器，将按键码属性渲染为按钮控件。

**工作流程：**
1. 显示当前按键名称（如「按键: W」）
2. 点击按钮弹出 `InputKeyDialog` 对话框
3. 对话框捕获按键后通过 `emit_changed()` 更新属性值

#### InputKeyDialog

**文件：** `input_key_dialog.gd`
**class_name：** `InputKeyDialog`
**继承：** `AcceptDialog`

按键捕获对话框，使用 Window 的 `window_input` 信号捕获按键事件。

**按键捕获流程：**
1. 用户点击「开始捕获按键」按钮
2. 连接 `window_input` 信号（备用方案：连接 SceneTree 的 `input` 信号）
3. 过滤 `InputEventKey` 事件：只处理 `pressed` 且非 `is_echo` 的事件
4. 发送 `key_selected` 信号并关闭对话框
5. 在 `_notification(NOTIFICATION_VISIBILITY_CHANGED)` 和 `_exit_tree()` 中确保清理信号连接

### 4. 调试工具 (Debugging Tools)

**目录：** `addons/fuse/editor/debugging/`

#### ExecutionTracker

**文件：** `execution_tracker.gd`
**class_name：** `ExecutionTracker`
**继承：** `RefCounted`

执行跟踪器，提供运行时执行跟踪功能。记录指令执行的详细历史，用于调试和性能分析。

**跟踪数据结构：**
```
execution_history: Array[Dictionary]
  └── current_execution: Dictionary
        ├── start_time / end_time / total_time
        ├── context_id
        ├── steps: Array[Dictionary]
        │     ├── instruction_start: 指令开始
        │     ├── instruction_complete: 指令完成（含执行时间、成功状态、错误信息）
        │     ├── error: 错误事件
        │     ├── performance_bottleneck: 性能瓶颈
        │     └── custom_event: 自定义事件
        ├── performance_metrics: {initial, final}
        ├── memory_snapshots: Array[{phase, timestamp, static_memory}]
        └── stats: {instruction_count, total_execution_time, average_execution_time, error_count, performance_issues, success_rate}
```

**可配置跟踪维度：**
- `track_performance_metrics` -- 性能指标
- `track_memory_usage` -- 内存使用
- `track_variable_changes` -- 变量变化
- `max_history_size` -- 最大历史记录数量（默认 100）

**API：**
- `start_tracking(context)` / `stop_tracking()` -- 会话控制
- `record_instruction_start()` / `record_instruction_complete()` -- 指令级跟踪
- `record_custom_event()` / `record_error()` / `record_performance_bottleneck()` -- 事件记录
- `get_execution_history()` / `get_recent_executions()` / `get_execution_stats()` -- 查询
- `export_execution_history(file_path)` -- 导出为 JSON

#### DebugVisualizer

**文件：** `debug_visualizer.gd`
**class_name：** `DebugVisualizer`
**继承：** `Control`

调试可视化面板，提供图形化界面展示执行历史。

**UI 布局：** `HSplitContainer` 分为左右两栏：
- **左侧面板**：控制按钮（刷新、清除、导出、自动刷新） + 执行树（`Tree`）
- **右侧面板**：执行详情（`RichTextLabel`） + 性能图表占位符（`Control`）

**执行树着色方案：**
- 绿色：成功完成
- 红色：有错误
- 黄色：有性能问题
- 浅蓝色：指令开始
- 灰色：自定义事件

**自动刷新：** 通过 `Timer` 实现定时刷新（默认 1 秒间隔）。

### 5. 静态分析（已整合）

静态分析逻辑已从独立的 `InstructionValidator` / `StaticAnalysisPanel` 迁入 `InstructionAnalyzer.analyze_problems`，结果在 FuseTopology 主屏标注（见 [FuseTopology](#fusetopology) 或 `topology/fuse_topology.gd`）。原 `editor/static_analysis/` 目录已移除。

### 6. 指令生成器 (Instruction Generator)

**目录：** `addons/fuse/editor/instruction_generator/`

根据节点类的方法和属性信息自动生成 Fuse 指令文件。

#### InstructionGenerator

**文件：** `instruction_generator.gd`
**class_name：** `InstructionGenerator`
**继承：** `RefCounted`

方法指令生成器，根据 Godot 方法的签名生成对应的 Fuse 调用指令。

**生成的指令结构：**
- `target_node: NodePath` -- 目标节点路径
- 每个参数根据类型映射为对应的 `@export` 属性
- 可选的返回值存储（`result_variable` + `result_variable_scope`）
- 支持变量绑定版本（`use_variables`）：每个参数可从直接值或变量读取

**变量绑定版本的特殊处理：**
- 为每个参数生成 `_source`（直接值/变量）、`_value`（直接值）、`_variable`（变量名）、`_scope`（作用域）属性
- 通过 `_get_property_list()` 动态控制属性显隐
- 通过 `_validate_property()` 根据选项动态设置 `PROPERTY_USAGE_NO_EDITOR`

**代码生成使用工具：**
- `TypeMapper` -- Godot 类型到 GDScript 类型的映射
- `ConflictHandler` -- 文件名冲突处理

**输出位置：** `res://fuse_generated/instructions/<ClassName>/`

#### PropertyInstructionGenerator

**文件：** `property_instruction_generator.gd`
**class_name：** `PropertyInstructionGenerator`
**继承：** `RefCounted`

属性指令生成器，生成 GET/SET 属性指令。

**SET 指令：**
- 设置目标节点的指定属性值
- 支持普通版本和变量绑定版本
- 包含目标节点验证和类型检查

**GET 指令：**
- 读取目标节点的指定属性值
- 支持保存到变量（Local / Scope / Global）
- Scope 作用域支持多种来源（最近 / 自定义 ID / Trigger Scope / 目标节点）

### 7. 右键菜单工具 (Context Menu)

**目录：** `addons/fuse/editor/context_menu/`

通过 Godot 4 的 `EditorContextMenuPlugin` 扩展场景树右键菜单。

#### FuseContextMenuPlugin

**文件：** `fuse_context_menu_plugin.gd`
**class_name：** `FuseContextMenuPlugin`
**继承：** `EditorContextMenuPlugin`

Fuse 上下文菜单系统的入口类。

**提供的菜单项（条件性显示）：**

| 菜单项 | 条件 | 行为 |
|--------|------|------|
| 合并为多事件触发器 | 选中 2+ 个 Trigger 节点且同级 | 合并为 MultiEventTrigger |
| 拆分为独立触发器 | 选中 1 个含 2+ 绑定的 MultiEventTrigger | 拆分为独立 Trigger |
| 生成指令... | 选中 1 个任意节点 | 打开方法/属性选择对话框 |

**指令生成流程：**
1. 右键菜单触发 `_on_generate_instruction()`
2. 创建 `MethodSelectorDialog` 对话框
3. 用户选择方法或属性后调用对应的 Generator
4. 生成的文件自动注册到 `InstructionRegistry`
5. 触发文件系统扫描

#### TriggerMerger

**文件：** `trigger_merger.gd`
**class_name：** `TriggerMerger`
**继承：** `RefCounted`

将多个 Trigger 节点合并为一个 MultiEventTrigger 节点。

**合并前提条件：**
- 至少 2 个节点
- 所有节点都是 Trigger 类型
- 所有节点具有相同的父节点

**合并操作：**
1. 按场景树索引排序
2. 为每个 Trigger 创建 EventBinding（深拷贝 event_definition 和 action_runner）
3. 验证绑定数据完整性
4. 创建 MultiEventTrigger 并设置 event_bindings
5. 完整的 UndoRedo 支持（`create_action` + `add_do_method` + `add_undo_method`）

#### TriggerSplitter

**文件：** `trigger_splitter.gd`
**class_name：** `TriggerSplitter`
**继承：** `RefCounted`

将 MultiEventTrigger 节点拆分为多个独立的 Trigger 节点（合并的逆操作）。

**拆分前提条件：**
- 节点类型为 MultiEventTrigger
- 包含至少 2 个 EventBinding

**命名策略：** 使用事件类名作为 Trigger 名称（如 `InputEvent`），重名时添加数字后缀。

### 8. 元数据系统 (Metadata System)

**文件：** `addons/fuse/editor/metadata/fuse_metadata.gd`
**class_name：** `FuseMetadata`
**继承：** `Resource`

统一的元数据 Resource 基类，为所有 Fuse 组件提供一致的元数据接口。

**字段设计：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `name_key` | String | 名称翻译键（优先） |
| `category_key` | String | 分类翻译键（优先） |
| `description_key` | String | 描述翻译键（优先） |
| `name` | String | 名称直接文本（向后兼容，已废弃） |
| `category` | String | 分类直接文本（向后兼容，已废弃） |
| `description` | String | 描述直接文本（向后兼容，已废弃） |
| `keywords` | Array | 搜索关键词 |
| `builtin_icon` | String | Godot 内置图标名称 |
| `custom_icon` | String | Fuse 自定义图标库名称 |
| `icon_name` | String | 图标名称（向后兼容） |
| `icon` | Texture2D | 图标资源（向后兼容） |

**本地化缓存机制：**
- 通过 `_cache_valid` / `_cache_locale` / `_cached_instance_id` 实现惰性缓存
- 语言切换或 `duplicate()` 后自动失效
- `get_localized_name()` / `get_localized_category()` / `get_localized_description()` 带自动缓存刷新

**图标获取优先级：**
1. `builtin_icon` -- Godot 内置图标（通过 `FuseIconManager.get_builtin_icon()`）
2. `custom_icon` -- Fuse 自定义图标库（通过 `FuseIconManager.get_custom_icon()`）
3. `icon_name` -- 向后兼容（先查自定义库，再查内置图标）
4. `icon` -- 直接 Texture2D 资源

## 设计决策

### 1. Inspector 驱动而非独立编辑器

选择 Inspector 插件模式而非独立的可视化节点图编辑器，原因如下：
- **降低复杂度**：避免维护独立的可视化编辑器，利用 Godot 已有的 Inspector 基础设施
- **一致性**：用户的编辑体验与 Godot 原生工作流保持一致
- **可扩展性**：通过 `_parse_property()` 精确控制增强哪些属性

### 2. 装饰器模式保留原生编辑器

所有 Inspector 增强都使用 `add_custom_control()` 添加额外 UI，**不屏蔽** Godot 原生属性编辑器（`_parse_property()` 返回 `false`）。用户可以同时使用原生编辑和 Fuse 增强。

### 3. 统一注册器 + 类型专用外观

`ComponentRegistry` 作为唯一的注册和查询实现，`InstructionRegistry` / `EventRegistry` / `ConditionRegistry` 仅提供类型安全的便捷 API。这消除了三种注册器之间的代码重复，同时保持了各类型 API 的语义清晰。

### 4. 静态方法为主的服务类

注册器、搜索器、验证器等工具类主要使用 `static func`，避免实例化的开销。这是因为编辑器工具在大多数场景下只需要单一的全局状态。

### 5. 本地化的渐进式策略

所有编辑器工具统一采用 `FuseLocalization` 进行本地化，并遵循以下模式：
- 优先使用翻译键（`translate("KEY")`）
- 回退到硬编码的中文文本
- 打开对话框时自动检测编辑器语言设置

### 6. 延迟更新避免 Tree 控件阻塞

在信号处理回调中操作 Tree 控件可能触发 blocked 状态，因此所有 Tree 更新都通过 `call_deferred()` 延迟执行，配合 `_updating_ui` 标志防止重入。

### 7. UndoRedo 集成

TriggerMerger 和 TriggerSplitter 完整集成了 Godot 的 UndoRedo 系统，使用 `create_action()` + `add_do_method()` + `add_undo_method()` + `commit_action()` 模式，确保用户可以撤销合并/拆分操作。

### 8. 自动代码生成与即时注册

指令生成器生成的 `.gd` 文件会立即通过 `InstructionRegistry.register_instruction()` 注册到系统，并通过 `EditorInterface.get_resource_filesystem().scan()` 触发文件系统扫描，确保生成的指令立即可用。

## 文件索引

| 文件路径 | class_name | 继承 | 职责 |
|----------|------------|------|------|
| `editor/fuse_inspector_plugin.gd` | -- | EditorInspectorPlugin | 统一 Inspector 增强 |
| `editor/scope_variable_container_plugin.gd` | -- | EditorInspectorPlugin | 作用域变量编辑 |
| `editor/component_registry.gd` | ComponentRegistry | RefCounted | 统一组件注册 |
| `editor/condition_registry.gd` | ConditionRegistry | RefCounted | Condition 注册外观 |
| `editor/event_registry.gd` | EventRegistry | RefCounted | Event 注册外观 |
| `editor/instruction_selector/instruction_registry.gd` | InstructionRegistry | RefCounted | Instruction 注册外观 |
| `editor/instruction_selector/instructions_selector.gd` | InstructionSelector | AcceptDialog | 指令选择器对话框 |
| `editor/instruction_selector/instructions_search.gd` | InstructionSearch | RefCounted | 指令搜索算法 |
| `editor/component_selector/component_selector.gd` | ComponentSelector | AcceptDialog | 组件选择器对话框 |
| `editor/input_key_selector/input_key_selector.gd` | InputKeySelector | EditorProperty | 按键属性编辑器 |
| `editor/input_key_selector/input_key_dialog.gd` | InputKeyDialog | AcceptDialog | 按键捕获对话框 |
| `editor/debugging/debug_visualizer.gd` | DebugVisualizer | Control | 调试可视化面板 |
| `editor/debugging/execution_tracker.gd` | ExecutionTracker | RefCounted | 执行跟踪器 |
| `editor/instruction_generator/instruction_generator.gd` | InstructionGenerator | RefCounted | 方法指令生成器 |
| `editor/instruction_generator/property_instruction_generator.gd` | PropertyInstructionGenerator | RefCounted | 属性指令生成器 |
| `editor/context_menu/fuse_context_menu_plugin.gd` | FuseContextMenuPlugin | EditorContextMenuPlugin | 右键菜单入口 |
| `editor/context_menu/trigger_merger.gd` | TriggerMerger | RefCounted | Trigger 合并工具 |
| `editor/context_menu/trigger_splitter.gd` | TriggerSplitter | RefCounted | Trigger 拆分工具 |
| `editor/metadata/fuse_metadata.gd` | FuseMetadata | Resource | 元数据 Resource 基类 |
