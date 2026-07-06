# Fuse 架构整改 Phase 2 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development(推荐)或 superpowers:executing-plans 逐任务实现本计划。步骤使用复选框(`- [ ]`)语法跟踪。

**Goal:** 把 `plugin.gd` 从 666 行的上帝对象降级为生命周期编排器,职责拆入 4 个 bootstrap 模块(`FuseTypeRegistrar`/`FuseComponentScanner`/`FuseEditorBootstrap`/`FuseRuntimeBootstrap`),保持插件启停行为完全不变。

**Architecture:** 每个 bootstrap `extends RefCounted`,构造时接收 `plugin: EditorPlugin` 引用(因 `add_custom_type`/`add_inspector_plugin`/`add_context_menu_plugin`/`add_autoload_singleton`/`scene_changed`/`get_tree()` 均为 `EditorPlugin` 方法),提供 `setup()`/`teardown()`。`plugin.gd` 的 `_enter_tree` 顺序创建并 setup、`_exit_tree` 逆序 teardown。TypeRegistrar 用「类型表 + 循环」收敛 50 个重复 `add_custom_type`/`remove_custom_type` 调用(DRY)。每个 Task 移走一块职责后插件仍可正常启停,独立验证、独立回退。

**Tech Stack:** Godot 4.6 / GDScript 2.0。重构验证靠「插件启停行为不变 + Phase 0 回归基线」,非 TDD 单元测试(无 GUT 框架,且本 Phase 是结构性移动)。

> **📋 完成状态（2026-06-16）**
> 
> | 指标 | 目标 | 实际 | 状态 |
> |------|:---:|:---:|:----:|
> | plugin.gd 行数 | ~150 | **129** | ✅ |
> | bootstrap 模块 | 4 | **4** | ✅ |
> | 插件启停行为 | 不变 | 不变 | ✅ |
> | Commits | 5 | `d6ad401`→`4d116ee` | ✅ |

---

## 关联文档

- 评估报告:`addons/fuse/docs/system_docs/analysis/2026-04-21-fuse-architecture-assessment.md` §5.1(上帝对象)
- 整改总计划:`addons/fuse/docs/system_docs/analysis/2026-04-21-fuse-architecture-remediation-plan.md` §6(Phase 2 目标结构)、§6.4(实施顺序)、§12 M2(里程碑)
- Phase 0+1 计划:`addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-phase0-1-implementation-plan.md`
- 回归基线:`addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md`
- 本计划覆盖:总计划 §6(Phase 2)

## 现状核验(Phase 1 完成后,2026-06-16 ground truth)

`plugin.gd` 当前 666 行,职责分布:

| 职责 | 方法 | 行号区间 | 目标模块 |
|------|------|----------|----------|
| 生命周期编排 | `_enter_tree`/`_exit_tree` | 14-278 | **留 plugin.gd**(压缩) |
| 50 个类型注册/清理 | `add_custom_type`/`remove_custom_type` | 22-115 / 162-253 | **FuseTypeRegistrar** |
| 类型注册校验 | `_validate_custom_type_registrations` | 355-387 | **FuseTypeRegistrar** |
| 组件扫描 | `_register_all_instructions`/`_register_events`/`_register_conditions`/`_register_components_from_folders`/`_scan_scripts_recursive` | 389-518 | **FuseComponentScanner** |
| 本地化初始化 | `_initialize_localization` | 524-539 | **FuseEditorBootstrap** |
| 图标初始化/清理 | `_initialize_icon_manager`/`_cleanup_icon_manager` | 544-555 | **FuseEditorBootstrap** |
| Inspector 插件注册 | (内联在 `_enter_tree`) | 121-128 | **FuseEditorBootstrap** |
| 上下文菜单 | `_register_context_menu_plugin`/`_unregister_context_menu_plugin` | 584-596 | **FuseEditorBootstrap** |
| 场景切换刷新 | `_on_scene_changed`/`_refresh_all_resource_names` | 628-665 | **FuseEditorBootstrap** |
| Event Bus | `_register_event_bus`/`_unregister_event_bus` | 560-578 | **FuseRuntimeBootstrap** |
| 反射缓存清理 | `_register_reflection_cache_cleanup`/`_unregister_reflection_cache_cleanup`/`_on_node_removed_for_cache` | 602-621 | **FuseRuntimeBootstrap** |
| 配置警告 | `_get_configuration_warnings` | 299-351 | **留 plugin.gd** |
| 插件元信息 | `_get_plugin_name`/`_get_plugin_icon`/`_has_main_screen`/`_make_visible`/`_apply_changes` | 281-296 | **留 plugin.gd** |

**目标:plugin.gd 从 666 行降到 ~150 行**(仅生命周期编排 + 元信息 + 配置警告)。

## 关键设计约束

1. **EditorPlugin 方法依赖**:`add_custom_type`/`remove_custom_type`/`add_inspector_plugin`/`remove_inspector_plugin`/`add_context_menu_plugin`/`remove_context_menu_plugin`/`add_autoload_singleton`/`remove_autoload_singleton` 都是 `EditorPlugin` 实例方法;`scene_changed` 是 `EditorPlugin` 信号;`get_tree()` 继承自 `Node`(`EditorPlugin is Node`)。非 `EditorPlugin` 类无法直接调用 → **每个 bootstrap 必须持有 `plugin: EditorPlugin` 引用,通过 `_plugin.xxx()` 调用**。

2. **setup/teardown 顺序**(保持「本地化优先」+ 组件扫描依赖本地化):
   - setup:`EditorBootstrap`(本地化+图标+Inspector+菜单+场景回调)→ `TypeRegistrar`(类型)→ `ComponentScanner`(组件,依赖本地化)→ `RuntimeBootstrap`(EventBus+反射缓存)
   - teardown:逆序 `RuntimeBootstrap` → `ComponentScanner`(clear registries)→ `TypeRegistrar`(remove types)→ `EditorBootstrap`

3. **数据驱动 TypeRegistrar**:50 个 `add_custom_type` 收敛为 `_TYPES` 表 + 循环(消除 100 行重复调用)。

