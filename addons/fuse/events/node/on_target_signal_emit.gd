# Event: OnTargetSignalEmit
##
## 目标信号触发事件 - 监听指定节点的特定信号并触发事件
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - target_node: Node - 目标节点引用
## - signal_info: SignalInfo - 信号信息对象
## - has_triggered: bool - 是否已触发标记
## - available_signals: Array - 可用信号列表
## - last_signal_context: Dictionary - 最后信号上下文
## - signals_loaded: bool - 信号是否已加载
## - is_refreshing: bool - 防止刷新循环的锁
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md
##
@tool
@icon("res://addons/fuse/icons/builtin/Signals.png")
class_name OnTargetSignalEmit extends BaseEvent

## 目标节点路径（相对于 Trigger 节点）
var target_node: NodePath:
	set(value):
		target_node = value
		_update_resource_name()

		# 在编辑器中，延迟刷新信号缓存（防止重复调度）
		if Engine.is_editor_hint() and not target_node.is_empty():
			_editor_is_refreshing = false  # 重置刷新锁
			call_deferred("_editor_refresh_signals")

## 目标信号名称
var target_signal: String = "":
	set(value):
		target_signal = value
		_update_resource_name()
		_update_signal_info()
		notify_property_list_changed()

## 是否只触发一次
var trigger_once: bool = false:
	set(value):
		trigger_once = value
		_update_resource_name()
		notify_property_list_changed()

## 信号参数过滤（可选）
var filter_signal_args: bool = false:
	set(value):
		filter_signal_args = value
		_update_resource_name()
		notify_property_list_changed()

## 参数过滤值（当 filter_signal_args 为 true 时使用；键为参数名，只配部分键即部分过滤）
var arg_filter_values: Dictionary = {}:
	set(value):
		arg_filter_values = value
		_update_resource_name()

# signal_info 缺失的 fail-open 警告只提示一次，避免高频信号刷屏
var _signal_info_warned: bool = false

# 编辑器专用临时变量（不序列化，仅用于编辑器会话）
var _editor_available_signals: Array = []  # 编辑器中缓存的可用信号列表
var _editor_signals_loaded: bool = false  # 编辑器中信号是否已加载
var _editor_is_refreshing: bool = false  # 编辑器中防止刷新循环的锁

# 缓存本地化字符串（静态变量，所有实例共享）
static var _cached_placeholder_select_node: String = ""
static var _cached_placeholder_no_signal: String = ""
static var _localization_cached: bool = false

## 初始化本地化缓存
##
## 这个方法会缓存本地化字符串，避免在 _get_property_list() 中频繁调用翻译函数
static func _init_localization_cache() -> void:
	if _localization_cached:
		return

	_cached_placeholder_select_node = FuseLocalization.translate("FUSE_EVENT_TARGET_SIGNAL_PLACEHOLDER_SELECT_NODE")
	_cached_placeholder_no_signal = FuseLocalization.translate("FUSE_EVENT_TARGET_SIGNAL_PLACEHOLDER_NO_SIGNAL")

	_localization_cached = true

## 更新资源名称
func _update_resource_name():
	var parts = []

	# 添加事件类型前缀
	var type_prefix = FuseLocalization.translate("FUSE_EVENT_TARGET_SIGNAL_RESOURCE_NAME").split("→")[0].strip_edges()
	parts.append(type_prefix)

	# 添加目标节点信息
	if not target_node.is_empty():
		var node_name = target_node.get_name(target_node.get_name_count() - 1)
		parts.append("→ %s" % node_name)
	else:
		parts.append(FuseLocalization.translate("FUSE_EVENT_TARGET_SIGNAL_NO_NODE"))

	# 添加信号信息
	if not target_signal.is_empty():
		var signal_display = target_signal
		# 从 RuntimeInstance 获取 signal_info
		if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("signal_info"):
			var signal_info = _runtime_instance_ref.get_runtime_state("signal_info")
			if signal_info:
				signal_display = signal_info.get_display_name()
		parts.append(":: %s" % signal_display)
	else:
		parts.append(FuseLocalization.translate("FUSE_EVENT_TARGET_SIGNAL_NO_SIGNAL"))

	# 添加触发次数标记
	if trigger_once:
		parts.append(FuseLocalization.translate("FUSE_EVENT_TARGET_SIGNAL_ONCE"))

	resource_name = " ".join(parts)

