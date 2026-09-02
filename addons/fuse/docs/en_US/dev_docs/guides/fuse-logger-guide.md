> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/fuse-logger-guide.md) | English

# FuseLogger Logging System Development Guide

> **Goal**: Provide developers with a complete development guide to the FuseLogger unified logging system, covering log level control, localized logging, component-level filtering, and performance optimizations.

**Audience**: Fuse system developers, contributors

**Last updated**: 2026-07-07

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Design](#architecture-design)
3. [FuseLogger API](#fuselogger-api)
4. [Log Level Control](#log-level-control)
5. [Localized Logging](#localized-logging)
6. [Component-Level Log Configuration](#component-level-log-configuration)
7. [Performance Optimizations](#performance-optimizations)
8. [Best Practices](#best-practices)
9. [Common Pitfalls](#common-pitfalls)

---

## System Overview

`FuseLogger` is the unified logging manager in the Fuse visual programming system, providing formatted output, level filtering, and localized log messages.

### Core Files

| File | Lines | Class |
|------|------|-----|
| `core/logging/fuse_logger.gd` | ~165 | `FuseLogger extends RefCounted` |

### Design Goals

- **Unified logging entry point**: all Fuse components emit logs through the same API
- **Level filtering**: each component can set its log level independently (NONE/INFO/WARNING/ERROR/DEBUG)
- **Localization support**: supports log messages built from translation keys
- **Formatted output**: rich color scheme (`print_rich`) distinguishes levels
- **Performance optimizations**: caches the `FuseLocalization` class reference to avoid repeated `load()` calls

---

## Architecture Design

```
Callers (ActionRunner / ExecutionContext / BaseInstruction ...)
        │
        │ FuseLogger.log_xxxx(component_name, component_level, message, context)
        ▼
┌────────────────────────────────────────────────────────┐
│                     FuseLogger                          │
│                                                         │
│  log_message(component, comp_level, msg_level, msg, ctx)│
│      │                                                   │
│      ├── should_log(comp_level, msg_level) ── false → skip  │
│      │   true                                            │
│      ├── format_message(level, component, message, ctx)  │
│      │   → color + icon + formatted string               │
│      └── Output: print_rich / push_warning / push_error    │
│                                                         │
│  Localization:                                          │
│  log_debug_localized(component, level, msg_key, args)   │
│      → _translate_message(msg_key, args)                │
│      → log_debug(component, level, localized_message)   │
└────────────────────────────────────────────────────────┘
```

---

## FuseLogger API

**File location**: `addons/fuse/core/logging/fuse_logger.gd`

**Class definition**:
```gdscript
class_name FuseLogger extends RefCounted
```

All methods are **static methods**.

### Log Level Enum

```gdscript
enum LogLevel {
    NONE,    # No output at all
    INFO,    # Only output info-level messages
    WARNING, # Only output warning-level messages
    ERROR,   # Only output error-level messages
    DEBUG    # Output all levels (debug, info, warning, error)
}
```

### Core Logging Method

```gdscript
## Generic logging method
## component_name: component name (e.g. "ActionRunner", "ExecutionContext")
## component_level: the component's configured log level
## message_level: the level of this message
## message: message content
## context: context identifier (e.g. execution_id)
static func log_message(
    component_name: String,
    component_level: LogLevel,
    message_level: LogLevel,
    message: String,
    context: String = ""
) -> void
```

### Level Convenience Methods

```gdscript
static func log_debug(component_name: String, component_level: LogLevel, message: String, context: String = "") -> void
static func log_info(component_name: String, component_level: LogLevel, message: String, context: String = "") -> void
static func log_warning(component_name: String, component_level: LogLevel, message: String, context: String = "") -> void
static func log_error(component_name: String, component_level: LogLevel, message: String, context: String = "") -> void
```

### Localized Logging Methods

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

### Helper Methods

```gdscript
## Decide whether a message should be logged (core of level filtering)
static func should_log(component_level: LogLevel, message_level: LogLevel) -> bool

## Format a log message (color + icon)
static func format_message(level: LogLevel, component_name: String, message: String, context: String = "") -> String
```

### Internal Methods

```gdscript
## Translate a message key (caches the FuseLocalization class reference)
static func _translate_message(message_key: String, args: Dictionary = {}) -> String
```

### should_log Logic

```gdscript
static func should_log(component_level: LogLevel, message_level: LogLevel) -> bool:
    if component_level == LogLevel.NONE:
        return false
    if component_level == LogLevel.DEBUG:
        return true       # DEBUG level outputs everything
    # Other levels match exactly
    return message_level == component_level
```

**Note**: in the current implementation, a component at INFO level only outputs INFO messages, not DEBUG; WARNING only outputs WARNING; ERROR only outputs ERROR. `DEBUG` is the only "allow all" level.

---

## Log Level Control

### Component-Level Configuration

Every loggable component has its own `log_level` property:

```gdscript
# ActionRunner
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO

# ExecutionContext
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.NONE
```

### Output Filtering Effect

| Component level | DEBUG | INFO | WARNING | ERROR |
|---------|-------|------|---------|-------|
| NONE | ✗ | ✗ | ✗ | ✗ |
| INFO | ✗ | ✓ | ✗ | ✗ |
| WARNING | ✗ | ✗ | ✓ | ✗ |
| ERROR | ✗ | ✗ | ✗ | ✓ |
| DEBUG | ✓ | ✓ | ✓ | ✓ |

### Calling Directly from Components

```gdscript
# Option 1: call through FuseLogger directly
FuseLogger.log_debug("MyComponent", log_level, "debug message")
FuseLogger.log_info("MyComponent", log_level, "info message")
FuseLogger.log_warning("MyComponent", log_level, "warning message")
FuseLogger.log_error("MyComponent", log_level, "error message")

# Option 2: wrap methods inside the component (as ActionRunner / ExecutionContext do)
func _log_debug(message: String):
    FuseLogger.log_debug("ComponentName", log_level, message)
```

---

## Localized Logging

### Usage

```gdscript
FuseLogger.log_info_localized(
    "MyComponent",
    log_level,
    "FUSE_LOG_MY_EVENT",
    {"param1": value1, "param2": value2}
)
```

### Translation Flow

1. `_translate_message()` loads the `FuseLocalization` class via `load()` on first call
2. Checks `FuseLocalization.init()` to make sure the translation system is initialized
3. Calls `FuseLocalization.translate_format(msg_key, args)` to get the translated text
4. If the localization system is unavailable, falls back to manually replacing `{param}` placeholders

```gdscript
static func _translate_message(message_key: String, args: Dictionary = {}) -> String:
    if _fuse_localization_class == null:
        _fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")
    # ... init + translate_format ...
    # fallback: manually replace {key} placeholders
    if not _fuse_localization_class:
        var result = message_key
        for key in args:
            result = result.replace("{%s}" % key, str(args[key]))
        return result
```

### Defining Entries in CSV

```csv
key,zh_CN,en_US
FUSE_LOG_MY_EVENT,事件触发: {param1},Event triggered: {param1}
```

---

## Component-Level Log Configuration

### ActionRunner

```gdscript
# The ActionRunner log level is set through an exported property
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO
```

Its internal logging methods (`_log_debug`, `_log_info`, `_log_warning`, `_log_error`) automatically pass `"ActionRunner"` as the component name.

### ExecutionContext

```gdscript
# The ExecutionContext log level property
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.NONE
```

It provides unified print methods:
```gdscript
context.print_message("info")    # → FuseLogger.log_info("ExecutionContext", ...)
context.print_warning("warn")    # → FuseLogger.log_warning("ExecutionContext", ...)
context.print_error("error")     # → FuseLogger.log_error("ExecutionContext", ...)
```

### Custom Components

```gdscript
# Use it inside your own component
class_name MyCustomComponent

var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO

func _log_debug(message: String):
    FuseLogger.log_debug("MyCustomComponent", log_level, message)

func _log_info(message: String):
    FuseLogger.log_info("MyCustomComponent", log_level, message)
```

---

## Performance Optimizations

### Caching the FuseLocalization Class Reference

```gdscript
static var _fuse_localization_class: RefCounted = null
```

- `load()` caches the class on the first `_translate_message()` call
- Subsequent calls use the cached class reference directly
- **Roughly 70% faster** (compared to calling `load()` every time)

### should_log Short-Circuit

The decision whether to output is made right at the entrance of `log_message()`:

```gdscript
if not should_log(component_level, message_level):
    return  # Return early, skipping formatting
```

### Component-Level Configuration Recommendations

- **Production**: set component levels to `INFO` or `WARNING` to avoid DEBUG output hurting performance
- **Development**: set to `DEBUG` for the most verbose logs
- **Error tracking**: keep critical error information through the `ERROR` level

---

## Best Practices

### 1. Always Use FuseLogger

```gdscript
# ✅ Recommended
FuseLogger.log_warning("MyComponent", log_level, "设备连接失败")

# ❌ Avoid
push_warning("设备连接失败")
```

### 2. Logs with Context

```gdscript
# Pass context (e.g. execution_id) for easier tracing
FuseLogger.log_info("ActionRunner", log_level, "指令执行完成", execution_id)
```

### 3. Use Localized Logging

```gdscript
# ✅ Recommended: use translation keys
_log_debug_localized("FUSE_LOG_MY_EVENT", {"count": count})

# ❌ Avoid: hard-coded log strings
_log_debug("事件触发，计数: %d" % count)
```

### 4. Use a Class-Name Constant for the Component Name

```gdscript
# ✅ Recommended: use a string constant or the class name directly
FuseLogger.log_info("MyComponent", log_level, "message")

# Keep it consistent so grep filtering works
```

### 5. Log Levels in Production

```gdscript
# Recommended when shipping the game
my_component.log_level = FuseLogger.LogLevel.ERROR  # Keep errors only
```

---

## Common Pitfalls

### Pitfall 1: Ignoring should_log and Filtering Manually

Do not check levels manually before calling — FuseLogger already handles filtering internally:

```gdscript
# ❌ Redundant check
if log_level >= FuseLogger.LogLevel.DEBUG:
    FuseLogger.log_debug("C", log_level, "msg")

# ✅ Call directly
FuseLogger.log_debug("C", log_level, "msg")  # Filtered automatically internally
```

### Pitfall 2: Misunderstanding LogLevel Semantics

`LogLevel` is an "output filtering level", not an "importance level":

```gdscript
# With log_level = INFO:
FuseLogger.log_debug("C", log_level, "debug")     # ✗ Not output
FuseLogger.log_info("C", log_level, "info")       # ✓ Output
FuseLogger.log_warning("C", log_level, "warning") # ✗ Not output
FuseLogger.log_error("C", log_level, "error")     # ✗ Not output
```

This differs from the "output at >= level" behavior of other frameworks. To output warning and above, set the level to `WARNING`.

### Pitfall 3: Localization System Unavailable

In exported Godot games or tests, `FuseLocalization` may not be loaded. `_translate_message()` falls back to manually replacing `{key}` placeholders, in which case message content is the translation key rather than translated text.

### Pitfall 4: print_rich Colors Invisible in a Terminal

`format_message()` uses `[color=xxx]` BB codes, visible only in the Godot editor console. In a system terminal or an exported game the output is plain text.

### Pitfall 5: Overusing DEBUG Logging in Performance-Sensitive Paths

Even when `should_log` returns false, expressions building the log string are still evaluated:

```gdscript
# ❌ The string is built even when nothing is output
_log_debug("详细状态: %s, %s, %s" % [a, b, c])

# ✅ Recommended (localized methods defer evaluation internally)
_log_debug_localized("FUSE_LOG_STATUS", {"a": a, "b": b, "c": c})
```

---

## Reference Documents

- [ExecutionContext and Diagnostics Guide](execution-context-diagnostics-guide.md)
- [ActionRunner Development Guide](action-runner-guide.md)
- [FuseEventBus Development Guide](event-bus-guide.md)
- [RuntimeBridge Development Guide](runtime-bridge-guide.md)

---

**Document maintainer**: Fuse development team | **Last updated**: 2026-07-07 | **Godot version**: 4.7
