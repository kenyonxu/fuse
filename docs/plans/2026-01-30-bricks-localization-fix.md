# Bricks 本地化修复实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 修复 Bricks 插件中 115 个指令和事件脚本的本地化问题，使其符合 BricksLocalization CSV 本地化系统规范。

**架构：** Bricks 使用自定义的 CSV 本地化系统（而非 Godot 内置的 `tr()`）。修复工作分为两个阶段：(1) 为 Instructions 修复日志和错误消息的本地化，使用 `_log_*_localized()` 方法和 `BricksLocalization.translate()`；(2) 为 Events 修复动态描述的本地化，使用 `BricksLocalization.translate_format()` 处理 `_update_resource_name()` 和 `get_description()`。

**技术栈：**
- Godot 4.6 + GDScript 2.0
- BricksLocalization CSV 本地化系统
- 翻译文件：`addons/bricks/localization/translations.csv`
- 基类：BaseInstruction, BaseEvent, BaseCondition

**参考文档：**
- [本地化系统 README](../addons/bricks/localization/README.md)
- [本地化不完整脚本列表](../addons/bricks/docs/本地化不完整脚本列表.md)

---

## Phase 1: 准备工作

### Task 1: 创建翻译键备份和分支

**文件：**
- Copy: `addons/bricks/localization/translations.csv` → `addons/bricks/localization/translations.csv.backup`

**Step 1: 备份现有翻译文件**

```bash
cd "e:\Godot\GodotProjects\project-juicy-godot"
cp addons/bricks/localization/translations.csv addons/bricks/localization/translations.csv.backup
```

Expected: 创建 `translations.csv.backup` 文件

**Step 2: 创建功能分支**

```bash
git checkout -b feature/bricks-localization-fix
```

Expected: 切换到新分支 `feature/bricks-localization-fix`

**Step 3: 提交备份**

```bash
git add addons/bricks/localization/translations.csv.backup
git commit -m "chore: backup translations.csv before localization fix"
```

Expected: 提交成功

---

### Task 2: 验证本地化系统工作状态

**文件：**
- Test: Run translation checker

**Step 1: 运行翻译检查工具获取基线**

```bash
cd "e:\Godot\GodotProjects\project-juicy-godot"
E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --script addons/bricks/localization/translation_checker.gd --quit
```

Expected: 控制台输出当前翻译统计（键总数、覆盖率等）

**Step 2: 记录基线统计**

Create: `docs/plans/localization_baseline.txt`

内容应包括：
- 当前翻译键总数
- Instructions 覆盖率
- Events 覆盖率
- Conditions 覆盖率

**Step 3: 提交基线记录**

```bash
git add docs/plans/localization_baseline.txt
git commit -m "docs: record localization baseline before fix"
```

Expected: 提交成功

---

## Phase 2: Instructions 高优先级文件修复

### Task 3: 修复 animation/set_animation_speed.gd

**文件：**
- Modify: `addons/bricks/instructions/animation/set_animation_speed.gd:84-126`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加翻译键到 CSV**

在 `translations.csv` 文件末尾添加：

```csv
BRICKS_ERROR_SPEED_MUST_BE_POSITIVE,速度值必须大于 0,Speed value must be greater than 0
BRICKS_LOG_SET_ANIMATION_SPEED,设置动画速度: {node} → {speed}x,Set animation speed: {node} → {speed}x
BRICKS_ERROR_TARGET_NODE_EMPTY,目标节点不能为空,Target node cannot be empty
BRICKS_INSTRUCTION_SET_ANIMATION_SPEED_DESC,设置 {node} 动画速度为 {speed}x,Set {node} animation speed to {speed}x
```

**Step 2: 修复第84行的日志错误**

将：
```gdscript
_log_error("速度值必须大于 0")
```

改为：
```gdscript
_log_error_localized("BRICKS_ERROR_SPEED_MUST_BE_POSITIVE", {})
```

**Step 3: 修复第99行的错误日志**

将：
```gdscript
_log_error("节点不是 AnimationPlayer 类型")
```

改为：
```gdscript
_log_error_localized("BRICKS_ERROR_NOT_ANIMATION_PLAYER", {})
```

**Step 4: 修复第108行的信息日志**

将：
```gdscript
_log_info("设置动画速度: %s → %.2fx" % [target_node, speed])
```

改为：
```gdscript
_log_info_localized("BRICKS_LOG_SET_ANIMATION_SPEED", {"node": target_node, "speed": speed})
```

**Step 5: 修复验证错误（第117, 120行）**

将：
```gdscript
errors.append("目标节点不能为空")
errors.append("速度值必须大于 0")
```

