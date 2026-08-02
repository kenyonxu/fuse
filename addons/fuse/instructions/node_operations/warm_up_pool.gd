@tool
@icon("res://addons/fuse/icons/builtin/TimeScreen.svg")
extends BaseInstruction
class_name WarmUpPool

## 预热对象池
##
## 预先创建指定数量的场景对象放入池中，减少运行时创建开销
## 适用于游戏启动时预加载常用对象，避免首次使用时的卡顿
##
## 使用场景：
## - 游戏启动时预加载子弹、特效等频繁使用的对象
## - 场景加载时预热该场景所需的对象池
## - 避免运行时首次实例化时的卡顿

## 预热模式
enum WarmUpMode {
	IMMEDIATE,  ## 立即预热所有对象
	BATCH       ## 分批预热，避免单帧卡顿
}

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# WarmUpPool 指令在 BATCH 模式下使用回调机制（定时器轮询）而非 await
	# 即使某些执行路径是同步的，声明为异步是安全的，因为同步路径会立即完成
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

## 场景路径
var scene_path: String = "":
	set(value):
		if scene_path != value:
			scene_path = value
			_update_resource_name()

## 预热数量
var warm_up_count: int = 10:
	set(value):
		if warm_up_count != value:
			warm_up_count = value
			_update_resource_name()

## 池初始大小
var pool_initial_size: int = 20:
	set(value):
		pool_initial_size = value
		notify_property_list_changed()

## 池最大大小
var pool_max_size: int = 100:
	set(value):
		pool_max_size = value
		notify_property_list_changed()

## 预热模式
var warm_up_mode: WarmUpMode = WarmUpMode.IMMEDIATE:
	set(value):
		if warm_up_mode != value:
			warm_up_mode = value
			_update_resource_name()
			notify_property_list_changed()

## 每批预热数量（仅当 warm_up_mode == BATCH 时使用）
var batch_size: int = 5:
	set(value):
		if batch_size != value:
			batch_size = value
			_update_resource_name()

## 批次间延迟（秒，仅当 warm_up_mode == BATCH 时使用）
var batch_delay: float = 0.1:
	set(value):
		if batch_delay != value:
			batch_delay = value
			_update_resource_name()

