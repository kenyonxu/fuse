# addons/fuse/editor/topology/fuse_graph_edit.gd
@tool
class_name FuseGraphEdit
extends GraphEdit

## Fuse 自建 GraphEdit（不依赖 gdscript_ast 的 GDSVirtualGraphEdit）
##
## 简化版（无虚拟化），Fuse 的 Trigger 指令链通常 <30 节点，
## 不需要 GDSVirtualGraphEdit 的 SMALL_GRAPH_THRESHOLD 虚拟化分页。
##
## 数据格式（非 GDSVirtualGraphEdit）：
##   nodes: {node_name: {kind, title, subtitle, pos}}
##   edges: Array [from_name, to_name, from_port, to_port]


## 设置 GraphEdit 内容
func set_graph(p_nodes: Dictionary, p_edges: Array) -> void:
	# 清理现有节点
	for c in get_children():
		if c is GraphNode:
			remove_child(c)
			c.queue_free()

	# 清理现有连线
	clear_connections()

	# 添加节点
	for node_name in p_nodes:
		var info: Dictionary = p_nodes[node_name]
		var gn := FuseGraphNode.new()
		gn.configure(
			info.get("kind", "instruction"),
			info.get("title", "?"),
			info.get("subtitle", "")
		)
		gn.name = node_name
		gn.position_offset = info.get("pos", Vector2(0, 0))
		add_child(gn)

	# 延迟连线（等节点渲染完成）
	call_deferred("_connect_edges", p_edges)


func _connect_edges(p_edges: Array) -> void:
	for edge in p_edges:
		var from_name: String = edge[0]
		var to_name: String = edge[1]
		var from_port: int = edge[2] if edge.size() > 2 else 0
		var to_port: int = edge[3] if edge.size() > 3 else 0

		if has_node(from_name) and has_node(to_name):
			connect_node(from_name, from_port, to_name, to_port)
