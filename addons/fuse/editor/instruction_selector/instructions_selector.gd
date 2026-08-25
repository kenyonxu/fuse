# 文件：instructions_selector.gd
@tool
class_name InstructionSelector extends AcceptDialog

var edited_object: Object
var property_name: String
var category_tree: Tree
var search_box: LineEdit
var _updating_ui: bool = false  # 防止重复更新的保护标志
var _fuse_localization_class: RefCounted = null  # 缓存本地化类引用

func _init(p_edited_object: Object, p_property_name: String):
    edited_object = p_edited_object
    property_name = p_property_name

    # 监听数组变化
    edited_object.property_list_changed.connect(_on_property_changed)

func _ready() -> void:
    # 一次性加载本地化类
    if _fuse_localization_class == null:
        _fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

    # 在窗口准备好后创建UI和初始化数据
    # 强制重新检测编辑器语言
    _refresh_locale_if_needed()

    # 强制刷新所有指令元数据的缓存
    _invalidate_all_metadata_caches()

    _setup_dialog()
    _create_ui()
    _update_instruction_list("")

## 刷新语言设置
##
## 每次打开指令选择器时，重新检测编辑器语言并更新本地化系统
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

                print("指令选择器: 语言已更新为 ", _fuse_localization_class.get_locale_code())


## 强制刷新所有元数据缓存
##
## 确保所有指令元数据在指令选择器打开时使用最新的本地化设置
func _invalidate_all_metadata_caches() -> void:
    var all_instructions = InstructionRegistry.get_all_instructions()
    for instruction_info in all_instructions:
        if instruction_info.has("metadata"):
            var metadata = instruction_info.metadata
            if metadata and metadata.has_method("_invalidate_cache"):
                metadata._invalidate_cache()


func _setup_dialog() -> void:
    # 设置对话框属性 - 更大的窗口尺寸
    if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
        self.title = _fuse_localization_class.translate("FUSE_UI_INSTRUCTION_SELECTOR_TITLE")
    else:
        self.title = "添加指令"  # 回退文本

    self.size = Vector2i(800, 800)  # 两倍窗口尺寸
    # 确保对话框在屏幕中心显示
    self.popup_centered()

func _create_ui() -> void:
    # 简化布局：只有搜索框 + 分类树
    var main_vbox = VBoxContainer.new()

    # 搜索框
    search_box = LineEdit.new()
    if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
        search_box.placeholder_text = _fuse_localization_class.translate("FUSE_UI_SEARCH_PLACEHOLDER")
    else:
        search_box.placeholder_text = "搜索指令..."  # 回退文本
    search_box.text_changed.connect(_on_search_text_changed)
    main_vbox.add_child(search_box)

    # 分类树（占据主要空间）
    category_tree = Tree.new()
    category_tree.columns = 2  # 第一列显示指令名，第二列显示加号按钮
    category_tree.hide_root = true
    category_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    category_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    category_tree.item_selected.connect(_on_category_selected)
    category_tree.button_clicked.connect(_on_tree_button_clicked)
    category_tree.item_activated.connect(_on_item_activated)

    # 设置列宽：第一列占据大部分空间，第二列固定宽度
    category_tree.set_column_expand(0, true)  # 第一列可扩展
    category_tree.set_column_expand(1, false) # 第二列固定宽度
    category_tree.set_column_custom_minimum_width(1, 32)  # 第二列最小宽度32像素

    # 创建根项目（即使隐藏也需要）
    var root = category_tree.create_item()
    root.set_text(0, "Root")

    main_vbox.add_child(category_tree)

    # 将主容器添加为对话框的子节点
    self.add_child(main_vbox)

    # 移除确定按钮的添加指令功能，确保功能唯一化
    # 只保留取消信号用于关闭对话框
    self.canceled.connect(_on_cancel_button_pressed)

func _on_property_changed() -> void:
    # 这个方法在窗口模式下不需要，因为窗口是临时的
    pass

