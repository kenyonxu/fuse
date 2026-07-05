# Bricks 插件阶段2 - 编辑器 UI 本地化实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Bricks 可视化编程插件的所有编辑器 UI 界面添加中英双语支持，自动跟随编辑器语言设置。

**Architecture:** 基于阶段1建立的 BricksLocalization 系统，修改所有编辑器 UI 组件使用 `translate()` 方法替换硬编码文本。使用动态加载避免循环依赖，确保每个组件在 `_ready()` 时刷新本地化文本。

**Tech Stack:** Godot 4.5 GDScript, BricksLocalization (CSV-based), EditorInterface API

---

## 前置准备

### 参考文档
- [localization_implementation_plan_v2.md](../../addons/bricks/docs/localization_implementation_plan_v2.md) - 总体实施计划
- [README.md](../../addons/bricks/localization/README.md) - BricksLocalization API 文档
- [STAGE1_COMPLETE.md](../../addons/bricks/localization/STAGE1_COMPLETE.md) - 阶段1完成报告

### 现有翻译键
UI 翻译键已在 `translations.csv` 中定义，包括：
- `BRICKS_UI_*` - 通用 UI 文本（按钮、标签等）
- 指令选择器特定键已存在

---

## Task 1: 本地化指令选择器对话框

**Files:**
- Modify: `addons/bricks/editor/instruction_selector/instructions_selector.gd:49-91`

**Step 1: 修改 _setup_dialog() 方法本地化标题**

将硬编码的"添加指令"替换为翻译键：

```gdscript
func _setup_dialog():
    # 设置对话框属性 - 更大的窗口尺寸
    var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")
    if BricksLocalization_class and BricksLocalization_class.has_method("translate"):
        self.title = BricksLocalization_class.translate("BRICKS_UI_INSTRUCTION_SELECTOR_TITLE")
    else:
        self.title = "添加指令"  # 回退

    self.size = Vector2i(800, 800)
    self.popup_centered()
```

**Step 2: 修改 _create_ui() 方法本地化搜索框占位符**

```gdscript
func _create_ui():
    var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")

    # 简化布局：只有搜索框 + 分类树
    var main_vbox = VBoxContainer.new()

    # 搜索框
    search_box = LineEdit.new()
    if BricksLocalization_class and BricksLocalization_class.has_method("translate"):
        search_box.placeholder_text = BricksLocalization_class.translate("BRICKS_UI_SEARCH_PLACEHOLDER")
    else:
        search_box.placeholder_text = "搜索指令..."  # 回退

    search_box.text_changed.connect(_on_search_text_changed)
    main_vbox.add_child(search_box)

    # ... 其余代码保持不变 ...
```

**Step 3: 测试指令选择器本地化**

打开 Godot 编辑器，测试步骤：
1. 创建一个带有 Trigger 组件的节点
2. 在 Inspector 中点击 instructions 数组的"添加"按钮
3. 观察指令选择器对话框标题和搜索框占位符
4. 在编辑器设置中切换语言（Editor → Editor Settings → Interface → Editor Language）
5. 重新打开指令选择器，验证文本已更新

**预期结果**：
- 中文环境：标题显示"指令选择器"，占位符显示"搜索指令..."
- 英文环境：标题显示"Instruction Selector"，占位符显示"Search instructions..."

**Step 4: 提交修改**

```bash
git add addons/bricks/editor/instruction_selector/instructions_selector.gd
git commit -m "feat(stage2): localize instruction selector dialog title and search placeholder"
```

---

## Task 2: 本地化输入键选择器对话框

**Files:**
- Modify: `addons/bricks/editor/input_key_selector/input_key_dialog.gd`
- Reference: `addons/bricks/localization/translations.csv` (查看 UI 翻译键)

**Step 1: 读取输入键对话框文件查看当前硬编码文本**

```bash
grep -n "\".*\"" addons/bricks/editor/input_key_selector/input_key_dialog.gd | head -20
```

**Step 2: 在 translations.csv 中添加输入键对话框专用键（如果缺失）**

检查以下键是否存在，如不存在则添加：
```csv
BRICKS_UI_INPUT_KEY_TITLE,选择输入键,Select Input Key
BRICKS_UI_INPUT_KEY_LABEL,输入键名称,Input Key Name
BRICKS_UI_INPUT_KEY_HINT,输入要监听的按键名称,Enter the key name to listen for
```

**Step 3: 修改对话框标题和标签使用翻译**

在 `input_key_dialog.gd` 中找到标题设置代码，修改为：

```gdscript
# 在 _ready() 或类似方法中
var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")
if BricksLocalization_class and BricksLocalization_class.has_method("translate"):
    self.title = BricksLocalization_class.translate("BRICKS_UI_INPUT_KEY_TITLE")
    label.text = BricksLocalization_class.translate("BRICKS_UI_INPUT_KEY_LABEL")
    line_edit.placeholder_text = BricksLocalization_class.translate("BRICKS_UI_INPUT_KEY_HINT")
else:
    # 回退到硬编码文本
    self.title = "选择输入键"
    label.text = "输入键名称"
    line_edit.placeholder_text = "输入要监听的按键名称"
```

**Step 4: 测试输入键对话框本地化**

1. 打开任意节点的 Inspector
2. 找到使用输入键的指令或事件
3. 点击输入键选择按钮
4. 验证对话框标题和标签已本地化
5. 切换编辑器语言并重新打开验证

**Step 5: 提交修改**

```bash
git add addons/bricks/editor/input_key_selector/input_key_dialog.gd
git commit -m "feat(stage2): localize input key dialog"
```

---

## Task 3: 本地化静态分析面板

**Files:**
- Modify: `addons/bricks/editor/static_analysis/static_analysis_panel.gd`

**Step 1: 查看静态分析面板的硬编码文本**

```bash
grep -n "\".*\"" addons/bricks/editor/static_analysis/static_analysis_panel.gd | grep -E "(标题|title|按钮|button|label|结果|result)" | head -20
```

**Step 2: 在 translations.csv 中添加静态分析面板专用键**

```csv
BRICKS_UI_STATIC_ANALYSIS_TITLE,静态分析,Static Analysis
BRICKS_UI_STATIC_ANALYSIS_RUN,运行分析,Run Analysis
BRICKS_UI_STATIC_ANALYSIS_RESULTS,分析结果,Analysis Results
BRICKS_UI_STATIC_ANALYSIS_NO_ISSUES,未发现问题,No issues found
BRICKS_UI_STATIC_ANALYSIS_ISSUES_FOUND,发现问题：{count},Issues found: {count}
```

**Step 3: 修改面板代码使用翻译**

在 `static_analysis_panel.gd` 中找到 UI 初始化代码：

```gdscript
func _ready():
    var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")

    # 本地化标题
    if BricksLocalization_class and BricksLocalization_class.has_method("translate"):
        title_label.text = BricksLocalization_class.translate("BRICKS_UI_STATIC_ANALYSIS_TITLE")
        run_button.text = BricksLocalization_class.translate("BRICKS_UI_STATIC_ANALYSIS_RUN")
    else:
        # 回退
        title_label.text = "静态分析"
        run_button.text = "运行分析"

    # 连接信号
    run_button.pressed.connect(_on_run_button_pressed)

func _on_run_button_pressed():
    # ... 执行分析逻辑 ...

    # 显示结果
    if BricksLocalization_class and BricksLocalization_class.has_method("translate_format"):
        if issue_count == 0:
            result_label.text = BricksLocalization_class.translate("BRICKS_UI_STATIC_ANALYSIS_NO_ISSUES")
        else:
            result_label.text = BricksLocalization_class.translate_format("BRICKS_UI_STATIC_ANALYSIS_ISSUES_FOUND", {"count": str(issue_count)})
    else:
        # 回退
        result_label.text = "分析完成"
```

**Step 4: 测试静态分析面板本地化**

1. 在 Godot 编辑器中打开 Bricks → Static Analysis 面板
2. 验证面板标题和按钮已本地化
3. 点击"运行分析"按钮
4. 验证结果显示已本地化（包括参数化翻译）
5. 切换编辑器语言并重新验证

**Step 5: 提交修改**

```bash
git add addons/bricks/editor/static_analysis/static_analysis_panel.gd
git commit -m "feat(stage2): localize static analysis panel"
```

---

## Task 4: 本地化调试可视化器

**Files:**
- Modify: `addons/bricks/editor/debugging/debug_visualizer.gd`

**Step 1: 查看调试可视化器的硬编码文本**

```bash
grep -n "\".*\"" addons/bricks/editor/debugging/debug_visualizer.gd | head -30
```

**Step 2: 在 translations.csv 中添加调试可视化器专用键**

