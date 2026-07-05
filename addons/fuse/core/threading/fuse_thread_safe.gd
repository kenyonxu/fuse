# addons/fuse/core/threading/fuse_thread_safe.gd
## Fuse 线程安全工具类
## 提供线程安全的操作封装，避免重复编写锁逻辑
##
## 注意：对于复杂的锁管理需求，请直接使用 Godot 的 Mutex 类。
## Godot Mutex 不支持 try_lock 操作，需要非阻塞锁的场景应考虑其他设计模式。
class_name FuseThreadSafe extends RefCounted

## 线程安全的字典获取
## 使用示例: var value = FuseThreadSafe.dict_get_safe(my_dict, "key", null, my_mutex)
static func dict_get_safe(dict: Dictionary, key: Variant, default: Variant = null, mutex: Mutex = null) -> Variant:
	if mutex != null:
		mutex.lock()
	var result = dict.get(key, default)
	if mutex != null:
		mutex.unlock()
	return result

## 线程安全的字典设置
static func dict_set_safe(dict: Dictionary, key: Variant, value: Variant, mutex: Mutex = null) -> void:
	if mutex != null:
		mutex.lock()
	dict[key] = value
	if mutex != null:
		mutex.unlock()

## 线程安全的字典擦除
static func dict_erase_safe(dict: Dictionary, key: Variant, mutex: Mutex = null) -> bool:
	if mutex != null:
		mutex.lock()
	var result = dict.erase(key)
	if mutex != null:
		mutex.unlock()
	return result

## 线程安全的字典检查
static func dict_has_safe(dict: Dictionary, key: Variant, mutex: Mutex = null) -> bool:
	if mutex != null:
		mutex.lock()
	var result = dict.has(key)
	if mutex != null:
		mutex.unlock()
	return result

## 线程安全的字典复制（用于快照）
static func dict_duplicate_safe(dict: Dictionary, deep: bool = false, mutex: Mutex = null) -> Dictionary:
	if mutex != null:
		mutex.lock()
	var result = dict.duplicate(deep)
	if mutex != null:
		mutex.unlock()
	return result

## 线程安全的数组追加
static func array_append_safe(arr: Array, value: Variant, mutex: Mutex = null) -> void:
	if mutex != null:
		mutex.lock()
	arr.append(value)
	if mutex != null:
		mutex.unlock()

## 线程安全的数组获取
static func array_get_safe(arr: Array, index: int, default_value: Variant = null, mutex: Mutex = null) -> Variant:
	if mutex != null:
		mutex.lock()
	var result = arr[index] if index >= 0 and index < arr.size() else default_value
	if mutex != null:
		mutex.unlock()
	return result

## 线程安全的数组大小获取
static func array_size_safe(arr: Array, mutex: Mutex = null) -> int:
	if mutex != null:
		mutex.lock()
	var result = arr.size()
	if mutex != null:
		mutex.unlock()
	return result
