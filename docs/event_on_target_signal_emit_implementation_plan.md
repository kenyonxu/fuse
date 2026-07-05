# EventOnTargetSignalEmit 实现计划

## 概述

本文档详细描述了 `EventOnTargetSignalEmit` 事件及其相关通用类的实现计划。这个实现计划基于之前的设计文档，提供了具体的实现步骤和代码结构。

## 实现阶段

### 阶段 1: 创建 SignalInfo 通用类

**目标**: 创建一个可复用的信号信息类，用于存储和操作 Godot 信号的元数据。

**文件**: `addons/bricks/utils/signal_info.gd`

**实现要点**:
1. 继承自 Resource 以支持序列化
2. 包含信号名称、参数信息、默认值等完整信息
3. 提供类型安全的参数验证
4. 支持信号签名的生成和显示
5. 实现序列化/反序列化功能

**关键方法**:
- `from_godot_signal()` - 从 Godot 信号字典创建
- `get_signature()` - 获取完整信号签名
- `get_display_name()` - 获取简短显示名称
- `validate_args()` - 验证参数值
- `create_arg_context()` - 创建参数上下文

### 阶段 2: 创建 SignalManager 通用类

**目标**: 创建一个信号管理器，提供信号信息的缓存和查询功能。

**文件**: `addons/bricks/utils/signal_manager.gd`

**实现要点**:
1. 继承自 RefCounted（无状态工具类）
2. 实现信号信息缓存机制
3. 提供便捷的信号查询接口
4. 支持缓存清理和统计
5. 优化性能，避免重复查询

**关键方法**:
- `get_node_signals()` - 获取节点所有信号
- `find_signal_by_name()` - 根据名称查找信号
- `has_signal()` - 检查信号是否存在
- `get_signal_names()` - 获取信号名称列表
- `clear_cache()` - 清理缓存

### 阶段 3: 实现 EventOnTargetSignalEmit 事件类

**目标**: 实现主要的事件类，提供动态信号监听功能。

**文件**: `addons/bricks/events/event_on_target_signal_emit.gd`

**实现要点**:
1. 继承自 BaseEvent
2. 集成 SignalInfo 和 SignalManager
3. 实现动态属性列表生成
4. 提供信号连接/断开管理
5. 支持参数过滤和条件触发

**关键功能**:
- 动态信号发现和选择
- 类型安全的信号连接
- 参数过滤和验证
- 编辑器友好的界面
- 完善的错误处理

## 详细实现步骤

### 步骤 1: SignalInfo 类实现

```gdscript
# 基础结构
@tool
class_name SignalInfo extends Resource

# 属性定义
var name: String = ""
var args: Array[Dictionary] = []
var default_args: Array[Variant] = []
var flags: int = 0
var owner_class_name: String = ""
var description: String = ""

# 静态工厂方法
static func from_godot_signal(signal_dict: Dictionary, class_name: String = "") -> SignalInfo

# 显示方法
func get_signature() -> String
func get_display_name() -> String
func get_arg_type_strings() -> Array[String]

# 验证方法
func has_arg_count(count: int) -> bool
func are_args_compatible(arg_types: Array[int]) -> bool
func validate_args(values: Array[Variant]) -> bool

# 编辑器支持
func get_arg_property_list() -> Array[Dictionary]

# 上下文创建
func create_arg_context(values: Array[Variant]) -> Dictionary

# 序列化
func serialize() -> Dictionary
func deserialize(data: Dictionary)

# 私有辅助方法
func _get_type_string(type: int) -> String
func _are_types_compatible(type1: int, type2: int) -> bool
func _is_value_valid_for_type(value: Variant, type: int) -> bool
```

### 步骤 2: SignalManager 类实现

```gdscript
# 基础结构
@tool
class_name SignalManager extends RefCounted

# 静态缓存
static var _signal_cache: Dictionary = {}

# 主要接口
static func get_node_signals(node: Node) -> Array[SignalInfo]
static func find_signal_by_name(node: Node, signal_name: String) -> SignalInfo
static func has_signal(node: Node, signal_name: String) -> bool
static func get_signal_names(node: Node) -> Array[String]
static func get_signal_display_names(node: Node) -> Array[String]

# 缓存管理
static func clear_cache_for_node(node: Node)
static func clear_all_cache()
static func get_cache_stats() -> Dictionary

# 私有方法
static func _get_cache_key(node: Node) -> String
static func _get_total_signal_count() -> int
```

### 步骤 3: EventOnTargetSignalEmit 类实现

