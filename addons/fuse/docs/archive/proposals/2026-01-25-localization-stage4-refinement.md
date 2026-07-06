# 本地化系统阶段4 - 完善与优化实施计划

> **STATUS: ⚠️ 已过时 (SUPERSEDED)** (2026-06-26 核实) — 本方案基于 CSV + 静态缓存,实际已迁移至 Godot 原生 TranslationDomain(.translation 二进制文件)。保留作历史参考。

> **For Claude:** REQUIRED SUB-SKILL: Use @superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完善Fuse本地化系统，补充遗漏翻译，优化性能，创建完整文档和工具

**Architecture:** 基于CSV的轻量级本地化系统，采用三层语言检测（项目设置 > 编辑器语言 > 操作系统语言），使用静态缓存优化性能

**Tech Stack:** GDScript 2.0, Godot 4.5, CSV文件, 静态缓存模式

---

## 前置条件

**已完成（阶段1-3）:**
- ✅ FuseLocalization 核心系统
- ✅ 298个翻译键（中英双语）
- ✅ 编辑器UI本地化
- ✅ 运行时日志/错误本地化
- ✅ 静态缓存优化（70%性能提升）
- ✅ 三层语言检测机制

**当前状态:**
- 翻译键覆盖率: 约95%
- 性能: 优秀（0.12μs/调用）
- 测试: 56个测试用例通过
- 文档: 实施计划完整，缺少用户文档

---

## Task 1: 补充翻译键

**目标:** 从298个增加到300+个翻译键，达到100%覆盖率

**Files:**
- Modify: `addons/fuse/localization/translations.csv`
- Reference: `addons/fuse/localization/fuse_localization.gd` (使用示例)

### Step 1: 搜索硬编码文本

搜索Fuse插件中所有硬编码的中英文文本：

```bash
# 在addons/fuse目录搜索硬编码中文字符
cd addons/fuse
grep -r "[\u4e00-\u9fa5]" --include="*.gd" --exclude-dir=localization | grep -v "FUSE_" | grep -v "^Binary"

# 搜索硬编码英文字符串（排除翻译键和注释）
grep -r '"[A-Z][a-z].*"' --include="*.gd" | grep -v "FUSE_" | grep -v "##"
```

Expected Output: 找到约5-10个遗漏的硬编码文本

### Step 2: 为遗漏文本创建翻译键

根据命名规范创建翻译键：

格式: `FUSE_[类别]_[子类别]_[具体项]`

示例翻译键（按优先级排序）:
```csv
# 可能遗漏的组件提示文本
FUSE_TOOLTIP_CONDITION_ADD,添加条件,Add Condition
FUSE_TOOLTIP_CONDITION_REMOVE,移除条件,Remove Condition
FUSE_TOOLTIP_EVENT_ADD,添加事件,Add Event
FUSE_TOOLTIP_EVENT_REMOVE,移除事件,Remove Event

# 可能遗漏的状态消息
FUSE_STATUS_READY,就绪,Ready
FUSE_STATUS_RUNNING,运行中,Running
FUSE_STATUS_COMPLETED,已完成,Completed
FUSE_STATUS_ERROR,错误,Error
FUSE_STATUS_CANCELLED,已取消,Cancelled
```

### Step 3: 添加翻译键到CSV

在 `addons/fuse/localization/translations.csv` 文件末尾添加：

```csv
# 状态提示（新增）
FUSE_STATUS_READY,就绪,Ready
FUSE_STATUS_RUNNING,运行中,Running
FUSE_STATUS_COMPLETED,已完成,Completed
FUSE_STATUS_ERROR,错误,Error
FUSE_STATUS_CANCELLED,已取消,Cancelled

# 工具提示（新增）
FUSE_TOOLTIP_CONDITION_ADD,添加条件,Add Condition
FUSE_TOOLTIP_CONDITION_REMOVE,移除条件,Remove Condition
FUSE_TOOLTIP_EVENT_ADD,添加事件,Add Event
FUSE_TOOLTIP_EVENT_REMOVE,移除事件,Remove Event
```

### Step 4: 在代码中应用新翻译键

找到硬编码文本的位置并替换：

示例（假设找到硬编码）:
```gdscript
# 修改前
tooltip_text = "添加条件"

# 修改后
tooltip_text = FuseLocalization.translate("FUSE_TOOLTIP_CONDITION_ADD")
```

### Step 5: 运行本地化测试验证

```bash
# 在Godot编辑器中运行
cd "e:\Godot\GodotProjects\project-juicy-godot"
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script test_scripts/run_localization_tests.gd
```

Expected Output:
```
All tests passed!
Total translation keys: 307+
```

### Step 6: 提交更改

```bash
git add addons/fuse/localization/translations.csv
git commit -m "feat(localization): 添加状态和工具提示翻译键，达到300+目标"
```

---

## Task 2: 创建翻译检查工具

**目标:** 创建EditorScript工具检查翻译完整性和一致性

**Files:**
- Create: `addons/fuse/localization/translation_checker.gd`

### Step 1: 创建翻译检查工具文件

创建 `addons/fuse/localization/translation_checker.gd`:

```gdscript
@tool
extends EditorScript

## 翻译完整性检查工具
## 检查所有指令和事件元数据是否都有对应的翻译键

func _run() -> void:
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	FuseLocalization.init()

	print("=" * 80)
	print("Fuse 翻译完整性检查")
	print("=" * 80)

	# 检查翻译统计
	_check_translation_stats()

	# 检查缺失翻译
	_check_missing_translations()

	# 检查指令元数据翻译键
	_check_instruction_metadata()

	# 检查事件元数据翻译键
	_check_event_metadata()

	print("\n" + "=" * 80)
	print("检查完成！")
	print("=" * 80)


func _check_translation_stats():
	print("\n--- 翻译统计 ---")
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	var stats = FuseLocalization.get_translation_stats()

	print("总翻译键数: %d" % stats.total_keys)
	print("中文翻译数: %d (%.1f%%)" % [stats.zh_CN_translations, stats.zh_CN_coverage])
	print("英文翻译数: %d (%.1f%%)" % [stats.en_US_translations, stats.en_US_coverage])
	print("当前语言: %s" % stats.current_locale)

	# 验证是否达到300+目标
	if stats.total_keys >= 300:
		print("✅ 已达到300+翻译键目标")
	else:
		print("⚠️  还差 %d 个翻译键达到300目标" % (300 - stats.total_keys))


func _check_missing_translations():
	print("\n--- 缺失翻译检查 ---")
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	var missing = FuseLocalization.get_missing_translations()

	if missing.is_empty():
		print("✅ 没有缺失的翻译")
	else:
		print("⚠️  发现 %d 个缺失的翻译:" % missing.size())
		for key in missing:
			print("  - %s" % key)


func _check_instruction_metadata():
	print("\n--- 指令元数据翻译键检查 ---")

	var instruction_dir = DirAccess.open("res://addons/fuse/instructions/")
	if not instruction_dir:
		print("❌ 无法打开指令目录")
		return

	instruction_dir.list_dir_begin()
	var file_name = instruction_dir.get_next()
	var issues = []

	while file_name != "":
		if file_name.ends_with(".gd"):
			var file_path = "res://addons/fuse/instructions/" + file_name
			var script = load(file_path)

			if script and script.has_method("_get_instruction_metadata"):
				var metadata = script._get_instruction_metadata()

				# 检查是否有翻译键
				if not metadata.has("name_key") or metadata.name_key.is_empty():
					if metadata.has("name") and not metadata.name.is_empty():
						issues.append("  %s: 缺少 name_key (当前: '%s')" % [file_name, metadata.name])

				if not metadata.has("category_key") or metadata.category_key.is_empty():
					if metadata.has("category") and not metadata.category.is_empty():
						issues.append("  %s: 缺少 category_key (当前: '%s')" % [file_name, metadata.category])

				if not metadata.has("description_key") or metadata.description_key.is_empty():
					if metadata.has("description") and not metadata.description.is_empty():
						issues.append("  %s: 缺少 description_key" % [file_name])

		file_name = instruction_dir.get_next()

	instruction_dir.list_dir_end()

	if issues.is_empty():
		print("✅ 所有指令元数据都有翻译键")
	else:
		print("⚠️  发现 %d 个问题:" % issues.size())
		for issue in issues:
			print(issue)


func _check_event_metadata():
	print("\n--- 事件元数据翻译键检查 ---")

	var event_dir = DirAccess.open("res://addons/fuse/events/")
	if not event_dir:
		print("❌ 无法打开事件目录")
		return

	event_dir.list_dir_begin()
	var file_name = event_dir.get_next()
	var issues = []

	while file_name != "":
		if file_name.ends_with(".gd"):
			var file_path = "res://addons/fuse/events/" + file_name
			var script = load(file_path)

			if script and script.has_method("_get_event_metadata"):
				var metadata = script._get_event_metadata()

				# 检查是否有翻译键
				if not metadata.has("name_key") or metadata.name_key.is_empty():
					if metadata.has("name") and not metadata.name.is_empty():
						issues.append("  %s: 缺少 name_key (当前: '%s')" % [file_name, metadata.name])

				if not metadata.has("category_key") or metadata.category_key.is_empty():
					if metadata.has("category") and not metadata.category.is_empty():
						issues.append("  %s: 缺少 category_key (当前: '%s')" % [file_name, metadata.category])

				if not metadata.has("description_key") or metadata.description_key.is_empty():
					if metadata.has("description") and not metadata.description.is_empty():
						issues.append("  %s: 缺少 description_key" % [file_name])

		file_name = event_dir.get_next()

	event_dir.list_dir_end()

	if issues.is_empty():
		print("✅ 所有时间元数据都有翻译键")
	else:
		print("⚠️  发现 %d 个问题:" % issues.size())
		for issue in issues:
			print(issue)
```

### Step 2: 在编辑器中测试翻译检查工具

在Godot编辑器中:
1. 点击 `项目 > 工具 > 执行脚本`
2. 选择 `addons/fuse/localization/translation_checker.gd`
3. 查看控制台输出

Expected Output:
```
================================================================================
Fuse 翻译完整性检查
================================================================================

--- 翻译统计 ---
总翻译键数: 307
中文翻译数: 307 (100.0%)
英文翻译数: 307 (100.0%)
当前语言: en_US
✅ 已达到300+翻译键目标

--- 缺失翻译检查 ---
✅ 没有缺失的翻译

--- 指令元数据翻译键检查 ---
✅ 所有指令元数据都有翻译键

--- 事件元数据翻译键检查 ---
✅ 所有时间元数据都有翻译键

================================================================================
检查完成！
================================================================================
```

### Step 3: 提交工具

```bash
git add addons/fuse/localization/translation_checker.gd
git commit -m "feat(localization): 添加翻译完整性检查工具"
```

---

## Task 3: 性能优化

**目标:** 优化CSV解析性能，添加性能监控（静态缓存已完成）

**Files:**
- Modify: `addons/fuse/localization/fuse_localization.gd`
- Create: `test_scripts/performance_localization_benchmark.gd`

### Step 1: 创建性能基准测试

创建 `test_scripts/performance_localization_benchmark.gd`:

```gdscript
extends SceneTree

## 本地化系统性能基准测试
## 测试加载、解析、翻译各环节的性能

func _init():
	print("================================================================================")
	print("本地化系统性能基准测试")
	print("================================================================================")

	# 测试1: CSV文件加载性能
	print("\n测试 1: CSV 文件加载性能")
	var iterations = 100
	var start = Time.get_ticks_usec()
	for i in range(iterations):
		var file = FileAccess.open("res://addons/fuse/localization/translations.csv", FileAccess.READ)
		if file:
			file.close()
	var elapsed = Time.get_ticks_usec() - start
	print("  %d 次文件打开耗时: %d μs (平均: %.2f μs/次)" % [iterations, elapsed, elapsed / float(iterations)])

	# 测试2: CSV解析性能
	print("\n测试 2: CSV 解析性能")
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	iterations = 50  # 解析较慢，减少次数
	start = Time.get_ticks_usec()
	for i in range(iterations):
		FuseLocalization.reload_translations()
	elapsed = Time.get_ticks_usec() - start
	print("  %d 次完整解析耗时: %d μs (平均: %.2f μs/次)" % [iterations, elapsed, elapsed / float(iterations)])

	# 测试3: 翻译查询性能（使用缓存）
	print("\n测试 3: 翻译查询性能（使用缓存）")
	FuseLocalization.init()
	iterations = 10000
	start = Time.get_ticks_usec()
	for i in range(iterations):
		FuseLocalization.translate("FUSE_INSTRUCTION_PRINT_NAME")
	elapsed = Time.get_ticks_usec() - start
	print("  %d 次翻译查询耗时: %d μs (平均: %.2f μs/次)" % [iterations, elapsed, elapsed / float(iterations)])

	# 测试4: 参数化翻译性能
	print("\n测试 4: 参数化翻译性能")
	iterations = 10000
	start = Time.get_ticks_usec()
	for i in range(iterations):
		FuseLocalization.translate_format("FUSE_ERROR_VAR_NOT_FOUND", {"name": "test_var"})
	elapsed = Time.get_ticks_usec() - start
	print("  %d 次参数化翻译耗时: %d μs (平均: %.2f μs/次)" % [iterations, elapsed, elapsed / float(iterations)])

	# 测试5: 内存占用估算
	print("\n测试 5: 内存占用估算")
	var stats = FuseLocalization.get_translation_stats()
	print("  翻译键数量: %d" % stats.total_keys)
	print("  估算字典大小: ~%.2f KB" % (stats.total_keys * 0.1))  # 每个键约0.1KB

	print("\n================================================================================")
	print("性能测试完成！")
	print("================================================================================")
	quit()
```

### Step 2: 运行性能基准测试

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script test_scripts/performance_localization_benchmark.gd
```

Expected Output:
```
================================================================================
本地化系统性能基准测试
================================================================================

测试 1: CSV 文件加载性能
  100 次文件打开耗时: 15000 μs (平均: 150.00 μs/次)

测试 2: CSV 解析性能
  50 次完整解析耗时: 50000 μs (平均: 1000.00 μs/次)

测试 3: 翻译查询性能（使用缓存）
  10000 次翻译查询耗时: 1200 μs (平均: 0.12 μs/次)

测试 4: 参数化翻译性能
  10000 次参数化翻译耗时: 1500 μs (平均: 0.15 μs/次)

测试 5: 内存占用估算
  翻译键数量: 307
  估算字典大小: ~30.70 KB

================================================================================
性能测试完成！
================================================================================
```

### Step 3: 优化CSV解析（如果需要）

如果基准测试显示解析性能不足1ms，优化解析：

在 `fuse_localization.gd` 的 `_parse_csv_line()` 方法中:
- 已优化（使用状态机解析）
- 当前性能已足够（< 1ms）

### Step 4: 提交性能测试工具

```bash
git add test_scripts/performance_localization_benchmark.gd
git commit -m "test(localization): 添加性能基准测试工具"
```

---

## Task 4: 创建翻译键参考文档

**目标:** 按类别组织所有翻译键，提供使用示例

**Files:**
- Create: `addons/fuse/localization/translation_keys.md`

### Step 1: 创建翻译键参考文档

创建 `addons/fuse/localization/translation_keys.md`:

```markdown
# Fuse 翻译键参考文档

本文档列出所有Fuse本地化系统的翻译键，按类别组织。

## 目录

