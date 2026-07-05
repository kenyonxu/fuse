# 文件：component_selector.gd
@tool
class_name ComponentSelector extends AcceptDialog

## Fuse 组件通用选择器
##
## 统一的组件选择界面，支持 Instruction、Event、Condition 三种组件类型
## 单选模式：点击组件即选中并关闭对话框

var edited_object: Object
var property_name: String
var component_type: ComponentRegistry.ComponentType
var category_tree: Tree
var search_box: LineEdit
var _updating_ui: bool = false  # 防止重复更新的保护标志
var _fuse_localization_class: RefCounted = null  # 缓存本地化类引用

func _init(p_edited_object: Object, p_property_name: String, p_component_type: ComponentRegistry.ComponentType):
	edited_object = p_edited_object
	property_name = p_property_name
	component_type = p_component_type

func _ready() -> void:
	# 一次性加载本地化类
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 在窗口准备好后创建UI和初始化数据
	# 强制重新检测编辑器语言
	_refresh_locale_if_needed()

	_setup_dialog()
	_create_ui()
	_update_component_list("")

## 刷新语言设置
##
## 每次打开选择器时，重新检测编辑器语言并更新本地化系统
func _refresh_locale_if_needed() -> void:
	if not _fuse_localization_class or not _fuse_localization_class.has_method("set_locale"):
		return

	# 检测编辑器语言
	if OS.has_feature("editor"):
		var editor_settings = EditorInterface.get_editor_settings()
		if editor_settings:
			var editor_locale = editor_settings.get("interface/editor/editor_language")
			if editor_locale:
				# 根据编辑器语言设置 FuseLocalization
				if editor_locale.begins_with("en"):
					_fuse_localization_class.set_locale("en_US")
				elif editor_locale.begins_with("zh"):
					_fuse_localization_class.set_locale("zh_CN")

				print("组件选择器: 语言已更新为 ", _fuse_localization_class.get_locale_code())

func _setup_dialog() -> void:
	# 设置对话框标题
	var title_key := ""
	match component_type:
		ComponentRegistry.ComponentType.EVENT:
			title_key = "FUSE_UI_EVENT_SELECTOR_TITLE"
		ComponentRegistry.ComponentType.CONDITION:
			title_key = "FUSE_UI_CONDITION_SELECTOR_TITLE"
		_:
			title_key = "FUSE_UI_COMPONENT_SELECTOR_TITLE"

	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		self.title = _fuse_localization_class.translate(title_key)
	else:
		match component_type:
			ComponentRegistry.ComponentType.EVENT:
				self.title = "选择事件"
			ComponentRegistry.ComponentType.CONDITION:
				self.title = "选择条件"
			_:
				self.title = "选择组件"

	self.size = Vector2i(600, 600)
	# 确保对话框在屏幕中心显示
	self.popup_centered()

func _create_ui() -> void:
	# 简化布局：只有搜索框 + 分类树
	var main_vbox = VBoxContainer.new()

	# 搜索框
	search_box = LineEdit.new()
	var placeholder_key := ""
	match component_type:
		ComponentRegistry.ComponentType.EVENT:
			placeholder_key = "FUSE_UI_SEARCH_EVENT_PLACEHOLDER"
		ComponentRegistry.ComponentType.CONDITION:
			placeholder_key = "FUSE_UI_SEARCH_CONDITION_PLACEHOLDER"
		_:
			placeholder_key = "FUSE_UI_SEARCH_PLACEHOLDER"

	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		search_box.placeholder_text = _fuse_localization_class.translate(placeholder_key)
	else:
		match component_type:
			ComponentRegistry.ComponentType.EVENT:
				search_box.placeholder_text = "搜索事件..."
			ComponentRegistry.ComponentType.CONDITION:
				search_box.placeholder_text = "搜索条件..."
			_:
				search_box.placeholder_text = "搜索组件..."

	search_box.text_changed.connect(_on_search_text_changed)
	main_vbox.add_child(search_box)

	# 分类树（占据主要空间）
	category_tree = Tree.new()
	category_tree.hide_root = true
	category_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_tree.item_activated.connect(_on_item_activated)  # 双击或按Enter激活

	# 创建根项目（即使隐藏也需要）
	var root = category_tree.create_item()
	root.set_text(0, "Root")

	main_vbox.add_child(category_tree)

	# 将主容器添加为对话框的子节点
	self.add_child(main_vbox)

	# 移除确定按钮（单选模式直接点击选择）
	# 只保留取消信号用于关闭对话框
	self.canceled.connect(_on_cancel_button_pressed)

func _on_cancel_button_pressed() -> void:
	self.hide()

