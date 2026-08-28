# addons/fuse/editor/serialization/nodepath_resolver.gd
@tool
class_name NodePathResolver
extends RefCounted

## NodePath 提取与自动匹配
##
## 从预设指令树提取所有 NodePath 引用（8a-1），
## 并提供三级匹配策略（相对路径结构→全局同名→手动选）生成映射建议（8a-2）。
##
## 依赖 InstructionAnalyzer._extract_nodepaths（Stage 6.5）做属性级别提取。

const _SUB_INSTRUCTIONS := ["instructions", "else_instructions", "loop_instructions"]


# ============================================================
# 8a-1: NodePath 提取
# ============================================================

## 从预设指令序列提取所有 NodePath 引用（去重）
## 递归扫描嵌套指令（if/else/loop）及 condition 节点。
static func extract_nodepaths(instructions: Array) -> Array[String]:
	var found: Array[String] = []
	var report := {"nodes": []}
	_scan_instructions(instructions, report)
	for np_str in report["nodes"]:
		if np_str not in found:
			found.append(np_str)
	return found


static func _scan_instructions(instructions: Array, report: Dictionary) -> void:
	for inst in instructions:
		if inst == null:
			continue

		InstructionAnalyzer._extract_nodepaths(inst, report)

		# Condition 节点中的 NodePath 引用
		# typeof 判别排除 BreakpointInstruction.condition 一类表达式 String（String 为真值）
		if "condition" in inst:
			var cond = inst.get("condition")
			if cond != null and typeof(cond) == TYPE_OBJECT:
				InstructionAnalyzer._extract_nodepaths(cond, report)

		# 递归扫描子指令（if/else/loop）
		for sub_key in _SUB_INSTRUCTIONS:
			if sub_key in inst and inst.get(sub_key) is Array:
				_scan_instructions(inst.get(sub_key), report)


# ============================================================
# 8a-2: 自动匹配 — 三级策略
# ============================================================

## 公开静态：尝试所有策略解析 NodePath 字符串到节点，失败返 null
## 锚点为 scene_root（与 E1 静态分析匹配；预设粘贴用 resolve_mapping 的 target_node 锚点不变）。
## 策略：
##   1. scene_root.get_node_or_null(np) —— 覆盖绝对路径 /root/... 和相对路径 Player
##   1b. scene_root.get_parent().get_node_or_null(np) —— 覆盖 ../... 跨兄弟路径
##   2. scene_root.find_children(last_name, ...) —— 全树按最后段节点名搜索（兜底）
## 守卫：np_str 为空或 scene_root 为 null 时直接返 null
static func resolve_or_null(np_str: String, scene_root: Node) -> Node:
	# 自守卫（spec §3.4 + 审阅 MEDIUM #4）
	if np_str.is_empty() or scene_root == null:
		return null

	var np := NodePath(np_str)

	# —— 策略 1: 相对路径结构 —— 从 scene_root 直接解析
	var found: Node = scene_root.get_node_or_null(np)
	if found != null:
		return found

	# —— 策略 1b: 父级回退 —— 覆盖 ../... 跨兄弟路径
	var parent := scene_root.get_parent()
	if parent != null:
		found = parent.get_node_or_null(np)
		if found != null:
			return found

	# —— 策略 2: 全局同名 —— 取最后一段节点名，全场景广度优先搜索
	if np.get_name_count() > 0:
		var last_name := _get_last_name(np_str)
		if last_name != "" and last_name != ".." and last_name != ".":
			# 守卫：节点未入树时 get_tree() 为 null，find_children 会崩溃
			if scene_root.get_tree() != null:
				var children := scene_root.find_children(last_name, "", true, false)
				if not children.is_empty():
					return children[0]

	# —— 策略 3: 全部失败 ——
	return null


## 生成 NodePath 映射建议
##
## 返回 {old_np_str: {"new": NodePath, "matched": bool, "suggestions": Array[String]}}
## matched=true → new 字段包含自动匹配结果
## matched=false → suggestions 可供手动选择
static func resolve_mapping(
	old_nodepaths: Array[String],
	target_node: Node
) -> Dictionary:
	var mapping := {}

	for old_np_str in old_nodepaths:
		var old_np := NodePath(old_np_str)
		var result := {"matched": false, "new": NodePath(""), "suggestions": []}

		# —— 策略 1: 相对路径结构匹配 ——
		var resolved := _match_relative(old_np, target_node)
		if resolved != NodePath(""):
			result.matched = true
			result.new = resolved

		# —— 策略 2: 全局同名匹配 ——
		if not result.matched and old_np.get_name_count() > 0:
			var last_name := _get_last_name(old_np_str)
			if last_name != "" and last_name != ".." and last_name != ".":
				var found := _find_node_by_name(target_node, last_name)
				if found:
					result.matched = true
					result.new = target_node.get_path_to(found)

		# —— 无匹配 → 收集场景所有节点作为候选 ——
		if not result.matched:
			result.suggestions = _collect_node_suggestions(target_node)

		mapping[old_np_str] = result

	return mapping


# ============================================================
# 策略 1: 相对路径结构匹配
# ============================================================

## 从 target_node 解析 old_np 相对路径，若新场景结构相符则返回映射
static func _match_relative(old_np: NodePath, target_node: Node) -> NodePath:
	var found := target_node.get_node_or_null(old_np)
	if found:
		return target_node.get_path_to(found)

	# 也尝试从父节点解析（预设可能在 Trigger 的父节点）
	var parent := target_node.get_parent()
	if parent:
		found = parent.get_node_or_null(old_np)
		if found:
			return target_node.get_path_to(found)

	return NodePath("")


# ============================================================
# 策略 2: 全局同名匹配
# ============================================================

## 从场景中搜索同名节点（广度优先，返回第一个匹配）
static func _find_node_by_name(from_node: Node, name: String) -> Node:
	var tree := from_node.get_tree()
	if tree == null:
		return null
	var scene_root := tree.current_scene
	if scene_root == null:
		scene_root = tree.root
	if scene_root == null:
		return null

	# 先查当前场景根以下
	var found: Array[Node] = scene_root.find_children(name, "", true, false)
	if not found.is_empty():
		return found[0]

	# 根节点自身
	if scene_root.name == name:
		return scene_root

	return null


# ============================================================
# 候选列表
# ============================================================

## 收集场景所有节点路径，供手动选择
static func _collect_node_suggestions(target_node: Node) -> Array[String]:
	var suggestions: Array[String] = []
	var tree := target_node.get_tree()
	if tree == null:
		return suggestions
	# 优先编辑中场景根（过滤编辑器内部节点，避免映射面板显示 @editor 等）
	var root: Node = null
	if Engine.is_editor_hint():
		root = EditorInterface.get_edited_scene_root()
	if root == null:
		root = tree.current_scene
	if root == null:
		root = tree.root
	if root == null:
		return suggestions

	_collect_paths_recursive(root, "", suggestions)
	return suggestions


static func _collect_paths_recursive(node: Node, prefix: String, out: Array[String]) -> void:
	var path := prefix + "/" + node.name if prefix != "" else node.name
	out.append(path)
	for child in node.get_children():
		_collect_paths_recursive(child, path, out)


# ============================================================
# 辅助
# ============================================================

## 提取 NodePath 字符串的最后一段节点名
static func _get_last_name(np_str: String) -> String:
	var idx := np_str.rfind("/")
	var last := np_str.substr(idx + 1) if idx >= 0 else np_str
	return last
