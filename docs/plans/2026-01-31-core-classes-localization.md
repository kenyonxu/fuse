# Bricks 核心类本地化实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 为 Bricks 可视化编程系统的三个核心类（Trigger、ExecutionContext、ActionRunner）实施完整的本地化支持，消除所有硬编码的中文字符串。

**架构:** 遵循 Bricks 本地化规范（README.md），使用 BricksLocalization 系统进行文本本地化，通过 BricksLogger 的本地化日志方法输出消息。

**技术栈:**
- GDScript 2.0 (Godot 4.6)
- BricksLocalization 系统
- BricksLogger 日志系统
- translations.csv 翻译文件

---

## 前置条件检查

### Task 0: 验证本地化系统状态

**文件:**
- Check: `addons/bricks/localization/bricks_localization.gd`
- Check: `addons/bricks/localization/translations.csv`
- Check: `addons/bricks/core/logger/bricks_logger.gd`

**Step 1: 验证 BricksLocalization 已初始化**

打开 `addons/bricks/localization/bricks_localization.gd`，确认包含以下方法：
- `translate(key: String) -> String`
- `translate_format(key: String, args: Dictionary) -> String`
- `get_current_locale() -> Locale`

**Step 2: 验证 BricksLogger 支持本地化日志**

打开 `addons/bricks/core/logger/bricks_logger.gd`，确认包含以下方法：
- `log_debug_localized(system: String, level: LogLevel, key: String, args: Dictionary)`
- `log_info_localized(system: String, level: LogLevel, key: String, args: Dictionary)`
- `log_warning_localized(system: String, level: LogLevel, key: String, args: Dictionary)`
- `log_error_localized(system: String, level: LogLevel, key: String, args: Dictionary)`

**Step 3: 统计当前翻译键数量**

Run: `grep -c "^BRICKS_" addons/bricks/localization/translations.csv`
Expected: 数字（当前翻译键数量，用于后续对比）

---

## 阶段 1: Trigger 类本地化

### Task 1: 为 Trigger 类添加本地化日志方法

**文件:**
- Modify: `addons/bricks/core/trigger.gd`

**Step 1: 在统一日志方法后添加本地化日志方法**

在 trigger.gd 的第 170 行后（`_log_error` 方法后）添加：

```gdscript
## 本地化日志方法
func _log_debug_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_debug_localized("Trigger", log_level, message_key, args)

func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_info_localized("Trigger", log_level, message_key, args)

func _log_warning_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_warning_localized("Trigger", log_level, message_key, args)

func _log_error_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_error_localized("Trigger", log_level, message_key, args)
```

**Step 2: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 3: 提交更改**

```bash
git add addons/bricks/core/trigger.gd
git commit -m "feat(trigger): add localized logging methods"
```

---

### Task 2: 添加 Trigger 相关的翻译键到 CSV

**文件:**
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 在 translations.csv 末尾添加 Trigger 相关翻译键**

在文件末尾添加以下内容（注意：在现有内容后追加，不要删除现有内容）：

```csv
# Trigger - 触发器核心类
BRICKS_LOG_TRIGGER_EDITOR_MODE_SKIPPED,编辑器模式下，跳过触发器初始化,Editor mode: skipping trigger initialization
BRICKS_ERROR_EVENT_DEFINITION_NOT_CONFIGURED,未配置事件定义,Event definition not configured
BRICKS_LOG_TRIGGER_INITIALIZED,触发器初始化完成: {description},Trigger initialized: {description}
BRICKS_LOG_TRIGGER_CLEANUP_COMPLETE,触发器清理完成: {name},Trigger cleanup complete: {name}
BRICKS_LOG_RUNTIME_EVENT_CLEANUP,运行时事件实例已清理,Runtime event instance cleaned up
BRICKS_LOG_TRIGGER_ALREADY_FIRED,触发器已触发过，忽略本次触发,Trigger already fired, ignoring this trigger
BRICKS_LOG_TRIGGER_FIRED,触发器触发: {description},Trigger fired: {description}
BRICKS_LOG_ACTION_RUNNER_EXECUTION_MODE,ActionRunner 执行模式: {mode},ActionRunner execution mode: {mode}
BRICKS_ERROR_ACTION_RUNNER_NO_RUN_METHOD,ActionRunner 没有 run 方法: {runner},ActionRunner has no run method: {runner}
BRICKS_ERROR_TRIGGER_NO_ACTION_RUNNER,触发器触发但没有配置 ActionRunner,Trigger fired but no ActionRunner configured
BRICKS_TRIGGER_NO_EVENT,Trigger (无事件),Trigger (no event)
BRICKS_LOG_TRIGGER_STATE_RESET,触发器状态已重置,Trigger state reset
BRICKS_ERROR_EVENT_DEFINITION_NOT_SPECIFIED,未指定事件定义,Event definition not specified
BRICKS_ERROR_ACTION_RUNNER_NOT_SPECIFIED,未指定动作执行器,ActionRunner not specified
BRICKS_LOG_TRIGGER_MANUAL_TRIGGER,手动触发触发器,Manually triggering trigger
```

**Step 2: 验证 CSV 格式正确性**

Run: 检查 CSV 文件确保每行都是 `key,zh_CN,en_US` 格式
Expected: 所有新增行格式正确

**Step 3: 提交更改**

```bash
git add addons/bricks/localization/translations.csv
git commit -m "feat(i18n): add Trigger localization keys to CSV"
```

---

### Task 3: 替换 trigger.gd 中的硬编码字符串（第 1-3 处）

**文件:**
- Modify: `addons/bricks/core/trigger.gd:29-56`

**Step 1: 替换 _ready() 方法中的硬编码字符串**

找到第 29 行：
```gdscript
_log_debug("编辑器模式下，跳过触发器初始化")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_TRIGGER_EDITOR_MODE_SKIPPED")
```

找到第 33-34 行：
```gdscript
_log_warning("未配置事件定义")
_create_bricks_error("未配置事件定义", BricksError.ErrorType.CONFIGURATION_ERROR)
```
替换为：
```gdscript
_log_warning_localized("BRICKS_ERROR_EVENT_DEFINITION_NOT_CONFIGURED")
_create_bricks_error_localized("BRICKS_ERROR_EVENT_DEFINITION_NOT_CONFIGURED", BricksError.ErrorType.CONFIGURATION_ERROR)
```

找到第 56 行：
```gdscript
_log_debug("触发器初始化完成: %s" % get_description())
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_TRIGGER_INITIALIZED", {"description": get_description()})
```

**Step 2: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 3: 提交更改**

```bash
git add addons/bricks/core/trigger.gd
git commit -m "fix(trigger): localize log messages in _ready method"
```

---

### Task 4: 替换 trigger.gd 中的硬编码字符串（第 4-7 处）

**文件:**
- Modify: `addons/bricks/core/trigger.gd:64-103`

**Step 1: 替换 _exit_tree() 方法中的硬编码字符串**

找到第 64 行：
```gdscript
_log_debug("触发器清理完成: %s" % name)
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_TRIGGER_CLEANUP_COMPLETE", {"name": name})
```

找到第 70 行：
```gdscript
_log_debug("运行时事件实例已清理")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_RUNTIME_EVENT_CLEANUP")
```

**Step 2: 替换 _on_event_fired() 方法中的硬编码字符串**

找到第 74 行：
```gdscript
_log_debug("触发器已触发过，忽略本次触发")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_TRIGGER_ALREADY_FIRED")
```

找到第 80 行：
```gdscript
_log_debug("触发器触发: %s" % get_description())
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_TRIGGER_FIRED", {"description": get_description()})
```