4. **实例引用迁移**:Inspector 插件(`fuse_plugin`/`input_key_plugin`)、上下文菜单(`_context_menu_plugin`)实例引用从 plugin.gd 移到 `FuseEditorBootstrap` 内部持有(供 teardown 移除)。

5. **行为不变硬约束**:每个 Task 完成后,插件必须能正常启用/停用,功能(类型创建、Inspector 选择器、上下文菜单、EventBus、组件扫描)与 Phase 1 后一致。

## File Structure

**新增 bootstrap 模块:**
- Create: `addons/fuse/editor/bootstrap/fuse_component_scanner.gd` — 组件扫描注册(指令/事件/条件)
- Create: `addons/fuse/editor/bootstrap/fuse_type_registrar.gd` — 类型注册/清理 + 校验(数据驱动)
- Create: `addons/fuse/editor/bootstrap/fuse_editor_bootstrap.gd` — 本地化/图标/Inspector/上下文菜单/场景刷新
- Create: `addons/fuse/editor/bootstrap/fuse_runtime_bootstrap.gd` — EventBus Autoload + 反射缓存清理

**改造:**
- Modify: `addons/fuse/plugin.gd` — 删除迁移走的方法,`_enter_tree`/`_exit_tree` 改为编排 4 个 bootstrap;持有 4 个 bootstrap 引用;保留元信息 + 配置警告

**职责边界:** bootstrap 模块间无横向依赖(各自只依赖 `plugin` 引用 + 全局类如 `ComponentRegistry`/`FuseIconManager`)。`_get_configuration_warnings` 留 plugin.gd(它是 `EditorPlugin` 配置警告钩子,且是纯文件存在检查,与类型注册逻辑正交)。

---

## 运行环境约定

```bash
# 按运行环境二选一(取消注释其一)
GODOT="E:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64.exe"; PROJECT="E:/Godot/GodotProjects/project-juicy-godot"  # Windows
#GODOT="/home/kai-remote/.local/bin/godot"; PROJECT="/home/kai-remote/github/project-juicy-godot"  # Linux
```

**回归基线命令**(每个 Task 后跑,确认无新增 fail;维度 4 headless 挂起已知,跳过):

```bash
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_action_runner_signals.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runtime_instruction_instance.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runner.gd"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_event_bus.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_registry_dedup.tscn"
```

> 提交(commit)遵循项目规范:征得用户同意后提交。每个 Task 末尾给出建议 commit message。
> **执行者注意**:本 Phase 改 `plugin.gd` 与新建 bootstrap 文件。每步后必须在 Godot 编辑器实际启用/禁用插件一次,确认无报错、功能正常,再进下一步。

---

# Task 2.1:提取 FuseComponentScanner(最独立,先做)

**理由:** 组件扫描只依赖全局 `ComponentRegistry`/`InstructionRegistry` 等 + `DirAccess`,不依赖 `EditorPlugin` 特殊方法(扫描本身不调 `add_custom_type`),最独立,风险最低。

**Files:**
- Create: `addons/fuse/editor/bootstrap/fuse_component_scanner.gd`
- Modify: `addons/fuse/plugin.gd`(删除 `_register_all_instructions`/`_register_events`/`_register_conditions`/`_register_components_from_folders`/`_scan_scripts_recursive`;`_enter_tree` 改调 scanner;`_exit_tree` 改调 scanner.teardown 清理 registries)

- [ ] **Step 1:创建 FuseComponentScanner**

创建 `addons/fuse/editor/bootstrap/fuse_component_scanner.gd`,把 plugin.gd 行 389-518 的扫描逻辑整体迁入(逻辑不变,仅包裹进类 + setup/teardown):