改为：
```gdscript
errors.append(BricksLocalization.translate("BRICKS_ERROR_TARGET_NODE_EMPTY"))
errors.append(BricksLocalization.translate("BRICKS_ERROR_SPEED_MUST_BE_POSITIVE"))
```

**Step 6: 在编辑器中验证语法**

打开 Godot 编辑器，检查该文件是否有语法错误。

**Step 7: 提交更改**

```bash
git add addons/bricks/instructions/animation/set_animation_speed.gd
git add addons/bricks/localization/translations.csv
git commit -m "fix(instructions): localize set_animation_speed.gd

- Replace _log_* with _log_*_localized methods
- Use BricksLocalization.translate for validation errors
- Add 4 translation keys to CSV"
```

Expected: 提交成功

---

### Task 4: 修复 animation/stop_animation.gd

**文件：**
- Modify: `addons/bricks/instructions/animation/stop_animation.gd:92-114`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加翻译键到 CSV**

在 `translations.csv` 文件末尾添加：

```csv
BRICKS_LOG_PAUSE_ANIMATION,暂停动画: {name},Pause animation: {name}
BRICKS_LOG_STOP_ANIMATION,停止动画: {name},Stop animation: {name}
```

**Step 2: 修复第92行的错误日志**

将：
```gdscript
_log_error("节点不是 AnimationPlayer 类型")
```

改为：
```gdscript
_log_error_localized("BRICKS_ERROR_NOT_ANIMATION_PLAYER", {})
```

**Step 3: 修复第102, 105行的信息日志**

将：
```gdscript
_log_info("暂停动画: %s" % anim_player.name)
_log_info("停止动画: %s" % anim_player.name)
```

改为：
```gdscript
_log_info_localized("BRICKS_LOG_PAUSE_ANIMATION", {"name": anim_player.name})
_log_info_localized("BRICKS_LOG_STOP_ANIMATION", {"name": anim_player.name})
```

**Step 4: 修复验证错误（第114行）**

将：
```gdscript
errors.append("目标节点不能为空")
```

改为：
```gdscript
errors.append(BricksLocalization.translate("BRICKS_ERROR_TARGET_NODE_EMPTY"))
```

**Step 5: 在编辑器中验证语法**

**Step 6: 提交更改**

```bash
git add addons/bricks/instructions/animation/stop_animation.gd
git add addons/bricks/localization/translations.csv
git commit -m "fix(instructions): localize stop_animation.gd

- Replace _log_info with _log_info_localized
- Use BricksLocalization.translate for validation errors
- Add 2 translation keys"
```

---

### Task 5: 修复 camera/set_camera_limit.gd

**文件：**
- Modify: `addons/bricks/instructions/camera/set_camera_limit.gd:136-162`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加翻译键到 CSV**

```csv
BRICKS_ERROR_LIMIT_OUT_OF_RANGE,边界值超出有效范围,Limit value out of valid range
BRICKS_LOG_SET_CAMERA_LIMIT,设置相机边界 {side}: {value},Set camera limit {side}: {value}
BRICKS_ERROR_CAMERA_NODE_EMPTY,目标相机节点不能为空,Target camera node cannot be empty
```

**Step 2: 修复第136行的错误日志**

将：
```gdscript
_log_error("边界值超出有效范围")
```

改为：
```gdscript
_log_error_localized("BRICKS_ERROR_LIMIT_OUT_OF_RANGE", {})
```

**Step 3: 修复第153行的信息日志**

将：
```gdscript
_log_info("设置相机边界 %s: %s" % [side_name, value])
```

改为：
```gdscript
_log_info_localized("BRICKS_LOG_SET_CAMERA_LIMIT", {"side": side_name, "value": str(value)})
```

**Step 4: 修复验证错误（第162行）**

将：
```gdscript
errors.append("目标相机节点不能为空")
```

改为：
```gdscript
errors.append(BricksLocalization.translate("BRICKS_ERROR_CAMERA_NODE_EMPTY"))
```

**Step 5: 验证语法**

**Step 6: 提交更改**

```bash
git add addons/bricks/instructions/camera/set_camera_limit.gd
git add addons/bricks/localization/translations.csv
git commit -m "fix(instructions): localize set_camera_limit.gd

- Replace _log_* with _log_*_localized methods
- Add 3 translation keys"
```

---

### Task 6: 修复 camera/set_camera_zoom.gd

**文件：**
- Modify: `addons/bricks/instructions/camera/set_camera_zoom.gd:146-200`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加翻译键到 CSV**

```csv
BRICKS_ERROR_NOT_CAMERA2D,节点不是 Camera2D 类型,Node is not Camera2D type
BRICKS_ERROR_ZOOM_MUST_BE_POSITIVE,缩放值必须大于 0,Zoom value must be greater than 0
BRICKS_LOG_SET_CAMERA_ZOOM,设置相机缩放: {node} → {zoom},Set camera zoom: {node} → {zoom}
BRICKS_ERROR_ZOOM_VAR_NAME_EMPTY,缩放变量名不能为空,Zoom variable name cannot be empty
```