## 获取动态属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# 初始化本地化缓存（如果还没有初始化）
	_init_localization_cache()

	# 目标节点选择
	properties.append({
		"name": "target_node",
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Node",
		"usage": PROPERTY_USAGE_DEFAULT
	})

	# 信号选择
	if _has_valid_target_node():
		var signal_names = _get_signal_names()
		if not signal_names.is_empty():
			properties.append({
				"name": "target_signal",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": ",".join(signal_names),
				"usage": PROPERTY_USAGE_DEFAULT
			})
		else:
			properties.append({
				"name": "target_signal",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
				"hint_string": _cached_placeholder_no_signal,
				"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_READ_ONLY
			})
	else:
		properties.append({
			"name": "target_signal",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
			"hint_string": _cached_placeholder_select_node,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_READ_ONLY
		})
	
	# 基础选项
	properties.append({
		"name": "trigger_once",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "filter_signal_args",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "arg_filter_values",
		"type": TYPE_DICTIONARY
	})
	
	# 如果启用参数过滤，添加过滤值配置
	if filter_signal_args:
		# 从 RuntimeInstance 获取 signal_info
		var signal_info = null
		if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("signal_info"):
			signal_info = _runtime_instance_ref.get_runtime_state("signal_info")
		if signal_info:
			var arg_properties = _get_arg_filter_properties()
			properties.append_array(arg_properties)
	
	return properties

## 属性验证和显示控制
func _validate_property(property: Dictionary) -> void:
	# 当 filter_signal_args 为 false 时，隐藏 arg_filter_values 属性
	if not filter_signal_args and property.name == "arg_filter_values":
		property.usage = PROPERTY_USAGE_NONE  # 完全隐藏属性
	
	# 当 filter_signal_args 为 true 时，显示 arg_filter_values 属性
	# 这个逻辑是隐式的，因为默认情况下属性是显示的

## 初始化事件（已弃用，使用 initialize_with_runtime_instance 代替）
func initialize(owner_node):
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

	# 转换到新的 RuntimeInstance 架构
	initialize_with_runtime_instance(owner_node, RuntimeEventInstance.new(self, owner_node))

## 终止事件
func terminate(owner_node):
	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

	# 断开信号连接
	var target_node = null
	if _runtime_instance_ref and _runtime_instance_ref.runtime_state.has("target_node"):
		target_node = _runtime_instance_ref.runtime_state["target_node"]

	if target_node and is_instance_valid(target_node):
		if target_node.is_connected(target_signal, _on_target_signal_emitted):
			target_node.disconnect(target_signal, _on_target_signal_emitted)
			var source_name = target_node.name if target_node.name else "Unknown"
			_log_debug_localized("FUSE_LOG_EVENT_SIGNAL_SOURCE", {"source": source_name, "signal": target_signal, "status": "disconnected"})

	# 清理 RuntimeInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.runtime_state.clear()
		_runtime_instance_ref = null

	# 清理引用
	_trigger_ref = null

## 信号处理函数
func _on_target_signal_emitted(...args):
	_log_debug_localized("FUSE_LOG_EVENT_SIGNAL_EMITTED", {"signal": target_signal})

	# 检查是否只触发一次
	if trigger_once:
		var has_triggered = false
		if _runtime_instance_ref:
			var state = _runtime_instance_ref.runtime_state
			if state.has("has_triggered"):
				has_triggered = state["has_triggered"]
		if has_triggered:
			_log_debug_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type(), "status": "already_triggered"})
			return

	# 参数过滤检查
	if filter_signal_args and not _check_signal_args(args):
		_log_debug_localized("FUSE_LOG_EVENT_SIGNAL_EMITTED", {"signal": target_signal, "status": "filtered"})
		return

	# 更新触发状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)

	# 获取目标节点
	var target_node = null
	if _runtime_instance_ref and _runtime_instance_ref.runtime_state.has("target_node"):
		target_node = _runtime_instance_ref.runtime_state["target_node"]

	# 安全地记录日志（target_node 可能为 null）
	var source_name = "Unknown"
	if target_node and target_node.has_method("get"):
		source_name = target_node.name if target_node.name else "Unknown"
	_log_info_localized("FUSE_LOG_EVENT_SIGNAL_EMITTED", {"signal": target_signal, "source": source_name})

	# 将信号上下文信息存储在 RuntimeInstance 中
	_store_signal_context(args)

	# 传递目标节点作为上下文（符合 BaseEvent 的信号签名）
	if target_node:
		triggered.emit(target_node)

