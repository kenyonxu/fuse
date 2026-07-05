@tool
class_name AudioComponent
extends Resource

## 音频组件资源
##
## 管理多个 AudioBinding 实例的可复用配置容器
## 支持信号自动连接和工厂方法创建预设组件

# =============================================================================
# 绑定配置
# =============================================================================

## 目标节点路径（可序列化）
@export var target_path: NodePath = ""

## 音频绑定列表
@export var audio_bindings: Array[AudioBinding] = []

# =============================================================================
# 初始化和设置
# =============================================================================

## 设置组件 - 将所有绑定连接到目标节点的信号
##
## 此方法会检查是否已连接，避免重复连接同一 target/player 组合
##
## @param target: 目标节点，其信号将被监听
## @param player: 音频播放器节点，必须实现 _on_binding_triggered 方法
func setup(target: Node, player: Node) -> void:
	# 将此组件的所有绑定连接到目标节点的信号
	# 每个绑定应连接到 player._on_binding_triggered
	if not target or not player:
		push_error("AudioComponent.setup: target and player must not be null")
		return

	for binding in audio_bindings:
		if not binding or binding.signal_name.is_empty():
			continue

		if target.has_signal(binding.signal_name):
			# 检查是否已连接，避免重复连接
			var callable = player._on_binding_triggered.bind(binding)
			if not target.is_connected(binding.signal_name, callable):
				target.connect(
					binding.signal_name,
					callable
				)
		else:
			push_warning("AudioComponent: target '%s' has no signal '%s'" % [target.name, binding.signal_name])

# =============================================================================
# 查询方法
# =============================================================================

## 获取绑定数量
func get_binding_count() -> int:
	return audio_bindings.size()

## 根据信号名称查找绑定
##
## @param signal_name: 要查找的信号名称
## @return: 找到的 AudioBinding，未找到返回 null
func find_binding_by_signal(signal_name: String) -> AudioBinding:
	for binding in audio_bindings:
		if binding and binding.signal_name == signal_name:
			return binding
	return null

## 获取目标节点
##
## 从 target_path 解析并获取目标节点实例
## 支持编辑器和运行时环境，处理相对/绝对路径
##
## @param base_node: 基础节点（通常是场景根节点）
## @return: 目标节点实例，失败返回 null
func get_target_node(base_node: Node) -> Node:
	if target_path.is_empty():
		return null

	var target_node: Node = base_node.get_node_or_null(target_path)
	if target_node:
		return target_node

	# 如果直接获取失败，尝试处理相对路径
	var path_str = str(target_path)
	if path_str.begins_with("../"):
		var root_path = str(base_node.get_path())
		var absolute_path = _get_absolute_path(path_str, root_path)
		target_node = base_node.get_node_or_null(absolute_path)
		if target_node:
			return target_node

	return null

## 从节点设置 target_path
##
## 将节点引用转换为可序列化的 NodePath
##
## @param node: 要设置为目标节点的节点
func set_target_from_node(node: Node) -> void:
	if not node:
		target_path = NodePath()
		return

	var base_node: Node
	if Engine.is_editor_hint():
		base_node = EditorInterface.get_edited_scene_root()
	else:
		base_node = Engine.get_main_loop().current_scene

	if base_node and base_node.is_ancestor_of(node):
		target_path = base_node.get_path_to(node)
	else:
		push_warning("AudioComponent: 节点不是基础节点的后代")

## 相对路径转绝对路径（内部方法）
func _get_absolute_path(relative_path: String, root_path: String) -> String:
	if relative_path.begins_with("../"):
		relative_path = relative_path.substr(3)
		return root_path + "/" + relative_path
	else:
		return root_path + "/" + relative_path

# =============================================================================
# 工厂方法 - 创建预设组件
# =============================================================================

## 创建脚步声组件（预设）
##
## 返回配置了脚步声的 AudioComponent
## 信号名: "footstep"
## 冷却时间: 0.3秒
static func create_footstep_component() -> AudioComponent:
	var component = AudioComponent.new()
	var binding = AudioBinding.new()
	binding.signal_name = "footstep"
	binding.adv_cooldown = 0.3
	component.audio_bindings.append(binding)
	return component

## 创建UI按钮组件（预设）
##
## @param click_event: 按钮点击时播放的音频事件
## 返回配置了按钮点击的 AudioComponent
## 信号名: "pressed"
static func create_ui_button_component(click_event: AudioEventResource) -> AudioComponent:
	var component = AudioComponent.new()
	var binding = AudioBinding.new()
	binding.signal_name = "pressed"
	binding.audio_event = click_event
	component.audio_bindings.append(binding)
	return component

# =============================================================================
# 序列化支持
# =============================================================================

## 获取配置字典（用于保存）
func get_config_dict() -> Dictionary:
	var bindings_dict = []
	for binding in audio_bindings:
		if binding:
			bindings_dict.append(binding.get_config_dict())

	return {
		"target_path": str(target_path),
		"audio_bindings": bindings_dict
	}

## 从配置字典加载
func load_from_dict(config_dict: Dictionary) -> bool:
	if not config_dict.has("audio_bindings"):
		return false

	# Load target_path
	if config_dict.has("target_path"):
		target_path = NodePath(config_dict.target_path)

	audio_bindings.clear()
	var bindings_dict = config_dict.audio_bindings

	for binding_dict in bindings_dict:
		var binding = AudioBinding.new()
		if binding.load_from_dict(binding_dict):
			audio_bindings.append(binding)

	return true

# =============================================================================
# 验证
# =============================================================================

## 验证组件配置是否有效
func validate() -> Dictionary:
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}

	if audio_bindings.is_empty():
		result.warnings.append("No audio bindings defined")

	# Validate target_path
	if not target_path.is_empty():
		result.warnings.append("target_path is set but will be validated at runtime")

	for i in range(audio_bindings.size()):
		var binding = audio_bindings[i]
		if not binding:
			result.issues.append("Binding at index %d is null" % i)
			result.valid = false
		else:
			var binding_validation = binding.validate()
			if not binding_validation.valid:
				var issues_str = ", ".join(binding_validation.issues)
				result.issues.append("Binding at index %d: %s" % [i, issues_str])
				result.valid = false
			result.warnings.append_array(binding_validation.warnings)

	return result