```csv
BRICKS_UI_DEBUG_VISUALIZER_TITLE,调试可视化,Debug Visualizer
BRICKS_UI_DEBUG_VISUALIZER_PAUSE,暂停,Pause
BRICKS_UI_DEBUG_VISUALIZER_RESUME,继续,Resume
BRICKS_UI_DEBUG_VISUALIZER_STEP,单步,Step
BRICKS_UI_DEBUG_VISUALIZER_STOP,停止,Stop
BRICKS_UI_DEBUG_VISUALIZER_CLEAR,清除,Clear
BRICKS_UI_DEBUG_VISUALIZER_NO_DATA,无调试数据,No debug data
```

**Step 3: 修改调试可视化器代码使用翻译**

```gdscript
func _ready():
    var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")

    # 本地化标题和按钮
    if BricksLocalization_class and BricksLocalization_class.has_method("translate"):
        title_label.text = BricksLocalization_class.translate("BRICKS_UI_DEBUG_VISUALIZER_TITLE")
        pause_button.text = BricksLocalization_class.translate("BRICKS_UI_DEBUG_VISUALIZER_PAUSE")
        resume_button.text = BricksLocalization_class.translate("BRICKS_UI_DEBUG_VISUALIZER_RESUME")
        step_button.text = BricksLocalization_class.translate("BRICKS_UI_DEBUG_VISUALIZER_STEP")
        stop_button.text = BricksLocalization_class.translate("BRICKS_UI_DEBUG_VISUALIZER_STOP")
        clear_button.text = BricksLocalization_class.translate("BRICKS_UI_DEBUG_VISUALIZER_CLEAR")
    else:
        # 回退到硬编码文本
        title_label.text = "调试可视化"
        pause_button.text = "暂停"
        resume_button.text = "继续"
        step_button.text = "单步"
        stop_button.text = "停止"
        clear_button.text = "清除"
```

**Step 4: 测试调试可视化器本地化**

1. 在 Godot 编辑器中运行包含 Bricks Trigger 的场景
2. 打开 Bricks → Debug Visualizer 面板
3. 验证所有按钮已本地化
4. 使用调试功能（暂停、继续、单步执行）
5. 切换编辑器语言并重新验证

**Step 5: 提交修改**

```bash
git add addons/bricks/editor/debugging/debug_visualizer.gd
git commit -m "feat(stage2): localize debug visualizer"
```

---

## Task 5: 本地化执行跟踪器

**Files:**
- Modify: `addons/bricks/editor/debugging/execution_tracker.gd`

**Step 1: 查看执行跟踪器的硬编码文本**

```bash
grep -n "\".*\"" addons/bricks/editor/debugging/execution_tracker.gd | head -30
```

**Step 2: 在 translations.csv 中添加执行跟踪器专用键**

```csv
BRICKS_UI_EXECUTION_TRACKER_TITLE,执行跟踪器,Execution Tracker
BRICKS_UI_EXECUTION_TRACKER_ENABLE,启用跟踪,Enable Tracking
BRICKS_UI_EXECUTION_TRACKER_DISABLE,禁用跟踪,Disable Tracking
BRICKS_UI_EXECUTION_TRACKER_CLEAR,清除跟踪,Clear Tracking
BRICKS_UI_EXECUTION_TRACKER_NO_TRACE,无执行跟踪数据,No execution trace data
BRICKS_UI_EXECUTION_TRACKER_TRACE_COUNT,跟踪数量：{count},Trace count: {count}
```

**Step 3: 修改执行跟踪器代码使用翻译**

```gdscript
func _ready():
    var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")

    # 本地化标题和按钮
    if BricksLocalization_class and BricksLocalization_class.has_method("translate"):
        title_label.text = BricksLocalization_class.translate("BRICKS_UI_EXECUTION_TRACKER_TITLE")
        enable_button.text = BricksLocalization_class.translate("BRICKS_UI_EXECUTION_TRACKER_ENABLE")
        disable_button.text = BricksLocalization_class.translate("BRICKS_UI_EXECUTION_TRACKER_DISABLE")
        clear_button.text = BricksLocalization_class.translate("BRICKS_UI_EXECUTION_TRACKER_CLEAR")
    else:
        # 回退
        title_label.text = "执行跟踪器"
        enable_button.text = "启用跟踪"
        disable_button.text = "禁用跟踪"
        clear_button.text = "清除跟踪"

func _update_trace_display():
    var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")

    if trace_data.is_empty():
        if BricksLocalization_class and BricksLocalization_class.has_method("translate"):
            status_label.text = BricksLocalization_class.translate("BRICKS_UI_EXECUTION_TRACKER_NO_TRACE")
        else:
            status_label.text = "无执行跟踪数据"
    else:
        if BricksLocalization_class and BricksLocalization_class.has_method("translate_format"):
            status_label.text = BricksLocalization_class.translate_format("BRICKS_UI_EXECUTION_TRACKER_TRACE_COUNT", {"count": str(trace_data.size())})
        else:
            status_label.text = "跟踪数量：%d" % trace_data.size()
```