```gdscript
@tool
class_name FuseComponentScanner extends RefCounted

## Fuse 组件扫描器
##
## 从 instructions/ events/ conditions/ 目录扫描脚本,
## 验证元数据后注册到 ComponentRegistry(经三个专用 Registry)。
## 不依赖 EditorPlugin 特殊方法,仅用全局 Registry + DirAccess。

var _plugin: EditorPlugin

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin

## 扫描并注册所有指令/事件/条件
func setup() -> void:
	_register_all_instructions()
	_register_events()
	_register_conditions()

## 清空所有注册表(插件停用时)
func teardown() -> void:
	InstructionRegistry.clear_all()
	EventRegistry.clear_all_events()
	ConditionRegistry.clear_all_conditions()

## 扫描并注册所有指令
func _register_all_instructions() -> void:
	var folders: Array[String] = [
		"res://addons/fuse/instructions/",
		"res://addons/fuse/integration/",
		"res://fuse_generated/instructions/"
	]
	_register_components_from_folders(folders, "_get_instruction_metadata", "InstructionRegistry", "register_instruction", "instructions_", "指令")

## 扫描并注册所有事件
func _register_events() -> void:
	_register_components_from_folders(
		["res://addons/fuse/events/"] as Array[String], "_get_event_metadata", "EventRegistry", "register_event", "base_", "事件")

## 扫描并注册所有条件
func _register_conditions() -> void:
	_register_components_from_folders(
		["res://addons/fuse/conditions/"] as Array[String], "_get_condition_metadata", "ConditionRegistry", "register_condition", "base_", "条件")

## 泛型组件注册方法
func _register_components_from_folders(
	folders: Array[String],
	metadata_method: String,
	registry_name: String,
	register_method: String,
	skip_prefix: String,
	component_label: String
) -> void:
	var all_files: Array[String] = []
	for folder in folders:
		var files = _scan_scripts_recursive(folder, skip_prefix)
		all_files.append_array(files)

	# 扫描前重置该类型的重复计数
	var ctype_for_reset: ComponentRegistry.ComponentType
	match registry_name:
		"InstructionRegistry":
			ctype_for_reset = ComponentRegistry.ComponentType.INSTRUCTION
		"EventRegistry":
			ctype_for_reset = ComponentRegistry.ComponentType.EVENT
		"ConditionRegistry":
			ctype_for_reset = ComponentRegistry.ComponentType.CONDITION
		_:
			ctype_for_reset = -1
	if ctype_for_reset != -1:
		ComponentRegistry.reset_duplicate_count(ctype_for_reset)

	var registered_count = 0
	var failed_files: Array[String] = []

	for file_path in all_files:
		var script = load(file_path) as GDScript
		if not script:
			failed_files.append(file_path + " (无法加载脚本)")
			continue

		if not script.has_method(metadata_method):
			failed_files.append(file_path + " (缺少 %s 方法)" % metadata_method)
			continue

		var metadata = script.call(metadata_method)
		if not metadata:
			failed_files.append(file_path + " (元数据为空)")
			continue

		var has_identifier = (
			(metadata.name_key and not metadata.name_key.is_empty()) or
			(metadata.name and not metadata.name.is_empty())
		)
		if not has_identifier:
			failed_files.append(file_path + " (缺少标识符)")
			continue

		# 通过字符串引用注册表，避免 Callable 闭包捕获问题
		match registry_name:
			"InstructionRegistry":
				InstructionRegistry.register_instruction(script)
			"EventRegistry":
				EventRegistry.register_event(script)
			"ConditionRegistry":
				ConditionRegistry.register_condition(script)
		registered_count += 1

	print("Fuse: 注册完成 - 找到 %d 个文件，成功注册 %d 个%s" % [all_files.size(), registered_count, component_label])
	if failed_files.size() > 0:
		print("Fuse: 注册失败的%s:" % component_label)
		for failed_file in failed_files:
			print("  - %s" % failed_file)
	# 输出重复 identifier 统计
	if ctype_for_reset != -1:
		var dup_count = ComponentRegistry.get_duplicate_count(ctype_for_reset)
		if dup_count > 0:
			print("Fuse: 发现 %d 个重复 %s identifier（已自动去重更新）" % [dup_count, component_label])

## 递归扫描文件夹中的 GDScript 文件
func _scan_scripts_recursive(folder: String, skip_prefix: String = "") -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(folder)
	if not dir:
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = folder.path_join(file_name)

		if dir.current_is_dir():
			if not file_name.begins_with("."):
				var sub_files = _scan_scripts_recursive(full_path, skip_prefix)
				files.append_array(sub_files)
		elif file_name.ends_with(".gd"):
			if skip_prefix.is_empty() or not file_name.begins_with(skip_prefix):
				files.append(full_path)

		file_name = dir.get_next()

	return files
```

- [ ] **Step 2:plugin.gd 接线 — 持有 scanner + _enter_tree 调用**

在 `plugin.gd` 顶部成员变量区(行 7-11 附近,`var _context_menu_plugin` 旁)新增:

```gdscript
var _scanner: FuseComponentScanner = null
```

在 `_enter_tree()` 中,把当前的扫描调用(行 133-136):
```gdscript
    # 扫描并注册所有组件
    _register_all_instructions()
    _register_events()
    _register_conditions()
```
替换为:
```gdscript
    # 扫描并注册所有组件（委托给 FuseComponentScanner）
    _scanner = FuseComponentScanner.new(self)
    _scanner.setup()
```

- [ ] **Step 3:plugin.gd 接线 — _exit_tree 调用 + 删除迁移走的方法**

在 `_exit_tree()` 中,把当前的 registry 清理(行 260-263):
```gdscript
    # 清理所有注册表
    InstructionRegistry.clear_all()
    EventRegistry.clear_all_events()
    ConditionRegistry.clear_all_conditions()
```
替换为:
```gdscript
    # 清理组件注册表（委托给 scanner）
    if _scanner:
        _scanner.teardown()
        _scanner = null
```

删除 plugin.gd 中已迁入 scanner 的 5 个方法:`_register_all_instructions`/`_register_events`/`_register_conditions`/`_register_components_from_folders`/`_scan_scripts_recursive`(原行 389-518,现因前面编辑行号会变,按方法名定位删除)。

- [ ] **Step 4:验证**

1. Godot 编辑器:禁用 → 启用 Fuse 插件。
2. 预期:控制台输出「注册完成」三行(指令/事件/条件,数量与 Phase 1 后一致),无报错;Inspector 中指令/事件/条件选择器仍有内容。
3. 跑回归基线(上面 5 条命令),结果与 Phase 1 一致(维度 1/3/5/6 + dedup 通过)。

- [ ] **Step 5:commit**

```bash
git add addons/fuse/editor/bootstrap/fuse_component_scanner.gd addons/fuse/plugin.gd
git commit -m "refactor(fuse): extract FuseComponentScanner from plugin.gd (phase2)"
```

---

# Task 2.2:提取 FuseTypeRegistrar(数据驱动)

**Files:**
- Create: `addons/fuse/editor/bootstrap/fuse_type_registrar.gd`
- Modify: `addons/fuse/plugin.gd`(删除 50 个 `add_custom_type`/`remove_custom_type` + `_validate_custom_type_registrations`;`_enter_tree`/`_exit_tree` 改调 registrar)

- [ ] **Step 1:创建 FuseTypeRegistrar(数据驱动类型表)**

创建 `addons/fuse/editor/bootstrap/fuse_type_registrar.gd`。把 plugin.gd 行 22-115 的 50 个 `add_custom_type` 收敛为 `_TYPES` 表 + 循环;`_validate_custom_type_registrations`(行 355-387)整体迁入:

```gdscript
@tool
class_name FuseTypeRegistrar extends RefCounted

## Fuse 类型注册器
##
## 统一管理所有 add_custom_type / remove_custom_type 调用，
## 数据驱动（_TYPES 表 + 循环），并提供开发期类型注册一致性校验。
## 通过持有 plugin: EditorPlugin 引用调用 add/remove_custom_type。

const _ICON: Texture2D = preload("res://icon.svg")

var _plugin: EditorPlugin

# [类型名, 注册基类, 脚本路径] —— 与 plugin.gd 原 add_custom_type 一一对应
const _TYPES: Array = [
	["BaseInstruction", "Resource", "res://addons/fuse/core/base/base_instruction.gd"],
	["ExecutionContext", "RefCounted", "res://addons/fuse/core/base/execution_context.gd"],
	["BaseCondition", "Resource", "res://addons/fuse/core/base/base_condition.gd"],
	["BaseVariable", "Resource", "res://addons/fuse/core/base/base_variable.gd"],
	["ActionRunner", "Resource", "res://addons/fuse/core/base/action_runner.gd"],
	["InstructionSerializer", "RefCounted", "res://addons/fuse/core/serialization/instruction_serializer.gd"],
	["BaseEvent", "Resource", "res://addons/fuse/core/base/base_event.gd"],
	["BaseTrigger", "Node", "res://addons/fuse/core/base_trigger.gd"],
	["Trigger", "Node", "res://addons/fuse/core/trigger.gd"],
	["FuseLogger", "RefCounted", "res://addons/fuse/core/logging/fuse_logger.gd"],
	["FuseError", "RefCounted", "res://addons/fuse/core/logging/fuse_error.gd"],
	["GlobalVariableManager", "RefCounted", "res://addons/fuse/core/global_variable_manager.gd"],
	["GlobalVariableResource", "Resource", "res://addons/fuse/core/global_variable_resource.gd"],
	["GlobalVariableAssistant", "Node", "res://addons/fuse/core/global_variable_assistant.gd"],
	["ScopeVariableContainer", "Node", "res://addons/fuse/core/base/scope_variable_container.gd"],
	["ScopeVariableManager", "Node", "res://addons/fuse/core/scope_variable_manager.gd"],
	["RuntimeEventInstance", "RefCounted", "res://addons/fuse/core/runtime_event_instance.gd"],
	["RuntimeActionRunnerInstance", "RefCounted", "res://addons/fuse/core/runtime_action_runner_instance.gd"],
	["CompiledInstructionSequence", "RefCounted", "res://addons/fuse/core/execution/compiled_instruction_sequence.gd"],
	["InstructionInstancePool", "RefCounted", "res://addons/fuse/core/pooling/instruction_instance_pool.gd"],
	["InstructionValidator", "RefCounted", "res://addons/fuse/editor/static_analysis/instruction_validator.gd"],
	["StaticAnalysisPanel", "Control", "res://addons/fuse/editor/static_analysis/static_analysis_panel.gd"],
	["ExecutionTracker", "RefCounted", "res://addons/fuse/editor/debugging/execution_tracker.gd"],
	["DebugVisualizer", "Control", "res://addons/fuse/editor/debugging/debug_visualizer.gd"],
	["FuseMetadata", "Resource", "res://addons/fuse/editor/metadata/fuse_metadata.gd"],
	["EventMetadata", "Resource", "res://addons/fuse/editor/metadata/event_metadata.gd"],
	["ConditionMetadata", "Resource", "res://addons/fuse/editor/metadata/condition_metadata.gd"],
	["FusePoolItem", "RefCounted", "res://addons/fuse/core/pooling/fuse_pool_item.gd"],
	["FuseObjectPool", "RefCounted", "res://addons/fuse/core/pooling/fuse_object_pool.gd"],
	["FusePoolManager", "RefCounted", "res://addons/fuse/core/pooling/fuse_pool_manager.gd"],
	["ComponentRegistry", "RefCounted", "res://addons/fuse/editor/component_registry.gd"],
	["EventRegistry", "RefCounted", "res://addons/fuse/editor/event_registry.gd"],
	["ConditionRegistry", "RefCounted", "res://addons/fuse/editor/condition_registry.gd"],
	["InstructionMetadata", "Resource", "res://addons/fuse/editor/instruction_selector/instructions_metadata.gd"],
	["InstructionRegistry", "RefCounted", "res://addons/fuse/editor/instruction_selector/instruction_registry.gd"],
	["InstructionSearch", "RefCounted", "res://addons/fuse/editor/instruction_selector/instructions_search.gd"],
	["InstructionSelector", "AcceptDialog", "res://addons/fuse/editor/instruction_selector/instructions_selector.gd"],
	["ComponentSelector", "AcceptDialog", "res://addons/fuse/editor/component_selector/component_selector.gd"],
	["TriggerMerger", "RefCounted", "res://addons/fuse/editor/context_menu/trigger_merger.gd"],
	["TriggerSplitter", "RefCounted", "res://addons/fuse/editor/context_menu/trigger_splitter.gd"],
	["PropertyInfo", "RefCounted", "res://addons/fuse/utils/property_info.gd"],
	["TypeConverter", "RefCounted", "res://addons/fuse/utils/type_converter.gd"],
	["PropertyManager", "RefCounted", "res://addons/fuse/utils/property_manager.gd"],
	["SignalInfo", "Resource", "res://addons/fuse/utils/signal_info.gd"],
	["SignalManager", "RefCounted", "res://addons/fuse/utils/signal_manager.gd"],
	["FuseNodeUtils", "RefCounted", "res://addons/fuse/utils/fuse_node_utils.gd"],
	["FunctionInfo", "Resource", "res://addons/fuse/utils/function_info.gd"],
	["FunctionManager", "RefCounted", "res://addons/fuse/utils/function_manager.gd"],
	["InputKeySelector", "EditorProperty", "res://addons/fuse/editor/input_key_selector/input_key_selector.gd"],
	["InputKeyDialog", "AcceptDialog", "res://addons/fuse/editor/input_key_selector/input_key_dialog.gd"],
]

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin

## 注册所有自定义类型
func setup() -> void:
	for t in _TYPES:
		_plugin.add_custom_type(t[0], t[1], load(t[2]), _ICON)
	# 开发期校验：类型注册基类与脚本实际继承一致性
	if Engine.is_editor_hint():
		_validate_type_registrations()

## 注销所有自定义类型
func teardown() -> void:
	for t in _TYPES:
		_plugin.remove_custom_type(t[0])

## 校验 _TYPES 的注册基类与脚本实际继承是否一致
## 递归向上遍历继承链，直到找到直接继承引擎类的基类
func _validate_type_registrations() -> void:
	for t in _TYPES:
		var type_name: String = t[0]
		var registered_base: String = t[1]
		var script = load(t[2]) as GDScript
		if script == null:
			push_warning("[Fuse] 校验失败：无法加载 %s" % t[2])
			continue
		var actual_base := ""
		var base_script = script.get_base_script()
		if base_script != null:
			var current_script = base_script
			while true:
				var next_base = current_script.get_base_script()
				if next_base != null:
					current_script = next_base
				else:
					actual_base = current_script.get_instance_base_type()
					break
		else:
			actual_base = script.get_instance_base_type()
		if actual_base != registered_base:
			push_warning("[Fuse] 类型注册不一致：%s 注册为 %s，实际继承 %s" % [type_name, registered_base, actual_base])
```

