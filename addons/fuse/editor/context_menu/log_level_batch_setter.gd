# 文件：addons/fuse/editor/context_menu/log_level_batch_setter.gd
@tool
class_name LogLevelBatchSetter extends RefCounted

## LogLevelBatchSetter - 子树内 Fuse 组件输出级别批量设置工具
##
## 配合场景树右键菜单使用：递归收集选中节点子树内所有带 log_level 的
## Fuse 组件（Trigger/Runner 节点 + Event/Instruction/Condition/ActionRunner
## 等嵌套资源），走 UndoRedo 批量修改。
##
## 收集采用通用递归（get_property_list + 按值类型分派），不维护嵌套属性
## 白名单——项目内已有三份子指令名单互相不同步，白名单必然漏掉新嵌套方式。
##
## 归属规则：
## - 外部 .tres 资源（resource_path 不含 "::"）可能被多个场景共享，整枝跳过并报告
## - 实例化子场景内的组件（owner 不属于当前场景）无法随当前场景落盘，整枝跳过并计数
## - 内嵌资源修改内存即可随场景保存；本工具不自动保存场景（Ctrl+S 生效），
##   避免把用户其他未保存的改动一起落盘

## ==================== 常量 ====================

## 递归深度上限（防御异常深/循环结构）
const MAX_DEPTH: int = 64

## ==================== 成员变量 ====================

var _editor_interface: EditorInterface
var _undo_redo: EditorUndoRedoManager

## ==================== 初始化 ====================

## 构造函数
## @param editor_interface 编辑器接口
## @param undo_redo UndoRedo 管理器
func _init(editor_interface: EditorInterface, undo_redo: EditorUndoRedoManager) -> void:
	_editor_interface = editor_interface
	_undo_redo = undo_redo

## ==================== 收集逻辑（static，可 headless 测试） ====================

## 收集 roots 各子树内所有可设置输出级别的 Fuse 组件
## @param roots 选中节点数组（子树可重叠，内部去重）
## @param scene_root 当前编辑的场景根，用于归属判定
## @return {
##   "applicable": Array[Dictionary],        # {"target": Object, "holder": Node, "current_level": int}
##   "skipped_external": Array[Dictionary],  # {"target": Resource, "path": String}
##   "skipped_nested_count": int,
## }
static func collect_components(roots: Array[Node], scene_root: Node) -> Dictionary:
	var result: Dictionary = {
		"applicable": [],
		"skipped_external": [],
		"skipped_nested_count": 0,
	}
	if scene_root == null:
		return result

	var visited: Dictionary = {}
	for root: Node in roots:
		if root == null or visited.has(root):
			continue
		_collect_node(root, scene_root, result, visited, 0)
	return result

## 判定节点是否属于当前编辑场景（修改可随场景保存）
static func _node_belongs_to_scene(node: Node, scene_root: Node) -> bool:
	return node == scene_root or node.owner == scene_root

## 判定资源是否外部文件（可能被多个场景共享）
static func _is_external_resource(res: Resource) -> bool:
	var path: String = res.resource_path
	return not path.is_empty() and not path.contains("::")

## 递归收集单个节点子树
static func _collect_node(node: Node, scene_root: Node, result: Dictionary, visited: Dictionary, depth: int) -> void:
	if depth > MAX_DEPTH:
		push_warning("[LogLevelBatchSetter] 递归深度超限，跳过: " + str(node.get_path()))
		return
	if visited.has(node):
		return
	visited[node] = true

	# 节点自身组件（BaseTrigger / Runner / GlobalVariableAssistant 等）
	if "log_level" in node:
		if _node_belongs_to_scene(node, scene_root):
			result["applicable"].append({
				"target": node,
				"holder": node,
				"current_level": node.get("log_level"),
			})
		else:
			result["skipped_nested_count"] += 1

	# 节点属性上挂载的 Fuse 资源
	_scan_properties(node, node, scene_root, result, visited, depth)

	# 递归子节点
	for child: Node in node.get_children():
		_collect_node(child, scene_root, result, visited, depth + 1)

## 枚举对象属性并按值类型分派（只取 OBJECT/ARRAY/DICTIONARY 声明的属性）
## get_property_list 天然包含 _get_property_list 动态注册的属性
## （EventBinding.conditions、loop_instructions 等），无需属性白名单
static func _scan_properties(obj: Object, holder: Node, scene_root: Node, result: Dictionary, visited: Dictionary, depth: int) -> void:
	if depth > MAX_DEPTH:
		return
	var seen_names: Dictionary = {}
	for prop: Dictionary in obj.get_property_list():
		var ptype: int = prop.get("type", TYPE_NIL)
		if ptype != TYPE_OBJECT and ptype != TYPE_ARRAY and ptype != TYPE_DICTIONARY:
			continue
		var pname: String = prop["name"]
		if pname in seen_names:
			continue
		seen_names[pname] = true
		_scan_value(obj.get(pname), holder, scene_root, result, visited, depth + 1)

