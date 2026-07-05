extends Node

## 简单的 OnTreeChanged 事件验证脚本

func _ready():
	print("=== 开始验证 OnTreeChanged 事件 ===")

	# 测试 1: 创建事件实例
	print("\n测试 1: 创建事件实例")
	var event = OnTreeChanged.new()
	assert(event != null, "事件实例创建失败")
	print("✓ 事件实例创建成功")

	# 测试 2: 检查枚举
	print("\n测试 2: 检查枚举定义")
	assert(OnTreeChanged.ChangeType.NodeAdded == 0, "NodeAdded 枚举值错误")
	assert(OnTreeChanged.ChangeType.NodeRemoved == 1, "NodeRemoved 枚举值错误")
	assert(OnTreeChanged.ChangeType.Any == 2, "Any 枚举值错误")
	print("✓ 枚举定义正确")

	# 测试 3: 检查属性
	print("\n测试 3: 检查事件属性")
	event.change_type = OnTreeChanged.ChangeType.NodeAdded
	assert(event.change_type == OnTreeChanged.ChangeType.NodeAdded, "change_type 设置失败")

	event.filter_by_group = "test_group"
	assert(event.filter_by_group == "test_group", "filter_by_group 设置失败")

	event.emit_changed_node = false
	assert(event.emit_changed_node == false, "emit_changed_node 设置失败")
	print("✓ 属性设置正常")

	# 测试 4: 检查方法
	print("\n测试 4: 检查必需方法")
	assert(event.has_method("_update_resource_name"), "缺少 _update_resource_name 方法")
	assert(event.has_method("initialize"), "缺少 initialize 方法")
	assert(event.has_method("terminate"), "缺少 terminate 方法")
	assert(event.has_method("get_description"), "缺少 get_description 方法")
	assert(event.has_method("get_event_type"), "缺少 get_event_type 方法")
	assert(event.has_method("get_event_category"), "缺少 get_event_category 方法")
	assert(event.has_method("validate"), "缺少 validate 方法")
	assert(event.has_method("_on_node_added"), "缺少 _on_node_added 方法")
	assert(event.has_method("_on_node_removed"), "缺少 _on_node_removed 方法")
	print("✓ 所有必需方法存在")

	# 测试 5: 检查资源名称更新
	print("\n测试 5: 检查资源名称更新")
	event.change_type = OnTreeChanged.ChangeType.NodeAdded
	event.filter_by_group = ""
	assert("节点添加" in event.resource_name, "资源名称不包含变化类型")

	event.change_type = OnTreeChanged.ChangeType.NodeRemoved
	assert("节点移除" in event.resource_name, "资源名称不包含变化类型")

	event.filter_by_group = "player"
	assert("player" in event.resource_name, "资源名称不包含组名")
	print("✓ 资源名称更新正确")

	# 测试 6: 检查事件元数据
	print("\n测试 6: 检查事件元数据")
	var metadata = event._get_event_metadata()
	assert(metadata != null, "元数据为空")
	assert(metadata.name_key == "FUSE_EVENT_ON_TREE_CHANGED_NAME", "name_key 错误")
	assert(metadata.category_key == "FUSE_EVENT_CATEGORY_SCENE", "category_key 错误")
	assert(metadata.description_key == "FUSE_EVENT_ON_TREE_CHANGED_DESC", "description_key 错误")
	print("✓ 事件元数据正确")

	# 测试 7: 检查事件类型和分类
	print("\n测试 7: 检查事件类型和分类")
	assert(event.get_event_type() == "tree_changed", "事件类型错误")
	assert(event.get_event_category() == "scene", "事件分类错误")
	print("✓ 事件类型和分类正确")

	# 测试 8: 检查描述
	print("\n测试 8: 检查事件描述")
	var desc = event.get_description()
	assert("场景树" in desc, "描述不包含场景树")
	assert("节点" in desc, "描述不包含节点")
	print("✓ 事件描述: ", desc)

	# 测试 9: 检查验证
	print("\n测试 9: 检查验证方法")
	var errors = event.validate()
	assert(errors is Array, "validate 应该返回数组")
	print("✓ 验证方法正常")

	print("\n=== 所有验证测试通过! ===")

	# 等待一帧后退出
	await get_tree().process_frame
	print("\n测试脚本运行完成")