- [ ] **Step 2:plugin.gd 接线 — 持有 registrar + _enter_tree 调用**

成员变量区新增:

```gdscript
var _registrar: FuseTypeRegistrar = null
```

在 `_enter_tree()` 中,把当前的「注册核心类」到 InputKeyDialog 的全部 50 个 `add_custom_type(...)` 调用(原行 21-115)替换为:

```gdscript
    # 注册核心类（委托给 FuseTypeRegistrar，数据驱动）
    _registrar = FuseTypeRegistrar.new(self)
    _registrar.setup()
```

同时删除 `_enter_tree` 末尾的校验调用块(原行 150-152):
```gdscript
    # 开发期校验：类型注册基类与脚本实际继承一致性
    if Engine.is_editor_hint():
        _validate_custom_type_registrations()
```
(校验已移入 registrar.setup)

- [ ] **Step 3:plugin.gd 接线 — _exit_tree 调用 + 删除迁移走的方法**

在 `_exit_tree()` 中,把当前的「清理注册的自定义类型」全部 50 个 `remove_custom_type(...)`(原行 161-253)替换为:

```gdscript
    # 清理自定义类型（委托给 registrar）
    if _registrar:
        _registrar.teardown()
        _registrar = null
```

删除 plugin.gd 中的 `_validate_custom_type_registrations` 方法(原行 353-387)。

- [ ] **Step 4:验证**

1. Godot 编辑器:禁用 → 启用插件。
2. 预期:无「类型注册不一致」警告;Inspector「创建节点/资源」里 BaseInstruction/BaseCondition/Trigger 等类型可正常识别与创建;禁用插件后类型正确注销(再次创建不会残留旧类型)。
3. 跑回归基线 5 条命令,结果与 Task 2.1 后一致。

- [ ] **Step 5:commit**

```bash
git add addons/fuse/editor/bootstrap/fuse_type_registrar.gd addons/fuse/plugin.gd
git commit -m "refactor(fuse): extract FuseTypeRegistrar (data-driven) from plugin.gd (phase2)"
```

---

# Task 2.3:提取 FuseEditorBootstrap

**Files:**
- Create: `addons/fuse/editor/bootstrap/fuse_editor_bootstrap.gd`
- Modify: `addons/fuse/plugin.gd`(删除本地化/图标/Inspector 注册/上下文菜单/场景刷新方法;迁移实例引用)

- [ ] **Step 1:创建 FuseEditorBootstrap**

创建 `addons/fuse/editor/bootstrap/fuse_editor_bootstrap.gd`,迁入本地化、图标、Inspector 插件、上下文菜单、场景刷新逻辑:

```gdscript
@tool
class_name FuseEditorBootstrap extends RefCounted

## Fuse 编辑器侧引导
##
## 负责：本地化初始化、图标管理器、Inspector 插件注册、
## 上下文菜单插件、场景切换 resource_name 刷新。
## 持有 Inspector/上下文菜单实例引用供 teardown 清理。

var _plugin: EditorPlugin

# Inspector 插件实例（teardown 时移除）
var _fuse_plugin: EditorInspectorPlugin = null
var _input_key_plugin: EditorInspectorPlugin = null
# 上下文菜单插件实例
var _context_menu_plugin: FuseContextMenuPlugin = null

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin

func setup() -> void:
	# 1. 本地化（必须在所有其他操作之前）
	_init_localization()
	# 2. 图标管理器
	_init_icon_manager()
	# 3. Fuse 统一 Inspector 插件
	_fuse_plugin = preload("res://addons/fuse/editor/fuse_inspector_plugin.gd").new()
	_plugin.add_inspector_plugin(_fuse_plugin)
	print("Fuse 统一 Inspector 插件已注册")
	# 4. 输入键选择器 Inspector 插件
	_input_key_plugin = preload("res://addons/fuse/editor/input_key_selector/input_key_inspector_plugin.gd").new()
	_plugin.add_inspector_plugin(_input_key_plugin)
	print("输入键选择器 Inspector 插件已注册")
	# 5. 上下文菜单插件
	_register_context_menu_plugin()
	# 6. 场景切换信号（刷新 resource_name 显示）
	_plugin.scene_changed.connect(_on_scene_changed)

func teardown() -> void:
	# 逆序清理
	if _plugin.scene_changed.is_connected(_on_scene_changed):
		_plugin.scene_changed.disconnect(_on_scene_changed)
	_unregister_context_menu_plugin()
	if _input_key_plugin:
		_plugin.remove_inspector_plugin(_input_key_plugin)
		_input_key_plugin = null
	if _fuse_plugin:
		_plugin.remove_inspector_plugin(_fuse_plugin)
		_fuse_plugin = null
	_cleanup_icon_manager()

## 初始化本地化系统
func _init_localization() -> void:
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	if FuseLocalization_class and FuseLocalization_class.has_method("init"):
		FuseLocalization_class.init()
		print("Fuse Localization 系统已初始化")
		if FuseLocalization_class.has_method("get_translation_stats"):
			var stats = FuseLocalization_class.get_translation_stats()
			print("  总翻译键: %d" % stats.total_keys)
			print("  中文覆盖率: %.1f%%" % stats.zh_CN_coverage)
			print("  英文覆盖率: %.1f%%" % stats.en_US_coverage)
			print("  当前语言: %s" % stats.current_locale)
	else:
		push_error("无法加载 FuseLocalization 系统")

## 初始化图标管理器
func _init_icon_manager() -> void:
	FuseIconManager.init()
	print("[FusePlugin] 图标管理器已初始化")

## 清理图标管理器
func _cleanup_icon_manager() -> void:
	FuseIconManager.cleanup()
	print("[FusePlugin] 图标管理器已清理")

## 注册上下文菜单插件
func _register_context_menu_plugin() -> void:
	var plugin_script := preload("res://addons/fuse/editor/context_menu/fuse_context_menu_plugin.gd")
	_context_menu_plugin = plugin_script.new()
	_context_menu_plugin.set_editor_plugin(_plugin)
	_plugin.add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE, _context_menu_plugin)
	print("[FusePlugin] 上下文菜单插件已注册")

## 清理上下文菜单插件
func _unregister_context_menu_plugin() -> void:
	if _context_menu_plugin != null:
		_plugin.remove_context_menu_plugin(_context_menu_plugin)
		_context_menu_plugin = null
		print("[FusePlugin] 上下文菜单插件已清理")

## 场景切换时刷新所有组件的 resource_name
func _on_scene_changed(scene_root: Node = null) -> void:
	if scene_root:
		_refresh_all_resource_names(scene_root)
		return
	var editor_interface = Engine.get_singleton("EditorInterface")
	if not editor_interface:
		return
	var root = editor_interface.get_edited_scene_root()
	if root:
		_refresh_all_resource_names(root)

## 递归遍历场景树，刷新所有组件的 resource_name
func _refresh_all_resource_names(node: Node) -> int:
	var count = 0
	if "action_runner" in node:
		var runner = node.get("action_runner")
		if runner and is_instance_valid(runner) and "instructions" in runner:
			for inst in runner.instructions:
				if inst and is_instance_valid(inst) and inst.has_method("_update_resource_name"):
					inst._update_resource_name()
					count += 1
	if "event_definition" in node:
		var event = node.get("event_definition")
		if event and is_instance_valid(event) and event.has_method("_update_resource_name"):
			event._update_resource_name()
			count += 1
	if node.has_method("_update_resource_name") and "target_node" in node:
		node._update_resource_name()
		count += 1
	for child in node.get_children():
		count += _refresh_all_resource_names(child)
	return count
```