**Step 2: 修复第146行的错误日志**

将：
```gdscript
_log_error("节点不是 Camera2D 类型")
```

改为：
```gdscript
_log_error_localized("BRICKS_ERROR_NOT_CAMERA2D", {})
```

**Step 3: 修复第158, 171行的错误日志**

将：
```gdscript
_log_error("缩放值必须大于 0")
```

改为：
```gdscript
_log_error_localized("BRICKS_ERROR_ZOOM_MUST_BE_POSITIVE", {})
```

**Step 4: 修复第185行的信息日志**

将：
```gdscript
_log_info("设置相机缩放: %s → %.2f" % [target_node, zoom_value])
```

改为：
```gdscript
_log_info_localized("BRICKS_LOG_SET_CAMERA_ZOOM", {"node": target_node, "zoom": str(zoom_value)})
```

**Step 5: 修复验证错误（第193, 197, 200行）**

将：
```gdscript
errors.append("目标节点不能为空")
errors.append("缩放值必须大于 0")
errors.append("缩放变量名不能为空")
```

改为：
```gdscript
errors.append(BricksLocalization.translate("BRICKS_ERROR_TARGET_NODE_EMPTY"))
errors.append(BricksLocalization.translate("BRICKS_ERROR_ZOOM_MUST_BE_POSITIVE"))
errors.append(BricksLocalization.translate("BRICKS_ERROR_ZOOM_VAR_NAME_EMPTY"))
```

**Step 6: 验证语法**

**Step 7: 提交更改**

```bash
git add addons/bricks/instructions/camera/set_camera_zoom.gd
git add addons/bricks/localization/translations.csv
git commit -m "fix(instructions): localize set_camera_zoom.gd

- Replace _log_* with _log_*_localized methods
- Fix all validation error messages
- Add 4 translation keys"
```

---

### Task 7: 修复 debug/print_variable_value.gd（第1部分 - 日志消息）

**文件：**
- Modify: `addons/bricks/instructions/debug/print_variable_value.gd:144-272`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加翻译键到 CSV**

```csv
BRICKS_ERROR_NO_GLOBAL_VAR_ASSISTANT,未检测到 GlobalVariableAssistant 节点,GlobalVariableAssistant node not detected
BRICKS_WARNING_EXECUTION_CONTEXT_NULL,执行上下文为空,Execution context is null
BRICKS_LOG_GET_GLOBAL_VAR_SUCCESS,成功获取 GlobalVariableAssistant 单例，资源路径: {path},Successfully got GlobalVariableAssistant singleton, resource path: {path}
BRICKS_ERROR_VAR_NAME_EMPTY,变量名称不能为空,Variable name cannot be empty
BRICKS_ERROR_VAR_NAME_INVALID,变量名称包含无效字符或格式不正确,Variable name contains invalid characters or incorrect format
```

**Step 2: 修复第144行的错误日志**

将：
```gdscript
_log_error("未检测到 GlobalVariableAssistant 节点")
```

改为：
```gdscript
_log_error_localized("BRICKS_ERROR_NO_GLOBAL_VAR_ASSISTANT", {})
```

**Step 3: 修复第155行的警告日志**

将：
```gdscript
_log_warning("执行上下文为空")
```

改为：
```gdscript
_log_warning_localized("BRICKS_WARNING_EXECUTION_CONTEXT_NULL", {})
```

**Step 4: 修复第234, 240, 272行的错误日志**

将所有：
```gdscript
_log_error("...")
```

改为：
```gdscript
_log_error_localized("BRICKS_ERROR_...", {...})
```

**Step 5: 修复第247, 260行的警告日志**

将：
```gdscript
_log_warning("...")
```

改为：
```gdscript
_log_warning_localized("BRICKS_WARNING_...", {...})
```

**Step 6: 修复第249行的信息日志**

将：
```gdscript
_log_info("成功获取 GlobalVariableAssistant 单例，资源路径: %s" % resource_path)
```

改为：
```gdscript
_log_info_localized("BRICKS_LOG_GET_GLOBAL_VAR_SUCCESS", {"path": resource_path})
```

**Step 7: 修复验证错误（第312, 314, 321行）**

将：
```gdscript
errors.append("变量名称不能为空")
errors.append("变量名称包含无效字符或格式不正确")
errors.append("无法获取 GlobalVariableAssistant 单例实例，请确保插件已正确加载")
```