找到第 86-90 行（三处相同）：
```gdscript
_log_debug("ActionRunner 执行模式: %s" % ActionRunner.ExecutionMode.keys()[action_runner.execution_mode])
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_ACTION_RUNNER_EXECUTION_MODE", {"mode": ActionRunner.ExecutionMode.keys()[action_runner.execution_mode]})
```

找到第 100 行：
```gdscript
_log_error("ActionRunner 没有 run 方法: %s" % action_runner)
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_ACTION_RUNNER_NO_RUN_METHOD", {"runner": str(action_runner)})
```

找到第 102-103 行：
```gdscript
_log_warning("触发器触发但没有配置 ActionRunner")
_create_bricks_error("触发器触发但没有配置 ActionRunner", BricksError.ErrorType.CONFIGURATION_ERROR)
```
替换为：
```gdscript
_log_warning_localized("BRICKS_ERROR_TRIGGER_NO_ACTION_RUNNER")
_create_bricks_error_localized("BRICKS_ERROR_TRIGGER_NO_ACTION_RUNNER", BricksError.ErrorType.CONFIGURATION_ERROR)
```

**Step 3: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 4: 提交更改**

```bash
git add addons/bricks/core/trigger.gd
git commit -m "fix(trigger): localize log messages in _exit_tree and _on_event_fired"
```

---

### Task 5: 替换 trigger.gd 中的硬编码字符串（第 8-16 处）

**文件:**
- Modify: `addons/bricks/core/trigger.gd:118-156`

**Step 1: 替换 get_description() 方法中的硬编码字符串**

找到第 122 行：
```gdscript
return "Trigger (无事件)"
```
替换为：
```gdscript
return BricksLocalization.translate("BRICKS_TRIGGER_NO_EVENT")
```

**Step 2: 替换 reset() 方法中的硬编码字符串**

找到第 130 行：
```gdscript
_log_debug("触发器状态已重置")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_TRIGGER_STATE_RESET")
```

**Step 3: 替换 validate() 方法中的硬编码字符串**

找到第 137-138 行：
```gdscript
errors.append("未指定事件定义")
_create_bricks_error("未指定事件定义", BricksError.ErrorType.CONFIGURATION_ERROR)
```
替换为：
```gdscript
var error_msg = BricksLocalization.translate("BRICKS_ERROR_EVENT_DEFINITION_NOT_SPECIFIED")
errors.append(error_msg)
_create_bricks_error_localized("BRICKS_ERROR_EVENT_DEFINITION_NOT_SPECIFIED", BricksError.ErrorType.CONFIGURATION_ERROR)
```

找到第 141-142 行：
```gdscript
errors.append("未指定动作执行器")
_create_bricks_error("未指定动作执行器", BricksError.ErrorType.CONFIGURATION_ERROR)
```
替换为：
```gdscript
var error_msg = BricksLocalization.translate("BRICKS_ERROR_ACTION_RUNNER_NOT_SPECIFIED")
errors.append(error_msg)
_create_bricks_error_localized("BRICKS_ERROR_ACTION_RUNNER_NOT_SPECIFIED", BricksError.ErrorType.CONFIGURATION_ERROR)
```

找到第 149-150 行：
```gdscript
errors.append("ActionRunner 没有 run 方法")
_create_bricks_error("ActionRunner 没有 run 方法", BricksError.ErrorType.CONFIGURATION_ERROR)
```
替换为：
```gdscript
var error_msg = BricksLocalization.translate("BRICKS_ERROR_ACTION_RUNNER_NO_RUN_METHOD")
errors.append(error_msg)
_create_bricks_error_localized("BRICKS_ERROR_ACTION_RUNNER_NO_RUN_METHOD", BricksError.ErrorType.CONFIGURATION_ERROR)
```

**Step 4: 替换 trigger_manually() 方法中的硬编码字符串**

找到第 156 行：
```gdscript
_log_debug("手动触发触发器")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_TRIGGER_MANUAL_TRIGGER")
```

**Step 5: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 6: 提交更改**

```bash
git add addons/bricks/core/trigger.gd
git commit -m "fix(trigger): localize remaining log messages and errors"
```

---

### Task 6: 添加 Trigger 类的 _create_bricks_error_localized 方法

**文件:**
- Modify: `addons/bricks/core/trigger.gd`

**Step 1: 在 _create_bricks_error 方法后添加本地化版本**

在第 182 行后（`_create_bricks_error` 方法后）添加：

```gdscript
## 创建 BricksError 实例（本地化版本）
## message_key: String - 错误消息翻译键
## error_type: BricksError.ErrorType - 错误类型
## args: Dictionary - 翻译参数
## context: Dictionary - 错误上下文
func _create_bricks_error_localized(message_key: String, error_type: BricksError.ErrorType = BricksError.ErrorType.RUNTIME_ERROR, args: Dictionary = {}, context: Dictionary = {}):
	var message = BricksLocalization.translate_format(message_key, args)
	_create_bricks_error(message, error_type, context)
```

**Step 2: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 3: 提交更改**

```bash
git add addons/bricks/core/trigger.gd
git commit -m "feat(trigger): add _create_bricks_error_localized helper method"
```

---

## 阶段 2: ExecutionContext 类本地化

### Task 7: 为 ExecutionContext 类添加本地化日志方法

**文件:**
- Modify: `addons/bricks/core/base/execution_context.gd`

**Step 1: 在统一日志方法后添加本地化日志方法**

在 execution_context.gd 的第 817 行后（`_log_error` 方法后）添加：

```gdscript
## 本地化日志方法
func _log_debug_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_debug_localized("ExecutionContext", log_level, message_key, args)

func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_info_localized("ExecutionContext", log_level, message_key, args)

func _log_warning_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_warning_localized("ExecutionContext", log_level, message_key, args)

func _log_error_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_error_localized("ExecutionContext", log_level, message_key, args)
```

**Step 2: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 3: 提交更改**

```bash
git add addons/bricks/core/base/execution_context.gd
git commit -m "feat(execution_context): add localized logging methods"
```

---

### Task 8: 添加 ExecutionContext 相关的翻译键到 CSV

**文件:**
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 在 translations.csv 末尾添加 ExecutionContext 相关翻译键**

在文件末尾添加以下内容：

