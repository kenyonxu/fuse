@tool
@icon("res://addons/fuse/icons/builtin/Load.png")
class_name CheckPreloadStatus extends BaseCondition
## 检查预加载状态条件
##
## 用于检查场景或资源是否已完成预加载。
## 此条件是线程安全的（只调用 ResourceLoader API）。
##
## 使用 PreloadSceneInstruction.is_scene_loaded() 和 get_loaded_scene() 静态方法。

## 预加载状态枚举
enum PreloadStatus {
	LOADED,      ## 已加载完成
	LOADING,     ## 正在加载中
	FAILED,      ## 加载失败
	NOT_LOADED   ## 未开始加载
}

## 场景路径
var scene_path: String = "":
	set(value):
		scene_path = value
		_update_resource_name()

## 期望的状态
var expected_status: PreloadStatus = PreloadStatus.LOADED:
	set(value):
		expected_status = value
		_update_resource_name()

## 更新资源名称
func _update_resource_name():
	var status_name = PreloadStatus.keys()[expected_status]
	if scene_path.is_empty():
		resource_name = FuseLocalization.translate_format(
			"FUSE_CONDITION_CHECK_PRELOAD_STATUS_FORMAT",
			{"scene": FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED"), "status": status_name}
		)
	else:
		resource_name = FuseLocalization.translate_format(
			"FUSE_CONDITION_CHECK_PRELOAD_STATUS_FORMAT",
			{"scene": FuseNodeUtils.get_path_display_name(scene_path), "status": status_name}
		)

	_description = resource_name

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
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
		hint_string = "*.tscn,*.scn,*.res",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Status 分类
	properties.append({
		name = "Expected Status",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 期望状态
	properties.append({
		name = "expected_status",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Loaded,Loading,Failed,Not Loaded",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 设置元数据
func _setup_metadata():
	pass

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	if scene_path.is_empty():
		_log_error("Scene path is empty")
		_create_fuse_error(
			FuseLocalization.translate("FUSE_ERROR_SCENE_PATH_EMPTY"),
			FuseError.ErrorType.VALIDATION_ERROR
		)
		return false

	# 使用 PreloadSceneInstruction 的静态方法检查状态
	var status = ResourceLoader.load_threaded_get_status(scene_path)

	var actual_status: PreloadStatus
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			actual_status = PreloadStatus.LOADED
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			actual_status = PreloadStatus.LOADING
		ResourceLoader.THREAD_LOAD_FAILED:
			actual_status = PreloadStatus.FAILED
		_:
			actual_status = PreloadStatus.NOT_LOADED

	var status_name = PreloadStatus.keys()[actual_status]
	var expected_name = PreloadStatus.keys()[expected_status]
	_log_debug("Preload status for '%s': %s (expected: %s)" % [FuseNodeUtils.get_path_display_name(scene_path), status_name, expected_name])

	return actual_status == expected_status

## 计算线程安全性
## 此条件是线程安全的，因为：
## 1. 只调用 ResourceLoader.load_threaded_get_status() 静态方法
## 2. 不访问节点属性
## 3. 不需要 ExecutionContext（除了日志）
## 4. 纯状态检查操作
func _compute_thread_safety() -> bool:
	# 调用基类缓存逻辑
	if _thread_safety_computed:
		return _thread_safety_cached

	# 此条件是线程安全的
	_thread_safety_cached = true
	_thread_safety_computed = true
	return true

## 计算条件依赖
func _compute_dependencies() -> Array[String]:
	# 此条件不依赖任何变量
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "check_preload_status"

## 获取条件分类
func get_condition_category() -> String:
	return "scene"

## 获取条件描述
func get_description() -> String:
	var status_name = PreloadStatus.keys()[expected_status]
	if scene_path.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_CHECK_PRELOAD_STATUS_NOT_SET")
	return FuseLocalization.translate_format(
		"FUSE_CONDITION_CHECK_PRELOAD_STATUS_DESC",
		{"scene": FuseNodeUtils.get_path_display_name(scene_path), "status": status_name}
	)

## 获取条件参数
func get_parameters() -> Dictionary:
	return {
		"scene_path": scene_path,
		"expected_status": expected_status
	}

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if scene_path.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_SCENE_PATH_EMPTY")
		errors.append(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)

	return errors

## 获取详细条件信息
func get_detailed_info() -> Dictionary:
	var info = super.get_detailed_info()
	info["scene_path"] = scene_path
	info["expected_status"] = PreloadStatus.keys()[expected_status]
	return info

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_CHECK_PRELOAD_STATUS_NAME"
	metadata.category_key = "FUSE_CATEGORY_SCENE"
	metadata.description_key = "FUSE_CONDITION_CHECK_PRELOAD_STATUS_DESC"
	metadata.keywords = [
		"preload", "预加载", "status", "状态", "loaded", "已加载",
		"loading", "加载中", "scene", "场景", "check", "检查",
		"async", "异步", "background", "后台"
	]
	metadata.builtin_icon = "Load"
	return metadata
