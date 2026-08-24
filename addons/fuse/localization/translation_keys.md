# Fuse 翻译键参考文档

> **最后更新**: 2026-01-25
> **翻译键总数**: 298个
> **支持语言**: 中文（zh_CN）、英文（en_US）

## 目录

- [使用指南](#使用指南)
- [翻译键分类](#翻译键分类)
- [翻译键列表](#翻译键列表)
  - [指令（FUSE_INSTRUCTION_）](#指令fuseinstruction_)
  - [指令分类（FUSE_CATEGORY_）](#指令分类fusecategory_)
  - [事件（FUSE_EVENT_）](#事件fuse_event_)
  - [事件分类（FUSE_EVENT_CATEGORY_）](#事件分类fuse_event_category_)
  - [错误消息（FUSE_ERROR_）](#错误消息fuseerror_)
  - [UI文本（FUSE_UI_）](#ui文本fuseui_)
  - [日志消息（FUSE_LOG_）](#日志消息fuselog_)
  - [日志级别（FUSE_LOG_LEVEL_）](#日志级别fuseloglevel_)
  - [插件相关（FUSE_PLUGIN_）](#插件相关fuseplugin_)
  - [变量作用域（FUSE_VARIABLE_SCOPE_）](#变量作用域fusevariable_)
  - [变量类型（FUSE_TYPE_）](#变量类型fuse_type_)
- [命名规范](#命名规范)
- [使用示例](#使用示例)
- [维护指南](#维护指南)

## 使用指南

### 如何使用翻译键

```gdscript
# 简单翻译
var message = FuseLocalization.translate("FUSE_LOG_DEBUG_MESSAGE")

# 参数化翻译
var message = FuseLocalization.translate_format("FUSE_LOG_PRINT_MESSAGE", {"text": "Hello"})

# 在指令中使用
static func get_metadata() -> Dictionary:
	return {
		"category": FuseLocalization.translate("FUSE_CATEGORY_DEBUG"),
		"label": FuseLocalization.translate("FUSE_INSTRUCTION_PRINT_NAME")
	}
```

### 添加新翻译键

1. 在 `translations.csv` 中添加新行
2. 遵循命名规范（见[命名规范](#命名规范)）
3. 提供所有语言的翻译
4. 在本文档中记录新键

## 翻译键分类

| 类别 | 前缀 | 数量 | 用途 |
|------|------|------|------|
| 指令 | FUSE_INSTRUCTION_ | 22 | 指令元数据（名称、描述） |
| 指令分类 | FUSE_CATEGORY_ | 8 | 指令分类标签 |
| 事件 | FUSE_EVENT_ | 10 | 事件元数据 |
| 事件分类 | FUSE_EVENT_CATEGORY_ | 4 | 事件分类标签 |
| 错误消息 | FUSE_ERROR_ | 24 | 错误提示 |
| UI文本 | FUSE_UI_ | 141 | 编辑器UI |
| 日志消息 | FUSE_LOG_ | 72 | 日志输出 |
| 日志级别 | FUSE_LOG_LEVEL_ | 4 | 日志级别标签 |
| 插件相关 | FUSE_PLUGIN_ | 4 | 插件信息 |
| 变量作用域 | FUSE_VARIABLE_SCOPE_ | 2 | 变量作用域标签 |
| 变量类型 | FUSE_TYPE_ | 7 | 变量类型标签 |

## 翻译键列表

### 指令（FUSE_INSTRUCTION_）

#### 指令名称和描述

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_INSTRUCTION_PRINT_NAME | 打印消息 | Print Message | 打印指令名称 |
| FUSE_INSTRUCTION_PRINT_DESC | 打印消息到输出窗口和执行上下文 | Prints a message to the output window and execution context | 打印指令描述 |
| FUSE_INSTRUCTION_PRINT_VARIABLE_NAME | 打印变量值 | Print Variable Value | 打印变量指令名称 |
| FUSE_INSTRUCTION_PRINT_VARIABLE_DESC | 查找并打印变量的值到输出窗口和执行上下文 | Finds and prints a variable value to the output window and execution context | 打印变量指令描述 |
| FUSE_INSTRUCTION_SET_VARIABLE_NAME | 设置变量 | Set Variable | 设置变量指令名称 |
| FUSE_INSTRUCTION_SET_VARIABLE_DESC | 设置变量的值，支持从另一个变量复制值或直接设置新值 | Sets the value of a variable, supports copying from another variable or setting a new value | 设置变量指令描述 |
| FUSE_INSTRUCTION_CREATE_VARIABLE_NAME | 创建变量 | Create Variable | 创建变量指令名称 |
| FUSE_INSTRUCTION_CREATE_VARIABLE_DESC | 创建一个新变量并设置初始值 | Creates a new variable and sets its initial value | 创建变量指令描述 |
| FUSE_INSTRUCTION_WAIT_NAME | 等待 | Wait | 等待指令名称 |
| FUSE_INSTRUCTION_WAIT_DESC | 等待指定时间（秒） | Waits for a specified duration (seconds) | 等待指令描述 |
| FUSE_INSTRUCTION_WAIT_FOR_SIGNAL_NAME | 等待信号 | Wait For Signal | 等待信号指令名称 |
| FUSE_INSTRUCTION_WAIT_FOR_SIGNAL_DESC | 暂停执行直到目标节点发出指定信号，信号参数以 event_ 前缀局部变量暴露；超时失败终止 | Pauses execution until the target node emits the specified signal; signal args exposed as event_* local variables; fails on timeout | 等待信号指令描述 |
| FUSE_INSTRUCTION_COUNT_NAME | 计数 | Count | 计数指令名称 |
| FUSE_INSTRUCTION_COUNT_DESC | 一个计数指令，用于演示如何维护状态和多次执行 | A counting instruction to demonstrate state maintenance and multiple execution | 计数指令描述 |
| FUSE_INSTRUCTION_QUIT_NAME | 退出应用程序 | Quit Application | 退出指令名称 |
| FUSE_INSTRUCTION_QUIT_DESC | 退出当前运行的应用程序 | Quits the currently running application | 退出指令描述 |
| FUSE_INSTRUCTION_RUN_CONDITION_CHECK_NAME | 运行条件检查 | Run Condition Check | 条件检查指令名称 |
| FUSE_INSTRUCTION_RUN_CONDITION_CHECK_DESC | 评估条件并根据结果执行不同的操作 | Evaluates a condition and performs different actions based on the result | 条件检查指令描述 |
| FUSE_INSTRUCTION_SET_INT_VARIABLE_NAME | 设置整数变量 | Set Int Variable | 设置整数变量指令名称 |
| FUSE_INSTRUCTION_SET_INT_VARIABLE_DESC | 设置整数类型变量的值 | Sets the value of an integer variable | 设置整数变量指令描述 |
| FUSE_INSTRUCTION_SET_PROPERTY_VALUE_NAME | 设置属性值 | Set Property Value | 设置属性值指令名称 |
| FUSE_INSTRUCTION_SET_PROPERTY_VALUE_DESC | 设置节点属性的值 | Sets the value of a node property | 设置属性值指令描述 |
| FUSE_INSTRUCTION_RUN_TARGET_NODE_FUNCTION_NAME | 运行节点函数 | Run Node Function | 运行节点函数指令名称 |
| FUSE_INSTRUCTION_RUN_TARGET_NODE_FUNCTION_DESC | 调用目标节点的指定函数 | Calls a specified function on the target node | 运行节点函数指令描述 |

### 指令分类（FUSE_CATEGORY_）

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_CATEGORY_DEBUG | 调试 | Debug | 调试分类 |
| FUSE_CATEGORY_VARIABLES | 变量 | Variables | 变量分类 |
| FUSE_CATEGORY_FLOW_CONTROL | 流程控制 | Flow Control | 流程控制分类 |
| FUSE_CATEGORY_NODE_OPERATIONS | 节点操作 | Node Operations | 节点操作分类 |
| FUSE_CATEGORY_LOGIC | 逻辑 | Logic | 逻辑分类 |
| FUSE_CATEGORY_MATH | 数学 | Math | 数学分类 |
| FUSE_CATEGORY_INPUT | 输入 | Input | 输入分类 |
| FUSE_CATEGORY_SYSTEM | 系统 | System | 系统分类 |

### 事件（FUSE_EVENT_）

#### 事件名称和描述

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_EVENT_ON_READY_NAME | 场景就绪 | Scene Ready | 场景就绪事件名称 |
| FUSE_EVENT_ON_READY_DESC | 场景就绪时触发（可选延迟） | Triggers when the scene is ready (optional delay) | 场景就绪事件描述 |
| FUSE_EVENT_ON_AREA_2D_ENTER_NAME | 区域进入 | Area Entered | 区域进入事件名称 |
| FUSE_EVENT_ON_AREA_2D_ENTER_DESC | 当物体进入 2D 区域时触发 | Triggers when an object enters a 2D area | 区域进入事件描述 |
| FUSE_EVENT_ON_INPUT_KEY_NAME | 按键输入 | Key Input | 按键输入事件名称 |
| FUSE_EVENT_ON_INPUT_KEY_DESC | 当按下指定按键时触发 | Triggers when a specified key is pressed | 按键输入事件描述 |
| FUSE_EVENT_ON_INPUT_ACTION_NAME | 动作输入 | Action Input | 动作输入事件名称 |
| FUSE_EVENT_ON_INPUT_ACTION_DESC | 当输入动作被触发时触发 | Triggers when an input action is triggered | 动作输入事件描述 |
| FUSE_EVENT_ON_TARGET_SIGNAL_EMIT_NAME | 目标信号发出 | Target Signal Emitted | 信号发出事件名称 |
| FUSE_EVENT_ON_TARGET_SIGNAL_EMIT_DESC | 当目标节点发出指定信号时触发 | Triggers when the target node emits a specified signal | 信号发出事件描述 |

### 事件分类（FUSE_EVENT_CATEGORY_）

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_EVENT_CATEGORY_SCENE | 场景 | Scene | 场景分类 |
| FUSE_EVENT_CATEGORY_INPUT | 输入 | Input | 输入分类 |
| FUSE_EVENT_CATEGORY_PHYSICS | 物理 | Physics | 物理分类 |
| FUSE_EVENT_CATEGORY_SIGNAL | 信号 | Signal | 信号分类 |

### 错误消息（FUSE_ERROR_）

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_ERROR_MESSAGE_EMPTY | 消息内容不能为空 | Message content cannot be empty | 消息验证错误 |
| FUSE_ERROR_VAR_NAME_EMPTY | 变量名称不能为空 | Variable name cannot be empty | 变量名验证错误 |
| FUSE_ERROR_VAR_NOT_FOUND | 未找到变量：{name} | Variable '{name}' not found | 变量不存在错误 |
| FUSE_ERROR_VAR_ALREADY_EXISTS | 变量已存在：{name} | Variable already exists: {name} | 变量重复错误 |
| FUSE_ERROR_VAR_TYPE_MISMATCH | 变量类型不匹配，期望：{expected}，实际：{actual} | Variable type mismatch, expected: {expected}, actual: {actual} | 变量类型错误 |
| FUSE_ERROR_EXECUTION_FAILED | 指令执行失败：{error} | Instruction execution failed: {error} | 执行失败错误 |
| FUSE_ERROR_VALIDATION_FAILED | 参数验证失败 | Parameter validation failed | 验证失败错误 |
| FUSE_ERROR_CONFIG_ERROR | 配置错误 | Configuration error | 配置错误 |
| FUSE_ERROR_RUNTIME_ERROR | 运行时错误 | Runtime error | 运行时错误 |
| FUSE_ERROR_TIMEOUT_ERROR | 超时错误 | Timeout error | 超时错误 |
| FUSE_ERROR_TARGET_NODE_NULL | 目标节点为空 | Target node is null | 目标节点为空 |
| FUSE_ERROR_TARGET_NODE_NOT_FOUND | 未找到目标节点 | Target node not found | 目标节点不存在 |
| FUSE_ERROR_FUNCTION_NOT_FOUND | 未找到函数：{name} | Function not found: {name} | 函数不存在 |
| FUSE_ERROR_PROPERTY_NOT_FOUND | 未找到属性：{name} | Property not found: {name} | 属性不存在 |
| FUSE_ERROR_PROPERTY_READ_ONLY | 属性是只读的 | Property is read-only | 属性只读 |
| FUSE_ERROR_INVALID_PARAMETER | 无效参数：{name} | Invalid parameter: {name} | 无效参数 |
| FUSE_ERROR_INDEX_OUT_OF_RANGE | 索引超出范围 | Index out of range | 索引错误 |
| FUSE_ERROR_INSTRUCTION_EXECUTION | 指令执行失败 | Instruction execution failed | 指令执行错误 |
| FUSE_ERROR_EVENT_INITIALIZATION | 事件初始化失败 | Event initialization failed | 事件初始化错误 |
| FUSE_ERROR_MISSING_PARAMETER | 缺少必需参数：{param} | Missing required parameter: {param} | 缺少参数 |
| FUSE_ERROR_INVALID_TARGET | 无效的目标节点 | Invalid target node | 无效目标 |
| FUSE_ERROR_PROPERTY_NOT_WRITABLE | 属性不可写 | Property is not writable | 属性不可写 |
| FUSE_ERROR_FUNCTION_CALL_FAILED | 函数调用失败 | Function call failed | 函数调用失败 |
| FUSE_ERROR_SIGNAL_NOT_FOUND | 未找到信号 | Signal not found | 信号不存在 |
| FUSE_ERROR_WAIT_FOR_SIGNAL_TIMEOUT | 等待信号超时 | Wait for signal timed out | 等待信号超时错误 |

### UI文本（FUSE_UI_）

#### 指令选择器

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_UI_INSTRUCTION_SELECTOR_TITLE | 指令选择器 | Instruction Selector | 选择器标题 |
| FUSE_UI_SEARCH_PLACEHOLDER | 搜索指令... | Search instructions... | 搜索框占位符 |
| FUSE_UI_NO_INSTRUCTIONS_FOUND | 未找到指令 | No instructions found | 无结果提示 |
| FUSE_UI_SELECT_INSTRUCTION | 选择指令 | Select Instruction | 选择按钮 |

#### 输入键选择器

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_UI_INPUT_KEY_SELECTOR_TITLE | 输入键选择器 | Input Key Selector | 选择器标题 |
| FUSE_UI_BTN_SELECT_KEY | 选择按键 | Select Key | 选择按键按钮 |
| FUSE_UI_KEY_LABEL | 按键 | Key | 按键标签 |
| FUSE_UI_INSTRUCTION_CLICK_TO_START | 点击下方按钮，然后按下任意键 | Click the button below, then press any key | 操作提示 |
| FUSE_UI_BTN_START_CAPTURE | 开始捕获按键 | Start Capturing Key | 开始捕获按钮 |
| FUSE_UI_WAITING_FOR_KEY | 请按下任意键... | Press any key... | 等待按键提示 |

#### 通用按钮

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_UI_BTN_ADD | 添加 | Add | 添加按钮 |
| FUSE_UI_BTN_REMOVE | 移除 | Remove | 移除按钮 |
| FUSE_UI_BTN_EDIT | 编辑 | Edit | 编辑按钮 |
| FUSE_UI_BTN_DELETE | 删除 | Delete | 删除按钮 |
| FUSE_UI_BTN_APPLY | 应用 | Apply | 应用按钮 |
| FUSE_UI_BTN_CANCEL | 取消 | Cancel | 取消按钮 |
| FUSE_UI_BTN_OK | 确定 | OK | 确定按钮 |
| FUSE_UI_BTN_YES | 是 | Yes | 是按钮 |
| FUSE_UI_BTN_NO | 否 | No | 否按钮 |
| FUSE_UI_BTN_SAVE | 保存 | Save | 保存按钮 |
| FUSE_UI_BTN_LOAD | 加载 | Load | 加载按钮 |
| FUSE_UI_BTN_RESET | 重置 | Reset | 重置按钮 |
| FUSE_UI_BTN_REFRESH | 刷新 | Refresh | 刷新按钮 |
| FUSE_UI_BTN_CLICK_TO_ADD_INSTRUCTION | 点击以添加指令... | Click to Add Instruction... | 添加指令按钮 |
| FUSE_UI_BTN_CLICK_TO_ADD_INSTRUCTION_TOOLTIP | 点击以添加指令... | Click to add instruction... | 添加指令提示 |
| FUSE_UI_BTN_CLEAR | 清除 | Clear | 清除按钮 |
| FUSE_UI_BTN_EXPORT | 导出 | Export | 导出按钮 |

#### 标签和提示

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_UI_LABEL_NAME | 名称 | Name | 名称标签 |
| FUSE_UI_LABEL_TYPE | 类型 | Type | 类型标签 |
| FUSE_UI_LABEL_VALUE | 值 | Value | 值标签 |
| FUSE_UI_LABEL_CATEGORY | 分类 | Category | 分类标签 |
| FUSE_UI_LABEL_DESCRIPTION | 描述 | Description | 描述标签 |
| FUSE_UI_LABEL_VARIABLES | 变量 | Variables | 变量标签 |
| FUSE_UI_LABEL_INSTRUCTIONS | 指令 | Instructions | 指令标签 |
| FUSE_UI_LABEL_EVENTS | 事件 | Events | 事件标签 |
| FUSE_UI_LABEL_CONDITIONS | 条件 | Conditions | 条件标签 |

#### 语言设置

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_UI_LANGUAGE_MENU | 🌐 语言 | Language | 语言菜单 |
| FUSE_UI_LANGUAGE_SETTINGS | 语言设置 | Language Settings | 语言设置 |

#### 调试可视化器

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_UI_DEBUG_AUTO_REFRESH | 自动刷新 | Auto Refresh | 自动刷新选项 |
| FUSE_UI_DEBUG_WELCOME_TITLE | 欢迎使用调试可视化工具 | Welcome to Debug Visualizer | 欢迎标题 |
| FUSE_UI_DEBUG_WELCOME_DESCRIPTION | 此工具可以帮助您： | This tool helps you: | 欢迎描述 |
| FUSE_UI_DEBUG_FEATURE_1 | 可视化指令执行流程 | Visualize instruction execution flow | 功能1 |
| FUSE_UI_DEBUG_FEATURE_2 | 分析性能瓶颈 | Analyze performance bottlenecks | 功能2 |
| FUSE_UI_DEBUG_FEATURE_3 | 调试复杂的执行逻辑 | Debug complex execution logic | 功能3 |
| FUSE_UI_DEBUG_FEATURE_4 | 监控运行时状态 | Monitor runtime state | 功能4 |
| FUSE_UI_DEBUG_WELCOME_INSTRUCTION | 执行一些指令后，点击'刷新'按钮查看执行历史。 | After executing some instructions, click the 'Refresh' button to view execution history. | 操作说明 |
| FUSE_UI_DEBUG_NO_HISTORY | 没有执行历史 | No execution history | 无历史提示 |
| FUSE_UI_DEBUG_HISTORY_TITLE | 执行历史 | Execution History | 历史标题 |
| FUSE_UI_DEBUG_EXECUTION_ITEM | 执行 #%d (%.2fs) | Execution #%d (%.2fs) | 执行项 |
| FUSE_UI_DEBUG_EXEC_STATS | 指令: %d, 错误: %d | Instructions: %d, Errors: %d | 执行统计 |
| FUSE_UI_DEBUG_STEP_START | 开始: %s | Start: %s | 步骤开始 |
| FUSE_UI_DEBUG_STEP_COMPLETE | 完成: %s %s %s | Complete: %s %s %s | 步骤完成 |
| FUSE_UI_DEBUG_STEP_ERROR | 错误: %s | Error: %s | 步骤错误 |
| FUSE_UI_DEBUG_STEP_PERFORMANCE | 性能问题: %s (%s) | Performance Issue: %s (%s) | 性能问题 |
| FUSE_UI_DEBUG_STEP_EVENT | 事件: %s | Event: %s | 事件步骤 |
| FUSE_UI_DEBUG_EXEC_DETAILS_TITLE | 执行详情 | Execution Details | 执行详情标题 |
| FUSE_UI_DEBUG_BASIC_INFO | 基本信息 | Basic Info | 基本信息 |
| FUSE_UI_DEBUG_START_TIME | 开始时间 | Start Time | 开始时间 |
| FUSE_UI_DEBUG_END_TIME | 结束时间 | End Time | 结束时间 |
| FUSE_UI_DEBUG_TOTAL_TIME | 总耗时 | Total Time | 总耗时 |
| FUSE_UI_DEBUG_SECONDS | 秒 | seconds | 秒 |
| FUSE_UI_DEBUG_CONTEXT_ID | 上下文ID | Context ID | 上下文ID |
| FUSE_UI_DEBUG_STEP_COUNT | 步骤数量 | Step Count | 步骤数量 |
| FUSE_UI_DEBUG_STATS | 统计信息 | Statistics | 统计信息 |
| FUSE_UI_DEBUG_INSTRUCTION_COUNT | 指令数量 | Instruction Count | 指令数量 |
| FUSE_UI_DEBUG_ERROR_COUNT | 错误数量 | Error Count | 错误数量 |
| FUSE_UI_DEBUG_PERF_ISSUES | 性能问题 | Performance Issues | 性能问题 |
| FUSE_UI_DEBUG_SUCCESS_RATE | 成功率 | Success Rate | 成功率 |
| FUSE_UI_DEBUG_AVG_TIME | 平均执行时间 | Average Execution Time | 平均执行时间 |
| FUSE_UI_DEBUG_PERF_METRICS | 性能指标 | Performance Metrics | 性能指标 |
| FUSE_UI_DEBUG_MEMORY_CHANGE | 内存使用变化 | Memory Usage Change | 内存变化 |
| FUSE_UI_DEBUG_MEMORY_SNAPSHOTS | 内存快照 | Memory Snapshots | 内存快照 |
| FUSE_UI_DEBUG_STEP_DETAILS_TITLE | 步骤详情 | Step Details | 步骤详情标题 |
| FUSE_UI_DEBUG_TYPE | 类型 | Type | 类型 |
| FUSE_UI_DEBUG_TIME | 时间 | Time | 时间 |
| FUSE_UI_DEBUG_INSTRUCTION | 指令 | Instruction | 指令 |
| FUSE_UI_DEBUG_INSTRUCTION_TYPE | 指令类型 | Instruction Type | 指令类型 |
| FUSE_UI_DEBUG_INSTRUCTION_INDEX | 指令索引 | Instruction Index | 指令索引 |
| FUSE_UI_DEBUG_EXECUTION_RESULT | 执行结果 | Execution Result | 执行结果 |
| FUSE_UI_DEBUG_YES | 是 | Yes | 是 |
| FUSE_UI_DEBUG_NO | 否 | No | 否 |
| FUSE_UI_DEBUG_SUCCESS | 成功 | Success | 成功 |
| FUSE_UI_DEBUG_EXECUTION_TIME | 执行时间 | Execution Time | 执行时间 |
| FUSE_UI_DEBUG_ERROR | 错误 | Error | 错误 |
| FUSE_UI_DEBUG_PERF_DATA | 性能数据 | Performance Data | 性能数据 |
| FUSE_UI_DEBUG_MEMORY_USAGE | 内存使用 | Memory Usage | 内存使用 |
| FUSE_UI_DEBUG_CPU_USAGE | CPU使用率 | CPU Usage | CPU使用率 |
| FUSE_UI_DEBUG_VARIABLE_STATE | 变量状态 | Variable State | 变量状态 |
| FUSE_UI_DEBUG_LOCAL_VARIABLES | 局部变量 | Local Variables | 局部变量 |
| FUSE_UI_DEBUG_GLOBAL_VARIABLES | 全局变量 | Global Variables | 全局变量 |
| FUSE_UI_DEBUG_COUNT | 个 | items | 计数单位 |
| FUSE_UI_DEBUG_VARIABLE_CHANGES | 变量变化 | Variable Changes | 变量变化 |
| FUSE_UI_DEBUG_EVENT_DATA | 事件数据 | Event Data | 事件数据 |
| FUSE_UI_DEBUG_ERROR_CONTEXT | 错误上下文 | Error Context | 错误上下文 |
| FUSE_UI_DEBUG_SECONDS_AGO | %.1f 秒前 | %.1f seconds ago | 秒前 |
| FUSE_UI_DEBUG_MINUTES_AGO | %.1f 分钟前 | %.1f minutes ago | 分钟前 |
| FUSE_UI_DEBUG_EXPORT_SUCCESS | 执行历史已导出到: %s | Execution history exported to: %s | 导出成功 |
| FUSE_UI_DEBUG_EXPORT_FAILED | 导出失败 | Export failed | 导出失败 |

### 日志消息（FUSE_LOG_）

#### 通用执行日志

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_LOG_EXECUTION_STARTED | 开始执行 | Execution started | 执行开始 |
| FUSE_LOG_EXECUTION_COMPLETED | 执行完成 | Execution completed | 执行完成 |
| FUSE_LOG_EXECUTION_CANCELLED | 执行已取消 | Execution cancelled | 执行取消 |
| FUSE_LOG_VARIABLE_ACCESS | 访问变量：{name} | Accessing variable: {name} | 访问变量 |
| FUSE_LOG_VARIABLE_CREATED | 创建变量：{name} | Created variable: {name} | 创建变量 |
| FUSE_LOG_VARIABLE_UPDATED | 更新变量：{name} | Updated variable: {name} | 更新变量 |
| FUSE_LOG_VARIABLE_DELETED | 删除变量：{name} | Deleted variable: {name} | 删除变量 |
| FUSE_LOG_OPERATION_SUCCESS | 操作成功：{operation} | Operation successful: {operation} | 操作成功 |
| FUSE_LOG_OPERATION_FAILED | 操作失败：{operation} | Operation failed: {operation} | 操作失败 |
| FUSE_LOG_COMPONENT_INITIALIZED | 组件已初始化：{name} | Component initialized: {name} | 组件初始化 |
| FUSE_LOG_FUNCTION_CALLED | 调用函数：{name} | Called function: {name} | 调用函数 |
| FUSE_LOG_PROPERTY_SET | 设置属性：{name} = {value} | Set property: {name} = {value} | 设置属性 |

#### 执行跟踪日志

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_LOG_TRACKING_STARTED | 开始执行跟踪，上下文ID: %s | Starting execution tracking, context ID: %s | 跟踪开始 |
| FUSE_LOG_WARNING_RECORD_NULL_INSTRUCTION_START | 尝试记录空指令的开始 | Attempting to record null instruction start | 空指令警告 |
| FUSE_LOG_RECORD_INSTRUCTION_START | 记录指令开始: %s | Recording instruction start: %s | 记录指令开始 |
| FUSE_LOG_WARNING_RECORD_NULL_INSTRUCTION_COMPLETE | 尝试记录空指令的完成 | Attempting to record null instruction complete | 空指令完成警告 |
| FUSE_LOG_RECORD_INSTRUCTION_COMPLETE | 记录指令完成: %s (耗时: %.3f秒) | Recording instruction complete: %s (time: %.3fs) | 记录指令完成 |
| FUSE_LOG_RECORD_CUSTOM_EVENT | 记录自定义事件: %s | Recording custom event: %s | 记录自定义事件 |
| FUSE_LOG_RECORD_EXECUTION_ERROR | 记录执行错误: %s | Recording execution error: %s | 记录执行错误 |
| FUSE_LOG_RECORD_PERFORMANCE_BOTTLENECK | 记录性能瓶颈: %s (严重程度: %s) | Recording performance bottleneck: %s (severity: %s) | 记录性能瓶颈 |
| FUSE_LOG_TRACKING_COMPLETED | 执行跟踪完成，总耗时: %.3f秒 | Execution tracking completed, total time: %.3fs | 跟踪完成 |
| FUSE_LOG_EXECUTION_HISTORY_CLEARED | 执行历史已清除 | Execution history cleared | 历史清除 |
| FUSE_LOG_TRACKING_CONFIG_UPDATED | 跟踪配置已更新 | Tracking configuration updated | 配置更新 |
| FUSE_LOG_WARNING_NO_EXECUTION_HISTORY_TO_EXPORT | 没有可导出的执行历史 | No execution history to export | 无历史警告 |
| FUSE_LOG_EXECUTION_HISTORY_EXPORTED | 执行历史已导出到: %s | Execution history exported to: %s | 历史导出 |
| FUSE_LOG_ERROR_FAILED_TO_OPEN_EXPORT_FILE | 无法打开文件进行导出: %s | Failed to open file for export: %s | 导出文件错误 |

#### 指令执行日志

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_LOG_PRINT_MESSAGE | 打印消息: {message} | Printing message: {message} | 打印消息 |
| FUSE_LOG_PRINT_EMPTY_WARNING | 消息内容为空，将不输出 | Message content is empty, nothing will be output | 空消息警告 |
| FUSE_LOG_PRINTING_VARIABLE | 打印变量: {name} | Printing variable: {name} | 打印变量 |
| FUSE_LOG_VARIABLE_VALUE | 变量值: {name} = {value} | Variable value: {name} = {value} | 变量值 |
| FUSE_LOG_SETTING_VARIABLE | 设置变量: {name} = {value} | Setting variable: {name} = {value} | 设置变量 |
| FUSE_LOG_SETTING_INT_VARIABLE | 设置整数变量: {name} = {value} | Setting int variable: {name} = {value} | 设置整数变量 |
| FUSE_LOG_CREATING_VARIABLE | 创建变量: {name} = {value} | Creating variable: {name} = {value} | 创建变量 |
| FUSE_LOG_WAITING_START | 开始等待 {duration} 秒 | Starting to wait for {duration} seconds | 开始等待 |
| FUSE_LOG_WAITING_COMPLETE | 等待完成 | Waiting completed | 等待完成 |
| FUSE_LOG_COUNT_INCREMENT | 计数增加: {count} -> {new_count} | Count incremented: {count} -> {new_count} | 计数增加 |
| FUSE_LOG_COUNT_RESET | 计数重置 | Count reset | 计数重置 |
| FUSE_LOG_QUITTING | 退出应用程序 | Quitting application | 退出应用 |
| FUSE_LOG_EVALUATING_CONDITION | 评估条件 | Evaluating condition | 评估条件 |
| FUSE_LOG_CONDITION_RESULT | 条件结果: {result} | Condition result: {result} | 条件结果 |
| FUSE_LOG_CONDITION_TRUE | 条件为真，执行操作 | Condition is true, executing actions | 条件为真 |
| FUSE_LOG_CONDITION_FALSE | 条件为假，跳过操作 | Condition is false, skipping actions | 条件为假 |
| FUSE_LOG_SETTING_PROPERTY | 设置属性: {node}.{property} = {value} | Setting property: {node}.{property} = {value} | 设置属性 |
| FUSE_LOG_CALLING_FUNCTION | 调用函数: {node}.{function}() | Calling function: {node}.{function}() | 调用函数 |
| FUSE_LOG_FUNCTION_CALL_SUCCESS | 函数调用成功: {function} | Function call successful: {function} | 函数调用成功 |
| FUSE_LOG_FUNCTION_CALL_FAILED | 函数调用失败: {function} | Function call failed: {function} | 函数调用失败 |
| FUSE_LOG_INSTRUCTION_START | 开始执行指令: {instruction} | Starting instruction: {instruction} | 指令开始 |
| FUSE_LOG_INSTRUCTION_COMPLETE | 指令执行完成 | Instruction execution completed | 指令完成 |
| FUSE_LOG_INSTRUCTION_CANCELLED | 指令执行已取消 | Instruction execution cancelled | 指令取消 |

#### 事件触发日志

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_LOG_EVENT_READY_TRIGGERED | 场景就绪事件触发 | Scene ready event triggered | 场景就绪 |
| FUSE_LOG_EVENT_READY_DELAY | 延迟 {delay} 秒后触发 | Triggering after {delay} seconds delay | 延迟触发 |
| FUSE_LOG_EVENT_AREA_ENTERED | 2D区域进入事件触发 | Area2D entered event triggered | 区域进入 |
| FUSE_LOG_EVENT_AREA_ENTERED_BODY | 物体进入区域: {body} | Body entered area: {body} | 物体进入 |
| FUSE_LOG_EVENT_INPUT_KEY_TRIGGERED | 按键输入事件触发: {key} | Input key event triggered: {key} | 按键触发 |
| FUSE_LOG_EVENT_KEY_PRESSED | 按键已按下: {key} | Key pressed: {key} | 按键按下 |
| FUSE_LOG_EVENT_INPUT_ACTION_TRIGGERED | 动作输入事件触发: {action} | Input action event triggered: {action} | 动作触发 |
| FUSE_LOG_EVENT_ACTION_PRESSED | 动作已触发: {action} | Action pressed: {action} | 动作按下 |
| FUSE_LOG_EVENT_SIGNAL_EMITTED | 信号发出事件触发: {signal} | Signal emit event triggered: {signal} | 信号触发 |
| FUSE_LOG_EVENT_SIGNAL_SOURCE | 信号源: {source} | Signal source: {source} | 信号源 |
| FUSE_LOG_EVENT_TRIGGERED | 事件触发 | Event triggered | 通用事件触发 |
| FUSE_LOG_EVENT_INITIALIZED | 事件已初始化 | Event initialized | 事件初始化 |
| FUSE_LOG_EVENT_TERMINATED | 事件已终止 | Event terminated | 事件终止 |

#### ActionRunner 日志

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_LOG_SIGNAL_DISCONNECTED | 已断开指令 '{instruction}' 的 finished 信号 | Disconnected finished signal for instruction '{instruction}' | 断开信号 |
| FUSE_LOG_DISCONNECTING_ALL_SIGNALS | 断开所有指令的信号连接... | Disconnecting all instruction signals... | 断开所有信号 |
| FUSE_LOG_SIGNALS_DISCONNECTED | 已断开 {count} 个信号连接 | Disconnected {count} signal(s) | 信号断开完成 |
| FUSE_LOG_ACTION_RUNNER_COMPLETED | ActionRunner 执行完成并清理资源 | ActionRunner execution completed and resources cleaned up | ActionRunner完成 |

#### GlobalVariableManager 日志

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_LOG_GLOBAL_VAR_MANAGER_INITIALIZED | 全局变量管理器（简化版本）初始化完成 | Global variable manager (simplified) initialized | 管理器初始化 |
| FUSE_LOG_VARIABLE_ADDED | 变量添加成功: {name} | Variable added successfully: {name} | 变量添加 |
| FUSE_LOG_VARIABLE_REMOVED | 变量移除成功: {name} | Variable removed successfully: {name} | 变量移除 |
| FUSE_LOG_ALL_VARIABLES_CLEARED | 所有变量已清空 | All variables cleared | 清空变量 |
| FUSE_LOG_VARIABLE_VALUE_CHANGED | 全局变量值变化: {name} ({old_value} -> {new_value}) | Global variable value changed: {name} ({old_value} -> {new_value}) | 变量值变化 |

#### 其他日志

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_LOG_DEBUG_EXECUTION_FLOW | 执行流程: {step} | Execution flow: {step} | 执行流程 |

### 日志级别（FUSE_LOG_LEVEL_）

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_LOG_LEVEL_DEBUG | 调试 | Debug | 调试级别 |
| FUSE_LOG_LEVEL_INFO | 信息 | Info | 信息级别 |
| FUSE_LOG_LEVEL_WARNING | 警告 | Warning | 警告级别 |
| FUSE_LOG_LEVEL_ERROR | 错误 | Error | 错误级别 |

### 插件相关（FUSE_PLUGIN_）

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_PLUGIN_NAME | Fuse 可视化编程 | Fuse Visual Programming | 插件名称 |
| FUSE_PLUGIN_DESCRIPTION | 一个用于 Godot 4.x 的可视化编程系统 | A visual programming system for Godot 4.x | 插件描述 |
| FUSE_PLUGIN_ACTIVATED | Fuse 可视化编程插件已激活 | Fuse Visual Programming plugin activated | 激活提示 |
| FUSE_PLUGIN_DEACTIVATED | Fuse 可视化编程插件已停用 | Fuse Visual Programming plugin deactivated | 停用提示 |

### 变量作用域（FUSE_VARIABLE_SCOPE_）

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_VARIABLE_SCOPE_LOCAL | 局部 | Local | 局部变量 |
| FUSE_VARIABLE_SCOPE_GLOBAL | 全局 | Global | 全局变量 |

### 变量类型（FUSE_TYPE_）

| 键名 | 中文 | 英文 | 用途 |
|------|------|------|------|
| FUSE_TYPE_BOOL | 布尔 | Bool | 布尔类型 |
| FUSE_TYPE_INT | 整数 | Int | 整数类型 |
| FUSE_TYPE_FLOAT | 浮点 | Float | 浮点类型 |
| FUSE_TYPE_STRING | 字符串 | String | 字符串类型 |
| FUSE_TYPE_VECTOR2 | 二维向量 | Vector2 | 二维向量类型 |
| FUSE_TYPE_VECTOR3 | 三维向量 | Vector3 | 三维向量类型 |
| FUSE_TYPE_COLOR | 颜色 | Color | 颜色类型 |

## 命名规范

### 翻译键命名规则

1. **前缀规则**: 所有翻译键以 `FUSE_` 开头
2. **类别前缀**:
   - 指令: `FUSE_INSTRUCTION_`
   - 指令分类: `FUSE_CATEGORY_`
   - 事件: `FUSE_EVENT_`
   - 事件分类: `FUSE_EVENT_CATEGORY_`
   - 错误: `FUSE_ERROR_`
   - UI: `FUSE_UI_`
   - 日志: `FUSE_LOG_`
   - 日志级别: `FUSE_LOG_LEVEL_`
   - 插件: `FUSE_PLUGIN_`
   - 变量作用域: `FUSE_VARIABLE_SCOPE_`
   - 变量类型: `FUSE_TYPE_`
3. **命名风格**: 全大写，使用下划线分隔
4. **描述性**: 键名应清楚描述用途

### 示例

**好的命名**:
- `FUSE_LOG_DEBUG_MESSAGE` - 清楚表示是日志调试消息
- `FUSE_INSTRUCTION_PRINT_NAME` - 清楚表示是指令名称
- `FUSE_ERROR_VAR_NOT_FOUND` - 清楚表示是变量未找到错误

**不好的命名**:
- `FUSE_MSG_1` - 不清楚用途
- `FUSE_PRINT` - 缺少类别前缀
- `FUSE_ERROR` - 过于通用，不清楚具体错误

## 使用示例

### 示例1: 在指令中使用

```gdscript
# print_instruction.gd
extends BaseInstruction

static func get_metadata() -> Dictionary:
	return {
		"category": FuseLocalization.translate("FUSE_CATEGORY_DEBUG"),
		"label": FuseLocalization.translate("FUSE_INSTRUCTION_PRINT_NAME"),
		"description": FuseLocalization.translate("FUSE_INSTRUCTION_PRINT_DESC"),
		"icon": "Res://addons/fuse/icons/instruction_print.svg"
	}

func execute(context: ExecutionContext) -> void:
	var message: String = FuseLocalization.translate("FUSE_LOG_PRINT_MESSAGE")
	FuseLogger.log_info("PrintInstruction", log_level, message)
```

### 示例2: 参数化翻译

```gdscript
# translations.csv
FUSE_LOG_PRINT_MESSAGE,打印消息: {message},Printing message: {message}

# code.gd
var args := {"message": "Hello World"}
var message := FuseLocalization.translate_format("FUSE_LOG_PRINT_MESSAGE", args)
# 输出: "打印消息: Hello World"
```

### 示例3: 错误消息本地化

```gdscript
# base_event.gd
func _create_fuse_error_localized(
	message_key: String,
	error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR,
	args: Dictionary = {},
	context: Dictionary = {}
) -> void:
	var localized_message := FuseLocalization.translate_format(message_key, args)
	_fuse_error = FuseError.create_with_context(
		error_type,
		"BaseEvent",
		localized_message,
		context
	)
```

### 示例4: UI文本本地化

```gdscript
# instruction_selector_dialog.gd
func _update_ui() -> void:
	title_label.text = FuseLocalization.translate("FUSE_UI_INSTRUCTION_SELECTOR_TITLE")
	search_placeholder.text = FuseLocalization.translate("FUSE_UI_SEARCH_PLACEHOLDER")
	no_results_label.text = FuseLocalization.translate("FUSE_UI_NO_INSTRUCTIONS_FOUND")
	select_button.text = FuseLocalization.translate("FUSE_UI_SELECT_INSTRUCTION")
```

### 示例5: 在编辑器插件中使用

```gdscript
# fuse_editor_plugin.gd
func _ready() -> void:
	var plugin_name = FuseLocalization.translate("FUSE_PLUGIN_NAME")
	var activated_message = FuseLocalization.translate("FUSE_PLUGIN_ACTIVATED")
	print("[%s] %s" % [plugin_name, activated_message])
```

## 维护指南

### 更新翻译键

当添加新翻译键时：
1. 更新 `translations.csv`
2. 更新本文档的"翻译键列表"部分
3. 更新"翻译键总数"（在文档顶部）
4. 运行翻译检查工具验证

### 添加新类别的翻译键

如果要添加新的翻译键类别：
1. 在 `translations.csv` 中使用新的前缀
2. 在本文档的"翻译键分类"表格中添加新类别
3. 在"翻译键列表"中添加新类别章节
4. 在"命名规范"中更新前缀列表
5. 提供使用示例

### 检查翻译完整性

```bash
# 在Godot编辑器中运行
Project → Tools → Execute Script
选择: addons/fuse/localization/translation_checker.gd
```

### 文档更新工作流

1. **修改 translations.csv**
2. **重新生成文档**（或手动更新）
3. **验证所有键都已记录**
4. **运行翻译检查工具**
5. **提交更改**

### 版本控制

提交翻译键更新时，使用以下提交格式：
```
docs(localization): 更新翻译键参考文档

- 添加新键: FUSE_EXAMPLE_NEW_KEY
- 更新键数: 298 -> 299
- 更新使用示例

相关任务: #123
```

---

**文档维护**: Fuse 本地化团队
**最后更新**: 2026-01-25
**反馈**: 请在 GitHub Issues 中报告问题或建议