func _on_cancel_button_pressed() -> void:
    self.hide()

func _on_search_text_changed(new_text: String) -> void:
    _update_instruction_list(new_text)

func _on_category_selected() -> void:
    if _updating_ui:
        return

    # 获取选中的树项目
    var selected = category_tree.get_selected()
    if not selected:
        return

    # 检查是否是指令项目（不是分类项目）
    var instruction_info = selected.get_metadata(0)
    if instruction_info:
        # 直接显示指令信息（简化版，不需要同步到右侧列表）
        _show_instruction_preview(instruction_info)
    else:
        # 如果是分类项目，只是刷新列表
        _update_instruction_list("")

func _on_tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
    # 处理Tree中的按钮点击事件
    if column == 1 and id == 0:  # 第二列的加号按钮
        var instruction_info = item.get_metadata(0)
        if instruction_info:
            _add_instruction_to_array(instruction_info)

func _on_item_activated() -> void:
    # 处理树项目双击或Enter键事件
    var selected = category_tree.get_selected()
    if not selected:
        return

    # 获取指令信息
    var instruction_info = selected.get_metadata(0)
    if not instruction_info:
        # 如果是分类项目，展开/折叠
        selected.set_collapsed(not selected.is_collapsed())
        return

    # 添加指令到数组（与点击加号按钮行为一致）
    _add_instruction_to_array(instruction_info)

func _on_instruction_selected(index: int = -1) -> void:
    # 简化版 - 不需要处理右侧列表选择
    pass

func _on_add_instruction_button_pressed() -> void:
    # 简化版 - 只从左侧分类树获取选中的指令
    var selected = category_tree.get_selected()
    var instruction_info = null

    if selected:
        instruction_info = selected.get_metadata(0)

    if instruction_info:
        _add_instruction_to_array(instruction_info)

func _add_instruction_to_array(instruction_info: Dictionary):
    if not instruction_info or not instruction_info.has("class"):
        print("错误：指令信息无效")
        return

    var instruction_class = instruction_info.class
    if not instruction_class:
        print("错误：指令类为空")
        return

    var instruction_instance = instruction_class.new()

    # 获取当前指令数组
    var instructions = edited_object.get(property_name)
    if not instructions:
        instructions = []

    # 创建新数组并添加指令
    var new_instructions = instructions.duplicate()
    new_instructions.append(instruction_instance)

    # 直接追加到数组（适用于所有对象，包括 ActionRunner 和嵌套指令列表）
    var existing_array = edited_object.get(property_name)
    if existing_array == null:
        existing_array = []
    existing_array.append(instruction_instance)
    edited_object.set(property_name, existing_array)

    # 等待一帧后验证（解决时序问题）
    await get_tree().process_frame

    # 验证设置是否成功
    var verified = edited_object.get(property_name)
    if not verified or verified.size() == 0 or verified[-1] != instruction_instance:
        print("警告：指令添加后验证失败")
        return

    # 通知编辑器更新
    if edited_object.has_method("notify_property_list_changed"):
        edited_object.notify_property_list_changed()

    if edited_object is Resource:
        edited_object.emit_changed()
        # 重要：不要重新检查对象，避免Inspector切换视图
        # 让编辑器自然刷新当前选中的对象

    # 使用本地化名称输出日志
    var metadata = instruction_info.metadata
    var localized_name = metadata.get_localized_name() if metadata and metadata.has_method("get_localized_name") else (metadata.name if metadata else "未知")
    print("成功添加指令：", localized_name)

func _verify_addition(instruction_name: String, actual_size: int):
    # 延迟验证，确保编辑器完全同步
    var current_instructions = edited_object.get(property_name)
    var final_size = current_instructions.size() if current_instructions else 0

    # 强制Inspector刷新
    call_deferred("_delayed_inspect_object", edited_object)