- [ ] **Step 2:plugin.gd 接线 — 持有 editor_bootstrap + _enter_tree 调用**

成员变量区:删除原 `var input_key_plugin`、`var fuse_plugin`、`var _context_menu_plugin`(已迁入 bootstrap),新增:

```gdscript
var _editor_bootstrap: FuseEditorBootstrap = null
```

在 `_enter_tree()` 开头(必须最先,因本地化优先),把当前的:
```gdscript
    # 初始化本地化系统（必须在所有其他操作之前）
    _initialize_localization()

    # 初始化图标管理器
    _initialize_icon_manager()
```
以及中部的 Inspector 插件注册块(原行 120-131)、`_register_context_menu_plugin()` 调用(原行 142)、`scene_changed.connect(_on_scene_changed)`(原行 148)——全部移除,在 `_enter_tree` 开头替换为:

```gdscript
    # 编辑器侧引导（本地化/图标/Inspector/菜单/场景刷新，必须最先）
    _editor_bootstrap = FuseEditorBootstrap.new(self)
    _editor_bootstrap.setup()
```

> 顺序约束:`_editor_bootstrap.setup()` 必须在 `_registrar.setup()` 和 `_scanner.setup()` 之前(本地化优先 + 组件扫描依赖本地化)。

- [ ] **Step 3:plugin.gd 接线 — _exit_tree 调用 + 删除迁移走的方法**

在 `_exit_tree()` 中,删除原:
```gdscript
    # 清理图标管理器
    _cleanup_icon_manager()
```
```gdscript
    # 清理上下文菜单插件
    _unregister_context_menu_plugin()
```
```gdscript
    # 清理 Inspector 插件
    remove_inspector_plugin(fuse_plugin)
    remove_inspector_plugin(input_key_plugin)
```
```gdscript
    # 断开场景切换信号
    if scene_changed.is_connected(_on_scene_changed):
        scene_changed.disconnect(_on_scene_changed)
```
替换为(放在 teardown 序列最末,逆序):

```gdscript
    # 清理编辑器侧引导（逆序最后）
    if _editor_bootstrap:
        _editor_bootstrap.teardown()
        _editor_bootstrap = null
```

删除 plugin.gd 中已迁入 bootstrap 的方法:`_initialize_localization`/`_initialize_icon_manager`/`_cleanup_icon_manager`/`_register_context_menu_plugin`/`_unregister_context_menu_plugin`/`_on_scene_changed`/`_refresh_all_resource_names`(原行 521-665 区域,按方法名定位)。

- [ ] **Step 4:验证**

1. 禁用 → 启用插件。
2. 预期:控制台有「Fuse Localization 系统已初始化」「图标管理器已初始化」「Inspector 插件已注册」「上下文菜单插件已注册」;Inspector 选择器按钮正常;场景树右键有 Fuse 上下文菜单;切换场景后指令/事件的 resource_name 正常显示。
3. 禁用插件:Inspector 插件/菜单正确移除,无残留连接报错。
4. 跑回归基线 5 条命令,一致。

- [ ] **Step 5:commit**

```bash
git add addons/fuse/editor/bootstrap/fuse_editor_bootstrap.gd addons/fuse/plugin.gd
git commit -m "refactor(fuse): extract FuseEditorBootstrap from plugin.gd (phase2)"
```

---

# Task 2.4:提取 FuseRuntimeBootstrap

**Files:**
- Create: `addons/fuse/editor/bootstrap/fuse_runtime_bootstrap.gd`
- Modify: `addons/fuse/plugin.gd`(删除 EventBus/反射缓存方法)

- [ ] **Step 1:创建 FuseRuntimeBootstrap**