```csv
# ExecutionContext - 执行上下文核心类
BRICKS_ERROR_INVALID_NODE_PATH_EMPTY,Invalid node path: empty,Invalid node path: empty
BRICKS_ERROR_SCENE_TREE_NOT_AVAILABLE,Scene tree not available,Scene tree not available
BRICKS_ERROR_NODE_NOT_FOUND_AT_PATH,Node not found at path: {path},Node not found at path: {path}
BRICKS_ERROR_INVALID_VARIABLE_OBJECT,Invalid variable object,Invalid variable object
BRICKS_LOG_VARIABLE_ALREADY_EXISTS_OVERWRITING,Local variable '{name}' already exists, overwriting,Local variable '{name}' already exists, overwriting
BRICKS_LOG_OVERWRITING_OLD_VALUE,Overwriting old value: {value} (type: {type}),Overwriting old value: {value} (type: {type})
BRICKS_LOG_ADDED_LOCAL_VARIABLE,Added local variable '{name}': {value} (type: {type}),Added local variable '{name}': {value} (type: {type})
BRICKS_LOG_NEW_VARIABLES_COUNT,New local variables count: {count},New local variables count: {count}
BRICKS_ERROR_VERIFICATION_FAILED,Verification failed: variable not found after adding,Verification failed: variable not found after adding
BRICKS_ERROR_GLOBAL_VARIABLE_ASSISTANT_NOT_FOUND,无法获取 GlobalVariableAssistant 单例,Cannot get GlobalVariableAssistant singleton
BRICKS_ERROR_GLOBAL_VARIABLE_NO_CURRENT_RESOURCE,GlobalVariableAssistant 没有配置 current_resource,GlobalVariableAssistant has no current_resource configured
BRICKS_ERROR_ADD_GLOBAL_VARIABLE_FAILED,添加全局变量 '{name}' 失败,Failed to add global variable '{name}'
BRICKS_LOG_GLOBAL_VARIABLE_ADDED,全局变量 '{name}' 已添加到上下文: {value},Global variable '{name}' added to context: {value}
BRICKS_ERROR_UNKNOWN_VARIABLE_SCOPE,Unknown variable scope: {scope},Unknown variable scope: {scope}
BRICKS_ERROR_VARIABLE_NAME_CANNOT_BE_EMPTY,Variable name cannot be empty,Variable name cannot be empty
BRICKS_LOG_RETRIEVED_LOCAL_VARIABLE,Retrieved local variable '{name}': {value} (type: {type}),Retrieved local variable '{name}': {value} (type: {type})
BRICKS_LOG_RETRIEVED_GLOBAL_VARIABLE,Retrieved global variable '{name}': {value} (type: {type}),Retrieved global variable '{name}': {value} (type: {type})
BRICKS_LOG_VARIABLE_NOT_FOUND_RETURNING_DEFAULT,Variable '{name}' not found, returning default: {default},Variable '{name}' not found, returning default: {default}
BRICKS_LOG_ACTION_RUNNER_SET,ActionRunner 已设置: {runner},ActionRunner set: {runner}
BRICKS_LOG_CLEANING_TARGET_NODE_REF,清理目标节点引用: {name},Cleaning target node reference: {name}
BRICKS_LOG_CLEANING_TRIGGER_NODE_REF,清理触发器节点引用: {name},Cleaning trigger node reference: {name}
BRICKS_LOG_EXECUTION_CONTEXT_CLEANED,Execution context cleaned up with explicit object release,Execution context cleaned up with explicit object release
BRICKS_LOG_EXECUTION_STATE_CHANGED,Execution state changed to: {state},Execution state changed to: {state}
BRICKS_LOG_EXECUTION_PROGRESS_UPDATED,Execution progress updated to: {progress},Execution progress updated to: {progress}
BRICKS_LOG_EXECUTION_ERROR,Execution error: {message},Execution error: {message}
BRICKS_LOG_EXECUTION_CANCELLATION_REQUESTED,Execution cancellation requested,Execution cancellation requested
BRICKS_LOG_EXECUTION_STATE_RESET,Execution state reset,Execution state reset
BRICKS_LOG_EXECUTION_HISTORY_CLEARED,执行历史已清除,Execution history cleared
BRICKS_LOG_STATE_CHANGE_LISTENER_ADDED,添加状态变化监听器,Added state change listener
BRICKS_LOG_STATE_CHANGE_LISTENER_REMOVED,移除状态变化监听器,Removed state change listener
BRICKS_LOG_DEPENDENCY_CHECK_COMPLETE,批量检查依赖关系完成: 检查了 {count} 组依赖关系,Batch dependency check complete: checked {count} groups
BRICKS_LOG_TARGET_NODE_SET,目标节点已设置: {name},Target node set: {name}
BRICKS_LOG_TRIGGER_NODE_SET,触发器节点已设置: {name},Trigger node set: {name}
BRICKS_WARNING_TARGET_NODE_RELEASED,目标节点已被释放,Target node has been released
BRICKS_WARNING_TRIGGER_NODE_RELEASED,触发器节点已被释放,Trigger node has been released
BRICKS_LOG_SETTING_BREAK_LOOP_FLAG,设置循环中断标志 (break),Setting break loop flag
BRICKS_LOG_SETTING_CONTINUE_LOOP_FLAG,设置循环继续标志 (continue),Setting continue loop flag
BRICKS_LOG_CLEARING_LOOP_FLAGS,清除循环控制标志,Clearing loop control flags
BRICKS_LOG_PUSH_LOOP_FLAGS_TO_STACK,保存循环标志到栈，栈深度: {depth},Pushing loop flags to stack, depth: {depth}
BRICKS_LOG_LOOP_FLAG_STACK_EMPTY,循环标志栈为空，清空标志,Loop flag stack empty, clearing flags
BRICKS_LOG_POP_LOOP_FLAGS_FROM_STACK,从栈恢复循环标志，栈深度: {depth},Popping loop flags from stack, depth: {depth}
BRICKS_LOG_PRECOMPILED_VARIABLE_INDEXES,预编译了 {count} 个变量索引,Precompiled {count} variable indexes
BRICKS_WARNING_INDEXED_ACCESS_NOT_ENABLED,索引访问未启用，请先调用 precompile_variable_access(),Indexed access not enabled, call precompile_variable_access() first
BRICKS_LOG_SET_VARIABLE_BY_INDEX,通过索引 {index} 设置变量值: {value},Set variable value by index {index}: {value}
BRICKS_ERROR_INDEX_OUT_OF_RANGE,索引 {index} 超出范围，有效范围: 0-{max},Index {index} out of range, valid range: 0-{max}
BRICKS_WARNING_INDEXED_ACCESS_DISABLED,索引访问未启用，请先调用 precompile_variable_access(),Indexed access disabled, call precompile_variable_access() first
```

**Step 2: 验证 CSV 格式正确性**

Run: 检查 CSV 文件确保每行都是 `key,zh_CN,en_US` 格式
Expected: 所有新增行格式正确

**Step 3: 提交更改**

```bash
git add addons/bricks/localization/translations.csv
git commit -m "feat(i18n): add ExecutionContext localization keys to CSV"
```

---

### Task 9: 批量替换 execution_context.gd 中的日志消息

**文件:**
- Modify: `addons/bricks/core/base/execution_context.gd`

**Step 1: 替换 get_node() 方法中的错误日志（第 159、173、187 行）**

找到第 159 行：
```gdscript
_log_error("Invalid node path: empty")
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_INVALID_NODE_PATH_EMPTY")
```

找到第 173 行：
```gdscript
_log_error("Scene tree not available")
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_SCENE_TREE_NOT_AVAILABLE")
```

找到第 187 行：
```gdscript
_log_error("Node not found at path: %s" % path)
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_NODE_NOT_FOUND_AT_PATH", {"path": str(path)})
```

**Step 2: 替换 add_variable() 方法中的日志（第 202 行）**

找到第 202 行：
```gdscript
_log_error("Invalid variable object")
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_INVALID_VARIABLE_OBJECT")
```

**Step 3: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 4: 提交更改**

```bash
git add addons/bricks/core/base/execution_context.gd
git commit -m "fix(execution_context): localize log messages in get_node and add_variable"
```

---

### Task 10: 替换 set_variable() 方法中的调试日志（第 244-300 行）

**文件:**
- Modify: `addons/bricks/core/base/execution_context.gd:244-300`

**注意:** ExecutionContext 有大量调试日志，但很多都是内部调试信息，只需要本地化用户可见的关键消息。

**Step 1: 替换变量覆盖警告（第 249 行）**

找到第 249 行：
```gdscript
_log_warning("Local variable '%s' already exists, overwriting" % name)
```
替换为：
```gdscript
_log_warning_localized("BRICKS_LOG_VARIABLE_ALREADY_EXISTS_OVERWRITING", {"name": name})
```

**Step 2: 替换全局变量相关错误（第 277、282、294 行）**

找到第 277 行：
```gdscript
_log_error("无法获取 GlobalVariableAssistant 单例")
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_GLOBAL_VARIABLE_ASSISTANT_NOT_FOUND")
```