func _on_search_text_changed(new_text: String) -> void:
	_update_component_list(new_text)

func _on_item_activated() -> void:
	# 处理树项目双击或Enter键事件
	var selected = category_tree.get_selected()
	if not selected:
		return

	# 获取组件信息
	var component_info = selected.get_metadata(0)
	if not component_info:
		# 如果是分类项目，展开/折叠
		selected.set_collapsed(not selected.is_collapsed())
		return

	# 选中组件并关闭对话框
	_set_component(component_info)
	self.hide()

func _update_component_list(search_query: String = ""):
	if _updating_ui:
		return

	_updating_ui = true
	var search_results = ComponentRegistry.search(component_type, search_query)

	# 使用延迟调用来更新分类树，避免在信号处理期间操作Tree
	call_deferred("_update_category_tree_deferred", search_results)

func _update_category_tree_deferred(components: Array[Dictionary]):
	# 延迟更新分类树，避免Tree控件blocked状态
	_update_category_tree(components)
	_updating_ui = false

func _update_category_tree(components: Array[Dictionary]):
	if not category_tree or not category_tree.is_inside_tree():
		return

	category_tree.clear()

	# 重新创建根项目
	var root = category_tree.create_item()
	if root == null:
		print("错误：无法创建根项目，Tree可能被blocked")
		_updating_ui = false
		return

	root.set_text(0, "Root")

	# 如果没有搜索结果，显示提示
	if components.is_empty():
		var empty_item = category_tree.create_item(root)
		var empty_text = "没有找到匹配的组件"
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			empty_text = _fuse_localization_class.translate("FUSE_UI_NO_COMPONENTS_FOUND")
		empty_item.set_text(0, empty_text)
		empty_item.set_selectable(0, false)
		return

	# 按分类组织组件
	var categories = {}
	for component_info in components:
		# 防御性编程：检查组件信息完整性
		if not component_info or not component_info.has("metadata"):
			continue

		var metadata = component_info.metadata
		if metadata == null:
			continue

		# 使用本地化方法获取分类
		var category = metadata.get_localized_category() if metadata.has_method("get_localized_category") else (metadata.category if metadata.category else "未分类")

		if not categories.has(category):
			categories[category] = []
		categories[category].append(component_info)

	# 创建分类树
	for category_name in categories.keys():
		var category_item = category_tree.create_item(root)
		if category_item == null:
			print("错误：无法创建分类项目：", category_name)
			continue

		category_item.set_text(0, category_name)
		category_item.set_collapsed(false)  # 默认展开

		for component_info in categories[category_name]:
			if not component_info or not component_info.has("metadata"):
				continue

			var metadata = component_info.metadata
			if metadata == null:
				continue

			# 使用本地化方法获取名称
			var localized_name = metadata.get_localized_name() if metadata.has_method("get_localized_name") else metadata.name
			var localized_desc = metadata.get_localized_description() if metadata.has_method("get_localized_description") else metadata.description

			if localized_name == null or localized_name == "":
				continue

			var component_item = category_tree.create_item(category_item)
			if component_item == null:
				print("错误：无法创建组件项目：", localized_name)
				continue

			component_item.set_text(0, localized_name)
			component_item.set_metadata(0, component_info)
			component_item.set_selectable(0, true)

			# 设置tooltip为本地化的描述
			if localized_desc:
				component_item.set_tooltip_text(0, localized_desc)

			# 显示组件图标（如果可用）
			if metadata and metadata.has_method("get_icon_texture"):
				var icon = metadata.get_icon_texture()
				if icon:
					component_item.set_icon(0, icon)

func _set_component(component_info: Dictionary):
	if not component_info or not component_info.has("class"):
		print("错误：组件信息无效")
		return

	var component_class = component_info.class
	if not component_class:
		print("错误：组件类为空")
		return

	# 创建组件实例
	var component_instance = component_class.new()

	# 设置属性
	edited_object.set(property_name, component_instance)

	# 通知编辑器更新
	if edited_object.has_method("notify_property_list_changed"):
		edited_object.notify_property_list_changed()

	if edited_object is Resource:
		edited_object.emit_changed()

	# 使用本地化名称输出日志
	var metadata = component_info.metadata
	var localized_name = metadata.get_localized_name() if metadata and metadata.has_method("get_localized_name") else (metadata.name if metadata else "未知")

	var component_type_name := ""
	match component_type:
		ComponentRegistry.ComponentType.EVENT:
			component_type_name = "事件"
		ComponentRegistry.ComponentType.CONDITION:
			component_type_name = "条件"
		_:
			component_type_name = "组件"

	print("成功设置%s：%s" % [component_type_name, localized_name])
