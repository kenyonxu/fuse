# Bricks 编辑器开发问题与解决方案

> **Bricks 组件修复标准** - 需要修复的组件必须同时满足以下三个条件：
> 1. ✅ 需要编辑器下解析路径
> 2. ✅ 需要编辑器下生成动态列表
> 3. ✅ 需要重新启动之后保存生成的列表（持久化）

## 目录

1. [线程安全](#1-线程安全)
2. [节点路径解析 - Resource 上下文](#2-节点路径解析---resource-上下文)
3. [属性持久化 - 场景加载顺序](#3-属性持久化---场景加载顺序)
4. [属性持久化 - 保存与恢复](#4-属性持久化---保存与恢复)
5. [性能优化 - 属性列表缓存](#5-性能优化---属性列表缓存)
6. [其他编辑器注意事项](#6-其他编辑器注意事项)

---

## 1. 线程安全

`[前提条件]`

### 问题描述

某些 Godot 方法在编辑器模式下有线程检查，会导致错误。

### 避免使用的方法

- `get_material()`
- `get_surface_override_material()`
- `get_active_materials()`

### 解决方案

使用 `get("property_name")` 进行属性访问：

```gdscript
# ❌ 错误 - 在编辑器中会导致线程错误
func get_material():
	return node.get_material()

# ✅ 正确 - 使用属性访问
func get_material():
	var material = node.get("material")
	if material != null and material is Material:
		return material
	return null
```

### 其他线程安全实践

- 避免在 `_get_property_list()` 中访问节点
- 使用 `call_deferred()` 延迟节点操作
- 使用 `Engine.is_editor_hint()` 检测编辑器环境

---

## 2. 节点路径解析 - Resource 上下文

`[标准1: 编辑器下解析路径]`

### 问题描述

Resource 存储在 Trigger 子节点时，相对路径解析需要特殊处理。当节点选择器返回 `..` 时，在 Bricks 资源上下文中表示"资源所在节点本身"而非父节点。

### 解决方案

使用 `BricksNodeUtils.find_node_from_resource_context()` 进行节点查找：

```gdscript
# 该方法会先找到包含资源的 Trigger 节点，然后从那里解析相对路径
var node = BricksNodeUtils.find_node_from_resource_context(self, node_path)
```

### 对应组件

- `RunTargetNodeFunction`
- `SetPropertyValue`

---

## 3. 属性持久化 - 场景加载顺序

`[标准1,2: 编辑器下解析路径 + 动态列表]`

### 问题描述

场景加载时，Godot 按顺序设置属性值，`edited_root` 可能还未准备好。Resource 的 setter 被调用时无法获取节点实例，导致属性信息丢失。

### 解决方案

在 `_get_property_list()` 中添加惰性初始化检查：

```gdscript
func _get_property_list():
	# 在编辑器中，如果节点实例为 null，尝试重新获取
	if Engine.is_editor_hint() and _target_node_instance == null:
		_update_target_node_info()
	# 返回属性列表...
```

利用编辑器会多次调用 `_get_property_list()` 的特性实现自动重试。

### 对应组件

- `RunTargetNodeFunction`
- `SetPropertyValue`

---

## 4. 属性持久化 - 保存与恢复

`[标准3: 持久化动态列表]`

### 问题描述

保存场景后重启编辑器，属性选择和 `to_value` 类型丢失。原因是 UI 显示时移除了前缀（如 `shader_parameter/`），但内部存储需要完整路径。

### 解决方案

1. 在 `_available_properties` 中存储完整路径（包含前缀）
2. UI 也显示完整路径，保持一致性
3. 在 `_update_property_type_info()` 中，如果属性列表为空，先调用 `_update_available_properties()`

```gdscript
func _update_property_type_info():
	if _available_properties.is_empty():
		_update_available_properties()
	# 继续处理...
```

### 对应组件

- `RunTargetNodeFunction` (方法缓存)
- `SetPropertyValue` (属性元数据)

---

## 5. 性能优化 - 属性列表缓存

`[标准2: 动态列表生成优化]`

### 问题描述

`_get_material_properties()` 被重复调用 20+ 次（Inspector 多次刷新）。

### 解决方案

实现缓存机制：

```gdscript
var _cached_material_properties: Array = []
var _cached_material_node: Node = null

func _get_material_properties():
	# 检查缓存有效性
	if _cached_material_node == _target_node and not _cached_material_properties.is_empty():
		return _cached_material_properties

	# 计算属性
	var properties = _compute_material_properties()

	# 更新缓存
	_cached_material_properties = properties
	_cached_material_node = _target_node
	return properties

# 在目标节点改变时清除缓存
var target_node: NodePath:
	set(value):
		target_node = value
		_cached_material_properties.clear()
		_cached_material_node = null
```

### 对应组件

- `SetPropertyValue` (属性列表缓存)

---

## 6. 其他编辑器注意事项

### Inspector 插件

- 实现自定义属性编辑器时继承 `EditorInspectorPlugin`
- 使用 `notify_property_list_changed()` 刷新属性列表

### 资源预览

- 资源应该在编辑器中可预览
- 提供 `get_editor_icon()` 和 `get_editor_color()` 方法

### 文件过滤 - .gdignore

- **不要在工作时创建 .gdignore 文件**
- .gdignore 会让 Godot 编辑器忽略整个文件夹
- 不支持通配符模式
- 仅在确定需要完全隐藏某个文件夹时使用

### 资源元数据文件

| 文件类型 | 是否提交 | 原因 |
|----------|----------|------|
| `.uid` | ✅ 必须 | Godot 4.x 资源唯一标识符 |
| `.import` | ✅ 必须 | 导入配置和设置 |
| `.remap` | ❌ 可忽略 | 临时映射文件 |

**重要：** 不要在 `.gitignore` 中添加 `*.uid`、`*.gd.uid` 或 `*.import` 规则。

---

## 快速参考

```gdscript
# 编辑器安全的属性访问
var material = node.get("material")

# 编辑器环境检测
if Engine.is_editor_hint():
	# 编辑器特定逻辑
	pass

# 延迟节点操作
call_deferred("_update_node_info")

# 刷新属性列表
notify_property_list_changed()

# 惰性初始化
func _get_property_list():
	if Engine.is_editor_hint() and _instance == null:
		_update_instance()
```

---

**相关文档:**
- [Bricks 系统概述](../../addons/bricks/docs/README.md)
- [GDScript 编码风格](../CLAUDE.md#代码规范)