找到第 282 行：
```gdscript
_log_error("GlobalVariableAssistant 没有配置 current_resource")
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_GLOBAL_VARIABLE_NO_CURRENT_RESOURCE")
```

找到第 294 行：
```gdscript
_log_error("添加全局变量 '%s' 失败" % name)
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_ADD_GLOBAL_VARIABLE_FAILED", {"name": name})
```

找到第 297 行：
```gdscript
_log_debug("全局变量 '%s' 已添加到上下文: %s" % [name, str(value)])
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_GLOBAL_VARIABLE_ADDED", {"name": name, "value": str(value)})
```

**Step 3: 替换作用域错误（第 300 行）**

找到第 300 行：
```gdscript
_log_error("Unknown variable scope: %s" % scope)
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_UNKNOWN_VARIABLE_SCOPE", {"scope": scope})
```

**Step 4: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 5: 提交更改**

```bash
git add addons/bricks/core/base/execution_context.gd
git commit -m "fix(execution_context): localize log messages in set_variable"
```

---

### Task 11: 替换 get_variable() 和其他方法中的日志（分散位置）

**文件:**
- Modify: `addons/bricks/core/base/execution_context.gd`

**Step 1: 替换变量名空错误（第 234、337、410 行）**

这些行都是：
```gdscript
_log_error("Variable name cannot be empty")
```
全部替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_VARIABLE_NAME_CANNOT_BE_EMPTY")
```

**Step 2: 替换节点清理日志（第 567、571 行）**

找到第 567 行：
```gdscript
_log_debug("清理目标节点引用: %s" % target.name)
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_CLEANING_TARGET_NODE_REF", {"name": target.name})
```

找到第 571 行：
```gdscript
_log_debug("清理触发器节点引用: %s" % trigger.name)
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_CLEANING_TRIGGER_NODE_REF", {"name": trigger.name})
```

**Step 3: 替换清理完成日志（第 603 行）**

找到第 603 行：
```gdscript
_log_debug("Execution context cleaned up with explicit object release")
```
保留原样（英文消息，已经是用户不可见的内部调试信息）

**Step 4: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 5: 提交更改**

```bash
git add addons/bricks/core/base/execution_context.gd
git commit -m "fix(execution_context): localize remaining log messages"
```

---

## 阶段 3: ActionRunner 类本地化

### Task 12: ActionRunner 类已有本地化方法，只需添加缺失的翻译键

**检查:** `addons/bricks/core/base/action_runner.gd` 已经包含本地化日志方法（第 581-592 行）

**Step 1: 验证 ActionRunner 已有本地化方法**

确认 action_runner.gd 第 581-592 行包含：
```gdscript
func _log_debug_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_debug_localized("ActionRunner", log_level, message_key, args)

func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_info_localized("ActionRunner", log_level, message_key, args)

func _log_warning_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_warning_localized("ActionRunner", log_level, message_key, args)

func _log_error_localized(message_key: String, args: Dictionary = {}) -> void:
	BricksLogger.log_error_localized("ActionRunner", log_level, message_key, args)