创建 `addons/fuse/editor/bootstrap/fuse_runtime_bootstrap.gd`,迁入 Event Bus Autoload 与反射缓存清理:

```gdscript
@tool
class_name FuseRuntimeBootstrap extends RefCounted

## Fuse 运行时基础设施引导
##
## 负责：FuseEventBus Autoload 注册/注销、
## 反射缓存自动清理（节点删除时清理 PropertyManager/SignalManager/FunctionManager 缓存）。

var _plugin: EditorPlugin

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin

func setup() -> void:
	_register_event_bus()
	_register_reflection_cache_cleanup()

func teardown() -> void:
	_unregister_reflection_cache_cleanup()
	_unregister_event_bus()

## 注册 Event Bus 为 Autoload
func _register_event_bus() -> void:
	var bus_path = "res://addons/fuse/core/fuse_event_bus.gd"
	var autoloads = ProjectSettings.get_setting("autoload", {})
	if not autoloads.has("FuseEventBus"):
		_plugin.add_autoload_singleton("FuseEventBus", bus_path)
		print("[FusePlugin] FuseEventBus 已注册为 Autoload")
	else:
		print("[FusePlugin] FuseEventBus Autoload 已存在")

## 清理 Event Bus
func _unregister_event_bus() -> void:
	var autoloads = ProjectSettings.get_setting("autoload", {})
	if autoloads.has("FuseEventBus"):
		_plugin.remove_autoload_singleton("FuseEventBus")
		print("[FusePlugin] FuseEventBus Autoload 已移除")

## 注册节点删除信号，自动清理反射缓存
func _register_reflection_cache_cleanup() -> void:
	var tree = _plugin.get_tree()
	if tree:
		tree.node_removed.connect(_on_node_removed_for_cache)
		print("[FusePlugin] 反射缓存自动清理已注册")

## 清理节点删除信号
func _unregister_reflection_cache_cleanup() -> void:
	var tree = _plugin.get_tree()
	if tree:
		if tree.node_removed.is_connected(_on_node_removed_for_cache):
			tree.node_removed.disconnect(_on_node_removed_for_cache)
	# 同时清理所有静态缓存
	PropertyManager.clear_all_cache()
	SignalManager.clear_all_cache()
	FunctionManager.clear_all_callable_cache()
	print("[FusePlugin] 反射缓存自动清理已注销")

## 节点删除时清理缓存
func _on_node_removed_for_cache(node: Node) -> void:
	ReflectionCache.get_instance().clear_node(node)
	FunctionManager.clear_callable_cache(node)
```

- [ ] **Step 2:plugin.gd 接线 — 持有 runtime_bootstrap + _enter_tree 调用**

成员变量区新增:

```gdscript
var _runtime_bootstrap: FuseRuntimeBootstrap = null
```

在 `_enter_tree()` 中,把当前的:
```gdscript
    # 注册 Event Bus 为 Autoload
    _register_event_bus()
```
```gdscript
    # 注册反射缓存自动清理（节点删除时自动清理缓存，防止内存泄漏）
    _register_reflection_cache_cleanup()
```
替换为(放在 scanner.setup() 之后):

```gdscript
    # 运行时基础设施引导（EventBus + 反射缓存）
    _runtime_bootstrap = FuseRuntimeBootstrap.new(self)
    _runtime_bootstrap.setup()
```

- [ ] **Step 3:plugin.gd 接线 — _exit_tree 调用 + 删除迁移走的方法**

在 `_exit_tree()` 中,把当前的:
```gdscript
    # 清理 Event Bus
    _unregister_event_bus()
```
```gdscript
    # 清理反射缓存
    _unregister_reflection_cache_cleanup()
```
替换为(放在 teardown 序列最前,逆序最先):

```gdscript
    # 清理运行时基础设施（逆序最先）
    if _runtime_bootstrap:
        _runtime_bootstrap.teardown()
        _runtime_bootstrap = null
```

删除 plugin.gd 中已迁入的方法:`_register_event_bus`/`_unregister_event_bus`/`_register_reflection_cache_cleanup`/`_unregister_reflection_cache_cleanup`/`_on_node_removed_for_cache`(原行 557-621 区域,按方法名定位)。

- [ ] **Step 4:验证**

1. 禁用 → 启用插件。
2. 预期:控制台「FuseEventBus 已注册为 Autoload」「反射缓存自动清理已注册」;项目设置里 FuseEventBus autoload 存在;删除节点时反射缓存被清理(无报错)。
3. 禁用插件:FuseEventBus autoload 正确移除,node_removed 信号断开,无残留。
4. 跑回归基线 5 条命令,一致。

- [ ] **Step 5:commit**

```bash
git add addons/fuse/editor/bootstrap/fuse_runtime_bootstrap.gd addons/fuse/plugin.gd
git commit -m "refactor(fuse): extract FuseRuntimeBootstrap from plugin.gd (phase2)"
```

---

# Task 2.5:压缩 plugin.gd + 最终验证

**Files:**
- Modify: `addons/fuse/plugin.gd`(清理残留注释/空段,确认仅剩生命周期编排 + 元信息 + 配置警告)

- [ ] **Step 1:确认 plugin.gd 最终结构**

此时 plugin.gd 应仅含:
- 成员变量:`_scanner`/`_registrar`/`_editor_bootstrap`/`_runtime_bootstrap`(4 个 bootstrap 引用)
- `_enter_tree()`:仅编排——顺序 `EditorBootstrap.setup()` → `TypeRegistrar.setup()` → `ComponentScanner.setup()` → `RuntimeBootstrap.setup()` + 末尾 `print("Fuse Visual Programming 插件已激活")`
- `_exit_tree()`:仅编排——逆序 `RuntimeBootstrap.teardown()` → `ComponentScanner.teardown()` → `TypeRegistrar.teardown()` → `EditorBootstrap.teardown()` + 末尾 `print("...已停用")`
- `_get_plugin_name()`/`_get_plugin_icon()`/`_has_main_screen()`/`_make_visible()`/`_apply_changes()`
- `_get_configuration_warnings()`(保留,文件存在检查)