改为：
```gdscript
errors.append(BricksLocalization.translate("BRICKS_ERROR_VAR_NAME_EMPTY"))
errors.append(BricksLocalization.translate("BRICKS_ERROR_VAR_NAME_INVALID"))
errors.append(BricksLocalization.translate("BRICKS_ERROR_NO_GLOBAL_VAR_ASSISTANT"))
```

**Step 8: 验证语法**

**Step 9: 提交更改**

```bash
git add addons/bricks/instructions/debug/print_variable_value.gd
git add addons/bricks/localization/translations.csv
git commit -m "fix(instructions): localize print_variable_value.gd

- Replace all _log_* with _log_*_localized methods
- Fix all validation error messages
- Add 5 translation keys"
```

---

### Task 8: 修复 flow_control/for_each.gd

**文件：**
- Modify: `addons/bricks/instructions/flow_control/for_each.gd:235-322`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加翻译键到 CSV**

```csv
BRICKS_ERROR_NO_SCENE_TREE,无法获取 SceneTree,Cannot get SceneTree
BRICKS_LOG_BREAK_DETECTED,检测到 break 标志，跳出循环（索引: {index}）,Break flag detected, exiting loop (index: {index})
BRICKS_LOG_CONTINUE_DETECTED,检测到 continue 标志，跳过本次迭代（索引: {index}）,Continue flag detected, skipping iteration (index: {index})
BRICKS_WARNING_SKIP_EMPTY_INSTRUCTION,跳过空指令,Skip empty instruction
BRICKS_WARNING_INSTRUCTION_NOT_SYNCED,指令未同步完成: {name},Instruction not synced: {name}
```

**Step 2: 修复第235行的错误日志**

将：
```gdscript
_log_error("无法获取 SceneTree")
```

改为：
```gdscript
_log_error_localized("BRICKS_ERROR_NO_SCENE_TREE", {})
```

**Step 3: 修复第266, 271, 301行的信息日志**

将所有：
```gdscript
_log_info("检测到 break 标志...")
_log_info("检测到 continue 标志...")
```

改为：
```gdscript
_log_info_localized("BRICKS_LOG_BREAK_DETECTED", {"index": str(i)})
_log_info_localized("BRICKS_LOG_CONTINUE_DETECTED", {"index": str(i)})
```

**Step 4: 修复第287, 295行的警告日志**

将：
```gdscript
_log_warning("跳过空指令")
_log_warning("指令未同步完成: %s" % instruction_name)
```

改为：
```gdscript
_log_warning_localized("BRICKS_WARNING_SKIP_EMPTY_INSTRUCTION", {})
_log_warning_localized("BRICKS_WARNING_INSTRUCTION_NOT_SYNCED", {"name": instruction_name})
```

**Step 5: 修复验证错误（第316-322行）**

将所有中文字符串错误消息改为：
```gdscript
errors.append(BricksLocalization.translate("BRICKS_ERROR_..."))
```

**Step 6: 验证语法**

**Step 7: 提交更改**

```bash
git add addons/bricks/instructions/flow_control/for_each.gd
git add addons/bricks/localization/translations.csv
git commit -m "fix(instructions): localize for_each.gd

- Replace all _log_* with _log_*_localized methods
- Fix validation errors
- Add 5 translation keys"
```

---

### Task 9: 修复 flow_control/for_loop.gd

**文件：**
- Modify: `addons/bricks/instructions/flow_control/for_loop.gd:227-336`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加翻译键到 CSV**

```csv
BRICKS_ERROR_NEGATIVE_LOOP_COUNT,循环次数不能为负数: {count},Loop count cannot be negative: {count}
BRICKS_WARNING_LOOP_COUNT_TOO_LARGE,循环次数过大: {count}，可能导致性能问题,Loop count too large: {count}, may cause performance issues
BRICKS_LOG_START_FOR_LOOP,开始 For Loop，将执行 {count} 次迭代,Starting For Loop, will execute {count} iterations
BRICKS_LOG_FOR_LOOP_COMPLETED,For Loop 完成，执行了 {count} 次迭代,For Loop completed, executed {count} iterations
BRICKS_LOG_DEBUG_FOR_LOOP_RESET,For Loop 状态已重置,For Loop state reset
```

**Step 2: 修复第227, 239行的错误日志**

将：
```gdscript
_log_error("循环次数不能为负数: %d" % count)
```

改为：
```gdscript
_log_error_localized("BRICKS_ERROR_NEGATIVE_LOOP_COUNT", {"count": str(count)})
```

**Step 3: 修复第233行的警告日志**

将：
```gdscript
_log_warning("循环次数过大: %d，可能导致性能问题" % count)
```

改为：
```gdscript
_log_warning_localized("BRICKS_WARNING_LOOP_COUNT_TOO_LARGE", {"count": str(count)})
```

**Step 4: 修复第248, 257, 262, 272, 291, 294行的信息日志**

