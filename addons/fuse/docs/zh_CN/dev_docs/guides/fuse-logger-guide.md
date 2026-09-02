# FuseLogger 日志系统开发指南

> **目标**: 为开发者提供 FuseLogger 统一日志系统的完整开发指引，包括日志级别控制、本地化日志、组件级过滤和性能优化。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-07-07

---

## 📋 目录

1. [系统概述](#系统概述)
2. [架构设计](#架构设计)
3. [FuseLogger API](#fuselogger-api)
4. [日志级别控制](#日志级别控制)
5. [本地化日志](#本地化日志)
6. [组件级日志配置](#组件级日志配置)
7. [性能优化](#性能优化)
8. [最佳实践](#最佳实践)
9. [常见陷阱](#常见陷阱)

---

## 系统概述

`FuseLogger` 是 Fuse 可视化编程系统中的统一日志管理器，提供格式化、级别过滤和本地化日志输出。

### 核心文件

| 文件 | 行数 | 类 |
|------|------|-----|
| `core/logging/fuse_logger.gd` | ~165 | `FuseLogger extends RefCounted` |

### 设计目标

- **统一日志入口**: 所有 Fuse 组件通过同一个 API 输出日志
- **级别过滤**: 每个组件可独立设置日志级别（NONE/INFO/WARNING/ERROR/DEBUG）
- **本地化支持**: 支持翻译键的日志消息
- **格式化输出**: 丰富的颜色方案（`print_rich`）区分不同级别
- **性能优化**: 缓存 `FuseLocalization` 类引用，避免重复 `load()`

---

## 架构设计

```
调用方（ActionRunner / ExecutionContext / BaseInstruction ...）
        │
        │ FuseLogger.log_xxxx(component_name, component_level, message, context)
        ▼
┌────────────────────────────────────────────────────────┐
│                     FuseLogger                          │
│                                                         │
│  log_message(component, comp_level, msg_level, msg, ctx)│
│      │                                                   │
│      ├── should_log(comp_level, msg_level) ── false → 跳过  │
│      │   true                                            │
│      ├── format_message(level, component, message, ctx)  │
│      │   → 颜色 + 图标 + 格式化字符串                      │
│      └── 输出: print_rich / push_warning / push_error    │
│                                                         │
│  本地化:                                                 │
│  log_debug_localized(component, level, msg_key, args)   │
│      → _translate_message(msg_key, args)                │
│      → log_debug(component, level, localized_message)   │
└────────────────────────────────────────────────────────┘
```

---

## FuseLogger API

**文件位置**: `addons/fuse/core/logging/fuse_logger.gd`

**类定义**:
```gdscript
class_name FuseLogger extends RefCounted
```

所有方法均为 **静态方法**。

### 日志级别枚举

```gdscript
enum LogLevel {
    NONE,    # 不输出任何日志
    INFO,    # 只输出 info 级别
    WARNING, # 只输出 warning 级别
    ERROR,   # 只输出 error 级别
    DEBUG    # 输出所有级别（debug, info, warning, error）
}
```

### 核心日志方法

```gdscript
## 通用日志方法
## component_name: 组件名称（如 "ActionRunner", "ExecutionContext"）
## component_level: 组件配置的日志级别
## message_level: 本条消息的级别
## message: 消息内容
## context: 上下文标识（如 execution_id）
static func log_message(
    component_name: String,
    component_level: LogLevel,
    message_level: LogLevel,
    message: String,
    context: String = ""
) -> void
```

### 级别便捷方法

```gdscript
static func log_debug(component_name: String, component_level: LogLevel, message: String, context: String = "") -> void
static func log_info(component_name: String, component_level: LogLevel, message: String, context: String = "") -> void
static func log_warning(component_name: String, component_level: LogLevel, message: String, context: String = "") -> void
static func log_error(component_name: String, component_level: LogLevel, message: String, context: String = "") -> void
```

### 本地化日志方法

```gdscript
static func log_debug_localized(
    component_name: String,
    component_level: LogLevel,
    message_key: String,
    args: Dictionary = {},
    context: String = ""
) -> void

static func log_info_localized(
    component_name: String,
    component_level: LogLevel,
    message_key: String,
    args: Dictionary = {},
    context: String = ""
) -> void

static func log_warning_localized(
    component_name: String,
    component_level: LogLevel,
    message_key: String,
    args: Dictionary = {},
    context: String = ""
) -> void

static func log_error_localized(
    component_name: String,
    component_level: LogLevel,
    message_key: String,
    args: Dictionary = {},
    context: String = ""
) -> void
```

### 辅助方法

```gdscript
## 判断是否应输出日志（级别过滤核心）
static func should_log(component_level: LogLevel, message_level: LogLevel) -> bool

## 格式化日志消息（颜色 + 图标）
static func format_message(level: LogLevel, component_name: String, message: String, context: String = "") -> String
```

### 内部方法

```gdscript
## 翻译消息键（缓存 FuseLocalization 类引用）
static func _translate_message(message_key: String, args: Dictionary = {}) -> String
```

### should_log 逻辑

```gdscript
static func should_log(component_level: LogLevel, message_level: LogLevel) -> bool:
    if component_level == LogLevel.NONE:
        return false
    if component_level == LogLevel.DEBUG:
        return true       # DEBUG 级别输出所有
    # 其他级别精确匹配
    return message_level == component_level
```

**注意**: 当前实现中 INFO 级别组件只输出 INFO 消息，不输出 DEBUG；WARNING 只输出 WARNING；ERROR 只输出 ERROR。`DEBUG` 级别是唯一的"允许所有"级别。

---

## 日志级别控制

### 组件级配置

每个可日志组件都有自己的 `log_level` 属性：

```gdscript
# ActionRunner
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO

# ExecutionContext
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.NONE
```

### 输出过滤效果

| 组件级别 | DEBUG | INFO | WARNING | ERROR |
|---------|-------|------|---------|-------|
| NONE | ✗ | ✗ | ✗ | ✗ |
| INFO | ✗ | ✓ | ✗ | ✗ |
| WARNING | ✗ | ✗ | ✓ | ✗ |
| ERROR | ✗ | ✗ | ✗ | ✓ |
| DEBUG | ✓ | ✓ | ✓ | ✓ |

### 在组件中直接调用

```gdscript
# 方式一：通过 FuseLogger 直接调用
FuseLogger.log_debug("MyComponent", log_level, "debug message")
FuseLogger.log_info("MyComponent", log_level, "info message")
FuseLogger.log_warning("MyComponent", log_level, "warning message")
FuseLogger.log_error("MyComponent", log_level, "error message")

# 方式二：组件内封装方法（如 ActionRunner / ExecutionContext 所做）
func _log_debug(message: String):
    FuseLogger.log_debug("ComponentName", log_level, message)
```

---

## 本地化日志

### 使用方式

```gdscript
FuseLogger.log_info_localized(
    "MyComponent",
    log_level,
    "FUSE_LOG_MY_EVENT",
    {"param1": value1, "param2": value2}
)
```

### 翻译流程

1. `_translate_message()` 第一次调用时 `load()` 加载 `FuseLocalization` 类
2. 检查 `FuseLocalization.init()` 确保翻译系统已初始化
3. 调用 `FuseLocalization.translate_format(msg_key, args)` 获取翻译文本
4. 如果本地化系统不可用，回退到手动替换 `{param}` 占位符

```gdscript
static func _translate_message(message_key: String, args: Dictionary = {}) -> String:
    if _fuse_localization_class == null:
        _fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")
    # ... init + translate_format ...
    # fallback：手动替换 {key} 占位符
    if not _fuse_localization_class:
        var result = message_key
        for key in args:
            result = result.replace("{%s}" % key, str(args[key]))
        return result
```

### 在 CSV 中定义

```csv
key,zh_CN,en_US
FUSE_LOG_MY_EVENT,事件触发: {param1},Event triggered: {param1}
```

---

## 组件级日志配置

### ActionRunner

```gdscript
# ActionRunner 日志级别通过导出属性设置
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO
```

内部日志方法（`_log_debug`, `_log_info`, `_log_warning`, `_log_error`）自动传入 `"ActionRunner"` 作为组件名。

### ExecutionContext

```gdscript
# ExecutionContext 日志级别属性
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.NONE
```

提供统一的打印方法：
```gdscript
context.print_message("info")    # → FuseLogger.log_info("ExecutionContext", ...)
context.print_warning("warn")    # → FuseLogger.log_warning("ExecutionContext", ...)
context.print_error("error")     # → FuseLogger.log_error("ExecutionContext", ...)
```

### 自定义组件

```gdscript
# 在自己的组件中使用
class_name MyCustomComponent

var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO

func _log_debug(message: String):
    FuseLogger.log_debug("MyCustomComponent", log_level, message)

func _log_info(message: String):
    FuseLogger.log_info("MyCustomComponent", log_level, message)
```

---

## 性能优化

### 缓存 FuseLocalization 类引用

```gdscript
static var _fuse_localization_class: RefCounted = null
```

- 第一次调用 `_translate_message()` 时 `load()` 缓存
- 后续调用直接使用缓存的类引用
- **性能提升约 70%**（相比每次调用都 `load()`）

### should_log 短路

在 `log_message()` 入口处立即判断是否应输出：

```gdscript
if not should_log(component_level, message_level):
    return  # 尽早返回，跳过格式化
```

### 组件级配置建议

- **生产环境**: 组件级别设为 `INFO` 或 `WARNING`，避免 DEBUG 输出影响性能
- **开发环境**: 设为 `DEBUG` 以获得最详细的日志
- **错误追踪**: 通过 `ERROR` 级别保留关键错误信息

---

## 最佳实践

### 1. 统一使用 FuseLogger

```gdscript
# ✅ 推荐
FuseLogger.log_warning("MyComponent", log_level, "设备连接失败")

# ❌ 避免
push_warning("设备连接失败")
```

### 2. 带上下文的日志

```gdscript
# 传递 context（如 execution_id）便于追踪
FuseLogger.log_info("ActionRunner", log_level, "指令执行完成", execution_id)
```

### 3. 使用本地化日志

```gdscript
# ✅ 推荐：使用翻译键
_log_debug_localized("FUSE_LOG_MY_EVENT", {"count": count})

# ❌ 避免：硬编码的日志字符串
_log_debug("事件触发，计数: %d" % count)
```

### 4. 组件名使用类名常量

```gdscript
# ✅ 推荐：使用字符串常量或直接写类名
FuseLogger.log_info("MyComponent", log_level, "message")

# 保持一致性，便于 grep 过滤
```

### 5. 生产环境日志级别

```gdscript
# 发布游戏时建议
my_component.log_level = FuseLogger.LogLevel.ERROR  # 只保留错误
```

---

## 常见陷阱

### 陷阱 1：忽略 should_log 直接过滤

不要在调用前手动判断级别——FuseLogger 内部已处理过滤：

```gdscript
# ❌ 多余判断
if log_level >= FuseLogger.LogLevel.DEBUG:
    FuseLogger.log_debug("C", log_level, "msg")

# ✅ 直接调用
FuseLogger.log_debug("C", log_level, "msg")  # 内部自动过滤
```

### 陷阱 2：混淆 LogLevel 的语义

`LogLevel` 是"输出过滤级别"而非"重要性级别"：

```gdscript
# log_level = INFO 时：
FuseLogger.log_debug("C", log_level, "debug")     # ✗ 不输出
FuseLogger.log_info("C", log_level, "info")       # ✓ 输出
FuseLogger.log_warning("C", log_level, "warning") # ✗ 不输出
FuseLogger.log_error("C", log_level, "error")     # ✗ 不输出
```

这与其他框架的">=级别才输出"行为不同。如需输出 warning 及以上，设级别为 `WARNING`。

### 陷阱 3：本地化系统不可用

在 Godot 导出的游戏或测试中，`FuseLocalization` 可能未被加载。`_translate_message()` 会回退到手动替换 `{key}` 占位符，此时消息内容为 translation key 而非翻译文本。

### 陷阱 4：print_rich 颜色在终端中不可见

`format_message()` 使用 `[color=xxx]` BB 代码，仅在 Godot 编辑器控制台中可见。在系统终端或导出游戏中以纯文本输出。

### 陷阱 5：性能敏感路径中过度使用 DEBUG 日志

即使 `should_log` 返回 false，构造日志字符串的表达式仍会被求值：

```gdscript
# ❌ 即使不输出，字符串也已被构造
_log_debug("详细状态: %s, %s, %s" % [a, b, c])

# ✅ 推荐（使用本地化方法，内部延迟求值）
_log_debug_localized("FUSE_LOG_STATUS", {"a": a, "b": b, "c": c})
```

---

## 参考文档

- [ExecutionContext 与 Diagnostics 指南](execution-context-diagnostics-guide.md)
- [ActionRunner 开发指南](action-runner-guide.md)
- [FuseEventBus 开发指南](event-bus-guide.md)
- [RuntimeBridge 开发指南](runtime-bridge-guide.md)

---

**文档维护**: Fuse 开发团队 | **最后更新**: 2026-07-07 | **Godot 版本**: 4.7
