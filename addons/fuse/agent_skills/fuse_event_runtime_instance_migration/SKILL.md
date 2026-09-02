---
name: fuse_event_runtime_instance_migration
description: 将 Fuse Event 迁移到 RuntimeEventInstance 架构的专用技能。使用最新的自声明状态模式，Event 通过实现 get_default_runtime_state() 方法声明自己的运行时状态，无需修改核心代码。支持迁移评估、执行、验证和问题解决。
---

# Fuse Event RuntimeInstance 迁移技能（自声明状态模式）

## 快速判断：是否需要迁移？

在开始迁移前，先确认 Event 是否真的需要迁移：

### ✅ 需要迁移的特征

1. Event 类中有**运行时状态变量**（如 `_has_triggered`, `_timer`, `_is_hovered`, `_is_active`）
2. Event **可能被多个场景/节点共享**
3. Event **尚未使用** RuntimeInstance 架构

### ❌ 无需迁移的特征

1. Event **无运行时状态变量**（纯响应式 Event）
2. Event **已经使用** RuntimeInstance 架构
3. Event **专用于单个场景**（不会共享）

**常见状态变量模式**：
```gdscript
var _has_triggered: bool = false        # 触发状态
var _is_hovered: bool = false           # 悬停状态
var _has_exited: bool = false           # 退出状态
var _timer: float = 0.0                 # 定时器
var _current_count: int = 0             # 计数器
var _is_active: bool = false            # 激活状态
var _last_trigger_time: float = 0.0     # 时间戳
var _owner_node_ref: Node = null        # 节点引用（运行时）
```

## 迁移工作流程（新版：自声明状态模式）

### 步骤 1：识别状态变量

读取 Event 类文件，识别所有运行时状态变量。

**检查要点**：
- 所有 `var` 声明的成员变量
- 特别注意以下划线 `_` 开头的私有变量
- 排除 `@export` 导出的配置变量

**示例**：
```gdscript
class_name OnInterval extends BaseEvent

@export var interval: float = 1.0       # ✅ 配置变量，保留
@export var repeat_count: int = 0       # ✅ 配置变量，保留

var _is_running: bool = false           # ❌ 运行时状态，需要迁移
var _current_repeat: int = 0            # ❌ 运行时状态，需要迁移
var _last_time: float = 0.0             # ❌ 运行时状态，需要迁移
var _timer: Timer = null                # ❌ 运行时状态，需要迁移
```

### 步骤 2：删除状态变量

在 Event 类中，**删除**所有运行时状态变量。

> 注：`_runtime_instance_ref` 已在 `BaseEvent` 中声明，子类无需重新声明，直接使用即可。

**修改前**：
```gdscript
class_name OnMyEvent extends BaseEvent

var _has_triggered: bool = false
var _trigger_count: int = 0
var _last_trigger_time: float = 0.0
```

**修改后**：
```gdscript
class_name OnMyEvent extends BaseEvent

# 🔧 运行时状态现在存储在 RuntimeEventInstance 中（通过继承的 _runtime_instance_ref 访问）
```

### 步骤 3：实现 get_default_runtime_state() ⭐

**这是新版架构的核心！** 在 Event 中添加 `get_default_runtime_state()` 方法：

```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	base["last_trigger_time"] = 0.0
	return base
```

**关键点**：
- ✅ **调用 `super.get_default_runtime_state()`** 获取基础状态
- ✅ **添加 Event 特定的状态**
- ✅ **返回完整的状态字典**
- ✅ **无需修改 RuntimeEventInstance 核心代码！**

**默认值使用指南**：
```gdscript
# bool: false
base["is_active"] = false

# int: 0
base["count"] = 0

# float: 0.0
base["timer"] = 0.0

# Array: []
base["triggered_bodies"] = []

# Variant: null
base["last_value"] = null
```

### 步骤 4：修改所有状态访问

将所有状态变量访问改为通过 RuntimeEventInstance：

**读取状态**：
```gdscript
# 旧代码
if _has_triggered:
    return

# 新代码
var has_triggered: bool = false
if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
    has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

if has_triggered:
    return
```

**写入状态**：
```gdscript
# 旧代码
_has_triggered = true
_trigger_count += 1

# 新代码
if _runtime_instance_ref:
    _runtime_instance_ref.set_runtime_state("has_triggered", true)
    _runtime_instance_ref.set_runtime_state("trigger_count",
        _runtime_instance_ref.get_runtime_state("trigger_count", 0) + 1
    )
```

**使用默认值**：
```gdscript
# 读取时提供默认值
var count = _runtime_instance_ref.get_runtime_state("trigger_count", 0)
var time = _runtime_instance_ref.get_runtime_state("last_time", 0.0)
```