将所有 `_log_info(...)` 改为 `_log_info_localized(...)`，使用对应的翻译键。

**Step 5: 修复第269, 276行的调试日志**

将：
```gdscript
_log_debug("设置索引变量: %s = %d" % [...])
_log_debug("执行迭代 %d/%d" % [...])
```

改为：
```gdscript
_log_debug_localized("BRICKS_LOG_SET_INDEX_VARIABLE", {"var": var_name, "value": str(i)})
_log_debug_localized("BRICKS_LOG_EXECUTE_ITERATION", {"current": str(i), "total": str(count)})
```

**Step 6: 修复第276, 285行的警告日志**

将：
```gdscript
_log_warning("跳过空指令")
_log_warning("指令未同步完成: %s" % ...)
```

改为：
```gdscript
_log_warning_localized("BRICKS_WARNING_SKIP_EMPTY_INSTRUCTION", {})
_log_warning_localized("BRICKS_WARNING_INSTRUCTION_NOT_SYNCED", {"name": ...})
```

**Step 7: 修复第336行的调试日志**

将：
```gdscript
_log_debug("For Loop 状态已重置")
```

改为：
```gdscript
_log_debug_localized("BRICKS_LOG_DEBUG_FOR_LOOP_RESET", {})
```

**Step 8: 修复验证错误（第305-312行）**

**Step 9: 验证语法**

**Step 10: 提交更改**

```bash
git add addons/bricks/instructions/flow_control/for_loop.gd
git add addons/bricks/localization/translations.csv
git commit -m "fix(instructions): localize for_loop.gd

- Replace all _log_* with _log_*_localized methods
- Fix all validation errors
- Add 5 translation keys"
```

---

## Phase 3: Events Input 类别修复

### Task 10: 修复 events/input/on_input_action.gd（第1部分 - 添加翻译键）

**文件：**
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加翻译键到 CSV**

在 `translations.csv` 文件末尾添加：

```csv
# Input Action Event - Enum Hints
BRICKS_ENUM_TRIGGER_MODE,刚按下,刚释放,按住,按下或释放,Just Pressed,Just Released,Hold,Pressed or Released

# Input Action Event - Resource Names
BRICKS_EVENT_INPUT_ACTION_NOT_SET,未设置,Not Set
BRICKS_EVENT_INPUT_ACTION_RESOURCE_NAME,输入动作: {action},Input Action: {action}
BRICKS_EVENT_INPUT_ACTION_WITH_COUNT,输入动作: {action} ({count}个事件),Input Action: {action} ({count} events)

# Input Action Event - Trigger Modes
BRICKS_TRIGGER_MODE_JUST_PRESSED,刚按下时,When just pressed
BRICKS_TRIGGER_MODE_JUST_RELEASED,刚释放时,When just released
BRICKS_TRIGGER_MODE_HOLD,按住时,When holding
BRICKS_TRIGGER_MODE_PRESSED_OR_RELEASED,按下或释放时,When pressed or released

# Input Action Event - Descriptions
BRICKS_EVENT_ON_INPUT_ACTION_DESC_WHEN,当 {action} {mode} 触发,Triggered when {action} {mode}
BRICKS_EVENT_ON_INPUT_ACTION_DESC_ONCE,仅首次,Once only
BRICKS_EVENT_ON_INPUT_ACTION_DESC_EVERY_TIME,每次,Every time

# Input Action Event - Validation Errors
BRICKS_ERROR_INPUT_ACTION_NOT_SET,未设置 'Target Input Action','Target Input Action' not set
BRICKS_ERROR_INPUTMAP_NOT_AVAILABLE,InputMap 不可用,InputMap not available
BRICKS_ERROR_INPUT_ACTION_NOT_EXISTS,Input Action '{action}' 在项目中不存在,Input Action '{action}' does not exist in project
BRICKS_ERROR_INPUT_ACTION_NO_EVENTS,Input Action '{action}' 没有绑定任何输入事件,Input Action '{action}' has no input events bound
```

**Step 2: 提交翻译键**

```bash
git add addons/bricks/localization/translations.csv
git commit -m "feat(i18n): add translation keys for on_input_action event

- Add 14 translation keys for Input Action event
- Include enum hints, resource names, trigger modes
- Include validation error messages"
```

---

### Task 11: 修复 events/input/on_input_action.gd（第2部分 - 修复代码）

**文件：**
- Modify: `addons/bricks/events/input/on_input_action.gd:68-175`

**Step 1: 修复第68行的枚举提示**

将：
```gdscript
"hint_string": "刚按下,刚释放,按住,按下或释放"
```

改为：
```gdscript
"hint_string": BricksLocalization.translate("BRICKS_ENUM_TRIGGER_MODE")
```

**Step 2: 修复第151行的资源名称**