```

Expected: 已存在，无需修改

---

### Task 13: 添加 ActionRunner 相关的翻译键到 CSV

**文件:**
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 在 translations.csv 末尾添加 ActionRunner 相关翻译键**

在文件末尾添加以下内容：

```csv
# ActionRunner - 动作运行器核心类
BRICKS_LOG_ACTION_RUNNER_INITIALIZED,ActionRunner initialized,ActionRunner initialized
BRICKS_ERROR_ACTION_RUNNER_ALREADY_RUNNING,ActionRunner 已经在运行,ActionRunner is already running
BRICKS_LOG_STARTING_EXECUTION,Starting execution with {count} instructions,Starting execution with {count} instructions
BRICKS_LOG_EXECUTION_STOPPED_BY_REQUEST,Execution stopped by request,Execution stopped by request
BRICKS_LOG_CANNOT_CANCEL_NOT_RUNNING,Cannot cancel: ActionRunner is not running,Cannot cancel: ActionRunner is not running
BRICKS_LOG_ALREADY_CANCELLING,Already canceling execution,Already canceling execution
BRICKS_LOG_CANCELLING_EXECUTION,Canceling execution: {reason},Canceling execution: {reason}
BRICKS_ERROR_TOO_MANY_INSTRUCTIONS,指令数量过多: {count} (最大: {max}),Too many instructions: {count} (max: {max})
BRICKS_ERROR_INSTRUCTION_AT_INDEX_NULL,索引 {index} 处的指令为空,Instruction at index {index} is null
BRICKS_ERROR_INSTRUCTION_VALIDATION_FAILED,指令验证失败 (索引 {index}): {errors},Instruction validation failed at index {index}: {errors}
BRICKS_LOG_STARTING_SEQUENTIAL_EXECUTION,Starting sequential execution,Starting sequential execution
BRICKS_LOG_SKIPPING_INSTRUCTION,跳过指令 {index} (剩余跳过: {remaining}),Skipping instruction {index} (remaining skips: {remaining})
BRICKS_LOG_STOP_EXECUTION,停止执行: {reason},Stop execution: {reason}
BRICKS_LOG_EXECUTION_CANCELLED,Execution cancelled: {reason},Execution cancelled: {reason}
BRICKS_LOG_EXECUTION_STOP,Execution stopped,Execution stopped
BRICKS_LOG_EXECUTING_INSTRUCTION,Executing instruction {current}/{total}: {description},Executing instruction {current}/{total}: {description}
BRICKS_LOG_ASYNC_INSTRUCTION_COMPLETED,异步指令完成: {time} 秒,Async instruction completed: {time} seconds
BRICKS_ERROR_INSTRUCTION_EXECUTION_FAILED,指令执行失败: {error},Instruction execution failed: {error}
BRICKS_LOG_STOPPING_DUE_TO_ERROR,Stopping execution due to instruction error: {error},Stopping execution due to instruction error: {error}
BRICKS_LOG_SEQUENTIAL_EXECUTION_COMPLETED,Sequential execution completed,Sequential execution completed
BRICKS_LOG_STARTING_PARALLEL_EXECUTION,Starting parallel execution,Starting parallel execution
BRICKS_LOG_EXECUTION_CANCELLED_DURING_PARALLEL,Execution cancelled during parallel task creation: {reason},Execution cancelled during parallel task creation: {reason}
BRICKS_LOG_EXECUTION_STOPPED_DURING_PARALLEL,Execution stopped during parallel task creation,Execution stopped during parallel task creation
BRICKS_LOG_STARTING_PARALLEL_INSTRUCTION,Starting parallel instruction: {description},Starting parallel instruction: {description}
BRICKS_LOG_PARALLEL_EXECUTION_STARTED,Parallel execution started {count} tasks,Parallel execution started {count} tasks
BRICKS_LOG_PARALLEL_EXECUTION_COMPLETED,Parallel execution completed,Parallel execution completed
BRICKS_LOG_PARALLEL_INSTRUCTION_FAILED,Parallel instruction {index} failed: {error},Parallel instruction {index} failed: {error}
BRICKS_ERROR_PARALLEL_EXECUTION_FAILED,并行执行失败，有 {count} 个错误,Parallel execution failed with {count} errors
BRICKS_ERROR_EXECUTION_TIMEOUT,执行超时: {elapsed} 秒 (限制: {timeout} 秒, 指令数: {count}),Execution timeout: {elapsed} seconds (limit: {timeout} seconds, instructions: {count})
BRICKS_ERROR_EXECUTION_TIMEOUT_FORMAT,执行超时 ({timeout} 秒),Execution timeout ({timeout} seconds)
BRICKS_ERROR_EXECUTION_TIMEOUT_AFTER,Execution timeout after {timeout} seconds,Execution timeout after {timeout} seconds
BRICKS_WARNING_CANNOT_CONNECT_SIGNAL_INSTRUCTION_NULL,无法连接信号：指令为空,Cannot connect signal: instruction is null
BRICKS_LOG_CONNECTED_INSTRUCTION_SIGNAL,已连接指令 '{name}' 的 finished 信号,Connected instruction '{name}' finished signal
BRICKS_LOG_EXECUTION_CANCELLED_TIME,Execution cancelled in {time} seconds: {reason},Execution cancelled in {time} seconds: {reason}
BRICKS_LOG_EXECUTION_COMPLETED_TIME,Execution completed in {time} seconds,Execution completed in {time} seconds
BRICKS_LOG_EXECUTION_TIME_NOTE, (包含指令初始化开销，实际等待时间可能略短), (includes instruction initialization overhead, actual wait time may be shorter)
BRICKS_LOG_ACTION_RUNNER_COMPLETED,ActionRunner 执行完成,ActionRunner execution completed
BRICKS_LOG_INSTRUCTION_ADDED,Added instruction at position {position}: {description},Added instruction at position {position}: {description}
BRICKS_LOG_INSTRUCTION_REMOVED,Removed instruction at position {position}: {description},Removed instruction at position {position}: {description}
BRICKS_LOG_CLEARED_ALL_INSTRUCTIONS,Cleared all instructions,Cleared all instructions
BRICKS_LOG_INSTRUCTION_COUNT_SET,设置跳过指令数量: {count},Set skip instruction count: {count}
BRICKS_LOG_STOP_EXECUTION_SET,设置停止执行: {stop} (原因: {reason}),Set stop execution: {stop} (reason: {reason})
BRICKS_LOG_ACTION_RUNNER_RESET,ActionRunner reset,ActionRunner reset
BRICKS_LOG_VALIDATION_CACHE_CLEARED,Validation cache cleared,Validation cache cleared
BRICKS_ERROR_EXECUTION_FAILED_RUNNER_RUNNING,执行失败 - ActionRunner 正在运行,Execution failed - ActionRunner is already running
BRICKS_LOG_BATCH_EXECUTION_COMPLETE,批量执行完成: 成功 {success}/{total}, 总时间: {time} 秒, 平均时间: {avg} 秒,Batch execution complete: success {success}/{total}, total time: {time}s, avg time: {avg}s
BRICKS_LOG_BATCH_INSTRUCTION_VALIDATION_COMPLETE,批量指令验证完成: 有效 {valid}/{total}, 无效 {invalid}/{total},Batch instruction validation complete: valid {valid}/{total}, invalid {invalid}/{total}
BRICKS_LOG_BATCH_GET_INSTRUCTION_INFO_COMPLETE,批量获取指令信息完成: 获取了 {count} 个指令的信息,Batch get instruction info complete: got info for {count} instructions
BRICKS_LOG_BATCH_ADD_INSTRUCTION_COMPLETE,批量添加指令完成: 成功 {added}/{total}, 失败 {failed}/{total},Batch add instruction complete: success {added}/{total}, failed {failed}/{total}
BRICKS_LOG_ALL_PARALLEL_TASKS_COMPLETED,All parallel tasks completed,All parallel tasks completed
BRICKS_LOG_DEBUG_MODE_ENABLED,调试模式已启用,Debug mode enabled
BRICKS_LOG_DEBUG_MODE_DISABLED,调试模式已禁用,Debug mode disabled
```

**Step 2: 验证 CSV 格式正确性**

Run: 检查 CSV 文件确保每行都是 `key,zh_CN,en_US` 格式
Expected: 所有新增行格式正确

**Step 3: 提交更改**

```bash
git add addons/bricks/localization/translations.csv
git commit -m "feat(i18n): add ActionRunner localization keys to CSV"
```

---

### Task 14: 批量替换 action_runner.gd 中的硬编码字符串（第 1 部分）

**文件:**
- Modify: `addons/bricks/core/base/action_runner.gd:14-106`

**Step 1: 替换 setter 中的日志（第 14、19、24、32、37 行）**

找到第 14 行：
```gdscript
_log_debug("Instructions updated (%d instructions)" % value.size())
```
替换为：
```gdscript
_log_debug("Instructions updated ({count} instructions)")  # 保持英文，这是内部调试消息
```

找到第 19 行：
```gdscript
_log_debug("Execution mode set to: %s" % ExecutionMode.keys()[value])
```
保持原样（英文内部调试消息）

找到第 24、32、37 行类似的调试日志：
保持原样或改为英文（内部调试消息可以不本地化）

**Step 2: 替换 run() 方法中的关键错误（第 86、87 行）**

找到第 86 行：
```gdscript
context.print_warning("ActionRunner is already running")
```
保持原样（已经是英文）

找到第 87 行：
```gdscript
_create_bricks_error("ActionRunner 已经在运行", BricksError.ErrorType.EXECUTION_ERROR)
```
替换为：
```gdscript
_create_bricks_error_localized("BRICKS_ERROR_ACTION_RUNNER_ALREADY_RUNNING", BricksError.ErrorType.EXECUTION_ERROR)
```

**Step 3: 替换 run() 方法中的启动日志（第 104-105 行）**

找到第 104 行：
```gdscript
_log_debug("Starting execution with %d instructions" % instructions.size())
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_STARTING_EXECUTION", {"count": instructions.size()})
```

找到第 105 行：
```gdscript
context.print_message("Starting execution with %d instructions" % instructions.size())
```
替换为：
```gdscript
context.print_message(BricksLocalization.translate_format("BRICKS_LOG_STARTING_EXECUTION", {"count": instructions.size()}))
```

**Step 4: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 5: 提交更改**

```bash
git add addons/bricks/core/base/action_runner.gd
git commit -m "fix(action_runner): localize error messages in run method"
```

---

### Task 15: 批量替换 action_runner.gd 中的硬编码字符串（第 2 部分）

**文件:**
- Modify: `addons/bricks/core/base/action_runner.gd:126-206`

**Step 1: 替换 stop() 和 cancel_execution() 中的日志（第 128、136、140、145 行）**

找到第 128 行：
```gdscript
_log_debug("Execution stopped by request")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_EXECUTION_STOPPED_BY_REQUEST")
```

找到第 136 行：
```gdscript
_log_debug("Cannot cancel: ActionRunner is not running")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_CANNOT_CANCEL_NOT_RUNNING")
```

找到第 140 行：
```gdscript
_log_debug("Already canceling execution")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_ALREADY_CANCELLING")
```

找到第 145 行：
```gdscript
_log_debug("Canceling execution: %s" % reason)
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_CANCELLING_EXECUTION", {"reason": reason})
```

**Step 2: 替换 validate_instructions() 中的错误（第 172-173、179-180、191-192 行）**

找到第 172-173 行：
```gdscript
_log_error("Too many instructions: %d (max: %d)" % [instructions.size(), MAX_INSTRUCTIONS])
_create_bricks_error("指令数量过多: %d (最大: %d)" % [instructions.size(), MAX_INSTRUCTIONS], BricksError.ErrorType.VALIDATION_ERROR)
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_TOO_MANY_INSTRUCTIONS", {"count": instructions.size(), "max": MAX_INSTRUCTIONS})
_create_bricks_error_localized("BRICKS_ERROR_TOO_MANY_INSTRUCTIONS", BricksError.ErrorType.VALIDATION_ERROR, {"count": instructions.size(), "max": MAX_INSTRUCTIONS})
```

找到第 179-180 行：
```gdscript
_log_error("Instruction at index %d is null" % i)
_create_bricks_error("索引 %d 处的指令为空" % i, BricksError.ErrorType.VALIDATION_ERROR)
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_INSTRUCTION_AT_INDEX_NULL", {"index": i})
_create_bricks_error_localized("BRICKS_ERROR_INSTRUCTION_AT_INDEX_NULL", BricksError.ErrorType.VALIDATION_ERROR, {"index": i})
```

找到第 191-192 行：
```gdscript
_log_error("Instruction validation failed at index %d: %s" % [i, ", ".join(errors)])
_create_bricks_error("指令验证失败 (索引 %d): %s" % [i, ", ".join(errors)], BricksError.ErrorType.VALIDATION_ERROR)
```
替换为：
```gdscript
_log_error_localized("BRICKS_ERROR_INSTRUCTION_VALIDATION_FAILED", {"index": i, "errors": ", ".join(errors)})
_create_bricks_error_localized("BRICKS_ERROR_INSTRUCTION_VALIDATION_FAILED", BricksError.ErrorType.VALIDATION_ERROR, {"index": i, "errors": ", ".join(errors)})
```

**Step 3: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 4: 提交更改**

```bash
git add addons/bricks/core/base/action_runner.gd
git commit -m "fix(action_runner): localize log messages in stop and validation"
```

---

### Task 16: 批量替换 action_runner.gd 中的硬编码字符串（第 3 部分）

**文件:**
- Modify: `addons/bricks/core/base/action_runner.gd:200-294`

**Step 1: 替换 _run_sequential() 中的日志（第 200、206、211、218、229-230、269、282-283 行）**

找到第 200 行：
```gdscript
_log_debug("Starting sequential execution")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_STARTING_SEQUENTIAL_EXECUTION")
```

找到第 206 行：
```gdscript
_log_debug("跳过指令 %d (剩余跳过: %d)" % [i, _skip_instruction_count])
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_SKIPPING_INSTRUCTION", {"index": i, "remaining": _skip_instruction_count})
```

找到第 211 行：
```gdscript
_log_debug("停止执行: %s" % _stop_reason)
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_STOP_EXECUTION", {"reason": _stop_reason})
```

找到第 218、221 行：
```gdscript
_log_debug("Execution cancelled: %s" % cancellation_reason)
# 或
_log_debug("Execution stopped")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_EXECUTION_CANCELLED", {"reason": cancellation_reason})
# 或
_log_debug_localized("BRICKS_LOG_EXECUTION_STOP")
```

找到第 229-230 行：
```gdscript
_log_debug("Executing instruction %d/%d: %s" % [i + 1, instructions.size(), instruction.get_description()])
context.print_message("Executing instruction %d/%d: %s" % [i + 1, instructions.size(), instruction.get_description()])
```
替换为：
```gdscript
var args = {"current": i + 1, "total": instructions.size(), "description": instruction.get_description()}
_log_debug_localized("BRICKS_LOG_EXECUTING_INSTRUCTION", args)
context.print_message(BricksLocalization.translate_format("BRICKS_LOG_EXECUTING_INSTRUCTION", args))
```

找到第 269 行：
```gdscript
_log_debug("异步指令完成: %.3f 秒" % instruction_time)
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_ASYNC_INSTRUCTION_COMPLETED", {"time": "%.3f" % instruction_time})
```

找到第 282-283 行：
```gdscript
_log_debug("Stopping execution due to instruction error: %s" % instruction.get_error_message())
_create_bricks_error("指令执行失败: %s" % instruction.get_error_message(), ...)
```
替换为：
```gdscript
var error_msg = instruction.get_error_message()
_log_debug_localized("BRICKS_LOG_STOPPING_DUE_TO_ERROR", {"error": error_msg})
_create_bricks_error_localized("BRICKS_ERROR_INSTRUCTION_EXECUTION_FAILED", BricksError.ErrorType.EXECUTION_ERROR, {"error": error_msg}, {...})
```

**Step 2: 替换完成日志（第 294 行）**

找到第 294 行：
```gdscript
_log_debug("Sequential execution completed")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_SEQUENTIAL_EXECUTION_COMPLETED")
```

**Step 3: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 4: 提交更改**

```bash
git add addons/bricks/core/base/action_runner.gd
git commit -m "fix(action_runner): localize log messages in _run_sequential"
```

---

### Task 17: 批量替换 action_runner.gd 中的硬编码字符串（第 4 部分 - _run_parallel）

**文件:**
- Modify: `addons/bricks/core/base/action_runner.gd:322-402`

**Step 1: 替换 _run_parallel() 中的日志（第 322、334、337、340、353、363-364、369、376 行）**

找到第 322 行：
```gdscript
_log_debug("Starting parallel execution")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_STARTING_PARALLEL_EXECUTION")
```

找到第 334 行：
```gdscript
_log_debug("Execution cancelled during parallel task creation: %s" % cancellation_reason)
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_EXECUTION_CANCELLED_DURING_PARALLEL", {"reason": cancellation_reason})
```

找到第 337 行：
```gdscript
_log_debug("Execution stopped during parallel task creation")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_EXECUTION_STOPPED_DURING_PARALLEL")
```

找到第 340 行：
```gdscript
_log_debug("Starting parallel instruction: %s" % instruction.get_description())
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_STARTING_PARALLEL_INSTRUCTION", {"description": instruction.get_description()})
```

找到第 353 行：
```gdscript
_log_debug("Parallel execution started %d tasks" % tasks.size())
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_PARALLEL_EXECUTION_STARTED", {"count": tasks.size()})
```

找到第 363-364 行：
```gdscript
errors.append("Instruction %d failed: %s" % [i, instruction.get_error_message()])
_log_error("Parallel instruction %d failed: %s" % [i, instruction.get_error_message()])
```
替换为：
```gdscript
var error_msg = instruction.get_error_message()
errors.append("Instruction %d failed: %s" % [i, error_msg])  # 保留英文用于错误数组
_log_error_localized("BRICKS_LOG_PARALLEL_INSTRUCTION_FAILED", {"index": i, "error": error_msg})
```

找到第 369 行：
```gdscript
var error_message = "Parallel execution failed with %d errors: %s" % [errors.size(), ", ".join(errors)]
```
保持英文（用于错误信号）

找到第 369-370 行：
```gdscript
_create_bricks_error("并行执行失败，有 %d 个错误" % errors.size(), ...)
```
替换为：
```gdscript
_create_bricks_error_localized("BRICKS_ERROR_PARALLEL_EXECUTION_FAILED", BricksError.ErrorType.EXECUTION_ERROR, {"count": errors.size()}, {...})
```

找到第 376 行：
```gdscript
_log_debug("Parallel execution completed")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_PARALLEL_EXECUTION_COMPLETED")
```

**Step 2: 替换超时错误（第 393-396、401 行）**

找到第 393-396 行：
```gdscript
_log_error("执行超时: %.2f 秒 (限制: %.2f 秒, 指令数: %d)" % [elapsed, effective_timeout, instructions.size()])
_create_bricks_error("执行超时 (%.2f 秒)" % effective_timeout, ...)
```
替换为：
```gdscript
var args = {"elapsed": "%.2f" % elapsed, "timeout": "%.2f" % effective_timeout, "count": instructions.size()}
_log_error_localized("BRICKS_ERROR_EXECUTION_TIMEOUT", args)
_create_bricks_error_localized("BRICKS_ERROR_EXECUTION_TIMEOUT_FORMAT", BricksError.ErrorType.TIMEOUT_ERROR, {"timeout": effective_timeout}, args)
```

找到第 401 行：
```gdscript
execution_failed.emit("Execution timeout after %.2f seconds" % effective_timeout)
```
替换为：
```gdscript
execution_failed.emit(BricksLocalization.translate_format("BRICKS_ERROR_EXECUTION_TIMEOUT_AFTER", {"timeout": effective_timeout}))
```

**Step 3: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 4: 提交更改**

```bash
git add addons/bricks/core/base/action_runner.gd
git commit -m "fix(action_runner): localize log messages in _run_parallel and timeout"
```

---

### Task 18: 替换 action_runner.gd 中剩余的硬编码字符串

**文件:**
- Modify: `addons/bricks/core/base/action_runner.gd:410-492`

**Step 1: 替换信号连接相关日志（第 411、420 行）**

找到第 411 行：
```gdscript
_log_warning("无法连接信号：指令为空")
```
替换为：
```gdscript
_log_warning_localized("BRICKS_WARNING_CANNOT_CONNECT_SIGNAL_INSTRUCTION_NULL")
```

找到第 420 行：
```gdscript
_log_debug("已连接指令 '%s' 的 finished 信号" % instruction.get_name())
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_CONNECTED_INSTRUCTION_SIGNAL", {"name": instruction.get_name()})
```

**Step 2: 替换 _complete_execution() 中的日志（第 472、476、480-481、486 行）**

找到第 472 行：
```gdscript
_log_debug("Execution cancelled in %.3f seconds: %s" % [total_time, cancellation_reason])
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_EXECUTION_CANCELLED_TIME", {"time": "%.3f" % total_time, "reason": cancellation_reason})
```

找到第 476 行：
```gdscript
_log_debug("Execution completed in %.3f seconds" % total_time)
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_EXECUTION_COMPLETED_TIME", {"time": "%.3f" % total_time})
```

找到第 480 行：
```gdscript
note = " (包含指令初始化开销，实际等待时间可能略短)"
```
替换为：
```gdscript
note = BricksLocalization.translate("BRICKS_LOG_EXECUTION_TIME_NOTE")
```

**Step 3: 替换其他方法和调试模式日志（第 664、672、701、707、760、763、796-799、814、866、869、882、920、928 行）**

找到第 664 行：
```gdscript
_log_debug("设置跳过指令数量: %d" % _skip_instruction_count)
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_INSTRUCTION_COUNT_SET", {"count": _skip_instruction_count})
```

找到第 672 行：
```gdscript
_log_debug("设置停止执行: %s (原因: %s)" % [stop, reason])
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_STOP_EXECUTION_SET", {"stop": stop, "reason": reason})
```

找到第 701 行：
```gdscript
_log_debug("ActionRunner reset")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_ACTION_RUNNER_RESET")
```

找到第 707 行：
```gdscript
_log_debug("Validation cache cleared")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_VALIDATION_CACHE_CLEARED")
```

找到第 760-763 行：
```gdscript
_log_debug("批量执行完成: 成功 %d/%d, 总时间: %.3f 秒, 平均时间: %.3f 秒" % [...])
```
替换为：
```gdscript
var args = {"success": results["success_count"], "total": results["total"], "time": "%.3f" % total_time, "avg": "%.3f" % avg_time}
_log_debug_localized("BRICKS_LOG_BATCH_EXECUTION_COMPLETE", args)
```

找到第 796-799 行：
```gdscript
_log_debug("批量指令验证完成: 有效 %d/%d, 无效 %d/%d" % [...])
```
替换为：
```gdscript
var args = {"valid": results["valid_count"], "total": results["total"], "invalid": results["invalid_count"]}
_log_debug_localized("BRICKS_LOG_BATCH_INSTRUCTION_VALIDATION_COMPLETE", args)
```

找到第 814 行：
```gdscript
_log_debug("批量获取指令信息完成: 获取了 %d 个指令的信息" % results.size())
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_BATCH_GET_INSTRUCTION_INFO_COMPLETE", {"count": results.size()})
```

找到第 866-869 行：
```gdscript
_log_debug("批量添加指令完成: 成功 %d/%d, 失败 %d/%d" % [...])
```
替换为：
```gdscript
var args = {"added": results["added_count"], "total": results["total"], "failed": results["failed_count"]}
_log_debug_localized("BRICKS_LOG_BATCH_ADD_INSTRUCTION_COMPLETE", args)
```

找到第 882 行：
```gdscript
_log_debug("All parallel tasks completed")
```
替换为：
```gdscript
_log_debug_localized("BRICKS_LOG_ALL_PARALLEL_TASKS_COMPLETED")
```

找到第 920 行：
```gdscript
_log_info("调试模式已启用")
```
替换为：
```gdscript
_log_info_localized("BRICKS_LOG_DEBUG_MODE_ENABLED")
```

找到第 928 行：
```gdscript
_log_info("调试模式已禁用")
```
替换为：
```gdscript
_log_info_localized("BRICKS_LOG_DEBUG_MODE_DISABLED")
```

**Step 4: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 5: 提交更改**

```bash
git add addons/bricks/core/base/action_runner.gd
git commit -m "fix(action_runner): localize remaining log messages"
```

---

### Task 19: 添加 ActionRunner 的 _create_bricks_error_localized 方法

**文件:**
- Modify: `addons/bricks/core/base/action_runner.gd`

**Step 1: 在 _create_bricks_error 方法后添加本地化版本**

在第 893 行后（`_create_bricks_error` 方法后）添加：

```gdscript
## 创建 BricksError 实例（本地化版本）
## message_key: String - 错误消息翻译键
## error_type: BricksError.ErrorType - 错误类型
## args: Dictionary - 翻译参数
## context: Dictionary - 错误上下文
func _create_bricks_error_localized(message_key: String, error_type: BricksError.ErrorType = BricksError.ErrorType.RUNTIME_ERROR, args: Dictionary = {}, context: Dictionary = {}):
	var message = BricksLocalization.translate_format(message_key, args)
	_create_bricks_error(message, error_type, context)