### 步骤 5：清理状态

在 `terminate()` 和 `reset()` 方法中清理 RuntimeEventInstance 状态：

```gdscript
func terminate(owner_node: Node) -> void:
    # 断开信号连接
    _disconnect_signals(owner_node)

    # 清理 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", false)
        _runtime_instance_ref.set_runtime_state("trigger_count", 0)

    # 清理引用
    _runtime_instance_ref = null

    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

func reset() -> void:
    super.reset()

    # 重置 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", false)
        _runtime_instance_ref.set_runtime_state("trigger_count", 0)
```

### 步骤 6：验证迁移

测试迁移后的 Event：

1. **功能测试**：Event 能正常触发和工作
2. **状态隔离测试**：多个 Trigger 共享同一个 Event 资源时，状态互不干扰
3. **内存泄漏测试**：Trigger 销毁后，RuntimeEventInstance 被正确清理

**测试场景**：
```
1. 创建两个不同的节点（如 ButtonA 和 ButtonB）
2. 为两个节点配置同一个 OnInterval Event 资源
3. 运行场景，观察：
   - 两个节点的 Event 都能独立触发
   - 触发次数和时间互不影响
   - 销毁一个节点后，另一个仍然正常工作
```

## 常见迁移模式

### 模式 1：布尔状态

```gdscript
# 在 get_default_runtime_state() 中
base["is_active"] = false

# 读取
var is_active = _runtime_instance_ref.get_runtime_state("is_active", false)

# 写入
_runtime_instance_ref.set_runtime_state("is_active", true)
```

### 模式 2：计数器

```gdscript
# 在 get_default_runtime_state() 中
base["count"] = 0

# 读取
var count = _runtime_instance_ref.get_runtime_state("count", 0)

# 递增
_runtime_instance_ref.set_runtime_state("count",
    _runtime_instance_ref.get_runtime_state("count", 0) + 1
)
```

### 模式 3：时间戳

```gdscript
# 在 get_default_runtime_state() 中
base["last_time"] = 0.0

# 读取
var last_time = _runtime_instance_ref.get_runtime_state("last_time", 0.0)

# 更新
_runtime_instance_ref.set_runtime_state("last_time", Time.get_ticks_msec() / 1000.0)
```

### 模式 4：Timer 对象（特殊处理）

**重要**：Timer 等节点对象**不存储**在 RuntimeEventInstance 中！

**正确做法**：
- Timer 对象保留在 Event 类中
- 只有计数器、标志位等运行时状态存储在 RuntimeEventInstance

```gdscript
class_name OnInterval extends BaseEvent

# _runtime_instance_ref 继承自 BaseEvent，无需声明
var _timer: Timer = null  # Timer 对象保留在 Event 类

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["current_count"] = 0  # 只存储计数器状态
    return base
```

### 模式 5：节点引用（特殊处理）

**警告**：不要在 RuntimeEventInstance 中直接存储节点引用！

**正确做法**：
- 节点引用仍存储在 Event 类中（作为配置）
- 或在每次需要时通过 NodePath 动态获取

```gdscript
# Event 类中
@export var target_node_path: NodePath = NodePath("")
var _target_node_ref: Node = null  # 缓存引用，不存储在 RuntimeEventInstance

func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    _runtime_instance_ref = runtime_instance

    # 缓存节点引用
    _target_node_ref = owner_node.get_node_or_null(target_node_path)
```

## 旧版 vs 新版对比

### 旧版（已弃用）❌

需要修改 `RuntimeEventInstance._initialize_runtime_state()`，添加 match 分支：

```gdscript
# 在 RuntimeEventInstance.gd 中添加
match event_definition.get_event_type():
    "my_event":
        runtime_state["has_triggered"] = false
        runtime_state["trigger_count"] = 0
```

**缺点**：
- 每次添加 Event 都要修改核心代码
- 违反开闭原则（Open/Closed Principle）
- 用户创建自定义 Event 不友好
- 代码集中在核心类中，难以维护

### 新版（推荐）✅

在 Event 中实现 `get_default_runtime_state()` 方法：

```gdscript
# 在 Event 类中添加
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["has_triggered"] = false
    base["trigger_count"] = 0
    return base
```

**优点**：
- ✅ 无需修改核心代码
- ✅ 遵循开闭原则
- ✅ 用户创建自定义 Event 更方便
- ✅ 状态声明清晰明确
- ✅ 易于维护和扩展

## 常见问题

### Q1: 迁移后 Event 不触发

**检查**：
1. `get_default_runtime_state()` 是否正确实现
2. 是否调用了 `super.get_default_runtime_state()`
3. 信号连接是否正确建立
4. 是否有状态检查逻辑阻止触发