**Step 4: 测试执行跟踪器本地化**

1. 在 Godot 编辑器中打开 Bricks → Execution Tracker 面板
2. 验证面板标题和按钮已本地化
3. 点击"启用跟踪"并触发一些指令执行
4. 验证跟踪计数显示已本地化（包括参数化翻译）
5. 切换编辑器语言并重新验证

**Step 5: 提交修改**

```bash
git add addons/bricks/editor/debugging/execution_tracker.gd
git commit -m "feat(stage2): localize execution tracker"
```

---

## Task 6: 本地化 Inspector 插件属性标签

**Files:**
- Modify: `addons/bricks/editor/instruction_selector/instructions_array_inspector_plugin.gd`
- Modify: `addons/bricks/editor/input_key_selector/input_key_inspector_plugin.gd`
- Reference: `addons/bricks/localization/translations.csv`

**Step 1: 查看指令数组 Inspector 插件的属性定义**

```bash
grep -n "get_property_list\|set\|hint_string" addons/bricks/editor/instruction_selector/instructions_array_inspector_plugin.gd | head -40
```

**Step 2: 在 translations.csv 中添加 Inspector 属性标签键**

检查是否存在，如不存在则添加：
```csv
# 已存在于 translations.csv:
# BRICKS_UI_LABEL_INSTRUCTIONS,指令,Instructions
# BRICKS_UI_LABEL_NAME,名称,Name
# BRICKS_UI_LABEL_TYPE,类型,Type
# BRICKS_UI_LABEL_VALUE,值,Value
# BRICKS_UI_LABEL_DESCRIPTION,描述,Description
```

**Step 3: 修改指令数组 Inspector 插件使用本地化标签**

在 `instructions_array_inspector_plugin.gd` 中找到 `_get_property_list()` 方法：

```gdscript
func _get_property_list() -> Array[Dictionary]:
    var properties = []

    var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")

    # 本地化属性名称
    var instructions_label = "指令"
    if BricksLocalization_class and BricksLocalization_class.has_method("translate"):
        instructions_label = BricksLocalization_class.translate("BRICKS_UI_LABEL_INSTRUCTIONS")

    properties.append({
        "name": "instructions",
        "type": TYPE_ARRAY,
        "hint": PROPERTY_HINT_NONE,
        "usage": PROPERTY_USAGE_DEFAULT,
        "hint_string": "%s/%s:%s" % [instructions_label, "BaseInstruction", ""]
    })

    return properties
```

**Step 4: 修改输入键 Inspector 插件使用本地化标签**

在 `input_key_inspector_plugin.gd` 中找到属性定义部分：

```gdscript
func _get_property_list() -> Array[Dictionary]:
    var properties = []

    var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")

    # 本地化属性名称
    var key_label = "输入键"
    if BricksLocalization_class and BricksLocalization_class.has_method("translate"):
        key_label = BricksLocalization_class.translate("BRICKS_UI_LABEL_NAME")

    properties.append({
        "name": "input_key",
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_NONE,
        "usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
        "hint_string": key_label
    })

    return properties
```

**Step 5: 测试 Inspector 插件本地化**

1. 在 Godot 编辑器中选择一个带有 Trigger 的节点
2. 在 Inspector 中查看 instructions 属性
3. 验证属性标签已本地化（中文："指令"，英文："Instructions"）
4. 查看 Input Key 相关属性的标签
5. 切换编辑器语言并刷新 Inspector，验证标签已更新

**Step 6: 提交修改**

```bash
git add addons/bricks/editor/instruction_selector/instructions_array_inspector_plugin.gd
git add addons/bricks/editor/input_key_selector/input_key_inspector_plugin.gd
git commit -m "feat(stage2): localize inspector plugin property labels"
```

---

## Task 7: 添加缺失的翻译键并验证覆盖率

**Files:**
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 审查所有已修改的文件，收集硬编码文本**

```bash
# 搜索所有编辑器 GD 文件中的中文字符串
grep -r "\"[\u4e00-\u9fa5]*\"" addons/bricks/editor/ --include="*.gd" | grep -v "本地化\|翻译\|language\|locale" | head -30
```