将：
```gdscript
var display_name = "未设置"
```

改为：
```gdscript
var display_name = BricksLocalization.translate("BRICKS_EVENT_INPUT_ACTION_NOT_SET")
```

**Step 3: 修复第160行的事件计数显示**

将：
```gdscript
display_name += " (%d个事件)" % events.size()
```

改为：
```gdscript
display_name = BricksLocalization.translate_format(
    "BRICKS_EVENT_INPUT_ACTION_WITH_COUNT",
    {"action": target_input_action, "count": str(events.size())}
)
```

**Step 4: 修复第181-187行的触发模式描述**

将：
```gdscript
match trigger_mode:
    TriggerMode.JUST_PRESSED:
        mode_desc = "刚按下时"
    TriggerMode.JUST_RELEASED:
        mode_desc = "刚释放时"
    ...
```

改为：
```gdscript
match trigger_mode:
    TriggerMode.JUST_PRESSED:
        mode_desc = BricksLocalization.translate("BRICKS_TRIGGER_MODE_JUST_PRESSED")
    TriggerMode.JUST_RELEASED:
        mode_desc = BricksLocalization.translate("BRICKS_TRIGGER_MODE_JUST_RELEASED")
    ...
```

**Step 5: 修复第130, 135, 140, 146行的验证错误**

将所有 `errors.append("中文错误")` 改为：
```gdscript
errors.append(BricksLocalization.translate("BRICKS_ERROR_INPUT_ACTION_..."))
```

**Step 6: 验证语法**

**Step 7: 在编辑器中测试**

在 Godot 编辑器中创建 OnInputAction 事件，验证：
- 枚举下拉菜单显示正确的文本
- 资源名称正确显示
- 验证错误正确显示

**Step 8: 提交更改**

```bash
git add addons/bricks/events/input/on_input_action.gd
git commit -m "fix(events): localize on_input_action event

- Replace enum hint_string with BricksLocalization.translate
- Localize _update_resource_name() method
- Localize get_description() method
- Fix validation error messages"
```

---

### Task 12: 修复 events/input/on_input_key.gd（第1部分 - 添加翻译键）

**文件：**
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加翻译键到 CSV**

```csv
# Input Key Event - Enum Hints
BRICKS_ENUM_KEY_TRIGGER_MODE,按下:0,释放:1,持续按下:2,Pressed:0,Released:1,Held:2

# Input Key Event - Resource Names
BRICKS_EVENT_INPUT_KEY_RESOURCE_NAME,按键{mode} [{key}] [{timing}],Key {mode} [{key}] [{timing}]
BRICKS_EVENT_INPUT_KEY_NOT_SET,未设置,Not Set
BRICKS_EVENT_INPUT_KEY_MODE_PRESSED,按键按下,Key Pressed
BRICKS_EVENT_INPUT_KEY_MODE_RELEASED,按键释放,Key Released
BRICKS_EVENT_INPUT_KEY_MODE_HELD,按键持续按下,Key Held
BRICKS_EVENT_INPUT_KEY_TIMING_ONCE,仅一次,Once
BRICKS_EVENT_INPUT_KEY_TIMING_DELAY,延迟 {delay},{Delay} {delay}
BRICKS_EVENT_INPUT_KEY_TIMING_INTERVAL,间隔 {interval},{Interval} {interval}

# Input Key Event - Descriptions
BRICKS_EVENT_ON_INPUT_KEY_DESC,{mode} {key} 键 [{timing}],When {key} key {mode} [{timing}]
BRICKS_EVENT_ON_INPUT_KEY_MODE_ONCE,仅检测一次,Detect only once
BRICKS_EVENT_ON_INPUT_KEY_MODE_DELAY,有 {delay} 秒延迟,With {delay}s delay
BRICKS_EVENT_ON_INPUT_KEY_MODE_INTERVAL,每次触发间隔 {interval} 秒,Interval {interval}s between triggers

# Input Key Event - Validation Errors
BRICKS_ERROR_KEY_CODE_NOT_SET,必须指定有效的按键代码,Must specify valid key code
BRICKS_ERROR_KEY_DELAY_NEGATIVE,延迟时间不能为负数,Delay time cannot be negative
BRICKS_ERROR_KEY_INTERVAL_TOO_SMALL,间隔时间不能小于 0.1 秒,Interval cannot be less than 0.1s
```

**Step 2: 提交翻译键**

```bash
git add addons/bricks/localization/translations.csv
git commit -m "feat(i18n): add translation keys for on_input_key event

- Add 18 translation keys for Input Key event
- Include enum hints, resource names, timing modes
- Include validation error messages"
```

---

### Task 13: 修复 events/input/on_input_key.gd（第2部分 - 修复代码）

