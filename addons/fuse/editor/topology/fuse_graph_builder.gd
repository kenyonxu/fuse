# addons/fuse/editor/topology/fuse_graph_builder.gd
@tool
class_name FuseGraphBuilder
extends RefCounted

## 逻辑流图构建器
##
## 遍历 InstructionAnalyzer 的 instructions_tree（8b-0），
## 构建 GraphEdit 可消费的 {nodes, edges} 数据结构（8b-1）。
##
## 数据格式（匹配自建 FuseGraphEdit.set_graph，非 GDSVirtualGraphEdit）：
##   nodes: {node_name: {kind, title, subtitle, pos}}
##   edges: Array of Array [from_name, to_name, from_port, to_port]


var _idx := 0


## 从 topology report 构建 GraphEdit 数据
static func build(report: Dictionary) -> Dictionary:
	var nodes: Dictionary = {}
	var edges: Array = []
	var builder := FuseGraphBuilder.new()

	# Trigger 根节点
	var trigger_name := "n0"
	nodes[trigger_name] = {
		"kind": "trigger",
		"title": report.get("trigger_name", "?"),
		"subtitle": report.get("event", {}).get("resource_name", ""),
		"node_name": trigger_name,
		"pos": Vector2(0, 0)
	}

	# 遍历 instructions_tree（明确 parent + branch label）
	var tree: Array = report.get("instructions_tree", [])
	if tree.is_empty():
		# 回退：使用 instructions_flat 构建线性图
		builder._build_flat(report.get("instructions_flat", []), nodes, edges, trigger_name)
	else:
		builder._build_tree(tree, nodes, edges, trigger_name)

	# 简单网格布局
	_layout_nodes(nodes, edges)

	return {"nodes": nodes, "edges": edges}


## 退化路径：无 instructions_tree 时用 flat 构建线性图
func _build_flat(flat: Array, nodes: Dictionary, edges: Array, parent_name: String) -> void:
	for inst_info in flat:
		_idx += 1
		var node_name := "n%d" % _idx
		nodes[node_name] = {
			"kind": "instruction",
			"title": inst_info.get("name", "?"),
			"subtitle": "",
			"node_name": node_name,
			"pos": Vector2(0, 0)
		}
		edges.append([parent_name, node_name, 0, 0])
		parent_name = node_name  # 链式


## 递归遍历 instructions_tree，明确 parent + branch label
func _build_tree(tree: Array, nodes: Dictionary, edges: Array, parent_name: String, branch_port: int = 0) -> void:
	for node_info in tree:
		_idx += 1
		var node_name := "n%d" % _idx
		var children: Dictionary = node_info.get("children", {})
		var is_branch := not children.is_empty()

		nodes[node_name] = {
			"kind": "branch" if is_branch else "instruction",
			"title": node_info.get("name", "?"),
			"subtitle": "",
			"node_name": node_name,
			"pos": Vector2(0, 0)
		}

		# 连接父节点 → 当前节点，to_port 标记分支类型
		edges.append([parent_name, node_name, 0, branch_port])

		# 递归子分支（branch label → port 映射）
		for branch_label in children:
			var subtree: Array = children[branch_label]
			if subtree.is_empty():
				continue
			var port := 0
			match branch_label:
				"else": port = 1
				"loop": port = 2
				_: port = 0  # "then" or unknown
			_build_tree(subtree, nodes, edges, node_name, port)


# ============================================================
# 布局
# ============================================================

static func _layout_nodes(nodes: Dictionary, edges: Array) -> void:
	## 简单网格布局：按深度层级（level）分配 x 坐标，
	## 同层节点按出现顺序分配 y 坐标。
	if nodes.is_empty():
		return

	# 计算每个节点的深度
	var depths := _compute_depths(nodes, edges)

	# 按深度分组
	var by_depth: Dictionary = {}  # depth → [node_names]
	for node_name in depths:
		var d: int = depths[node_name]
		if not by_depth.has(d):
			by_depth[d] = []
		by_depth[d].append(node_name)

	# 按 depth 排序
	var sorted_depths := by_depth.keys()
	sorted_depths.sort()

	# 分配位置
	var x_step := 280.0
	var y_start := 30.0
	var y_step := 120.0

	for d in sorted_depths:
		var names: Array = by_depth[d]
		var x: float = 30.0 + d * x_step
		for i in names.size():
			var node_name: String = names[i]
			if node_name in nodes:
				nodes[node_name]["pos"] = Vector2(x, y_start + i * y_step)


static func _compute_depths(nodes: Dictionary, edges: Array) -> Dictionary:
	## 计算每个节点的深度（最短路径从根到达）
	var depths := {}
	for node_name in nodes:
		depths[node_name] = 0

	var changed := true
	while changed:
		changed = false
		for edge in edges:
			var from_name: String = edge[0]
			var to_name: String = edge[1]
			if from_name in depths and to_name in depths:
				if depths[to_name] <= depths[from_name]:
					depths[to_name] = depths[from_name] + 1
					changed = true

	return depths
