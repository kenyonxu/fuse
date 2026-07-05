@tool
@icon("res://addons/bricks/icons/instruction.svg")
extends BaseInstruction

## 调用 AnimatedSprite2D.play 方法
## 自动生成 - 请勿手动修改

## 目标节点路径
@export var target_node: NodePath = NodePath("")

## 方法参数
@export var name: StringName = &""
@export var custom_speed: float = 0.0
@export var from_end: bool = false

static func _get_instruction_metadata() -> InstructionMetadata:
	var md = InstructionMetadata.new()
	md.name = "调用 AnimatedSprite2D.play"
	md.category = "用户生成"
	md.description = "调用 AnimatedSprite2D 节点的 play 方法"
	md.keywords = ["animatedsprite2d", "play", "call"]
	return md

func _setup_metadata():
	pass

func _update_resource_name():
	resource_name = "CallAnimatedSprite2DPlay"

func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点
	if target_node.is_empty():
		set_error("目标节点路径为空")
		finished.emit()
		return

	# 获取目标节点
	var node := context.get_node(target_node)
	if node == null:
		set_error("找不到目标节点: %s" % str(target_node))
		finished.emit()
		return

	# 类型检查
	if not node is AnimatedSprite2D:
		set_error("目标节点不是 AnimatedSprite2D 类型")
		finished.emit()
		return

	# 调用方法
	node.play(name, custom_speed, from_end)

	_on_execution_completed()

func get_description() -> String:
	return "调用 AnimatedSprite2D.play on " + str(target_node)

func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append("目标节点路径为空")
	return errors