**Step 2: 在 translations.csv 中补充缺失的翻译键**

将步骤1中发现的硬编码文本添加到 `translations.csv`：

```csv
# 示例格式（根据实际发现的内容添加）
BRICKS_UI_DEBUG_PANEL,调试面板,Debug Panel
BRICKS_UI_TRACE_PANEL,跟踪面板,Trace Panel
# ... 根据实际需要添加
```

**Step 3: 验证翻译键覆盖率**

```bash
# 统计翻译键数量
grep "^BRICKS_UI_" addons/bricks/localization/translations.csv | wc -l

# 检查是否有空翻译
awk -F',' 'NR>1 {if ($2=="" || $3=="") print NR": "$1}' addons/bricks/localization/translations.csv
```

**Step 4: 运行阶段1的本地化测试确保兼容性**

在 Godot 编辑器中：
1. 打开 `addons/bricks/tests/test_localization.tscn` 场景
2. 按 F5 运行测试场景
3. 验证所有 13 个测试仍然通过
4. 检查控制台输出是否有新的翻译警告

**Step 5: 提交修改**

```bash
git add addons/bricks/localization/translations.csv
git commit -m "feat(stage2): add missing UI translation keys"
```

---

## Task 8: 集成测试和文档更新

**Files:**
- Create: `addons/bricks/localization/STAGE2_COMPLETE.md`
- Modify: `addons/bricks/docs/localization_implementation_plan_v2.md`

**Step 1: 运行完整的编辑器 UI 本地化测试**

在 Godot 编辑器中执行以下测试场景：

1. **指令选择器测试**：
   - 打开指令选择器
   - 验证标题和搜索框已本地化
   - 切换编辑器语言，重新打开验证

2. **输入键对话框测试**：
   - 打开输入键选择器
   - 验证对话框标题和标签已本地化
   - 切换语言验证

3. **静态分析面板测试**：
   - 打开静态分析面板
   - 运行分析，验证结果显示已本地化
   - 切换语言验证

4. **调试可视化器测试**：
   - 打开调试可视化器
   - 验证所有按钮已本地化
   - 使用调试功能验证
   - 切换语言验证

5. **执行跟踪器测试**：
   - 打开执行跟踪器
   - 启用跟踪，验证状态显示已本地化
   - 切换语言验证

6. **Inspector 插件测试**：
   - 选择带有 Trigger 的节点
   - 验证 Inspector 中所有属性标签已本地化
   - 切换语言，刷新 Inspector 验证

**Step 2: 创建阶段2完成报告**

创建文件 `addons/bricks/localization/STAGE2_COMPLETE.md`：

```markdown
# Bricks 本地化系统 - 阶段 2 完成报告

## 📅 完成时间
2026-01-24

## ✅ 完成状态

**阶段 2：编辑器 UI 本地化** - ✅ 已完成

---

## 📊 实施统计

### 修改的文件
- 指令选择器对话框 (`instructions_selector.gd`)
- 输入键选择器对话框 (`input_key_dialog.gd`)
- 静态分析面板 (`static_analysis_panel.gd`)
- 调试可视化器 (`debug_visualizer.gd`)
- 执行跟踪器 (`execution_tracker.gd`)
- 指令数组 Inspector 插件 (`instructions_array_inspector_plugin.gd`)
- 输入键 Inspector 插件 (`input_key_inspector_plugin.gd`)

### 新增翻译键
- UI 专用键：约 30-40 个
- 对话框标题和标签
- 按钮文本
- 状态消息

## 🎯 已实现的功能

### 1. 对话框本地化
- ✅ 指令选择器对话框标题和搜索框
- ✅ 输入键选择器对话框全部文本

### 2. 面板本地化
- ✅ 静态分析面板标题、按钮、结果显示
- ✅ 调试可视化器全部按钮和标签
- ✅ 执行跟踪器全部按钮和状态显示

### 3. Inspector 插件本地化
- ✅ 指令数组属性标签
- ✅ 输入键属性标签

## 🔧 技术实现

### 本地化方法
所有 UI 组件使用统一的模式：

```gdscript
var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")
if BricksLocalization_class and BricksLocalization_class.has_method("translate"):
    ui_element.text = BricksLocalization_class.translate("BRICKS_UI_...")
else:
    ui_element.text = "回退文本"  # 向后兼容