目标 `_enter_tree` / `_exit_tree` 应形如:

```gdscript
func _enter_tree():
    # 编辑器侧引导（本地化/图标/Inspector/菜单/场景刷新，必须最先，本地化优先）
    _editor_bootstrap = FuseEditorBootstrap.new(self)
    _editor_bootstrap.setup()

    # 注册核心类（数据驱动类型表）
    _registrar = FuseTypeRegistrar.new(self)
    _registrar.setup()

    # 扫描并注册所有组件
    _scanner = FuseComponentScanner.new(self)
    _scanner.setup()

    # 运行时基础设施（EventBus + 反射缓存）
    _runtime_bootstrap = FuseRuntimeBootstrap.new(self)
    _runtime_bootstrap.setup()

    print("Fuse Visual Programming 插件已激活")

func _exit_tree():
    # 逆序清理
    if _runtime_bootstrap:
        _runtime_bootstrap.teardown()
        _runtime_bootstrap = null
    if _scanner:
        _scanner.teardown()
        _scanner = null
    if _registrar:
        _registrar.teardown()
        _registrar = null
    if _editor_bootstrap:
        _editor_bootstrap.teardown()
        _editor_bootstrap = null
    print("Fuse Visual Programming 插件已停用")
```

- [ ] **Step 2:清理残留注释/空段**

删除因方法迁移留下的孤立注释段(如 `# ==================== 上下文菜单插件 ====================`、`# ==================== 反射缓存自动清理 ====================`、`# ==================== 资源名称刷新 ====================` 等分隔注释,它们引导的方法已迁走)。

- [ ] **Step 3:核验行数**

```bash
wc -l addons/fuse/plugin.gd
```
预期:≤ 160 行(从 666 行降至编排器规模)。若仍 > 200,检查是否有方法未迁净。

- [ ] **Step 4:全量回归验证**

1. 禁用 → 启用插件,完整跑一遍功能检查:
   - 类型创建(BaseInstruction/BaseCondition/Trigger 等)
   - Inspector 指令/事件/条件选择器
   - 上下文菜单(Fuse 项)
   - 组件扫描日志(指令/事件/条件数量与 Phase 1 一致)
   - EventBus autoload
2. 跑回归基线 5 条命令,全部与 Phase 1 一致(维度 1/3/5/6 + dedup 通过;维度 4 已知挂起,不变)。
3. 禁用插件,确认无报错、无残留连接/autoload。

- [ ] **Step 5:更新回归基线文档「Phase 2 完成后复跑记录」**

在 `2026-06-15-fuse-architecture-regression-baseline.md` 追加 Phase 2 复跑段(对照基线,确认无新增 fail)。

- [ ] **Step 6:commit**

```bash
git add addons/fuse/plugin.gd addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md
git commit -m "refactor(fuse): slim plugin.gd to lifecycle orchestrator (phase2 complete)"
```

---

## Self-Review

**1. 整改总计划 §6 覆盖:**
- §6.2 四个 bootstrap 模块 → Task 2.1-2.4 各创建一个 ✓
- §6.3 职责划分:TypeRegistrar(类型+校验)/ComponentScanner(扫描)/EditorBootstrap(Inspector+菜单+图标+本地化+场景回调)/RuntimeBootstrap(EventBus+反射缓存)→ 与各 Task 一致 ✓
- §6.4 实施顺序(先无状态工具→注册器→压缩)→ Task 2.1 Scanner(最独立)→ 2.2 Registrar → 2.3 Editor → 2.4 Runtime → 2.5 压缩 ✓
- §12 M2 里程碑(plugin.gd 主要只做编排)→ Task 2.5 行数 ≤160 ✓

**2. Placeholder 扫描:** 无 TBD/TODO;每个 bootstrap 给完整代码;plugin.gd 改动给确切方法名/行号区间/替换前后代码;验证给具体命令与预期。

**3. 类型/签名一致性:**
- 4 个 bootstrap 统一 `_init(plugin: EditorPlugin)` + `setup()`/`teardown()` ✓
- plugin.gd 持有 `_scanner`/`_registrar`/`_editor_bootstrap`/`_runtime_bootstrap`(各 Task Step 2 定义 ↔ Task 2.5 引用)✓
- `_TYPES` 数组 50 项与 plugin.gd 原 `add_custom_type`(行 22-115)一一对应(已逐项核对)✓
- setup 顺序约束(EditorBootstrap 先,本地化优先)在 Task 2.3 Step 2 + Task 2.5 Step 1 一致声明 ✓

**4. 风险点:**
- `_TYPES` 用 `load()`(运行期)替代原 `preload()`(编译期):功能等价(都是加载资源),`load` 在 setup 执行;`_ICON` 仍 `preload`(const 要求)。已在 Task 2.2 Step 1 体现。
- `scene_changed`/`get_tree()` 通过 `_plugin.` 访问:EditorBootstrap 用 `_plugin.scene_changed`、RuntimeBootstrap 用 `_plugin.get_tree()` ✓
- teardown 顺序:逆序 setup,且 clear registries(Scanner)与 remove_custom_type(Registrar)独立无依赖 ✓
- 配置警告 `_get_configuration_warnings` 保留 plugin.gd:它不依赖任何 bootstrap,独立文件检查 ✓

---

## 执行交接

计划已保存至 `addons/fuse/docs/system_docs/analysis/2026-06-16-fuse-phase2-implementation-plan.md`。

**本 Phase 由远程机器执行,我负责审查 + 制定 Phase 3 计划**(分工见 `feedback-fuse-remediation-role-split`)。

执行约定:
- 逐 Task 执行,每个 Task 后**必须在 Godot 编辑器实际禁用→启用插件一次**确认无报错 + 跑回归基线 5 条命令,再进下一 Task。
- Task 2.1-2.4 顺序不可乱(EditorBootstrap 必须最先 setup,本地化优先)。
- Task 2.5 完成后更新回归基线文档,提交。

完成后把结果(commits + plugin.gd 最终行数 + 回归日志)发我审查,通过后我制定 Phase 3(全局变量服务重构)计划。