## 获取事件描述
func get_description():
	var node_name = target_node.get_name(target_node.get_name_count() - 1) if not target_node.is_empty() else FuseLocalization.translate("FUSE_EVENT_TARGET_SIGNAL_NO_NODE").trim_prefix("→ ")
	var signal_name = target_signal if not target_signal.is_empty() else FuseLocalization.translate("FUSE_EVENT_TARGET_SIGNAL_NO_SIGNAL").trim_prefix(":: ")
	var once_text = FuseLocalization.translate("FUSE_EVENT_TARGET_SIGNAL_DESC_ONLY_ONCE") if trigger_once else ""

	return FuseLocalization.translate_format(
		"FUSE_EVENT_TARGET_SIGNAL_DESC_TRIGGERED",
		{"node": node_name, "signal": signal_name, "once": once_text}
	)

## 获取事件类型
func get_event_type():
	return "target_signal_emit"

## 获取事件分类
func get_event_category():
	return "signal"

## 验证配置
func validate():
	var errors = []

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_SIGNAL_NODE_REQUIRED"))

	if target_signal.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_SIGNAL_SIGNAL_REQUIRED"))

	return errors

## 重置状态
func reset():
	super.reset()

	# 清理 RuntimeInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.runtime_state.clear()

		# 重新初始化默认状态
		var default_state = get_default_runtime_state()
		for key in default_state:
			_runtime_instance_ref.runtime_state[key] = default_state[key]

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

# 私有方法实现

## 检查是否有有效的目标节点
func _has_valid_target_node():
	if target_node.is_empty():
		return false

	# 在编辑器中，检查是否能获取到节点
	if Engine.is_editor_hint():
		# 如果已经尝试加载过，使用缓存的判断
		if _editor_signals_loaded:
			return true

		# 否则，直接尝试获取节点来判断
		return _get_target_node_in_editor() != null

	# 在运行时，获取实际节点验证
	return _get_target_node_from_runtime() != null

## 获取信号名称列表
func _get_signal_names():
	# 在编辑器中使用临时缓存
	if Engine.is_editor_hint():
		# 如果正在刷新，返回空列表（避免循环）
		if _editor_is_refreshing:
			return []

		var names = []
		for signal_info in _editor_available_signals:
			names.append(signal_info.name)
		return names

	# 在运行时使用 RuntimeInstance
	if _runtime_instance_ref and _runtime_instance_ref.runtime_state.has("is_refreshing") and _runtime_instance_ref.runtime_state["is_refreshing"]:
		return []

	var names = []
	var available_signals = []
	if _runtime_instance_ref and _runtime_instance_ref.runtime_state.has("available_signals"):
		available_signals = _runtime_instance_ref.runtime_state["available_signals"]

	for signal_info in available_signals:
		names.append(signal_info.name)

	return names

## 刷新信号缓存
func _refresh_signal_cache():
	# 防止循环：如果已经在刷新中，跳过
	if Engine.is_editor_hint():
		if _editor_is_refreshing:
			return

		# 在编辑器中，只要有 target_node 就尝试刷新
		if target_node.is_empty():
			_editor_available_signals.clear()
			_editor_signals_loaded = false
			return
		# 使用 call_deferred 延迟执行
		_editor_is_refreshing = true
		call_deferred("_editor_refresh_signals")
		return

	# 在运行时，使用 RuntimeInstance
	if _runtime_instance_ref and _runtime_instance_ref.runtime_state.has("is_refreshing") and _runtime_instance_ref.runtime_state["is_refreshing"]:
		return

	# 检查有效性后再刷新
	if _runtime_instance_ref:
		_runtime_instance_ref.runtime_state["available_signals"].clear()
		_runtime_instance_ref.runtime_state["signals_loaded"] = false

	if not _has_valid_target_node():
		return

	# 直接获取目标节点
	var target = _get_target_node_from_runtime()
	if not target:
		return

	# 获取信号信息
	var signals = SignalManager.get_node_signals(target)
	if _runtime_instance_ref:
		_runtime_instance_ref.runtime_state["available_signals"] = signals
		_runtime_instance_ref.runtime_state["signals_loaded"] = true
	_update_signal_info()

## 在编辑器中刷新信号缓存（主线程安全）
func _editor_refresh_signals():
	if target_node.is_empty():
		_editor_is_refreshing = false
		return

	_editor_available_signals.clear()
	_editor_signals_loaded = false  # 重置标志

	var target = _get_target_node_in_editor()
	if not target:
		_editor_is_refreshing = false
		return

	# 获取信号信息
	var signals = SignalManager.get_node_signals(target)
	_editor_available_signals = signals
	_editor_signals_loaded = true  # 标记已尝试加载

	_update_signal_info()

	# 通知属性列表已更改，触发刷新
	notify_property_list_changed()

	_editor_is_refreshing = false  # 释放锁，允许下次刷新

