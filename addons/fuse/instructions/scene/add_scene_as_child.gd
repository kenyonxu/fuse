@tool
@icon("res://addons/fuse/icons/builtin/FileTree.png")
extends BaseInstruction
class_name AddSceneAsChild

## 将场景实例化为子节点

# 静态缓存：属性提示文本
static var _cached_placeholder_text: String = ""
static var _property_cache_initialized: bool = false

# 场景文件路径
var scene_path: String = ""

# 目标父节点路径
var target_parent: NodePath = NodePath("")

# 新节点名称（空 = 使用场景默认名称）
var new_node_name: String = ""

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ADD_SCENE_AS_CHILD_NAME"
	metadata.category_key = "FUSE_CATEGORY_SCENE"
	metadata.description_key = "FUSE_INSTRUCTION_ADD_SCENE_AS_CHILD_DESC"
	metadata.keywords = ["scene", "instantiate", "child", "add", "spawn", "场景", "实例化", "子节点", "添加", "生成"]
	metadata.builtin_icon = "FileTree"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 初始化静态缓存
static func _init_property_cache() -> void:
	if _property_cache_initialized:
		return
	_cached_placeholder_text = FuseLocalization.translate("FUSE_PLACEHOLDER_LEAVE_EMPTY_FOR_DEFAULT")
	_property_cache_initialized = true

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	_init_property_cache()

	var properties: Array[Dictionary] = []
	# Scene 分类
	properties.append({
		name = "Scene",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 场景路径
	properties.append({
		name = "scene_path",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_FILE,
		hint_string = "*.tscn,*.scn",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Parent 分类
	properties.append({
		name = "Parent",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标父节点
	properties.append({
		name = "target_parent",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Options 分类
	properties.append({
		name = "Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 新节点名称
	properties.append({
		name = "new_node_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
		hint_string = _cached_placeholder_text,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var scene_file = FuseNodeUtils.get_path_display_name(scene_path) if not scene_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")

	var parent_str = ""
	if not target_parent.is_empty():
		parent_str = " " + FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_SCENE_AS_CHILD_TO", {
			"scene": "'" + scene_file + "'",
			"parent": "'" + str(target_parent) + "'"
		})
	else:
		parent_str = " " + FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_SCENE_AS_CHILD_TO_CURRENT", {
			"scene": "'" + scene_file + "'"
		})

	var name_str = ""
	if not new_node_name.is_empty():
		name_str = " " + FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_SCENE_AS_CHILD_NAMED", {
			"name": new_node_name
		})

	resource_name = FuseLocalization.translate("FUSE_INSTRUCTION_ADD_SCENE_AS_CHILD_NAME") + parent_str + name_str

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证场景路径
	if scene_path.is_empty():
		_log_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 加载场景
	var scene_resource = load(scene_path)
	if not scene_resource:
		_log_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
		set_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})
		finished.emit()
		return

	if not scene_resource is PackedScene:
		_log_error_localized("FUSE_ERROR_NOT_PACKED_SCENE", {"scene_path": scene_path})
		set_error_localized("FUSE_ERROR_NOT_PACKED_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene_path": scene_path})
		finished.emit()
		return

	# 实例化场景
	var instance = scene_resource.instantiate()
	if not instance:
		_log_error_localized("FUSE_ERROR_FAILED_INSTANTIATE", {"scene_path": scene_path})
		set_error_localized("FUSE_ERROR_FAILED_INSTANTIATE", FuseError.ErrorType.RUNTIME_ERROR, {"scene_path": scene_path})
		finished.emit()
		return

	# 获取父节点
	var parent: Node
	if target_parent.is_empty():
		# 如果没有指定父节点，使用当前场景
		var scene_tree = Engine.get_main_loop()
		if scene_tree and scene_tree.current_scene:
			parent = scene_tree.current_scene
		else:
			_log_error_localized("FUSE_ERROR_PARENT_NODE_NOT_FOUND", {})
			set_error_localized("FUSE_ERROR_PARENT_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
			finished.emit()
			return
	else:
		parent = context.get_node(target_parent)

	if not parent:
		_log_error_localized("FUSE_ERROR_PARENT_NODE_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_PARENT_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 设置新节点名称
	if not new_node_name.is_empty():
		instance.name = new_node_name

	# 添加到场景树
	parent.add_child(instance)

	_log_info_localized("FUSE_LOG_SCENE_INSTANTIATED_AS_CHILD", {"scene": FuseNodeUtils.get_path_display_name(scene_path), "node_name": instance.name})
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if scene_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCENE_PATH_EMPTY"))

	return errors

## 获取指令描述
func get_description() -> String:
	var scene_file = FuseNodeUtils.get_path_display_name(scene_path) if not scene_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")

	var parent_str = ""
	if not target_parent.is_empty():
		parent_str = " " + FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_SCENE_AS_CHILD_TO", {
			"scene": "",
			"parent": str(target_parent)
		})

	var name_str = ""
	if not new_node_name.is_empty():
		name_str = " " + FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_SCENE_AS_CHILD_NAMED", {
			"name": new_node_name
		})

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_SCENE_AS_CHILD_DESC_FORMAT", {
		"scene": scene_file,
		"parent": parent_str,
		"name": name_str
	})
