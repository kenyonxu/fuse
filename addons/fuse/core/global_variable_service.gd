@tool
class_name GlobalVariableService extends RefCounted

## 全局变量服务层（纯 RefCounted，不依赖场景树）
##
## 提供与 GlobalVariableAssistant 命名风格一致的变量 CRUD API，
## 全部委托 GlobalVariableManager（事实 Service 核心）。
## 无场景节点时可独立工作，替代脱树 Node 兜底。
##
## 使用示例：
## ```gdscript
## var service = GlobalVariableService.new()
## service.add_global_variable("score", my_var)
## var val = service.get_global_variable("score")
## ```

var _manager: GlobalVariableManager


func _init():
	_manager = GlobalVariableManager.get_instance()


# ============================================================
# 变量 CRUD（对齐 Assistant API 命名风格）
# ============================================================

## 添加全局变量
func add_global_variable(name: String, variable: BaseVariable) -> bool:
	return _manager.add_variable(name, variable)


## 获取特定的全局变量
func get_global_variable(name: String) -> BaseVariable:
	return _manager.get_variable(name)


## 检查全局变量是否存在
func has_global_variable(name: String) -> bool:
	return _manager.has_variable(name)


## 移除全局变量
func remove_global_variable(name: String) -> bool:
	return _manager.remove_variable(name)


## 获取所有全局变量名称列表
func get_all_global_variable_names() -> Array[String]:
	return _manager.get_all_variable_names()


## 获取所有全局变量的详细信息（用于调试）
func get_all_global_variables_info() -> Dictionary:
	var result: Dictionary = {}
	var var_names = _manager.get_all_variable_names()
	for var_name in var_names:
		var base_var = _manager.get_variable(var_name)
		if base_var == null:
			continue
		if base_var is BaseVariable:
			result[var_name] = {
				"value": base_var.value,
				"type": base_var.get_type_name(),
				"persistent": base_var.persistent
			}
		else:
			result[var_name] = {
				"value": base_var,
				"type": "Unknown",
				"persistent": false
			}
	return result


## 获取变量数量（委托 Manager）
func get_variable_count() -> int:
	return _manager.get_variable_count()


# ============================================================
# 持久化操作（委托 Manager）
# ============================================================

## 手动保存持久化变量到指定路径
func save_persistent_variables(path: String) -> bool:
	return _manager.save_persistent_to_resource(path)


## 加载资源文件到变量管理器
func load_resource(path: String) -> bool:
	return _manager.load_from_resource(path)


## 创建新资源文件
func create_new_resource(path: String, description: String) -> bool:
	var resource = Resource.new()
	resource.set_meta("description", description)
	resource.set_meta("version", "2.0")
	resource.set_meta("created_time", Time.get_ticks_msec() / 1000.0)
	var error = ResourceSaver.save(resource, path)
	return error == OK


## 获取当前资源路径（从 Manager）
func get_resource_path() -> String:
	return _manager._resource_path


## 获取调试/统计信息
func get_statistics() -> Dictionary:
	return _manager.get_statistics()