## 更新信号信息
func _update_signal_info():
	# 在编辑器中使用临时缓存
	if Engine.is_editor_hint():
		if not target_signal.is_empty() and not _editor_available_signals.is_empty():
			for signal_info in _editor_available_signals:
				if signal_info.name == target_signal:
					# 在编辑器中不需要存储 signal_info，只需用于显示
					return
		return

	# 在运行时使用 RuntimeInstance
	var available_signals = []
	if _runtime_instance_ref and _runtime_instance_ref.runtime_state.has("available_signals"):
		available_signals = _runtime_instance_ref.runtime_state["available_signals"]

	if not target_signal.is_empty() and not available_signals.is_empty():
		for signal_info in available_signals:
			if signal_info.name == target_signal:
				if _runtime_instance_ref:
					_runtime_instance_ref.set_runtime_state("signal_info", signal_info)
				return

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("signal_info", null)




## 在编辑器中获取目标节点
func _get_target_node_in_editor():
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type(), "action": "get_target_node"})
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type(), "target_node": str(target_node)})

	if target_node.is_empty():
		_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type(), "status": "path_empty"})
		return null

	# 在编辑器中，尝试从当前编辑场景获取节点
	var edited_scene_root = null
	if Engine.is_editor_hint():
		_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type(), "mode": "editor"})
		edited_scene_root = EditorInterface.get_edited_scene_root()
		print(edited_scene_root)
		if not edited_scene_root:
			_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type(), "status": "no_scene_root"})
			return null

		# 使用 FuseNodeUtils 工具类递归查找节点
		var target = FuseNodeUtils.find_node_from_resource_context(edited_scene_root, self, target_node)
		print(target)
		if target:
			_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type(), "status": "found", "node_name": target.name})
			return target

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type(), "status": "not_found"})
	return null

## 创建测试场景
func _create_test_scene() -> Node:
	var scene = Node.new()
	scene.name = "TestRoot"
	
	# 创建测试节点
	var test_button = Button.new()
	test_button.name = "TestButton"
	scene.add_child(test_button)
	
	var test_label = Label.new()
	test_label.name = "TestLabel"
	scene.add_child(test_label)
	
	var test_timer = Timer.new()
	test_timer.name = "TestTimer"
	scene.add_child(test_timer)
	
	return scene

## 检查信号参数（Dictionary 按名过滤：键存在即参与，全部通过才匹配）
func _check_signal_args(args):
	var signal_info = null
	if _runtime_instance_ref:
		signal_info = _runtime_instance_ref.runtime_state.get("signal_info", null)

	# signal_info 不可用（运行时状态异常）时放行，避免静默丢弃全部触发
	if not signal_info:
		if not _signal_info_warned:
			push_warning("OnTargetSignalEmit: filter_signal_args 已启用但 signal_info 不可用，跳过参数过滤")
			_signal_info_warned = true
		return true

	# 门控开启但未配置任何键：明确不匹配（暴露配置缺失而非静默全过）
	if arg_filter_values.is_empty():
		return false

	var named: Dictionary = signal_info.create_arg_context(args)
	for key in arg_filter_values:
		if not named.has(str(key)):
			return false
		if not SignalInfo.matches_arg(arg_filter_values[key], named[str(key)]):
			return false
	return true

## 创建信号上下文
func _create_signal_context(args):
	var target_node = null
	var signal_info = null

	if _runtime_instance_ref:
		var state = _runtime_instance_ref.runtime_state
		if state.has("target_node"):
			target_node = state["target_node"]
		if state.has("signal_info"):
			signal_info = state["signal_info"]

	var context = {
		"source_node": target_node,
		"signal_name": target_signal,
		"signal_args": args
	}

	# 如果有信号信息，添加参数名称
	if signal_info:
		context["named_args"] = signal_info.create_arg_context(args)

	return context

## 获取参数过滤属性
func _get_arg_filter_properties():
	var signal_info = null

	# 在编辑器中，从临时缓存获取
	if Engine.is_editor_hint():
		if not target_signal.is_empty():
			for sig in _editor_available_signals:
				if sig.name == target_signal:
					signal_info = sig
					break
	else:
		# 在运行时，从 RuntimeInstance 获取
		if _runtime_instance_ref and _runtime_instance_ref.runtime_state.has("signal_info"):
			signal_info = _runtime_instance_ref.runtime_state["signal_info"]

	if not signal_info:
		return []

	return signal_info.get_arg_property_list()

