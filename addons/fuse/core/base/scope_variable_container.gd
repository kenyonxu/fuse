## addons/fuse/core/base/scope_variable_container.gd
@tool
@icon("res://addons/fuse/icons/builtin/LocalVariable.png")
class_name ScopeVariableContainer extends Node

## 作用域变量容器
## 附加到节点上，为该节点及其子树提供作用域变量存储

## 作用域配置
@export_group("Scope Configuration")
@export var scope_id: String = "":
	set(value):
		scope_id = value
		# 只有在树中才注册，避免过早注册
		if is_inside_tree():
			_register_scope()

@export var scope_description: String = ""

## 变量存储 - 导出为字典，使用 Godot 原生编辑器
@export var variables: Dictionary[String, Variant] = {}:
	set(new_values):
		# 记录旧值用于信号
		var old_values = _variables.duplicate()
		_variables = new_values

		# 为每个变化的变量发出信号
		for name in _variables.keys():
			var new_value = _variables[name]
			var old_value = old_values.get(name)
			if new_value != old_value:
				scope_variable_changed.emit(name, old_value, new_value)

		# 检测被删除的变量
		for name in old_values.keys():
			if not _variables.has(name):
				scope_variable_removed.emit(name)
	get:
		return _variables

# 内部存储（保持兼容性）
var _variables: Dictionary[String, Variant] = {}

## 继承模式
enum InheritanceMode {
	NONE,           # 不继承父作用域
	READ_ONLY,      # 只读继承父作用域
	READ_WRITE      # 读写继承父作用域
}
@export var inheritance_mode: InheritanceMode = InheritanceMode.READ_ONLY

var _parent_scope: ScopeVariableContainer = null
var _child_scopes: Array[ScopeVariableContainer] = []

## 信号
signal scope_variable_changed(name: String, old_value: Variant, new_value: Variant)
signal scope_variable_added(name: String)
signal scope_variable_removed(name: String)

func _enter_tree():
	call_deferred("_register_scope")
	call_deferred("_register_with_parent_scope")

func _exit_tree():
	_unregister_scope()
	_unregister_from_parent_scope()
	# 清理子作用域列表
	_child_scopes.clear()

func _register_scope():
	if not scope_id.is_empty():
		var manager = ScopeVariableManager.get_instance()
		if manager != null:
			manager.register_scope(self)

func _unregister_scope():
	if not scope_id.is_empty():
		var manager = ScopeVariableManager.get_instance()
		if manager != null:
			manager.unregister_scope(self)

func _register_with_parent_scope():
	## 将自己注册到父作用域的子作用域列表
	var parent_scope = get_parent_scope()
	if parent_scope != null and parent_scope != self:
		if not self in parent_scope._child_scopes:
			parent_scope._child_scopes.append(self)

func _unregister_from_parent_scope():
	## 从父作用域的子作用域列表中移除
	var parent_scope = get_parent_scope()
	if parent_scope != null:
		var index = parent_scope._child_scopes.find(self)
		if index >= 0:
			parent_scope._child_scopes.remove_at(index)

## 变量操作方法

func set_variable(name: String, value: Variant) -> bool:
	## 设置作用域变量
	if name.is_empty():
		push_error("变量名不能为空")
		return false

	var old_value: Variant = _variables.get(name)
	_variables[name] = value

	# Object 与非 Object 不能直接比较（混型写入视为已变更），避免
	# "Invalid operands 'Object' and 'String'" 运行时错误
	if (old_value is Object) != (value is Object) or old_value != value:
		scope_variable_changed.emit(name, old_value, value)

	# 通知编辑器属性已更改
	notify_property_list_changed()
	return true

func get_variable(name: String, default: Variant = null) -> Variant:
	## 获取作用域变量
	return _variables.get(name, default)

func has_variable(name: String) -> bool:
	## 检查变量是否存在
	return _variables.has(name)

func remove_variable(name: String) -> bool:
	## 移除作用域变量
	if _variables.has(name):
		var old_value = _variables[name]
		_variables.erase(name)
		scope_variable_removed.emit(name)

		# 通知编辑器属性已更改
		notify_property_list_changed()
		return true
	return false

func get_variable_names() -> PackedStringArray:
	## 获取所有变量名
	return PackedStringArray(_variables.keys())

func clear_variables():
	## 清空所有变量
	##
	## 会为每个被移除的变量发出 scope_variable_removed 信号。
	var names: PackedStringArray = _variables.keys()
	_variables.clear()
	for name in names:
		scope_variable_removed.emit(name)

	# 通知编辑器属性已更改
	notify_property_list_changed()

## 作用域链方法

func get_parent_scope() -> ScopeVariableContainer:
	## 获取父作用域容器
	if _parent_scope == null:
		_update_parent_scope()
	return _parent_scope

func _update_parent_scope():
	## 更新父作用域引用
	_parent_scope = null
	var parent = get_parent()

	while parent != null:
		if parent is ScopeVariableContainer:
			_parent_scope = parent
			break
		parent = parent.get_parent()

func get_child_scopes() -> Array[ScopeVariableContainer]:
	## 获取子作用域容器
	return _child_scopes.duplicate()

func get_scope_chain() -> Array[ScopeVariableContainer]:
	## 获取完整的作用域链（从根到当前）
	var chain: Array[ScopeVariableContainer] = []
	var current: ScopeVariableContainer = self

	while current != null:
		chain.push_front(current)
		current = current.get_parent_scope()

	return chain