**文件：**
- Modify: `addons/bricks/events/input/on_input_key.gd:14-281`

**Step 1: 修复第14行的枚举提示**

将：
```gdscript
"hint_string": "按下:0,释放:1,持续按下:2"
```

改为：
```gdscript
"hint_string": BricksLocalization.translate("BRICKS_ENUM_KEY_TRIGGER_MODE")
```

**Step 2: 修复第77-84行的 _update_resource_name()**

将整个方法改为使用 `BricksLocalization.translate_format()`：

```gdscript
func _update_resource_name() -> void:
    if key_code == KEY_NONE:
        resource_name = BricksLocalization.translate("BRICKS_EVENT_INPUT_KEY_NOT_SET")
        return

    var mode_key = ""
    match trigger_mode:
        TriggerMode.JUST_PRESSED:
            mode_key = "BRICKS_EVENT_INPUT_KEY_MODE_PRESSED"
        TriggerMode.JUST_RELEASED:
            mode_key = "BRICKS_EVENT_INPUT_KEY_MODE_RELEASED"
        TriggerMode.HELD:
            mode_key = "BRICKS_EVENT_INPUT_KEY_MODE_HELD"

    var mode_text = BricksLocalization.translate(mode_key)

    var timing_key = ""
    if trigger_once:
        timing_key = "BRICKS_EVENT_INPUT_KEY_TIMING_ONCE"
    elif delay > 0:
        timing_key = BricksLocalization.translate_format(
            "BRICKS_EVENT_INPUT_KEY_TIMING_DELAY",
            {"delay": str(delay)}
        )
    elif interval > 0:
        timing_key = BricksLocalization.translate_format(
            "BRICKS_EVENT_INPUT_KEY_TIMING_INTERVAL",
            {"interval": str(interval)}
        )

    resource_name = BricksLocalization.translate_format(
        "BRICKS_EVENT_INPUT_KEY_RESOURCE_NAME",
        {"mode": mode_text, "key": OS.get_keycode_string(key_code), "timing": timing_key}
    )
```

**Step 3: 修复第244-254行的 get_description()**

使用类似的模式，将所有中文字符串替换为翻译键。

**Step 4: 修复第267, 272-281行的验证错误**

将所有中文字符串错误改为：
```gdscript
errors.append(BricksLocalization.translate("BRICKS_ERROR_KEY_..."))
```

**Step 5: 验证语法**

**Step 6: 提交更改**

```bash
git add addons/bricks/events/input/on_input_key.gd
git commit -m "fix(events): localize on_input_key event

- Replace all hardcoded Chinese strings with BricksLocalization
- Localize _update_resource_name() method
- Localize get_description() method
- Fix validation error messages"
```

---

## Phase 4: 验证和测试

### Task 14: 运行翻译完整性检查

**文件：**
- Test: Run translation checker

**Step 1: 运行翻译检查工具**

```bash
cd "e:\Godot\GodotProjects\project-juicy-godot"
E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --script addons/bricks/localization/translation_checker.gd --quit
```

Expected: 控制台输出显示新增的翻译键已生效

**Step 2: 对比基线统计**

对比 `docs/plans/localization_baseline.txt` 和当前输出，确认：
- 翻译键总数增加
- Instructions 覆盖率提升
- Events 覆盖率提升

**Step 3: 记录改进统计**

Create: `docs/plans/localization_improvement.txt`

记录改进数据。

**Step 4: 提交改进记录**

```bash
git add docs/plans/localization_improvement.txt
git commit -m "docs: record localization improvements after phase 1-3"
```

---

### Task 15: 在编辑器中手动测试修复的文件

**文件：**
- Test: Manual testing in Godot editor

**Step 1: 测试 Instructions 修复**

打开 Godot 编辑器：

1. 创建测试场景
2. 添加修复后的 Instructions：
   - set_animation_speed
   - stop_animation
   - set_camera_limit
   - set_camera_zoom
   - print_variable_value
   - for_each
   - for_loop

3. 测试验证错误是否正确显示为本地化文本
4. 测试日志消息是否输出本地化文本（查看控制台）

**Step 2: 测试 Events 修复**

1. 创建 Trigger 节点
2. 添加修复后的 Events：
   - OnInputAction
   - OnInputKey

3. 检查编辑器中的资源名称是否正确显示
4. 检查枚举下拉菜单是否显示本地化文本
5. 测试验证错误是否正确显示

**Step 3: 测试语言切换**

修改 `project.godot`:

```ini
[internationalization]
locale/locale="en"
```

重启编辑器，验证所有文本切换为英文。

**Step 4: 创建测试报告**

Create: `docs/plans/localization_test_report.md`

记录测试结果，包括：
- 通过的测试项
- 失败的测试项
- 发现的问题

**Step 5: 提交测试报告**