## 运行时状态
var _remaining_count: int = 0
var _batch_timer: SceneTreeTimer = null

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_WARM_UP_POOL_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_WARM_UP_POOL_DESC"
	metadata.keywords = ["warmup", "pool", "preload", "cache", "预热", "池", "预加载"]
	metadata.builtin_icon = "TimeScreen"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

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
		hint_string = "*.tscn,*.scn",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Warm Up 分类
	properties.append({
		name = "Warm Up",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 预热数量
	properties.append({
		name = "warm_up_count",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "1,500,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 预热模式
	properties.append({
		name = "warm_up_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Immediate,Batch",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 批量模式参数（仅当 warm_up_mode == BATCH 时显示）
	if warm_up_mode == WarmUpMode.BATCH:
		properties.append({
			name = "batch_size",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1,100,1",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "batch_delay",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.01,1.0,0.01",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# Pool Config 分类
	properties.append({
		name = "Pool Config",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 池初始大小
	properties.append({
		name = "pool_initial_size",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "1,500,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 池最大大小
	properties.append({
		name = "pool_max_size",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "10,1000,10",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 属性验证（条件性显示属性）
func _validate_property(property: Dictionary) -> void:
	# 批量模式参数仅在 BATCH 模式下显示
	if warm_up_mode != WarmUpMode.BATCH:
		if property.name in ["batch_size", "batch_delay"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_WARM_UP_POOL_ACTION"))

	if not scene_path.is_empty():
		parts.append("'%s'" % FuseNodeUtils.get_path_display_name(scene_path))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_WARM_UP_POOL_NO_SCENE"))

	parts.append("×%d" % warm_up_count)

	if warm_up_mode == WarmUpMode.BATCH:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_WARM_UP_POOL_BATCH_MODE", {
			"batch_size": batch_size,
			"delay": batch_delay
		}))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_WARM_UP_POOL_DESC_FORMAT", {
		"scene": FuseNodeUtils.get_path_display_name(scene_path) if not scene_path.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_WARM_UP_POOL_NO_SCENE"),
		"count": warm_up_count
	})

	if warm_up_mode == WarmUpMode.BATCH:
		desc += " " + FuseLocalization.translate_format("FUSE_INSTRUCTION_WARM_UP_POOL_BATCH_DESC", {
			"batch_size": batch_size,
			"delay": batch_delay
		})

	return desc

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证场景路径
	if scene_path.is_empty():
		_log_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证预热数量
	if warm_up_count <= 0:
		_log_error_localized("FUSE_ERROR_WARM_UP_COUNT_INVALID", {
			"count": warm_up_count
		})
		set_error_localized("FUSE_ERROR_WARM_UP_COUNT_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {
			"count": warm_up_count
		})
		finished.emit()
		return

	# 根据模式执行
	match warm_up_mode:
		WarmUpMode.IMMEDIATE:
			_warm_up_immediate()
		WarmUpMode.BATCH:
			_warm_up_batch()

## 立即预热
func _warm_up_immediate():
	var pool_manager = FusePoolManager.get_instance()
	var pool_config = {
		"initial_size": pool_initial_size,
		"max_size": pool_max_size
	}

	pool_manager.warm_up_pool(scene_path, warm_up_count, pool_config)

	_log_info_localized("FUSE_LOG_WARM_UP_POOL_COMPLETED", {
		"scene": scene_path,
		"count": warm_up_count
	})

	_on_execution_completed()

## 分批预热
## 注意：分批预热是"触发即忘"操作，指令立即完成，预热在后台继续
func _warm_up_batch():
	_remaining_count = warm_up_count

	# 立即执行第一批
	_warm_up_next_batch()

	# 指令立即完成，预热在后台继续
	_log_info_localized("FUSE_LOG_WARM_UP_POOL_STARTED", {
		"scene": scene_path,
		"count": warm_up_count,
		"batch_size": batch_size
	})
	_on_execution_completed()

## 预热下一批（内部回调）
func _warm_up_next_batch():
	if _remaining_count <= 0:
		# 预热完成（后台任务完成，不发射 finished 信号，因为指令已经完成）
		_cleanup_batch_timer()
		_log_info_localized("FUSE_LOG_WARM_UP_POOL_BATCH_COMPLETED", {
			"scene": scene_path,
			"count": warm_up_count
		})
		return

	# 计算本批数量
	var current_batch = mini(batch_size, _remaining_count)

	# 预热本批
	var pool_manager = FusePoolManager.get_instance()
	var pool_config = {
		"initial_size": pool_initial_size,
		"max_size": pool_max_size
	}

	pool_manager.warm_up_pool(scene_path, current_batch, pool_config)

	_remaining_count -= current_batch

	_log_debug_localized("FUSE_LOG_WARM_UP_POOL_BATCH", {
		"batch": current_batch,
		"remaining": _remaining_count,
		"total": warm_up_count
	})

	# 如果还有剩余，设置定时器继续下一批
	if _remaining_count > 0:
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			_batch_timer = scene_tree.create_timer(batch_delay)
			_batch_timer.timeout.connect(_warm_up_next_batch)
		else:
			# 无法创建定时器，立即完成剩余部分
			_log_warning_localized("FUSE_WARNING_NO_SCENE_TREE_IMMEDIATE_WARM_UP", {})
			pool_manager.warm_up_pool(scene_path, _remaining_count, pool_config)
			_remaining_count = 0

## 清理分批定时器
func _cleanup_batch_timer():
	if _batch_timer and is_instance_valid(_batch_timer):
		if _batch_timer.timeout.is_connected(_warm_up_next_batch):
			_batch_timer.timeout.disconnect(_warm_up_next_batch)
		_batch_timer = null

## 清理资源
##
## 注意：分批预热模式下，定时器不能在指令完成时清理，
## 因为指令是"触发即忘"的，定时器需要在后台继续运行直到预热完成。
## 定时器在 _warm_up_next_batch() 完成所有批次后自行清理。
func _cleanup_resources():
	super._cleanup_resources()
	# 仅在分批预热未进行时清理定时器
	# 如果分批预热还在进行中，定时器需要继续工作
	if _remaining_count <= 0:
		_cleanup_batch_timer()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if scene_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCENE_PATH_EMPTY"))

	if warm_up_count <= 0:
		errors.append(FuseLocalization.translate_format("FUSE_ERROR_WARM_UP_COUNT_INVALID", {
			"count": warm_up_count
		}))

	if warm_up_mode == WarmUpMode.BATCH:
		if batch_size <= 0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_BATCH_SIZE_INVALID"))

		if batch_delay < 0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_BATCH_DELAY_INVALID"))

	return errors