**调试方法**：
```gdscript
func get_default_runtime_state() -> Dictionary:
    print("[DEBUG] Initializing runtime state for: ", get_event_type())
    var base = super.get_default_runtime_state()
    base["my_state"] = false
    return base
```

### Q2: 状态没有正确隔离

**检查**：
1. 是否所有状态访问都通过 `RuntimeEventInstance`
2. Event 类中是否还残留状态变量
3. 是否正确使用了 `_runtime_instance_ref`

**常见错误**：
```gdscript
# ❌ 错误：直接使用旧的状态变量
if _has_triggered:
    return

# ✅ 正确：通过 RuntimeEventInstance 访问
var has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered", false)
if has_triggered:
    return
```

### Q3: 信号上下文（context）问题

使用 `_emit_triggered()` 自动设置 trigger meta，无需手动创建临时节点：

```gdscript
# ✅ 推荐：自动设置 trigger meta，防止信号广播到其他 RuntimeEventInstance
_emit_triggered(target_node, owner)
# 或 context 与 trigger_node 相同时：
_emit_triggered(owner_node, owner_node)
```

`_emit_triggered()` 会在 context 上设置 `"trigger"` meta，RuntimeEventInstance 据此验证并转发信号。

### Q4: Timer 或其他节点对象的迁移

**方案**：将 Timer 等对象存储在 Event 类中，不存储在 RuntimeEventInstance

```gdscript
class_name OnInterval extends BaseEvent

# _runtime_instance_ref 继承自 BaseEvent，无需声明
var _timer: Timer = null  # Timer 对象仍在 Event 类中

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["current_count"] = 0  # 只存储计数器状态
    return base
```

### Q5: 性能影响

**内存开销**：
- 每个 `RuntimeEventInstance`：约 200-500 字节
- 100 个 Trigger：约 50-110 KB
- **影响可忽略**

**CPU 开销**：
- 状态访问：字典查找 O(1)，<1 微秒
- 信号转发：额外一次信号发射，<10 微秒
- **总体影响 <1%**

## 迁移检查清单

迁移前：
- [ ] 确认 Event 有运行时状态变量
- [ ] 确认 Event 可能被多个节点共享
- [ ] 备份原始 Event 文件
- [ ] 阅读 [完整迁移指南](../../docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md)

迁移步骤：
- [ ] 1. 识别所有运行时状态变量
- [ ] 2. 删除状态变量，添加 `_runtime_instance_ref`
- [ ] 3. ⭐ **实现 `get_default_runtime_state()` 方法（新版核心）**
- [ ] 4. 修改所有状态访问代码
- [ ] 5. 在 `terminate()` 和 `reset()` 中清理状态

迁移后验证：
- [ ] Event 功能正常工作
- [ ] 多个节点共享 Event 时状态独立
- [ ] 没有内存泄漏
- [ ] 在 Event 文件顶部添加迁移注释

## 添加迁移注释

迁移完成后，在 Event 文件顶部添加注释：

```gdscript
## Event: OnMyEvent
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _has_triggered: bool - 是否已触发
## - _trigger_count: int - 触发次数
## - _last_trigger_time: float - 最后触发时间
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: ../../docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md
class_name OnMyEvent
extends BaseEvent
```

## 参考资源

### 核心文档
- **完整迁移指南**：[../../docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md](../../docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md)
- **快速开始**：按本 skill「迁移步骤」顺序执行
- **重构执行摘要**：已并入完整迁移指南结论章（../../docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md）

### API 文档
- **RuntimeEventInstance API**：`addons/fuse/core/runtime_event_instance.gd`
- **BaseEvent API**：`addons/fuse/core/base/base_event.gd`

### 已迁移示例
查看以下 Events 的 `get_default_runtime_state()` 方法实现：
- **OnTimer**：1 个状态变量
- **OnInputKey**：2 个状态变量
- **OnInterval**：4 个状态变量（最复杂）
- **OnMouseButton**：2 个状态变量
- **OnCooldownFinished**：3 个状态变量
- **OnVariableChanged**：3 个状态变量
- **OnMouseEnter**：1 个状态变量
- **OnMouseExit**：1 个状态变量
- **（共 12 个已迁移 Events）**

### 工具
- **评估工具**：`tools/evaluate_events_migration.py`
- **测试工具**：`tools/test_evaluation.py`

## 架构优势总结

使用新版自声明状态模式的优势：

1. **开闭原则**：对扩展开放，对修改封闭
2. **用户友好**：用户创建自定义 Event 无需修改核心代码
3. **清晰明确**：状态声明就在 Event 类中，一目了然
4. **易于维护**：相关代码集中，便于理解和修改
5. **向后兼容**：旧版 match 分支模式仍然可用

**就这么简单！** 🎉