```

**Step 2: 验证语法正确性**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 3: 提交更改**

```bash
git add addons/bricks/core/base/action_runner.gd
git commit -m "feat(action_runner): add _create_bricks_error_localized helper method"
```

---

## 阶段 4: 验证和测试

### Task 20: 运行翻译完整性检查

**文件:**
- Run: `addons/bricks/localization/translation_checker.gd`

**Step 1: 在 Godot 编辑器中运行翻译检查工具**

1. 打开 Godot 编辑器
2. 点击菜单：**项目 → 工具 → 执行脚本**
3. 选择文件：`addons/bricks/localization/translation_checker.gd`
4. 查看控制台输出

**Step 2: 验证检查结果**

Expected output 包含：
- 翻译键总数（应该增加了约 100+ 个新键）
- 分类统计（应该包含 Trigger、ExecutionContext、ActionRunner）
- 翻译完整性（应该 100%）
- 覆盖率（应该覆盖所有核心类）
- 命名规范检查（应该无错误）

**Step 3: 如有错误，记录并修复**

如果有缺失的翻译键或格式错误，返回相应的 Task 修复。

---

### Task 21: 功能测试 - Trigger 本地化

**测试场景:** 在编辑器中创建 Trigger 并验证本地化

**Step 1: 创建测试场景**

在 `demos/bricks_juicy_demo.tscn` 中：
1. 添加一个 Trigger 节点
2. 不配置 Event Definition
3. 观察控制台输出

**Expected Output:** 应该显示本地化后的错误消息（根据当前语言设置）

**Step 2: 配置 Event 并测试**

1. 配置一个简单的 Event Definition
2. 运行场景
3. 观察控制台输出

**Expected Output:** 应该显示本地化的初始化和触发消息

**Step 3: 切换语言测试**

修改 `project.godot`：
```ini
[internationalization]
locale/locale="en"  # 切换到英语
```

重新运行场景，验证英文消息正确显示。

---

### Task 22: 功能测试 - ExecutionContext 本地化

**测试场景:** 通过指令测试 ExecutionContext 的本地化

**Step 1: 创建测试指令**

创建一个简单的测试指令，使用变量：
```gdscript
extends BaseInstruction