## 存储信号上下文
func _store_signal_context(args):
	var context = _create_signal_context(args)
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_signal_context", context)
		# 桥接：named_args 同步写入 last_event_args，
		# 宿主 Trigger 会把它逐键同步为 event_<参数名> 局部变量
		if context.has("named_args"):
			_runtime_instance_ref.set_runtime_state("last_event_args", context["named_args"])

## 获取最后一次信号的上下文信息
func get_last_signal_context() -> Dictionary:
	if _runtime_instance_ref and _runtime_instance_ref.runtime_state.has("last_signal_context"):
		return _runtime_instance_ref.runtime_state["last_signal_context"].duplicate(true)
	return {}

## 清理信号缓存
func _clear_signal_cache():
	# 在编辑器中清理临时缓存
	if Engine.is_editor_hint():
		_editor_available_signals.clear()
		_editor_signals_loaded = false
		_editor_is_refreshing = false
		return

	# 在运行时清理 RuntimeInstance
	if _runtime_instance_ref and (_runtime_instance_ref.runtime_state.has("signals_loaded") or (_runtime_instance_ref.runtime_state.has("available_signals") and _runtime_instance_ref.runtime_state["available_signals"].size() > 0)):
		_runtime_instance_ref.runtime_state["available_signals"].clear()
		_runtime_instance_ref.runtime_state["signal_info"] = null
		_runtime_instance_ref.runtime_state["signals_loaded"] = false  # 重置加载标志
		_runtime_instance_ref.runtime_state["is_refreshing"] = false  # 重置刷新锁

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["target_node"] = null
	base["signal_info"] = null
	base["has_triggered"] = false
	base["available_signals"] = []
	base["last_signal_context"] = {}
	base["signals_loaded"] = false
	base["is_refreshing"] = false
	return base

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance
	_trigger_ref = owner_node

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	var target = _get_target_node_from_runtime()
	if not target:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 验证信号
	if target_signal.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_SIGNAL_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"signal_name": target_signal})
		return

	# 检查信号是否存在
	if not SignalManager.has_signal_named(target, target_signal):
		_create_fuse_error_localized("FUSE_ERROR_SIGNAL_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"signal_name": target_signal, "node_name": target.name})
		return

	# 将目标节点存储到 RuntimeInstance 中（供后续访问使用）
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("target_node", target)

	# 连接信号
	if not target.is_connected(target_signal, _on_target_signal_emitted):
		var connect_result = target.connect(target_signal, _on_target_signal_emitted)
		if connect_result != OK:
			_create_fuse_error_localized("FUSE_ERROR_EVENT_INITIALIZATION", FuseError.ErrorType.RUNTIME_ERROR, {"signal_name": target_signal, "error_code": connect_result})
			return

	# 运行时解析 SignalInfo（参数过滤与 named_args 桥接都依赖它；历史上运行时从不构建，属修复）
	if _runtime_instance_ref:
		for sig_info in SignalManager.get_node_signals(target):
			if sig_info.name == target_signal:
				_runtime_instance_ref.set_runtime_state("signal_info", sig_info)
				break

	var source_name = target.name if target.name else "Unknown"
	_log_info_localized("FUSE_LOG_EVENT_SIGNAL_SOURCE", {"source": source_name, "signal": target_signal})

## 获取运行时目标节点
func _get_target_node_from_runtime() -> Node:
	# 在编辑器中，使用编辑器的场景根节点
	if Engine.is_editor_hint():
		return _get_target_node_in_editor()

	# 在运行时，使用 FuseNodeUtils 的多种策略查找节点
	if not _trigger_ref or not is_instance_valid(_trigger_ref):
		_log_warning_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type(), "status": "no_trigger_ref"})
		return null

	return FuseNodeUtils.find_node_at_runtime(_trigger_ref, target_node)

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_TARGET_SIGNAL_EMIT_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_NODE"
	metadata.description_key = "FUSE_EVENT_ON_TARGET_SIGNAL_EMIT_DESC"
	metadata.keywords = ["signal", "信号", "emit", "发出", "connect", "连接", "event", "事件", "listener", "监听"]
	metadata.builtin_icon = "Signals"
	return metadata