```bash
git add docs/plans/localization_test_report.md
git commit -m "docs: add manual localization test report"
```

---

## Phase 5: 清理和文档

### Task 16: 更新本地化不完整脚本列表

**文件：**
- Modify: `addons/bricks/docs/本地化不完整脚本列表.md`

**Step 1: 更新文档状态**

在文档顶部添加进度跟踪：

```markdown
## 修复进度

- [x] Phase 1: 准备工作
- [x] Phase 2: Instructions 高优先级文件 (7/7)
- [x] Phase 3: Events Input 类别 (2/58)
- [ ] Phase 4: Events Physics 类别 (0/4)
- [ ] Phase 5: Events 其他类别 (0/52)
```

**Step 2: 更新统计数据**

更新概览统计表格，反映已完成的工作。

**Step 3: 标记已完成的文件**

在详细清单中，将已完成的文件标记为 ✅。

**Step 4: 提交文档更新**

```bash
git add addons/bricks/docs/本地化不完整脚本列表.md
git commit -m "docs: update localization progress tracker

- Mark phase 1-3 as complete
- Update progress tracking
- Update statistics"
```

---

### Task 17: 创建后续工作计划

**文件：**
- Create: `docs/plans/2026-01-30-bricks-localization-phase2.md`

**Step 1: 创建后续阶段计划**

包含：
- Events Physics 类别修复计划
- Events Animation 类别修复计划
- Events Lifecycle 类别修复计划
- 剩余 Instructions 文件检查和修复
- 自动化本地化检查工具设计

**Step 2: 提交后续计划**

```bash
git add docs/plans/2026-01-30-bricks-localization-phase2.md
git commit -m "docs: create phase 2 localization plan

- Outline Physics events fixes
- Outline Animation events fixes
- Design automation tools"
```

---

### Task 18: 合并到主分支

**Step 1: 运行完整测试套件**

确保所有现有测试仍然通过。

**Step 2: 检查是否有遗留问题**

```bash
git status
```

**Step 3: 合并到开发分支**

```bash
git checkout Develop_brick
git merge feature/bricks-localization-fix
```

**Step 4: 推送到远程**

```bash
git push origin Develop_brick
```

**Step 5: 创建 Pull Request（如果需要）**

```bash
gh pr create --title "fix: Bricks localization fixes (Phase 1-3)" \
            --body "## Summary
- Fixed 7 high-priority instruction files
- Fixed 2 input event files
- Added 47+ translation keys
- Improved localization coverage from 30% to ~35%

## Test plan
- [x] Manual testing in Godot editor
- [x] Translation checker passes
- [x] Language switching works

## Related issues
Refs: localization incomplete script list"
```

---

## 附录

### A. 翻译键命名规范速查

**Instructions:**
```
BRICKS_ERROR_[错误类型]
BRICKS_LOG_[日志类型]
BRICKS_WARNING_[警告类型]
```

**Events:**
```
BRICKS_ENUM_[枚举类型]
BRICKS_EVENT_[类型]_[动作]_RESOURCE_NAME
BRICKS_EVENT_[类型]_[动作]_DESCRIPTION
BRICKS_ERROR_[错误类型]
```

### B. 常用代码片段

**日志本地化：**
```gdscript
# 替换
_log_error("错误消息")
# 为
_log_error_localized("BRICKS_ERROR_MESSAGE_KEY", {})

# 参数化
_log_info("值: %s" % value)
# 为
_log_info_localized("BRICKS_LOG_VALUE", {"value": str(value)})
```

**验证错误本地化：**
```gdscript
# 替换
errors.append("验证错误")
# 为
errors.append(BricksLocalization.translate("BRICKS_ERROR_VALIDATE"))
```

**动态描述本地化：**
```gdscript
# 替换
resource_name = "名称: %s" % param
# 为
resource_name = BricksLocalization.translate_format(
    "BRICKS_EVENT_RESOURCE_NAME",
    {"param": param}
)
```

### C. 故障排除

**问题：翻译键找不到**
- 检查 CSV 文件中是否存在该键
- 检查键名拼写是否正确
- 检查 CSV 文件格式（逗号分隔）

**问题：参数化翻译不工作**
- 检查占位符格式：`{param}`
- 检查传递的参数字典
- 确保使用 `translate_format` 而不是 `translate`

**问题：语言切换不生效**
- 检查 `project.godot` 中的 `locale/locale` 设置
- 重启编辑器
- 检查 `BricksLocalization.init()` 是否被调用

---

**计划版本：** 1.0
**创建日期：** 2026-01-30
**预计工作量：** Phase 1-3: 约 4-6 小时
**优先级：** 高（P0 - 用户可见文本）
**风险等级：** 低（只修改文本，不改变逻辑）