- [指令相关](#指令相关)
- [事件相关](#事件相关)
- [分类](#分类)
- [错误消息](#错误消息)
- [UI文本](#ui文本)
- [日志消息](#日志消息)
- [变量相关](#变量相关)
- [系统相关](#系统相关)

---

## 指令相关

### 指令名称

| 翻译键 | 中文 | 英文 | 用途 |
|--------|------|------|------|
| `FUSE_INSTRUCTION_PRINT_NAME` | 打印消息 | Print Message | Print指令 |
| `FUSE_INSTRUCTION_PRINT_VARIABLE_NAME` | 打印变量值 | Print Variable Value | PrintVariable指令 |
| `FUSE_INSTRUCTION_SET_VARIABLE_NAME` | 设置变量 | Set Variable | SetVariable指令 |
| `FUSE_INSTRUCTION_CREATE_VARIABLE_NAME` | 创建变量 | Create Variable | CreateVariable指令 |
| `FUSE_INSTRUCTION_WAIT_NAME` | 等待 | Wait | Wait指令 |
| `FUSE_INSTRUCTION_COUNT_NAME` | 计数 | Count | Count指令 |
| `FUSE_INSTRUCTION_QUIT_NAME` | 退出应用程序 | Quit Application | Quit指令 |
| `FUSE_INSTRUCTION_RUN_CONDITION_CHECK_NAME` | 运行条件检查 | Run Condition Check | RunConditionCheck指令 |
| `FUSE_INSTRUCTION_SET_INT_VARIABLE_NAME` | 设置整数变量 | Set Int Variable | SetIntVariable指令 |
| `FUSE_INSTRUCTION_SET_PROPERTY_VALUE_NAME` | 设置属性值 | Set Property Value | SetPropertyValue指令 |
| `FUSE_INSTRUCTION_RUN_TARGET_NODE_FUNCTION_NAME` | 运行节点函数 | Run Node Function | RunTargetNodeFunction指令 |

### 指令描述

| 翻译键 | 中文 | 英文 |
|--------|------|------|
| `FUSE_INSTRUCTION_PRINT_DESC` | 打印消息到输出窗口和执行上下文 | Prints a message to the output window and execution context |
| `FUSE_INSTRUCTION_PRINT_VARIABLE_DESC` | 查找并打印变量的值到输出窗口和执行上下文 | Finds and prints a variable value to the output window and execution context |
| `FUSE_INSTRUCTION_SET_VARIABLE_DESC` | 设置变量的值，支持从另一个变量复制值或直接设置新值 | Sets the value of a variable, supports copying from another variable or setting a new value |
| ... | ... | ... |

---

## 事件相关

### 事件名称

| 翻译键 | 中文 | 英文 |
|--------|------|------|
| `FUSE_EVENT_ON_READY_NAME` | 场景就绪 | Scene Ready |
| `FUSE_EVENT_ON_AREA_2D_ENTER_NAME` | 区域进入 | Area Entered |
| `FUSE_EVENT_ON_INPUT_KEY_NAME` | 按键输入 | Key Input |
| `FUSE_EVENT_ON_INPUT_ACTION_NAME` | 动作输入 | Action Input |
| `FUSE_EVENT_ON_TARGET_SIGNAL_EMIT_NAME` | 目标信号发出 | Target Signal Emitted |

---

## 分类

| 翻译键 | 中文 | 英文 |
|--------|------|------|
| `FUSE_CATEGORY_DEBUG` | 调试 | Debug |
| `FUSE_CATEGORY_VARIABLES` | 变量 | Variables |
| `FUSE_CATEGORY_FLOW_CONTROL` | 流程控制 | Flow Control |
| `FUSE_CATEGORY_NODE_OPERATIONS` | 节点操作 | Node Operations |
| `FUSE_CATEGORY_LOGIC` | 逻辑 | Logic |
| `FUSE_CATEGORY_MATH` | 数学 | Math |
| `FUSE_CATEGORY_INPUT` | 输入 | Input |
| `FUSE_CATEGORY_SYSTEM` | 系统 | System |

---

## 错误消息

### 基础错误

| 翻译键 | 中文 | 英文 | 参数 |
|--------|------|------|------|
| `FUSE_ERROR_MESSAGE_EMPTY` | 消息内容不能为空 | Message content cannot be empty | - |
| `FUSE_ERROR_VAR_NAME_EMPTY` | 变量名称不能为空 | Variable name cannot be empty | - |
| `FUSE_ERROR_VAR_NOT_FOUND` | 未找到变量：{name} | Variable '{name}' not found | name: 变量名 |
| `FUSE_ERROR_VAR_ALREADY_EXISTS` | 变量已存在：{name} | Variable already exists: {name} | name: 变量名 |
| `FUSE_ERROR_VAR_TYPE_MISMATCH` | 变量类型不匹配，期望：{expected}，实际：{actual} | Variable type mismatch, expected: {expected}, actual: {actual} | expected: 期望类型, actual: 实际类型 |
| `FUSE_ERROR_EXECUTION_FAILED` | 指令执行失败：{error} | Instruction execution failed: {error} | error: 错误信息 |

### 使用示例

```gdscript
# 简单翻译
var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
# 中文: "变量名称不能为空"
# 英文: "Variable name cannot be empty"

# 参数化翻译
var error_msg = FuseLocalization.translate_format(
    "FUSE_ERROR_VAR_NOT_FOUND",
    {"name": "my_variable"}
)
# 中文: "未找到变量：my_variable"
# 英文: "Variable 'my_variable' not found"
```

---

## UI文本

### 按钮

| 翻译键 | 中文 | 英文 |
|--------|------|------|
| `FUSE_UI_BTN_ADD` | 添加 | Add |
| `FUSE_UI_BTN_REMOVE` | 移除 | Remove |
| `FUSE_UI_BTN_EDIT` | 编辑 | Edit |
| `FUSE_UI_BTN_DELETE` | 删除 | Delete |
| `FUSE_UI_BTN_APPLY` | 应用 | Apply |
| `FUSE_UI_BTN_CANCEL` | 取消 | Cancel |
| `FUSE_UI_BTN_OK` | 确定 | OK |
| `FUSE_UI_BTN_YES` | 是 | Yes |
| `FUSE_UI_BTN_NO` | 否 | No |
| `FUSE_UI_BTN_SAVE` | 保存 | Save |
| `FUSE_UI_BTN_LOAD` | 加载 | Load |
| `FUSE_UI_BTN_RESET` | 重置 | Reset |
| `FUSE_UI_BTN_REFRESH` | 刷新 | Refresh |

---

## 日志消息

### 指令执行日志

| 翻译键 | 中文 | 英文 |
|--------|------|------|
| `FUSE_LOG_EXECUTION_STARTED` | 开始执行 | Execution started |
| `FUSE_LOG_EXECUTION_COMPLETED` | 执行完成 | Execution completed |
| `FUSE_LOG_EXECUTION_CANCELLED` | 执行已取消 | Execution cancelled |
| `FUSE_LOG_OPERATION_SUCCESS` | 操作成功：{operation} | Operation successful: {operation} |
| `FUSE_LOG_OPERATION_FAILED` | 操作失败：{operation} | Operation failed: {operation} |

### 变量操作日志

| 翻译键 | 中文 | 英文 |
|--------|------|------|
| `FUSE_LOG_VARIABLE_ACCESS` | 访问变量：{name} | Accessing variable: {name} |
| `FUSE_LOG_VARIABLE_CREATED` | 创建变量：{name} | Created variable: {name} |
| `FUSE_LOG_VARIABLE_UPDATED` | 更新变量：{name} | Updated variable: {name} |
| `FUSE_LOG_VARIABLE_DELETED` | 删除变量：{name} | Deleted variable: {name} |

---

## 变量相关

### 变量类型

| 翻译键 | 中文 | 英文 |
|--------|------|------|
| `FUSE_TYPE_BOOL` | 布尔 | Bool |
| `FUSE_TYPE_INT` | 整数 | Int |
| `FUSE_TYPE_FLOAT` | 浮点 | Float |
| `FUSE_TYPE_STRING` | 字符串 | String |
| `FUSE_TYPE_VECTOR2` | 二维向量 | Vector2 |
| `FUSE_TYPE_VECTOR3` | 三维向量 | Vector3 |
| `FUSE_TYPE_COLOR` | 颜色 | Color |

### 变量作用域

| 翻译键 | 中文 | 英文 |
|--------|------|------|
| `FUSE_VARIABLE_SCOPE_LOCAL` | 局部 | Local |
| `FUSE_VARIABLE_SCOPE_GLOBAL` | 全局 | Global |

---

## 系统相关

| 翻译键 | 中文 | 英文 |
|--------|------|------|
| `FUSE_PLUGIN_NAME` | Fuse 可视化编程 | Fuse Visual Programming |
| `FUSE_PLUGIN_DESCRIPTION` | 一个用于 Godot 4.x 的可视化编程系统 | A visual programming system for Godot 4.x |
| `FUSE_PLUGIN_ACTIVATED` | Fuse 可视化编程插件已激活 | Fuse Visual Programming plugin activated |
| `FUSE_PLUGIN_DEACTIVATED` | Fuse 可视化编程插件已停用 | Fuse Visual Programming plugin deactivated |

---

## 使用指南

### 1. 基础翻译

```gdscript
var localized_text = FuseLocalization.translate("FUSE_UI_BTN_ADD")
```

### 2. 参数化翻译

```gdscript
var localized_text = FuseLocalization.translate_format(
    "FUSE_ERROR_VAR_NOT_FOUND",
    {"name": "my_var"}
)
```

### 3. 在指令中使用

```gdscript
class_name MyInstruction extends BaseInstruction

func execute(context: ExecutionContext):
    _start_execution(context)

    # 使用本地化日志
    _log_info_localized("FUSE_LOG_EXECUTION_STARTED", {})

    # 处理错误
    if error:
        _set_error_localized(
            "FUSE_ERROR_EXECUTION_FAILED",
            FuseError.ErrorType.RUNTIME_ERROR,
            {"error": "具体错误信息"}
        )
        finished.emit()
        return

    finished.emit()
```

---

## 统计信息

- **总翻译键数**: 307+
- **语言**: 简体中文（zh_CN）、英语（en_US）
- **覆盖率**: 100%
- **最后更新**: 2026-01-25
```

### Step 2: 提交文档

```bash
git add addons/fuse/localization/translation_keys.md
git commit -m "docs(localization): 添加翻译键参考文档"
```

---

## Task 5: 更新系统文档

**目标:** 更新README，添加本地化系统说明

**Files:**
- Modify: `addons/fuse/localization/README.md` (如果存在)
- Create: `addons/fuse/localization/USER_GUIDE.md`

### Step 1: 创建用户使用指南

创建 `addons/fuse/localization/USER_GUIDE.md`:

```markdown
# Fuse 本地化系统 - 用户使用指南

本指南说明如何在Fuse插件中使用本地化功能。

## 目录

- [快速开始](#快速开始)
- [语言设置](#语言设置)
- [在指令中使用本地化](#在指令中使用本地化)
- [常见问题](#常见问题)

---

## 快速开始

### 自动语言检测

Fuse本地化系统会自动检测并使用合适的语言，优先级如下：

1. **项目设置** (最高优先级)
   - 在 `project.godot` 中配置 `locale/locale="en"` 或 `"zh_CN"`

2. **编辑器语言**
   - 使用编辑器界面的语言设置（仅编辑器环境）

3. **操作系统语言** (回退选项)
   - 使用系统的语言设置

### 配置项目语言

在项目根目录的 `project.godot` 文件中添加：

```ini
[internationalization]
locale/test="false"
locale/fallback="zh_CN"
locale/locale="en"  # 设置为 "en" 或 "zh_CN"
```

---

## 语言设置

### 编辑器环境

在编辑器中使用Fuse时，本地化系统会：
1. 优先使用项目设置的语言
2. 如果项目设置未配置，使用编辑器界面语言
3. 自动显示对应语言的UI和消息

### 运行时环境

在游戏运行时，本地化系统会：
1. 使用项目配置的语言
2. 保持整个会话期间语言一致
3. 无需手动切换

**注意**: Fuse不提供手动语言切换UI，语言由配置自动确定。

---

## 在指令中使用本地化

### 方法1: 使用便捷方法（推荐）

```gdscript
class_name MyInstruction extends BaseInstruction

func execute(context: ExecutionContext):
    _start_execution(context)

    # 本地化日志
    _log_info_localized("FUSE_LOG_EXECUTION_STARTED", {})
    _log_debug_localized("FUSE_LOG_VARIABLE_ACCESS", {"name": "my_var"})

    # 本地化错误
    if has_error():
        _set_error_localized(
            "FUSE_ERROR_VALIDATION_FAILED",
            FuseError.ErrorType.VALIDATION_ERROR
        )
        finished.emit()
        return

    # 正常执行
    finished.emit()
```

### 方法2: 直接调用FuseLocalization

```gdscript
func some_function():
    # 加载本地化类
    var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
    FuseLocalization.init()

    # 简单翻译
    var text = FuseLocalization.translate("FUSE_UI_BTN_ADD")

    # 参数化翻译
    var error = FuseLocalization.translate_format(
        "FUSE_ERROR_VAR_NOT_FOUND",
        {"name": "my_variable"}
    )
```

### 方法3: 在FuseLogger中使用

```gdscript
var FuseLogger = load("res://addons/fuse/core/logging/fuse_logger.gd")
var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")

# 本地化日志
FuseLogger.log_info_localized(
    "MyComponent",
    FuseLogger.LogLevel.INFO,
    "FUSE_LOG_EXECUTION_STARTED",
    {},  # 参数
    "context"  # 可选上下文
)
```

---

## 创建自定义指令的本地化

### 1. 在translations.csv中添加翻译键

```csv
# 你的自定义指令
FUSE_INSTRUCTION_MY_CUSTOM_NAME,我的自定义指令,My Custom Instruction
FUSE_INSTRUCTION_MY_CUSTOM_DESC,这是一个自定义指令的描述,This is a description for a custom instruction
FUSE_LOG_MY_CUSTOM_STARTED,开始执行自定义指令,Started custom instruction
FUSE_ERROR_MY_CUSTOM_FAILED,自定义指令失败,Custom instruction failed
```

### 2. 在指令元数据中使用

```gdscript
class_name MyCustomInstruction extends BaseInstruction

static func get_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_MY_CUSTOM_NAME"
	metadata.category_key = "FUSE_CATEGORY_CUSTOM"
	metadata.description_key = "FUSE_INSTRUCTION_MY_CUSTOM_DESC"
	return metadata

func execute(context: ExecutionContext):
	_start_execution(context)

	_log_info_localized("FUSE_LOG_MY_CUSTOM_STARTED", {})

	# 你的逻辑...

	finished.emit()
```

---

## 常见问题

### Q: 如何切换语言？

**A:** 编辑项目根目录的 `project.godot` 文件，修改 `locale/locale` 的值：

```ini
locale/locale="en"     # 英语
locale/locale="zh_CN"  # 简体中文
```

保存后重新打开项目即可生效。

### Q: 为什么有些文本还是中文/英文？

**A:** 可能的原因：
1. 该文本的翻译键缺失 - 运行翻译检查工具确认
2. 代码中使用了硬编码文本 - 需要替换为翻译键
3. 翻译系统未初始化 - 确保调用了 `FuseLocalization.init()`

### Q: 如何添加新语言？

**A:** 需要3个步骤：

1. **在CSV中添加新列**:
   ```csv
   key,zh_CN,en_US,ja_JP
   FUSE_UI_BTN_ADD,添加,Add,追加
   ```

2. **在FuseLocalization中添加语言枚举**:
   ```gdscript
   enum Locale {
       ZH_CN,
       EN_US,
       JA_JP  # 新增
   }
   ```

3. **更新加载逻辑和显示名称**:
   参考现有代码添加日语支持

### Q: 性能影响如何？

**A:** 非常小：
- 初始化: < 1ms（仅首次）
- 翻译查询: 0.12μs/次（使用缓存）
- 内存占用: ~30KB（300个翻译键）

### Q: 如何检查翻译覆盖率？

**A:** 在Godot编辑器中运行翻译检查工具：
1. 点击 `项目 > 工具 > 执行脚本`
2. 选择 `addons/fuse/localization/translation_checker.gd`
3. 查看控制台输出

---

## 相关文档

- [翻译键参考](translation_keys.md) - 所有翻译键列表
- [实施计划](../docs/localization_implementation_plan_v2.md) - 系统设计和实现细节
- [API文档](#) - 待添加

---

## 获取帮助

如有问题或建议，请：
- 查看翻译键参考文档
- 运行翻译检查工具
- 提交Issue到项目仓库

---

**最后更新**: 2026-01-25
**文档版本**: 1.0
```

### Step 2: 更新本地化README

如果 `addons/fuse/localization/README.md` 不存在，创建它：

```markdown
# Fuse 本地化系统

Fuse可视化编程插件的轻量级本地化解决方案。

## 特性

- ✅ **轻量级**: 基于CSV文件，无需外部依赖
- ✅ **高性能**: 静态缓存优化，0.12μs/次查询
- ✅ **易维护**: 简单的CSV格式，易于编辑
- ✅ **自动化**: 三层语言检测，无需手动切换
- ✅ **完整覆盖**: 300+翻译键，100%覆盖率

## 快速开始

### 配置语言

编辑项目根目录的 `project.godot`:

```ini
[internationalization]
locale/locale="en"  # 或 "zh_CN"
```

### 基础使用

```gdscript
# 加载并初始化
var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
FuseLocalization.init()

# 翻译文本
var text = FuseLocalization.translate("FUSE_UI_BTN_ADD")

# 参数化翻译
var error = FuseLocalization.translate_format(
    "FUSE_ERROR_VAR_NOT_FOUND",
    {"name": "my_var"}
)
```

## 文档

- [用户使用指南](USER_GUIDE.md) - 如何使用本地化系统
- [翻译键参考](translation_keys.md) - 所有翻译键列表
- [实施计划](../docs/localization_implementation_plan_v2.md) - 架构设计和实现

## 工具

- **翻译检查工具**: `addons/fuse/localization/translation_checker.gd`
  - 在编辑器中执行检查翻译完整性

- **性能基准测试**: `test_scripts/performance_localization_benchmark.gd`
  - 测试系统性能和开销

## 架构

```
FuseLocalization (核心管理器)
├── CSV 解析器
├── 语言检测器 (三层检测)
├── 翻译缓存 (静态优化)
└── API (translate, translate_format)

使用方:
├── FuseLogger (本地化日志)
├── FuseError (本地化错误)
├── BaseInstruction (便捷方法)
└── BaseEvent (便捷方法)
```

## 性能

| 指标 | 值 |
|------|-----|
| 初始化时间 | < 1ms |
| 翻译查询 | 0.12μs/次 |
| 内存占用 | ~30KB |
| 首次加载 | 8μs |

## 语言支持

- ✅ 简体中文 (zh_CN)
- ✅ 英语 (en_US)
- 🚧 更多语言（可扩展）

## 贡献

### 添加新翻译

1. 编辑 `translations.csv`
2. 添加新行: `key,zh_CN,en_US`
3. 运行翻译检查工具验证

### 添加新语言

参考用户指南中的"如何添加新语言"章节。

---

**版本**: 1.0
**最后更新**: 2026-01-25
```

### Step 3: 提交文档

```bash
git add addons/fuse/localization/USER_GUIDE.md addons/fuse/localization/README.md
git commit -m "docs(localization): 添加用户使用指南和更新README"
```

---

## Task 6: 集成测试

**目标:** 创建完整的集成测试，验证所有功能

**Files:**
- Create: `addons/fuse/tests/test_stage4_integration.gd`
- Create: `test_scripts/test_language_detection.gd`

### Step 1: 创建语言检测测试

创建 `test_scripts/test_language_detection.gd`:

```gdscript
extends SceneTree

## 测试三层语言检测机制

func _init():
	print("================================================================================")
	print("语言检测集成测试")
	print("================================================================================")

	# 保存当前项目设置
	var original_locale = ProjectSettings.get_setting("internationalization/locale/locale")
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")

	# 测试1: 项目设置优先级
	print("\n测试 1: 项目设置优先级")
	ProjectSettings.set_setting("internationalization/locale/locale", "en")
	FuseLocalization.reload_translations()
	var locale1 = FuseLocalization.get_current_locale()
	print("  项目设置为 'en'，检测到: %s" % FuseLocalization.Locale.keys()[locale1])
	assert(locale1 == FuseLocalization.Locale.EN_US, "应该是EN_US")
	print("  ✅ 通过")

	# 测试2: 无效项目设置，回退到OS语言
	print("\n测试 2: 回退到操作系统语言")
	ProjectSettings.set_setting("internationalization/locale/locale", "")
	FuseLocalization.reload_translations()
	var locale2 = FuseLocalization.get_current_locale()
	var os_locale = TranslationServer.get_locale()
	print("  OS语言: %s，检测到: %s" % [os_locale, FuseLocalization.Locale.keys()[locale2]])
	if os_locale.begins_with("zh"):
		assert(locale2 == FuseLocalization.Locale.ZH_CN, "应该是ZH_CN")
	elif os_locale.begins_with("en"):
		assert(locale2 == FuseLocalization.Locale.EN_US, "应该是EN_US")
	print("  ✅ 通过")

	# 测试3: 语言缓存机制
	print("\n测试 3: 语言缓存机制")
	ProjectSettings.set_setting("internationalization/locale/locale", "zh_CN")
	FuseLocalization.init()  # 第一次初始化
	var locale3_1 = FuseLocalization.get_current_locale()

	ProjectSettings.set_setting("internationalization/locale/locale", "en")
	FuseLocalization.init()  # 第二次初始化，应使用缓存
	var locale3_2 = FuseLocalization.get_current_locale()

	print("  第一次: %s" % FuseLocalization.Locale.keys()[locale3_1])
	print("  第二次: %s" % FuseLocalization.Locale.keys()[locale3_2])
	assert(locale3_1 == locale3_2, "应该使用缓存的值")
	print("  ✅ 通过")

	# 恢复原始设置
	ProjectSettings.set_setting("internationalization/locale/locale", original_locale)

	print("\n================================================================================")
	print("所有测试通过！")
	print("================================================================================")
	quit()
```

### Step 2: 创建阶段4集成测试

创建 `addons/fuse/tests/test_stage4_integration.gd`:

```gdscript
extends Node

## 阶段4集成测试
## 测试本地化系统的完整性和性能

func _ready():
	print("================================================================================")
	print("阶段4本地化集成测试")
	print("================================================================================")

	var test_count = 0
	var passed = 0

	# 测试1: 翻译键数量
	print("\n测试 1: 翻译键数量统计")
	test_count += 1
	if _test_translation_key_count():
		passed += 1
		print("  ✅ 通过")
	else:
		print("  ❌ 失败")

	# 测试2: 翻译完整性
	print("\n测试 2: 翻译完整性")
	test_count += 1
	if _test_translation_completeness():
		passed += 1
		print("  ✅ 通过")
	else:
		print("  ❌ 失败")

	# 测试3: 性能基准
	print("\n测试 3: 性能基准")
	test_count += 1
	if _test_performance():
		passed += 1
		print("  ✅ 通过")
	else:
		print("  ❌ 失败")

	# 测试4: 语言检测
	print("\n测试 4: 语言检测机制")
	test_count += 1
	if _test_locale_detection():
		passed += 1
		print("  ✅ 通过")
	else:
		print("  ❌ 失败")

	# 总结
	print("\n================================================================================")
	print("测试总结: %d/%d 通过 (%.1f%%)" % [passed, test_count, float(passed) / test_count * 100])
	print("================================================================================")

	# 退出
	get_tree().quit_on_tree_unload = false
	await get_tree().process_frame
	get_tree().quit()


func _test_translation_key_count() -> bool:
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	FuseLocalization.init()
	var stats = FuseLocalization.get_translation_stats()

	print("  总翻译键数: %d" % stats.total_keys)
	print("  中文覆盖率: %.1f%%" % stats.zh_CN_coverage)
	print("  英文覆盖率: %.1f%%" % stats.en_US_coverage)

	return stats.total_keys >= 300 and stats.zh_CN_coverage == 100.0 and stats.en_US_coverage == 100.0


func _test_translation_completeness() -> bool:
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	FuseLocalization.init()
	var missing = FuseLocalization.get_missing_translations()

	if not missing.is_empty():
		print("  ⚠️  发现 %d 个缺失的翻译" % missing.size())
		for key in missing:
			print("    - %s" % key)
		return false

	print("  没有缺失的翻译")
	return true


func _test_performance() -> bool:
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	FuseLocalization.init()

	# 测试1000次翻译查询
	var iterations = 1000
	var start = Time.get_ticks_usec()
	for i in range(iterations):
		FuseLocalization.translate("FUSE_INSTRUCTION_PRINT_NAME")
	var elapsed = Time.get_ticks_usec() - start
	var avg_time = elapsed / float(iterations)

	print("  %d 次查询耗时: %d μs" % [iterations, elapsed])
	print("  平均时间: %.2f μs/次" % avg_time)
	print("  性能目标: < 1.0 μs/次")

	return avg_time < 1.0  # 小于1μs为优秀


func _test_locale_detection() -> bool:
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")

	# 测试重新加载
	FuseLocalization.reload_translations()
	var current_locale = FuseLocalization.get_current_locale()

	print("  当前语言: %s" % FuseLocalization.Locale.keys()[current_locale])
	print("  语言代码: %s" % FuseLocalization.get_locale_code())

	# 验证语言代码格式
	var locale_code = FuseLocalization.get_locale_code()
	var valid_codes = ["zh_CN", "en_US", "unknown"]

	if not locale_code in valid_codes:
		print("  ❌ 无效的语言代码: %s" % locale_code)
		return false

	return true
```

### Step 3: 运行集成测试

```bash
# 测试语言检测
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script test_scripts/test_language_detection.gd

# 测试阶段4集成
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" addons/fuse/tests/test_stage4_integration.tscn
```

Expected Output:
```
================================================================================
阶段4本地化集成测试
================================================================================

测试 1: 翻译键数量统计
  总翻译键数: 307
  中文覆盖率: 100.0%
  英文覆盖率: 100.0%
  ✅ 通过

测试 2: 翻译完整性
  没有缺失的翻译
  ✅ 通过

测试 3: 性能基准
  1000 次查询耗时: 120 μs
  平均时间: 0.12 μs/次
  性能目标: < 1.0 μs/次
  ✅ 通过

测试 4: 语言检测机制
  当前语言: EN_US
  语言代码: en_US
  ✅ 通过

================================================================================
测试总结: 4/4 通过 (100.0%)
================================================================================
```

### Step 4: 提交测试

```bash
git add test_scripts/test_language_detection.gd addons/fuse/tests/test_stage4_integration.gd
git commit -m "test(localization): 添加阶段4集成测试"
```

---

## Task 7: 更新实施计划文档

**目标:** 在实施计划中标注阶段4完成

**Files:**
- Modify: `addons/fuse/docs/localization_implementation_plan_v2.md`

### Step 1: 更新文档头部

修改文档开头的状态信息：

```markdown
## 📋 文档信息

- **创建日期**: 2026-01-22
- **版本**: 2.3
- **状态**: 阶段 1 已完成 ✅ | 阶段 2 已完成 ✅ | 阶段 3 已完成 ✅ | 阶段 4 已完成 ✅
- **阶段1完成日期**: 2026-01-24
- **阶段2完成日期**: 2026-01-24
- **阶段3完成日期**: 2026-01-25
- **阶段4完成日期**: 2026-01-25
```

### Step 2: 添加阶段4完成总结

在阶段4部分后添加完成总结：

```markdown
#### 阶段 4 完成总结

**成果统计**:
- 新增翻译键: 298 → 307+（新增 9+ 个）
- 创建工具: 3 个（翻译检查、性能基准、集成测试）
- 文档文件: 3 个（翻译键参考、用户指南、更新README）
- 集成测试: 4 个新测试（100% 通过）

**新增内容**:
- 翻译键参考文档（按类别组织）
- 用户使用指南（快速开始、常见问题）
- 翻译检查工具（EditorScript）
- 性能基准测试工具
- 语言检测集成测试
- 完整的集成测试套件

**质量指标**:
- ✅ 翻译覆盖率: 100%
- ✅ 性能测试: 优秀（0.12μs/次）
- ✅ 语言自动检测: 正常工作
- ✅ 完整文档: 已完成
```

### Step 3: 更新文档底部版本信息

```markdown
**最后更新**: 2026-01-25
**文档版本**: 2.3
**当前状态**: 阶段 1 已完成 ✅ | 阶段 2 已完成 ✅ | 阶段 3 已完成 ✅ | 阶段 4 已完成 ✅
**项目状态**: 本地化系统完整实现 ✅
```

### Step 4: 提交文档更新

```bash
git add addons/fuse/docs/localization_implementation_plan_v2.md
git commit -m "docs(localization): 标注阶段4完成，更新实施计划"
```

---

## 验收标准

### 功能完整性

- ✅ 翻译键数量: 300+ (当前307+)
- ✅ 翻译覆盖率: 100%
- ✅ 所有组件已本地化
- ✅ 静态缓存优化已完成

### 性能指标

- ✅ 翻译查询: < 1.0μs/次 (实际: 0.12μs)
- ✅ 初始化: < 1ms
- ✅ 内存占用: ~30KB
- ✅ 首次加载: < 10μs (实际: 8μs)

### 文档完整性

- ✅ 翻译键参考文档
- ✅ 用户使用指南
- ✅ README更新
- ✅ 实施计划完整

### 工具和测试

- ✅ 翻译检查工具
- ✅ 性能基准测试
- ✅ 集成测试套件
- ✅ 所有测试通过率: 100%

---

## 预期结果

完成后本地化系统将：

1. **功能完整**: 300+翻译键，100%覆盖率
2. **性能优秀**: 0.12μs/次查询，极低开销
3. **文档齐全**: 用户指南、参考文档、实施计划
4. **工具完善**: 检查工具、性能测试、集成测试
5. **易于维护**: CSV格式，简单的添加新语言流程

---

**总预计时间**: 2-3天（假设已完成阶段1-3）
**提交频率**: 每完成一个Task提交一次
**测试策略**: TDD，每个功能先写测试
