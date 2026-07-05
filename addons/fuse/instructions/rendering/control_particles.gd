@tool
@icon("res://addons/fuse/icons/builtin/Particles.svg")
extends BaseInstruction
class_name ControlParticles

## Control Particles 指令 - 控制 GPUParticles2D/3D 的播放/停止/重启

## 粒子动作枚举
enum ParticleAction {
	RESTART,  ## 重新开始
	START,    ## 开始播放
	STOP      ## 停止播放
}

## 目标节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

## 动作类型
var action: ParticleAction = ParticleAction.RESTART:
	set(value):
		action = value
		_update_resource_name()

## 一次性发射
var one_shot: bool = false:
	set(value):
		one_shot = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_CONTROL_PARTICLES_NAME"
	metadata.category_key = "FUSE_CATEGORY_RENDERING"
	metadata.description_key = "FUSE_INSTRUCTION_CONTROL_PARTICLES_DESC"
	metadata.keywords = ["粒子", "particles", "GPU", "特效", "effect", "播放", "play", "停止", "stop", "重启", "restart"]
	metadata.builtin_icon = "Particles"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Control Particles",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "GPUParticles2D,GPUParticles3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "action",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Restart,Start,Stop",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "one_shot",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CONTROL_PARTICLES_NAME"))

	var action_str = ""
	match action:
		ParticleAction.RESTART:
			action_str = FuseLocalization.translate("FUSE_PARTICLES_ACTION_RESTART")
		ParticleAction.START:
			action_str = FuseLocalization.translate("FUSE_PARTICLES_ACTION_START")
		ParticleAction.STOP:
			action_str = FuseLocalization.translate("FUSE_PARTICLES_ACTION_STOP")

	parts.append("[%s]" % action_str)

	if not target_node.is_empty():
		parts.append("[%s]" % _get_node_display_name(target_node))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	var action_str = ""
	match action:
		ParticleAction.RESTART:
			action_str = FuseLocalization.translate("FUSE_PARTICLES_ACTION_RESTART")
		ParticleAction.START:
			action_str = FuseLocalization.translate("FUSE_PARTICLES_ACTION_START")
		ParticleAction.STOP:
			action_str = FuseLocalization.translate("FUSE_PARTICLES_ACTION_STOP")

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_CONTROL_PARTICLES_DESC_FORMAT", {
		"action": action_str,
		"target": target_desc
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var node = context.get_node(target_node)
	if node == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	if node is GPUParticles2D:
		var particles := node as GPUParticles2D
		particles.one_shot = one_shot
		_apply_action(particles)
	elif node is GPUParticles3D:
		var particles := node as GPUParticles3D
		particles.one_shot = one_shot
		_apply_action(particles)
	else:
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": node.name, "expected": "GPUParticles2D or GPUParticles3D"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "expected": "GPUParticles2D or GPUParticles3D"})
		finished.emit()
		return

	_log_info_localized("FUSE_LOG_PARTICLES_CONTROLLED", {"node": node.name, "action": ParticleAction.keys()[action]})

	_on_execution_completed()

## 应用粒子动作
func _apply_action(particles: Node) -> void:
	match action:
		ParticleAction.RESTART:
			particles.restart()
		ParticleAction.START:
			particles.emitting = true
		ParticleAction.STOP:
			particles.emitting = false

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors
