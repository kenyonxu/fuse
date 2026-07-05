## addons/fuse/core/scope_variable_manager.gd
@tool
class_name ScopeVariableManager extends Node

## 作用域变量管理器（单例）
## 管理场景中所有作用域变量的注册、查找和清理

static var _instance: ScopeVariableManager = null

## 作用域注册表
var _scope_registry: Dictionary = {}

## 信号连接存储（用于后续断开连接）
var _signal_connections: Dictionary = {}  # scope_id -> Callable

## 常量
const MAX_SCOPE_SEARCH_DEPTH: int = 100  # 最大作用域搜索深度

## 信号
signal scope_registered(scope_id: String, container: ScopeVariableContainer)
signal scope_unregistered(scope_id: String)
signal variable_changed(scope_id: String, name: String, value: Variant)

func _init():
	if _instance != null:
		push_error("ScopeVariableManager 已是单例，请使用 ScopeVariableManager.get_instance()")
		queue_free()  # 销毁重复的实例
		return
	_instance = self

static func get_instance() -> ScopeVariableManager:
	## 获取单例实例
	if _instance == null:
		_instance = ScopeVariableManager.new()
		Engine.get_main_loop().root.call_deferred("add_child", _instance)
		_instance.name = "ScopeVariableManager"
	return _instance

## 注册管理方法

func register_scope(container: ScopeVariableContainer) -> bool:
	## 注册作用域容器
	if container == null:
		push_error("无法注册 null 容器")
		return false

	if container.scope_id.is_empty():
		push_error("scope_id 为空，无法注册")
		return false

	if _scope_registry.has(container.scope_id):
		var existing = _scope_registry[container.scope_id]
		if existing != container:
			push_error("scope_id '%s' 已被占用，拒绝注册" % container.scope_id)
			return false
		# 同一容器重新注册，清理旧的信号连接
		_unregister_scope_connections(container)

	_scope_registry[container.scope_id] = container

	# 创建 lambda 函数转发信号
	var on_variable_changed = func(name: String, old_value: Variant, new_value: Variant):
		variable_changed.emit(container.scope_id, name, new_value)

	# 存储连接以便后续断开
	_signal_connections[container.scope_id] = on_variable_changed

	# 连接信号
	container.scope_variable_changed.connect(on_variable_changed)

	scope_registered.emit(container.scope_id, container)
	return true

## 断开作用域的信号连接（内部辅助方法）
func _unregister_scope_connections(container: ScopeVariableContainer) -> void:
	if container == null or container.scope_id.is_empty():
		return

	if _signal_connections.has(container.scope_id):
		var connection = _signal_connections[container.scope_id]
		if container.scope_variable_changed.is_connected(connection):
			container.scope_variable_changed.disconnect(connection)
		_signal_connections.erase(container.scope_id)

func unregister_scope(container: ScopeVariableContainer) -> bool:
	## 注销作用域容器
	if container == null:
		return false

	if container.scope_id.is_empty():
		return false

	if _scope_registry.has(container.scope_id):
		var registered = _scope_registry[container.scope_id]
		if registered == container:
			# 断开信号连接
			_unregister_scope_connections(container)

			_scope_registry.erase(container.scope_id)
			scope_unregistered.emit(container.scope_id)
			return true

	return false

func get_scope_by_id(scope_id: String) -> ScopeVariableContainer:
	## 通过 scope_id 获取作用域容器
	if _scope_registry.has(scope_id):
		return _scope_registry[scope_id]
	return null

func get_all_scopes() -> Dictionary:
	## 获取所有已注册的作用域
	return _scope_registry.duplicate()

## 作用域查找方法

func find_nearest_scope(node: Node) -> ScopeVariableContainer:
	## 从节点向上查找最近的作用域容器
	if node == null:
		return null

	var current: Node = node
	var max_iterations = MAX_SCOPE_SEARCH_DEPTH
	var iteration = 0

	while current != null and iteration < max_iterations:
		iteration += 1
		if current is ScopeVariableContainer:
			return current
		current = current.get_parent()

	return null

func find_scope_by_node_path(node_path: NodePath, context: Node) -> ScopeVariableContainer:
	## 通过节点路径查找作用域容器
	if context == null:
		return null

	var node = context.get_node(node_path)
	if node == null:
		return null

	if node is ScopeVariableContainer:
		return node

	return find_nearest_scope(node)

func get_scope_node_chain(node: Node) -> Array[ScopeVariableContainer]:
	## 获取从节点到根的所有作用域容器（按从近到远排序）
	var scopes: Array[ScopeVariableContainer] = []
	var current: Node = node

	while current != null:
		if current is ScopeVariableContainer:
			scopes.append(current)
		current = current.get_parent()

	return scopes
