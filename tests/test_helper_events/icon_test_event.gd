## 图标系统测试用事件
## 用于测试图标管理系统和向后兼容性

@tool
class_name IconTestEvent extends BaseEvent

## 初始化事件
func initialize(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 终止事件
func terminate(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 更新资源名称
func _update_resource_name():
	resource_name = FuseLocalization.translate("FUSE_EVENT_TEST_NAME")

## 获取事件描述
func get_description() -> String:
	return FuseLocalization.translate("FUSE_EVENT_TEST_DESC")

## 获取事件类型
func get_event_type() -> String:
	return "test_icon_event"

## 获取事件分类
func get_event_category() -> String:
	return "test"

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_TEST_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_TEST"
	metadata.description_key = "FUSE_EVENT_TEST_DESC"
	metadata.keywords = ["test", "icon", "测试"]
	metadata.builtin_icon = "Play"
	return metadata
