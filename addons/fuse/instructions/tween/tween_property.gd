@tool
@icon("res://addons/fuse/icons/builtin/MemberProperty.png")
extends BaseTweenInstruction
class_name TweenPropertyInstruction


## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## Tween Property 指令 - 动画化节点的任意属性（高级功能）
##
## 这是 Tween 指令中最复杂的一个，因为它需要：
## - 动态属性列表（使用 PropertyManager）
## - 属性类型推断（使用 PropertyInfo）
## - Material 动画支持（Shared Material 和 Material Override）
## - auto_free 支持（使用 tween_callback）

## 异步指令标记
## 注意：BaseTweenInstruction 已自动处理异步，无需手动设置 _is_async

## 属性来源枚举
enum PropertySource {
	NODE_PROPERTY,       # 节点属性
	MATERIAL_PROPERTY    # Material 属性
}

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		# 清除缓存
		_cached_material_properties.clear()
		_cached_material_node = null
		# 仅在直接指定节点路径时更新编辑器节点实例
		if not use_variable_for_target:
			_update_target_node_info()
		_update_resource_name()
		notify_property_list_changed()

## 是否从变量获取目标节点
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		if use_variable_for_target:
			# 切换到变量模式：清空编辑器缓存，避免显示旧节点的属性
			_target_node_instance = null
			_cached_material_node = null
			_cached_material_properties.clear()
			_available_properties = []
			_current_property_info = null
		else:
			# 切换回直接模式：重新解析节点
			_update_target_node_info()
		_update_resource_name()
		notify_property_list_changed()

## 目标节点变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## 目标节点变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## 目标节点目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

var property_source: PropertySource = PropertySource.NODE_PROPERTY:
	set(value):
		property_source = value
		# 清除缓存
		_cached_material_properties.clear()
		_cached_material_node = null
		_update_available_properties()
		_update_property_type_info()
		_update_resource_name()
		notify_property_list_changed()

var property_path: String = "":
	set(value):
		property_path = value
		# 如果在编辑器模式下且节点实例为 null，先尝试获取节点
		if Engine.is_editor_hint() and not use_variable_for_target and _target_node_instance == null and not target_node.is_empty():
			_update_target_node_info()
		_update_property_type_info()
		_update_resource_name()
		notify_property_list_changed()

var to_value: Variant = 0.0:
	set(value):
		to_value = value
		_update_resource_name()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

var auto_free: bool = false:
	set(value):
		auto_free = value
		_update_resource_name()
		notify_property_list_changed()

var easing_type: BaseTweenInstruction.EasingType = BaseTweenInstruction.EasingType.EASE_IN_OUT:
	set(value):
		easing_type = value
		_update_resource_name()

var trans_type: BaseTweenInstruction.TransitionType = BaseTweenInstruction.TransitionType.SINE:
	set(value):
		trans_type = value
		_update_resource_name()

## 运行时状态（遗留模式）
var _target_node_instance: Node = null
var _current_property_info: PropertyInfo = null
var _available_properties: Array[PropertyInfo] = []
var _tween: Tween = null

## 缓存（避免重复计算材质属性列表）
var _cached_material_properties: Array[PropertyInfo] = []
var _cached_material_node: Node = null

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_TWEEN_PROPERTY_NAME"
	metadata.category_key = "FUSE_CATEGORY_TWEEN"
	metadata.description_key = "FUSE_INSTRUCTION_TWEEN_PROPERTY_DESC"
	metadata.keywords = ["tween", "property", "animate", "custom", "属性", "动画", "自定义", "material"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式
func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	return modes


## 获取属性列表（动态生成）
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# 在编辑器模式下，如果节点实例为 null 但 target_node 不为空，尝试重新获取节点
	if Engine.is_editor_hint() and not use_variable_for_target and _target_node_instance == null and not target_node.is_empty():
		_update_target_node_info()

	# 基础参数分类
	properties.append({
		name = "Tween Property",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标节点

	# 是否从变量获取目标节点
	properties.append({
		name = "use_variable_for_target",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_target:
		# 直接指定节点路径
		properties.append({
			name = "target_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 从变量获取节点
		properties.append({
			name = "target_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "target_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if target_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "target_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if target_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "target_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif target_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "target_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# 属性来源选择
	properties.append({
		name = "property_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Node Property,Material Property",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 动态生成属性枚举
	var enum_string = _get_property_enum_string()
	properties.append({
		name = "property_path",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_ENUM,
		hint_string = enum_string,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# to_value - 动态类型
	var value_type = TYPE_NIL
	var value_hint = PROPERTY_HINT_NONE
	var value_hint_string = ""

	if _current_property_info != null:
		value_type = _current_property_info.type
		value_hint = _current_property_info.hint
		value_hint_string = _current_property_info.hint_string

	properties.append({
		name = "to_value",
		type = value_type,
		hint = value_hint,
		hint_string = value_hint_string,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 持续时间
	properties.append({
		name = "duration",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,10,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# auto_free
	properties.append({
		name = "auto_free",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 缓动类型
	properties.append({
		name = "easing_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "In,Out,InOut,OutIn",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 过渡类型
	properties.append({
		name = "trans_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Linear,Sine,Quad,Cubic,Quart,Quint,Expo,Circ,Back,Spring,Bounce,Elastic",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 获取属性枚举字符串
func _get_property_enum_string() -> String:
	if _target_node_instance == null:
		return FuseLocalization.translate("FUSE_TWEEN_PROPERTY_SELECT_NODE_FIRST")

	var property_infos = _get_available_properties()
	var property_names = []

	for prop_info in property_infos:
		property_names.append(prop_info.name)

	if property_names.is_empty():
		return FuseLocalization.translate("FUSE_TWEEN_PROPERTY_NO_AVAILABLE_PROPERTIES")

	return ",".join(property_names)

## 更新目标节点信息
func _update_target_node_info():
	_target_node_instance = null
	_available_properties = []
	_current_property_info = null

	if target_node.is_empty() or use_variable_for_target:
		return

	# 尝试获取节点实例（编辑器模式下）
	if Engine.is_editor_hint():
		# 使用 FuseNodeUtils 工具类获取节点
		var editor_interface = Engine.get_singleton("EditorInterface")
		if editor_interface:
			var edited_root = editor_interface.get_edited_scene_root()

			if edited_root:
				# 使用新的 find_node_from_resource_context 方法
				# 这个方法会自动找到资源所在的节点，然后从那里解析相对路径
				_target_node_instance = FuseNodeUtils.find_node_from_resource_context(edited_root, self, target_node)

	if _target_node_instance:
		_available_properties = _get_available_properties()
		_update_property_type_info()
		_log_debug("成功获取目标节点: " + str(target_node) + " (类型: " + _target_node_instance.get_class() + ")")
		# 通知编辑器更新属性列表
		notify_property_list_changed()
	else:
		_log_debug("无法获取目标节点: " + str(target_node))
		# 即使获取失败也要通知更新属性列表（显示提示信息）
		notify_property_list_changed()

## 更新可用属性列表（根据属性来源）
func _update_available_properties():
	if _target_node_instance == null:
		_available_properties = []
		return

	_available_properties = _get_available_properties()
	notify_property_list_changed()

## 更新属性类型信息
func _update_property_type_info():
	_current_property_info = null

	if _target_node_instance == null or property_path.is_empty():
		return

	# 根据属性来源获取属性信息
	match property_source:
		PropertySource.NODE_PROPERTY:
			_current_property_info = PropertyManager.find_property(_target_node_instance, property_path)
		PropertySource.MATERIAL_PROPERTY:
			# 对于 Material，直接从已构建的属性列表中查找
			# 如果属性列表为空（场景加载时），先构建属性列表
			if _available_properties.is_empty():
				_update_available_properties()
			for prop_info in _available_properties:
				if prop_info.name == property_path:
					_current_property_info = prop_info
					break

	if _current_property_info != null:
		# 根据属性类型设置合适的默认值
		_set_default_value_for_type()
		_log_debug("属性信息已更新: " + property_path + " (类型: " + _current_property_info.get_type_name() + ")")
	else:
		_log_warning("无法找到属性信息: " + property_path)

## 根据属性类型设置默认值
## 仅当当前值与新属性类型不匹配时才重置，避免编辑器重新解析目标节点时
## 把已保存的 to_value 抹成类型默认值（如 float 属性的 1.0 被重置为 0.0）
func _set_default_value_for_type():
	if _current_property_info == null:
		return

	# 类型已匹配，保留当前值
	if typeof(to_value) == _current_property_info.type:
		return

	match _current_property_info.type:
		TYPE_INT:
			to_value = 0
		TYPE_FLOAT:
			to_value = 0.0
		TYPE_STRING:
			to_value = ""
		TYPE_BOOL:
			to_value = false
		TYPE_VECTOR2:
			to_value = Vector2.ZERO
		TYPE_VECTOR2I:
			to_value = Vector2i.ZERO
		TYPE_VECTOR3:
			to_value = Vector3.ZERO
		TYPE_VECTOR3I:
			to_value = Vector3i.ZERO
		TYPE_VECTOR4:
			to_value = Vector4.ZERO
		TYPE_COLOR:
			to_value = Color.WHITE
		TYPE_QUATERNION:
			to_value = Quaternion.IDENTITY
		TYPE_RECT2:
			to_value = Rect2()
		TYPE_RECT2I:
			to_value = Rect2i()
		TYPE_TRANSFORM2D:
			to_value = Transform2D()
		TYPE_TRANSFORM3D:
			to_value = Transform3D()
		TYPE_PLANE:
			to_value = Plane()
		TYPE_AABB:
			to_value = AABB()
		TYPE_BASIS:
			to_value = Basis()
		TYPE_PROJECTION:
			to_value = Projection()
		_:
			# 对于数组、字典等复杂类型，保持当前值或设置为空
			pass

## 获取可用属性列表
func _get_available_properties() -> Array[PropertyInfo]:
	if _target_node_instance == null:
		return []

	# 根据属性来源获取不同的属性列表
	match property_source:
		PropertySource.NODE_PROPERTY:
			return PropertyManager.get_writable_properties(_target_node_instance)
		PropertySource.MATERIAL_PROPERTY:
			return _get_material_properties()
		_:
			return []

## 获取节点的 Material
func _get_node_material() -> Material:
	if _target_node_instance == null:
		return null

	# 只使用属性访问，避免调用 get_material() 等可能触发线程问题的方法
	# 这在编辑器模式和运行时模式都安全
	var material = _target_node_instance.get("material")
	if material != null and material is Material:
		_log_debug("通过属性获取到 Material: " + material.get_class())
		return material

	_log_debug("节点没有 Material 属性或为空，节点类型: " + _target_node_instance.get_class())
	return null

## 获取 Material 的可动画属性
func _get_material_properties() -> Array[PropertyInfo]:
	# 检查缓存：如果目标节点未改变且缓存不为空，直接返回缓存
	if _cached_material_node == _target_node_instance and not _cached_material_properties.is_empty():
		return _cached_material_properties

	var material = _get_node_material()
	if material == null:
		return []

	# 在编辑器模式下，使用 try-catch 保护属性列表获取
	var properties: Array[PropertyInfo] = []

	# 使用 defer 来避免线程安全问题
	# 在编辑器中，某些属性访问可能会触发线程检查
	if Engine.is_editor_hint():
		# 编辑器模式：仅添加常用的 material 属性
		# 避免调用 get_property_list() 以防止线程问题
		_add_common_material_properties(material, properties)
	else:
		# 运行时模式：可以安全获取完整属性列表
		var prop_list = material.get_property_list()

		for prop_dict in prop_list:
			var prop_info = PropertyInfo.create(prop_dict)

			# 过滤出可以动画的属性
			if prop_info.name.begins_with("_"):
				continue
			if prop_info.name == "resource_path":
				continue
			if prop_info.name == "resource_local_to_scene":
				continue
			if prop_info.name == "resource_name":
				continue

			properties.append(prop_info)

	# 更新缓存
	_cached_material_properties = properties
	_cached_material_node = _target_node_instance

	return properties

## 添加常用的 Material 属性（编辑器模式安全版本）
func _add_common_material_properties(material: Material, properties: Array[PropertyInfo]):
	# 检查 material 类型并添加相应属性
	var material_class = material.get_class()

	# 直接获取属性列表，而不是使用 has_property()
	var prop_list = material.get_property_list()

	# 将属性字典转换为 PropertyInfo 对象
	for prop_dict in prop_list:
		var prop_name = prop_dict.get("name", "")
		var prop_info = PropertyInfo.new()
		prop_info.name = prop_name
		prop_info.type = prop_dict.get("type", TYPE_NIL)
		prop_info.hint = prop_dict.get("hint", PROPERTY_HINT_NONE)
		prop_info.hint_string = prop_dict.get("hint_string", "")

		# 对于 ShaderMaterial，只显示 shader_parameter/* 属性
		if material_class == "ShaderMaterial":
			# 跳过所有非 shader_parameter 属性（包括 shader 属性）
			if not prop_name.begins_with("shader_parameter/"):
				continue
			# 跳过 shader 参数的分类标题
			if prop_name == "shader_parameter/":
				continue
			# 保留完整的属性名（带前缀）用于内部使用
			# 这样可以保证保存和加载时的一致性
		else:
			# 对于其他 Material 类型，跳过一些不常用的属性
			if prop_name.begins_with("_"):
				continue
			if prop_name == "resource_name":
				continue
			if prop_name == "resource_local_to_scene":
				continue
			if prop_name == "resource_path":
				continue
			if prop_name == "resource_scene_unique_id":
				continue
			if prop_name in ["RefCounted", "Resource", "Material", "script"]:
				continue

		properties.append(prop_info)

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_PROPERTY_NAME"))
	var target_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_str = FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			target_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	parts.append("[%s]" % target_str)

	# 显示属性来源
	var source_text = ""
	match property_source:
		PropertySource.NODE_PROPERTY:
			source_text = "Node"
		PropertySource.MATERIAL_PROPERTY:
			source_text = "Material"
	parts.append("[%s]" % source_text)

	if not property_path.is_empty():
		parts.append("." + property_path)
	else:
		parts.append(".[%s]" % FuseLocalization.translate("FUSE_TWEEN_PROPERTY_NO_PROPERTY_SELECTED"))

	parts.append("= %s" % str(to_value))
	parts.append("(%.2fs)" % duration)

	if auto_free:
		parts.append("[auto_free]")

	resource_name = " ".join(parts)

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 控制目标节点相关属性可见性
	if not use_variable_for_target:
		if property.name in ["target_variable", "target_scope", "target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if target_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, target_utils_scope_source)
## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false
## 获取指令描述（必需）
func get_description() -> String:
	var target_desc := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_desc = FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			target_desc = "%s [%s]" % [target_variable, target_scope_str]
	else:
		target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	# target_desc ready
	var prop_desc = property_path if not property_path.is_empty() else FuseLocalization.translate("FUSE_TWEEN_PROPERTY_NO_PROPERTY_SELECTED")
	var auto_free_suffix = FuseLocalization.translate("FUSE_TWEEN_PROPERTY_AUTO_FREE_SUFFIX") if auto_free else ""

	# 添加属性来源信息
	var source_desc = ""
	match property_source:
		PropertySource.NODE_PROPERTY:
			source_desc = "Node"
		PropertySource.MATERIAL_PROPERTY:
			source_desc = "Material"

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_PROPERTY_DESC_FORMAT", {
		"target": target_desc,
		"property": prop_desc,
		"value": str(to_value),
		"auto_free": auto_free_suffix
	}) + " [%s]" % source_desc

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 验证目标节点

	# 获取目标节点
	var target = _resolve_node(
		context,
		use_variable_for_target,
		target_node,
		target_variable,
		target_scope,
		target_scope_source,
		target_custom_scope_id,
		target_target_node_path,
		"FUSE_ERROR_TARGET_VARIABLE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_NOT_FOUND"
	)
	if not target:
		finished.emit()
		return

	# 验证属性路径
	if property_path.is_empty():
		_log_error_localized("FUSE_ERROR_PROPERTY_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_PROPERTY_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 根据属性来源进行不同的验证和处理
	var tween_property_path = property_path
	var validation_target = target

	match property_source:
		PropertySource.NODE_PROPERTY:
			# 验证节点属性存在且可写
			if not PropertyManager.has_property(target, property_path):
				_log_error_localized("FUSE_ERROR_PROPERTY_NOT_FOUND", {"property": property_path})
				set_error_localized("FUSE_ERROR_PROPERTY_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"property": property_path})
				finished.emit()
				return

			if not PropertyManager.is_property_writable(target, property_path):
				_log_error_localized("FUSE_ERROR_PROPERTY_NOT_WRITABLE", {"property": property_path})
				set_error_localized("FUSE_ERROR_PROPERTY_NOT_WRITABLE", FuseError.ErrorType.VALIDATION_ERROR, {"property": property_path})
				finished.emit()
				return

		PropertySource.MATERIAL_PROPERTY:
			# 验证节点是否有 material
			var material = _get_runtime_node_material(target)
			if material == null:
				_log_error_localized("FUSE_ERROR_MATERIAL_NOT_FOUND", {})
				set_error_localized("FUSE_ERROR_MATERIAL_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return

			# 对于 ShaderMaterial，需要添加 shader_parameter/ 前缀
			var actual_property_path = property_path
			if material.get_class() == "ShaderMaterial":
				# 检查是否已经有前缀（如果没有则添加）
				if not property_path.begins_with("shader_parameter/"):
					actual_property_path = "shader_parameter/" + property_path

			# 使用 "material:property_name" 语法来 tween material 属性
			tween_property_path = "material:" + actual_property_path
			validation_target = material

			# 验证 material 属性存在（直接使用 Godot API，因为 Material 不是 Node）
			if not _has_material_property(material, actual_property_path):
				_log_error_localized("FUSE_ERROR_MATERIAL_PROPERTY_NOT_FOUND", {"property": property_path})
				set_error_localized("FUSE_ERROR_MATERIAL_PROPERTY_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"property": property_path})
				finished.emit()
				return

	# Variant 目标值：preset 的引擎值规范形字符串（"(x, y)"）在 Variant 属性上
	# 保持 String（PresetValueCodec 仅对类型化属性做字符串解析）——按目标属性的
	# 运行时类型补解析；否则 tween_property 对类型不匹配静默不生成 tweener，
	# 指令 await finished 永挂（deep_tween 实测链条死锁于此）
	if to_value is String and "(" in to_value and property_source != PropertySource.MATERIAL_PROPERTY:
		var current: Variant = target.get_indexed(tween_property_path) if ":" in tween_property_path else target.get(tween_property_path)
		var type_str := type_string(typeof(current))
		if type_str in ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Color", "Quaternion", "Rect2"]:
			var parsed: Variant = str_to_var("%s%s" % [type_str, to_value])
			if parsed != null:
				to_value = parsed

	# 验证属性值（使用完整的属性路径进行验证）
	var validation_property_path = tween_property_path
	if property_source == PropertySource.MATERIAL_PROPERTY:
		# 提取 material: 后面的部分
		validation_property_path = tween_property_path.substr(9)  # 去掉 "material:" 前缀

	var validation
	if property_source == PropertySource.MATERIAL_PROPERTY:
		# 对于 Material，使用专门的验证方法（Material 不是 Node）
		validation = _validate_material_property_value(validation_target, validation_property_path, to_value)
	else:
		# 对于 Node 属性，使用 PropertyManager
		validation = PropertyManager.validate_property_value(validation_target, validation_property_path, to_value)

	if not validation.valid:
		_log_error_localized("FUSE_ERROR_PROPERTY_VALUE_VALIDATION_FAILED", {"error": validation.error})
		set_error_localized("FUSE_ERROR_PROPERTY_VALUE_VALIDATION_FAILED", FuseError.ErrorType.VALIDATION_ERROR, {"error": validation.error})
		finished.emit()
		return

	# 创建 Tween
	_tween = _create_tween(target)
	if _tween == null:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 应用缓动设置（使用基类的辅助方法）
	_apply_easing_settings(_tween, easing_type, trans_type)

	# 播放动画
	var converted_value = validation.converted_value if validation.has("converted_value") else to_value
	_tween.tween_property(target, tween_property_path, converted_value, duration)

	# auto_free 支持
	if auto_free:
		_tween.tween_callback(target.queue_free)
		_log_info_localized("FUSE_LOG_TWEEN_PROPERTY_AUTO_FREE", {"node": target.name})

	var property_type = TypeConverter.get_type_name(typeof(converted_value))
	var source_text = "Material" if property_source == PropertySource.MATERIAL_PROPERTY else "Node"
	_log_info_localized("FUSE_LOG_TWEEN_PROPERTY", {
		"node": target.name,
		"property": tween_property_path,
		"value": str(converted_value),
		"type": property_type,
		"duration": str(duration)
	})
	_log_debug("Tweening " + source_text + " property: " + tween_property_path)

	# 等待动画完成
	await _tween.finished
	_on_execution_completed()

## 获取运行时节点的 Material
func _get_runtime_node_material(node: Node) -> Material:
	# 只使用属性访问，避免调用 get_material() 等可能触发线程问题的方法
	# 这在编辑器模式和运行时模式都安全
	var material = node.get("material")
	if material != null and material is Material:
		_log_debug("通过属性获取到 Material: " + material.get_class())
		return material

	# 如果属性访问失败，尝试通过属性列表查找（对于嵌套的 material）
	# 注意：这里仍然使用属性访问，不调用方法
	if node.has_method("get") and node.has_method("get_property_list"):
		var props = node.get_property_list()
		for prop in props:
			if prop.get("name") == "material" and prop.get("type") == TYPE_OBJECT:
				material = node.get("material")
				if material != null and material is Material:
					_log_debug("通过属性列表获取到 Material: " + material.get_class())
					return material

	_log_debug("无法获取 Material，节点类型: " + node.get_class())
	return null

## 检查 Material 是否有指定属性
func _has_material_property(material: Material, property_name: String) -> bool:
	var property_list = material.get_property_list()
	for prop in property_list:
		if prop.get("name", "") == property_name:
			return true
	return false

## 验证 Material 属性值
func _validate_material_property_value(material: Material, property_name: String, value: Variant) -> Dictionary:
	# 检查属性是否存在
	if not _has_material_property(material, property_name):
		return {"valid": false, "error": "Material 属性不存在: " + property_name}

	# 获取属性信息以进行类型验证
	var property_list = material.get_property_list()
	for prop in property_list:
		if prop.get("name", "") == property_name:
			var prop_type = prop.get("type", TYPE_NIL)

			# 简单的类型检查（Material 属性通常都是可写的）
			if typeof(value) != prop_type:
				# 尝试类型转换
				var converted = TypeConverter.safe_convert(value, prop_type)
				if typeof(converted) == prop_type:
					return {"valid": true, "converted_value": converted}
				else:
					return {"valid": false, "error": "无法将值转换为属性类型: " + TypeConverter.get_type_name(prop_type)}

			return {"valid": true, "converted_value": value}

	return {"valid": false, "error": "未找到属性信息: " + property_name}

## 验证参数（必需）
func validate() -> Array[String]:
	var errors = super.validate()
	# 验证 目标节点
	if use_variable_for_target:
		if target_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VARIABLE_EMPTY"))
		if target_scope == BaseVariable.VariableScope.SCOPE:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				target_utils_scope_source,
				target_custom_scope_id,
				target_target_node_path
			))
	else:
		if target_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))


	if property_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_PROPERTY_PATH_EMPTY"))

	if duration <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DURATION_MUST_BE_POSITIVE"))

	# 验证属性存在（如果有目标节点实例）
	if _target_node_instance != null and not property_path.is_empty():
		match property_source:
			PropertySource.NODE_PROPERTY:
				if not PropertyManager.has_property(_target_node_instance, property_path):
					errors.append(FuseLocalization.translate_format("FUSE_ERROR_PROPERTY_NOT_FOUND", {"property": property_path}))
				elif not PropertyManager.is_property_writable(_target_node_instance, property_path):
					errors.append(FuseLocalization.translate_format("FUSE_ERROR_PROPERTY_NOT_WRITABLE", {"property": property_path}))
			PropertySource.MATERIAL_PROPERTY:
				var material = _get_node_material()
				if material == null:
					errors.append(FuseLocalization.translate("FUSE_ERROR_MATERIAL_NOT_FOUND"))
				else:
					# 对于 Material，直接使用 Godot API（Material 不是 Node）
					if not _has_material_property(material, property_path):
						errors.append(FuseLocalization.translate_format("FUSE_ERROR_MATERIAL_PROPERTY_NOT_FOUND", {"property": property_path}))

	return errors

## 取消指令执行
func cancel():
	if is_running():
		if _tween != null and is_instance_valid(_tween):
			_tween.kill()
			_tween = null
		super.cancel()

## 资源清理
func _cleanup_resources():
	super._cleanup_resources()
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
		_tween = null
	_target_node_instance = null
	_current_property_info = null
	_available_properties = []

## 重置指令状态
func reset():
	super.reset()
	_tween = null
	_target_node_instance = null
	_current_property_info = null
	_available_properties = []

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
##
## 声明 TweenProperty 指令需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["tween"] = null  # Tween 引用
	state["target_instance"] = null  # 目标节点实例
	state["tween_callback"] = null  # 完成回调引用（用于断开连接）
	state["is_running"] = false  # 运行状态
	return state

## 使用运行时实例执行（推荐模式）
##
## 这种模式下，所有状态存储在 runtime_instance.runtime_state 中，
## 确保多个执行实例互不干扰。
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	var state = runtime_instance.runtime_state

	# 验证目标节点
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 获取目标节点
	var target = _resolve_node(
		runtime_instance.execution_context,
		use_variable_for_target,
		target_node,
		target_variable,
		target_scope,
		target_scope_source,
		target_custom_scope_id,
		target_target_node_path,
		"FUSE_ERROR_TARGET_VARIABLE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_NOT_FOUND"
	)
	if target == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		runtime_instance._complete_execution()
		return true

	# 保存目标节点引用
	state["target_instance"] = target

	# 验证属性路径
	if property_path.is_empty():
		_log_error_localized("FUSE_ERROR_PROPERTY_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_PROPERTY_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 根据属性来源进行不同的验证和处理
	var tween_property_path = property_path
	var validation_target = target

	match property_source:
		PropertySource.NODE_PROPERTY:
			# 验证节点属性存在且可写
			if not PropertyManager.has_property(target, property_path):
				_log_error_localized("FUSE_ERROR_PROPERTY_NOT_FOUND", {"property": property_path})
				set_error_localized("FUSE_ERROR_PROPERTY_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"property": property_path})
				runtime_instance._complete_execution()
				return true

			if not PropertyManager.is_property_writable(target, property_path):
				_log_error_localized("FUSE_ERROR_PROPERTY_NOT_WRITABLE", {"property": property_path})
				set_error_localized("FUSE_ERROR_PROPERTY_NOT_WRITABLE", FuseError.ErrorType.VALIDATION_ERROR, {"property": property_path})
				runtime_instance._complete_execution()
				return true

		PropertySource.MATERIAL_PROPERTY:
			# 验证节点是否有 material
			var material = _get_runtime_node_material(target)
			if material == null:
				_log_error_localized("FUSE_ERROR_MATERIAL_NOT_FOUND", {})
				set_error_localized("FUSE_ERROR_MATERIAL_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
				runtime_instance._complete_execution()
				return true

			# 对于 ShaderMaterial，需要添加 shader_parameter/ 前缀
			var actual_property_path = property_path
			if material.get_class() == "ShaderMaterial":
				if not property_path.begins_with("shader_parameter/"):
					actual_property_path = "shader_parameter/" + property_path

			# 使用 "material:property_name" 语法来 tween material 属性
			tween_property_path = "material:" + actual_property_path
			validation_target = material

			# 验证 material 属性存在
			if not _has_material_property(material, actual_property_path):
				_log_error_localized("FUSE_ERROR_MATERIAL_PROPERTY_NOT_FOUND", {"property": property_path})
				set_error_localized("FUSE_ERROR_MATERIAL_PROPERTY_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"property": property_path})
				runtime_instance._complete_execution()
				return true

	# Variant 目标值字符串补解析（同主 execute 路径——ActionRunner 实际走此路径）
	if to_value is String and "(" in to_value and property_source != PropertySource.MATERIAL_PROPERTY:
		var cur: Variant = target.get_indexed(tween_property_path) if ":" in tween_property_path else target.get(tween_property_path)
		var tstr := type_string(typeof(cur))
		if tstr in ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Color", "Quaternion", "Rect2"]:
			var parsed: Variant = str_to_var("%s%s" % [tstr, to_value])
			if parsed != null:
				to_value = parsed

	# 验证属性值
	var validation_property_path = tween_property_path
	if property_source == PropertySource.MATERIAL_PROPERTY:
		validation_property_path = tween_property_path.substr(9)

	var validation
	if property_source == PropertySource.MATERIAL_PROPERTY:
		validation = _validate_material_property_value(validation_target, validation_property_path, to_value)
	else:
		validation = PropertyManager.validate_property_value(validation_target, validation_property_path, to_value)

	if not validation.valid:
		_log_error_localized("FUSE_ERROR_PROPERTY_VALUE_VALIDATION_FAILED", {"error": validation.error})
		set_error_localized("FUSE_ERROR_PROPERTY_VALUE_VALIDATION_FAILED", FuseError.ErrorType.VALIDATION_ERROR, {"error": validation.error})
		runtime_instance._complete_execution()
		return true

	# 创建 Tween
	var tween = _create_tween(target)
	if tween == null:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		runtime_instance._complete_execution()
		return true

	state["tween"] = tween
	state["is_running"] = true

	# 应用缓动设置
	_apply_easing_settings(tween, easing_type, trans_type)

	# 播放动画
	var converted_value = validation.converted_value if validation.has("converted_value") else to_value
	tween.tween_property(target, tween_property_path, converted_value, duration)

	# auto_free 支持
	if auto_free:
		tween.tween_callback(target.queue_free)
		_log_info_localized("FUSE_LOG_TWEEN_PROPERTY_AUTO_FREE", {"node": target.name})

	var property_type = TypeConverter.get_type_name(typeof(converted_value))
	var source_text = "Material" if property_source == PropertySource.MATERIAL_PROPERTY else "Node"
	_log_info_localized("FUSE_LOG_TWEEN_PROPERTY", {
		"node": target.name,
		"property": tween_property_path,
		"value": str(converted_value),
		"type": property_type,
		"duration": str(duration)
	})
	_log_debug("Tweening " + source_text + " property: " + tween_property_path)

	# 使用回调注册机制（替代 await）
	var callback = _create_tween_finished_callback(runtime_instance)
	tween.finished.connect(callback, CONNECT_ONE_SHOT)
	runtime_instance.register_timer_callback(callback)
	state["tween_callback"] = callback

	return false  # 异步执行

## 创建 Tween 完成回调（避免 bind）
func _create_tween_finished_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_tween_finished(runtime_instance)
	return callback

## Tween 完成回调（运行时实例版本）
func _on_runtime_tween_finished(runtime_instance: RuntimeInstructionInstance) -> void:
	# 检查实例是否仍然有效
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state

	# 清理状态
	state["tween"] = null
	state["target_instance"] = null
	state["is_running"] = false
	state["tween_callback"] = null

	# 标记完成
	runtime_instance._complete_execution()

## 暂停处理
##
## 当运行时实例被暂停时，暂停 Tween 动画
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var tween = state.get("tween")

	if tween and is_instance_valid(tween):
		tween.pause()
		state["is_running"] = false
		_log_debug("Tween 动画已暂停")

## 恢复处理
##
## 当运行时实例被恢复时，恢复 Tween 动画
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var tween = state.get("tween")

	if tween and is_instance_valid(tween):
		tween.play()
		state["is_running"] = true
		_log_debug("Tween 动画已恢复")

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("TweenProperty", log_level, message, property_path)

func _log_info(message: String):
	FuseLogger.log_info("TweenProperty", log_level, message, property_path)

func _log_warning(message: String):
	FuseLogger.log_warning("TweenProperty", log_level, message, property_path)

func _log_error(message: String):
	FuseLogger.log_error("TweenProperty", log_level, message, property_path)

## 从变量或节点路径解析节点
func _resolve_node(
	context: ExecutionContext,
	use_variable: bool,
	node_path: NodePath,
	variable_name: String,
	variable_scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath,
	empty_variable_error_key: String,
	empty_node_error_key: String,
	not_found_error_key: String
) -> Node:
	if use_variable:
		if variable_name.is_empty():
			_log_error_localized(empty_variable_error_key, {})
			set_error_localized(empty_variable_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var node_value = VariableOperations.get_variable(
			context,
			variable_name,
			variable_scope,
			null
		)

		if node_value == null and not VariableOperations.has_variable(context, variable_name, variable_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name})
			return null

		# 支持多种类型：Node、String（节点路径）、NodePath
		if node_value is Node:
			return node_value
		elif node_value is String or node_value is NodePath:
			var resolved_path = NodePath(node_value)
			var resolved_node = context.get_node(resolved_path)
			if not resolved_node:
				_log_error_localized(not_found_error_key, {"node": str(node_value)})
				set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_value)})
				return null
			return resolved_node
		else:
			_log_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			set_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			return null
	else:
		if node_path.is_empty():
			_log_error_localized(empty_node_error_key, {})
			set_error_localized(empty_node_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var resolved_node = context.get_node(node_path)
		if not resolved_node:
			_log_error_localized(not_found_error_key, {"node": str(node_path)})
			set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_path)})
			return null
		return resolved_node