```gdscript
# 基础结构
@tool
@icon("res://addons/bricks/icons/event.svg")
class_name EventOnTargetSignalEmit extends BaseEvent

# 导出属性
@export var target_node_path: NodePath
@export var target_signal: String = ""
@export var trigger_once: bool = false
@export var filter_signal_args: bool = false
@export var arg_filter_values: Array[Variant] = []

# 内部状态
var _target_node: Node = null
var _signal_info: SignalInfo = null
var _has_triggered: bool = false
var _available_signals: Array[SignalInfo] = []

# BaseEvent 重写方法
func initialize(owner_node: Node) -> void
func terminate(owner_node: Node) -> void
func get_description() -> String
func get_event_type() -> String
func get_event_category() -> String
func validate() -> Array[String]
func reset() -> void

# 编辑器支持
func _get_property_list() -> Array[Dictionary]
func _update_resource_name()
func _validate_property(property: Dictionary) -> void

# 信号处理
func _on_target_signal_emitted(...args) -> void

# 私有方法
func _has_valid_target_node() -> bool
func _get_signal_names() -> Array[String]
func _refresh_signal_cache()
func _update_signal_info()
func _get_target_node_from_path(owner_node: Node) -> Node
func _check_signal_args(args: Array) -> bool
func _create_signal_context(args: Array) -> Dictionary
func _get_arg_filter_properties() -> Array[Dictionary]
func _clear_signal_cache()
```

## 实现优先级

### 高优先级
1. **SignalInfo 基础功能** - 核心数据结构
2. **SignalManager 缓存机制** - 性能优化
3. **EventOnTargetSignalEmit 基础功能** - 核心事件逻辑

### 中优先级
1. **编辑器集成** - 动态属性列表
2. **参数过滤** - 高级功能
3. **错误处理** - 稳定性

### 低优先级
1. **性能优化** - 缓存优化
2. **扩展功能** - 高级用法
3. **测试覆盖** - 质量保证

## 测试策略

### 单元测试
1. **SignalInfo 测试**
   - 创建和序列化
   - 参数验证
   - 类型兼容性检查

2. **SignalManager 测试**
   - 缓存功能
   - 查询接口
   - 性能测试

3. **EventOnTargetSignalEmit 测试**
   - 基础功能
   - 编辑器界面
   - 错误处理

### 集成测试
1. **信号连接测试**
2. **参数传递测试**
3. **编辑器集成测试**

### 性能测试
1. **大量信号监听**
2. **缓存效率测试**
3. **内存使用测试**

## 错误处理策略

### SignalInfo 错误
- 无效的信号字典
- 类型不匹配
- 参数验证失败

### SignalManager 错误
- 节点为空
- 缓存冲突
- 查询失败

### EventOnTargetSignalEmit 错误
- 目标节点不存在
- 信号不存在
- 连接失败
- 参数过滤错误

## 性能考虑

### 缓存策略
- 使用节点路径作为缓存键
- 实现智能缓存清理
- 提供缓存统计信息

### 内存管理
- 及时断开信号连接
- 清理内部状态
- 避免循环引用

### 优化技巧
- 延迟加载信号信息
- 批量处理信号查询
- 重复使用对象实例

## 扩展计划

### 短期扩展
1. **多信号监听** - 同时监听多个信号
2. **信号转换** - 参数类型转换
3. **条件触发** - 复杂触发条件

### 长期扩展
1. **信号链** - 信号串联处理
2. **可视化编辑** - 图形化信号连接
3. **调试工具** - 信号调试界面

## 文档需求

### API 文档
1. **SignalInfo 类文档**
2. **SignalManager 类文档**
3. **EventOnTargetSignalEmit 类文档**

### 使用指南
1. **基础使用教程**
2. **高级功能指南**
3. **最佳实践建议**

### 示例代码
1. **简单示例**
2. **复杂场景**
3. **性能优化示例**

## 发布计划

### 版本 1.0
- 基础功能实现
- 核心测试通过
- 基本文档完成

### 版本 1.1
- 编辑器集成优化
- 性能改进
- 错误处理完善

### 版本 1.2
- 高级功能添加
- 扩展接口提供
- 完整测试覆盖

## 总结

这个实现计划提供了清晰的路线图，确保 `EventOnTargetSignalEmit` 事件及其相关类能够高效、可靠地实现。通过分阶段的实现方式，我们可以逐步构建一个强大而灵活的信号监听系统，同时保持代码质量和可维护性。

关键成功因素：
1. **模块化设计** - 每个类都有明确的职责
2. **可复用性** - SignalInfo 和 SignalManager 可以在其他地方使用
3. **性能优化** - 通过缓存和优化策略确保高效运行
4. **编辑器友好** - 提供直观的用户界面
5. **错误处理** - 完善的错误检查和报告机制

通过遵循这个计划，我们将创建一个既满足当前需求又具有未来扩展性的信号监听系统。