func execute(context: ExecutionContext):
    _start_execution(context)

    # 测试变量操作
    context.set_variable("test_var", 123)
    var value = context.get_variable("test_var", 0)

    _log_info_localized("BRICKS_LOG_ADDED_LOCAL_VARIABLE", {"name": "test_var", "value": str(value), "type": "int"})

    finished.emit()
    _on_execution_completed()
```

**Step 2: 在 ActionRunner 中测试**

1. 创建 ActionRunner 资源
2. 添加测试指令
3. 运行并观察控制台

**Expected Output:** 应该显示本地化的变量操作消息

**Step 3: 测试错误场景**

1. 测试无效节点路径
2. 测试未找到的变量
3. 验证错误消息本地化

---

### Task 23: 功能测试 - ActionRunner 本地化

**测试场景:** 测试 ActionRunner 的完整本地化

**Step 1: 测试顺序执行**

创建包含多个指令的 ActionRunner：
- 3-5 个简单的 Print 指令
- 运行并观察控制台

**Expected Output:** 应该显示本地化的执行进度消息

**Step 2: 测试错误处理**

1. 创建一个会失败的指令
2. 启用 `stop_on_error`
3. 运行并观察错误消息

**Expected Output:** 应该显示本地化的错误消息

**Step 3: 测试超时**

1. 设置 `enable_instruction_timeout = true`
2. 设置 `instruction_timeout = 1.0`
3. 创建一个耗时长的指令
4. 运行并观察超时消息

**Expected Output:** 应该显示本地化的超时错误

---

### Task 24: 性能基准测试

**文件:**
- Run: `test_scripts/performance_localization_benchmark.gd`

**Step 1: 运行性能基准测试**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --script test_scripts/performance_localization_benchmark.gd`