```

### 参数化翻译
使用 `translate_format()` 处理动态内容：

```gdscript
BricksLocalization_class.translate_format("BRICKS_UI_ISSUES_FOUND", {"count": str(count)})
```

## ⚠️ 已知限制

- UI 布局可能需要根据文本长度调整（未自动处理）
- 某些复杂 UI 可能需要额外调整

## 📝 用户可见的变化

### 中文环境
- 所有对话框、面板、按钮显示中文
- Inspector 属性标签显示中文
- 状态消息和结果显示显示中文

### 英文环境
- All dialogs, panels, buttons display in English
- Inspector property labels display in English
- Status messages and results display in English

---

**阶段 2 状态**: ✅ **完成**

**最后更新**: 2026-01-24

**测试状态**: ✅ **所有 UI 组件已本地化**
```

**Step 3: 更新总体实施计划**

修改 `addons/bricks/docs/localization_implementation_plan_v2.md`，在阶段2部分添加完成标记：

```markdown
### 阶段 2：编辑器 UI 本地化（2-3 天）✅ 已完成

**完成日期**: 2026-01-24

**目标**：本地化所有编辑器界面

**语言策略**: 自动跟随编辑器语言设置，无需手动切换菜单 ✅

#### 任务清单

- [x] **2.1 修改指令选择器** ✅
  - ✅ 本地化标题和按钮文本
  - ✅ 本地化搜索占位符
  - ✅ 本地化指令列表显示
  - ✅ 已实现自动语言检测（`_refresh_locale_if_needed()`）

- [x] **2.2 修改输入键选择器** ✅
  - ✅ 本地化对话框文本
  - ✅ 本地化按钮和标签

- [x] **2.3 修改静态分析面板** ✅
  - ✅ 本地化面板标题和结果

- [x] **2.4 修改调试可视化器** ✅
  - ✅ 本地化调试信息显示

- [x] **2.5 修改执行跟踪器** ✅
  - ✅ 本地化跟踪信息

- [x] **2.6 本地化 Inspector 插件** ✅
  - ✅ 本地化属性标签和提示
```

**Step 4: 最终提交文档**

```bash
git add addons/bricks/localization/STAGE2_COMPLETE.md
git add addons/bricks/docs/localization_implementation_plan_v2.md
git commit -m "docs(stage2): add stage 2 completion report and update implementation plan"
```

---

## 验收标准检查清单

在标记阶段2完成前，确保以下所有项都已验证：

### 功能完整性
- [ ] 所有对话框标题已本地化
- [ ] 所有按钮文本已本地化
- [ ] 所有输入框占位符已本地化
- [ ] 所有面板标题已本地化
- [ ] 所有状态消息已本地化（包括参数化翻译）
- [ ] Inspector 属性标签已本地化

### 语言切换
- [ ] 中文环境下所有 UI 显示中文
- [ ] 英文环境下所有 UI 显示英文
- [ ] 切换编辑器语言后，新打开的窗口使用新语言
- [ ] 无 UI 文本溢出或布局问题
- [ ] 所有按钮和菜单可正常使用

### 兼容性
- [ ] 阶段1的测试仍然全部通过
- [ ] 无新的翻译警告或错误
- [ ] 本地化系统初始化正常
- [ ] 向后兼容（未翻译部分显示回退文本）

### 代码质量
- [ ] 所有修改已提交（清晰的提交信息）
- [ ] 文档已更新（完成报告、实施计划）
- [ ] 代码遵循项目规范
- [ ] 无硬编码文本残留（除预期保留的）

---

## 故障排除

### 问题：翻译未生效

**症状**: UI 仍显示硬编码文本

**诊断步骤**:
1. 检查 `BricksLocalization` 是否已初始化
2. 检查翻译键是否存在于 `translations.csv`
3. 检查代码中是否正确使用了 `translate()` 方法
4. 查看控制台是否有翻译缺失警告

**解决方案**:
- 确保插件已重新加载
- 确保翻译键格式正确（无多余空格）
- 使用动态加载避免循环依赖

### 问题：文本溢出

**症状**: 本地化后的文本太长，超出 UI 边界

**解决方案**:
- 调整 UI 控件的最小尺寸
- 使用 `label.autowrap_mode = TextServer.AUTOWRAP_WORD`
- 考虑使用更短的翻译文本

---

## 下一步（可选：阶段3）

如果需要继续完善本地化，可以考虑：
- 阶段3：运行时消息本地化（已在总体计划中定义）
- 或根据实际需求优先级调整后续任务

---

**计划完成标准**: 所有 8 个任务已完成，所有 UI 组件已本地化，文档已更新。