## 按值运行时类型分派：容器展开、Fuse 资源收集并下钻
static func _scan_value(value: Variant, holder: Node, scene_root: Node, result: Dictionary, visited: Dictionary, depth: int) -> void:
	if value == null or depth > MAX_DEPTH:
		return

	if value is Array:
		for element: Variant in value:
			_scan_value(element, holder, scene_root, result, visited, depth)
		return

	if value is Dictionary:
		for element: Variant in value.values():
			_scan_value(element, holder, scene_root, result, visited, depth)
		return

	if not _is_fuse_resource(value):
		# 非 Fuse 资源（SpriteFrames 等引擎资源）不深入
		return

	var res: Resource = value
	if visited.has(res):
		return
	visited[res] = true

	# 外部 .tres 整枝跳过：其嵌套子资源同属外部文件，改动不会随当前场景落盘
	if _is_external_resource(res):
		result["skipped_external"].append({"target": res, "path": res.resource_path})
		return

	# 实例化子场景内的内嵌资源同样整枝跳过
	if not _node_belongs_to_scene(holder, scene_root):
		if "log_level" in res:
			result["skipped_nested_count"] += 1
		return

	if "log_level" in res:
		result["applicable"].append({
			"target": res,
			"holder": holder,
			"current_level": res.get("log_level"),
		})

	# CheckComposite 的 LogicNode 是 RefCounted 内部类非 Resource，特判下钻
	if res is CheckComposite:
		var root_node: Variant = res.get("_root_node")
		if root_node != null:
			_scan_logic_node(root_node, holder, scene_root, result, visited, depth)

	_scan_properties(res, holder, scene_root, result, visited, depth)

## 递归 CheckComposite.LogicNode（叶子 condition / 逻辑 operands）
static func _scan_logic_node(logic_node: Variant, holder: Node, scene_root: Node, result: Dictionary, visited: Dictionary, depth: int) -> void:
	if logic_node == null or visited.has(logic_node) or depth > MAX_DEPTH:
		return
	visited[logic_node] = true

	if logic_node.get("condition") != null:
		_scan_value(logic_node.get("condition"), holder, scene_root, result, visited, depth)

	for operand: Variant in logic_node.get("operands"):
		_scan_logic_node(operand, holder, scene_root, result, visited, depth + 1)

## 判定资源是否 Fuse 组件类型（含容器 EventBinding 与变量资源）
static func _is_fuse_resource(value: Variant) -> bool:
	return value is BaseEvent \
		or value is BaseInstruction \
		or value is BaseCondition \
		or value is ActionRunner \
		or value is EventBinding \
		or value is BaseVariable \
		or value is GlobalVariableResource

## ==================== 批量应用 ====================

## 将选中节点子树内组件的 log_level 批量设为指定级别（走 UndoRedo）
## @param nodes 选中节点数组
## @param scene_root 当前编辑的场景根
## @param level 目标级别
func apply(nodes: Array[Node], scene_root: Node, level: FuseLogger.LogLevel) -> void:
	var collected: Dictionary = collect_components(nodes, scene_root)

	# 过滤已是目标值的组件，避免产生空操作步骤
	var targets: Array[Dictionary] = []
	var backups: Array[Dictionary] = []
	for item: Dictionary in collected["applicable"]:
		if item["current_level"] == level:
			continue
		targets.append({"target": item["target"]})
		backups.append({"target": item["target"], "old_level": item["current_level"]})

	_report(collected, level, targets.size())

	if targets.is_empty():
		return

	var level_name: String = FuseLogger.LogLevel.keys()[level]
	_undo_redo.create_action("设置 Fuse 输出级别为 %s" % level_name)
	_undo_redo.add_do_method(self, "_do_apply", targets, level)
	_undo_redo.add_undo_method(self, "_undo_apply", backups)
	_undo_redo.commit_action()

## Do 操作：批量写入新级别
func _do_apply(targets: Array[Dictionary], level: FuseLogger.LogLevel) -> void:
	for item: Dictionary in targets:
		var target: Object = item["target"]
		if is_instance_valid(target):
			target.set("log_level", level)

## Undo 操作：恢复各组件旧级别
func _undo_apply(backups: Array[Dictionary]) -> void:
	for item: Dictionary in backups:
		var target: Object = item["target"]
		if is_instance_valid(target):
			target.set("log_level", item["old_level"])

## 输出面板报告：修改数、跳过的外部资源与实例内组件
func _report(collected: Dictionary, level: FuseLogger.LogLevel, changed_count: int) -> void:
	var level_name: String = FuseLogger.LogLevel.keys()[level]

	if changed_count > 0:
		print("[LogLevelBatchSetter] 已将 %d 个 Fuse 组件的输出级别设为 %s（Ctrl+S 保存后生效）" % [changed_count, level_name])
	else:
		print("[LogLevelBatchSetter] 选中子树内没有需要修改的 Fuse 组件（目标级别 %s）" % level_name)

	var external_paths: Dictionary = {}
	for item: Dictionary in collected["skipped_external"]:
		external_paths[item["path"]] = true
	if not external_paths.is_empty():
		print("[LogLevelBatchSetter] 跳过 %d 个外部共享资源: %s" % [external_paths.size(), ", ".join(external_paths.keys())])

	var nested_count: int = collected["skipped_nested_count"]
	if nested_count > 0:
		print("[LogLevelBatchSetter] 跳过 %d 个实例化子场景内的组件（需打开源场景修改）" % nested_count)