**Step 2: 对比结果**

对比本地化前后的性能数据：
- 初始化时间
- 翻译查询时间
- 内存占用

**Expected:** 性能影响应该小于 5%（符合 README.md 中的规格）

---

### Task 25: 文档更新

**文件:**
- Modify: `addons/bricks/localization/README.md`
- Modify: `addons/bricks/localization/translation_keys.md` (如果存在)

**Step 1: 更新 README.md 中的统计信息**

找到第 11 行：
```markdown
- ✅ **完整覆盖**: 298+ 翻译键，100% 覆盖率
```
更新为：
```markdown
- ✅ **完整覆盖**: 400+ 翻译键，100% 覆盖率（Trigger、ExecutionContext、ActionRunner 已完全本地化）
```

**Step 2: 添加核心类本地化说明**

在 README.md 中添加新章节：

```markdown
### 核心类本地化状态

以下核心类已完成本地化：

- ✅ **Trigger** - 触发器核心类（所有日志、错误、验证消息）
- ✅ **ExecutionContext** - 执行上下文类（所有变量操作、节点访问消息）
- ✅ **ActionRunner** - 动作运行器类（所有执行流程、错误处理消息）

这些核心类使用 `_log_*_localized()` 方法输出本地化消息，遵循统一的本地化规范。
```

**Step 3: 提交文档更新**

```bash
git add addons/bricks/localization/README.md
git commit -m "docs(i18n): update localization status for core classes"
```

---

## 最终验证

### Task 26: 最终代码审查和提交

**Step 1: 检查所有修改**

Run: `git status`
Expected: 所有修改的文件都应该已提交

**Step 2: 检查翻译键数量**

Run: `grep -c "^BRICKS_" addons/bricks/localization/translations.csv`
Expected: 应该比原始数量多约 100+ 个翻译键

**Step 3: 生成提交摘要**

查看最近的提交：
```bash
git log --oneline --graph -20
```

**Step 4: 创建总结文档**

创建 `docs/plans/2026-01-31-core-classes-localization-summary.md`：

```markdown
# 核心类本地化完成总结

## 实施内容

### 已本地化的类
1. Trigger (16 处硬编码字符串)
2. ExecutionContext (20+ 处硬编码字符串)
3. ActionRunner (25+ 处硬编码字符串)

### 新增翻译键
- Trigger: 15 个键
- ExecutionContext: 42 个键
- ActionRunner: 48 个键
- 总计: 105 个新翻译键

### 新增方法
- `Trigger._log_*_localized()` - 本地化日志方法
- `Trigger._create_bricks_error_localized()` - 本地化错误创建
- `ExecutionContext._log_*_localized()` - 本地化日志方法
- `ActionRunner._create_bricks_error_localized()` - 本地化错误创建

## 测试验证
- ✅ 翻译完整性检查通过
- ✅ 功能测试通过（Trigger、ExecutionContext、ActionRunner）
- ✅ 中英文切换测试通过
- ✅ 性能基准测试通过（影响 < 5%）

## 提交统计
- 总提交数: 26 个
- 修改文件数: 4 个（trigger.gd, execution_context.gd, action_runner.gd, translations.csv）
- 新增代码行: ~200 行
```

**Step 5: 最终提交**

```bash
git add docs/plans/2026-01-31-core-classes-localization-summary.md
git commit -m "docs(i18n): add core classes localization completion summary"
```

---

## 实施注意事项

### 关键原则

1. **不破坏现有功能**: 所有修改仅替换字符串，不改变逻辑
2. **保持向后兼容**: 保留 `_log_*()` 方法，新增 `_log_*_localized()` 方法
3. **本地化所有用户可见文本**: 错误消息、日志消息、验证消息
4. **内部调试消息可以不本地化**: 如 "Instructions updated" 这类纯调试信息

### 常见错误和解决方案

**错误 1:** `Translation key not found`
- **原因:** 翻译键未添加到 CSV
- **解决:** 检查 CSV 文件，确保键存在且格式正确

**错误 2:** `Invalid argument count for translate_format`
- **原因:** 参数字典与翻译模板不匹配
- **解决:** 确保模板中的 `{param}` 与 args 字典键一致

**错误 3:** 语法错误
- **原因:** 字符串格式化语法错误
- **解决:** 检查 `%` 格式化是否正确替换为 `{"key": value}` 格式

### 性能优化提示

根据 README.md，本地化系统已优化：
- 静态缓存：翻译数据首次加载后缓存
- 性能提升：70% 比动态翻译
- 查询时间：0.12μs/次
- 内存占用：~30KB (298 个键)

新增 105 个键后预计内存占用：~35KB，仍然非常轻量。

---

## 计划完成检查清单

- [ ] Task 0: 验证本地化系统状态
- [ ] Task 1-6: Trigger 类本地化完成
- [ ] Task 7-11: ExecutionContext 类本地化完成
- [ ] Task 12-19: ActionRunner 类本地化完成
- [ ] Task 20: 翻译完整性检查通过
- [ ] Task 21-23: 功能测试全部通过
- [ ] Task 24: 性能基准测试通过
- [ ] Task 25: 文档更新完成
- [ ] Task 26: 最终审查和提交

**预计完成时间:** 2-3 小时（包含测试）
**预计翻译键增量:** +105 个键
**预计提交数:** 26 个提交

---

**计划版本:** 1.0
**创建日期:** 2026-01-31
**作者:** Claude (using writing-plans skill)
**状态:** Ready for execution