func _delayed_inspect_object(obj: Object):
    # 延迟检查对象，确保数据完全写入后再刷新
    EditorInterface.inspect_object(obj)

func _force_editor_refresh():
    # 强制刷新编辑器界面
    EditorInterface.inspect_object(edited_object)

func _update_instruction_list(search_query: String = ""):
    if _updating_ui:
        return

    _updating_ui = true
    var search_results = InstructionSearch.search(search_query)

    # 提取指令信息用于分类树
    var filtered_instructions: Array[Dictionary] = []
    for result in search_results:
        filtered_instructions.append(result.item)

    # 使用延迟调用来更新分类树，避免在信号处理期间操作Tree
    call_deferred("_update_category_tree_deferred", filtered_instructions)

func _update_category_tree_deferred(instructions: Array[Dictionary]):
    # 延迟更新分类树，避免Tree控件blocked状态
    _update_category_tree(instructions)
    _updating_ui = false

func _update_category_tree(instructions: Array[Dictionary]):
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

    # 按分类组织指令
    var categories = {}
    for instruction_info in instructions:
        # 防御性编程：检查指令信息完整性
        if not instruction_info or not instruction_info.has("metadata"):
            continue

        var metadata = instruction_info.metadata
        if metadata == null:
            continue

        # 使用本地化方法获取分类
        var category = metadata.get_localized_category() if metadata.has_method("get_localized_category") else (metadata.category if metadata.category else "未分类")

        if not categories.has(category):
            categories[category] = []
        categories[category].append(instruction_info)

    # 创建分类树
    for category_name in categories.keys():
        var category_item = category_tree.create_item(root)  # 明确指定父项目
        if category_item == null:
            print("错误：无法创建分类项目：", category_name)
            continue

        category_item.set_text(0, category_name)
        category_item.set_collapsed(false)  # 默认展开

        for instruction_info in categories[category_name]:
            if not instruction_info or not instruction_info.has("metadata"):
                continue

            var metadata = instruction_info.metadata
            if metadata == null:
                continue

            # 使用本地化方法获取名称
            var localized_name = metadata.get_localized_name() if metadata.has_method("get_localized_name") else metadata.name
            var localized_desc = metadata.get_localized_description() if metadata.has_method("get_localized_description") else metadata.description

            if localized_name == null or localized_name == "":
                continue

            var instruction_item = category_tree.create_item(category_item)
            if instruction_item == null:
                print("错误：无法创建指令项目：", localized_name)
                continue

            instruction_item.set_text(0, localized_name)
            instruction_item.set_metadata(0, instruction_info)
            instruction_item.set_selectable(0, true)   # 第一列可选中，用于选择指令
            instruction_item.set_selectable(1, false) # 第二列不可选中，避免空白区域被选中

            # 设置tooltip为本地化的描述
            if localized_desc:
                instruction_item.set_tooltip_text(0, localized_desc)

            # 显示指令图标（如果可用）
            if metadata and metadata.has_method("get_icon_texture"):
                var icon = metadata.get_icon_texture()
                if icon:
                    instruction_item.set_icon(0, icon)

            # 在第二列添加加号按钮
            var plus_icon = FuseIconManager.get_builtin_icon("Add")
            instruction_item.add_button(1, plus_icon, 0, false, "添加指令")

func _show_instruction_preview(instruction_info: Dictionary):
    # 简化版 - 使用分类树的tooltip显示指令预览
    if category_tree and instruction_info and instruction_info.has("metadata"):
        var metadata = instruction_info.metadata
        if metadata:
            # 使用本地化方法获取描述
            var localized_desc = metadata.get_localized_description() if metadata.has_method("get_localized_description") else metadata.description
            if localized_desc:
                # 设置当前选中项目的tooltip - 使用TreeItem的set_tooltip_text方法
                var selected = category_tree.get_selected()
                if selected:
                    selected.set_tooltip_text(0, localized_desc)