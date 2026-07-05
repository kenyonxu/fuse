# addons/fuse/editor/topology/fuse_graph_node.gd
@tool
class_name FuseGraphNode
extends GraphNode

## Fuse 自建 GraphNode（不依赖 gdscript_ast）
##
## 三种节点类型：
##   trigger     — 触发源（蓝色）
##   instruction — 普通指令（绿色）
##   branch      — 分支指令 if/else/loop（橙色）


func configure(p_kind: String, p_title: String, p_subtitle: String) -> void:
	title = p_title
	custom_minimum_size = Vector2(200, 0)

	# 标题颜色（用于区分节点类型）
	match p_kind:
		"trigger":
			add_theme_color_override("title_color", Color(0.3, 0.6, 1.0))
			self_modulate = Color(0.9, 0.95, 1.0)
		"branch":
			add_theme_color_override("title_color", Color(1.0, 0.65, 0.1))
			self_modulate = Color(1.0, 0.95, 0.85)
		"instruction":
			add_theme_color_override("title_color", Color(0.4, 0.9, 0.4))
			self_modulate = Color(0.9, 1.0, 0.9)

	# 副标题标签
	if not p_subtitle.is_empty():
		var label := Label.new()
		label.text = p_subtitle
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color.GRAY)
		add_child(label)

	# 插槽配置
	# slot 0: 左侧输入(type 0) + 右侧输出(type 0) — "then" 分支
	# slot 1: 左侧输入(type 1) — "else" 分支（仅输入，用于展示分支连线颜色）
	set_slot(0, true, 0, Color(0.3, 0.6, 1.0), true, 0, Color(0.3, 0.6, 1.0))
	set_slot(1, true, 1, Color(1.0, 0.65, 0.1), false, -1, Color.TRANSPARENT)
