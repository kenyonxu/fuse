@tool
@icon("res://addons/fuse/icons/builtin/OS.svg")
extends BaseCondition
class_name CheckPlatform

## 检查当前运行平台
##
## 通过 OS.get_name() 检测当前运行的操作系统平台。

## 平台枚举
enum Platform {
	WINDOWS,  ## Windows
	MACOS,    ## macOS
	LINUX,    ## Linux
	ANDROID,  ## Android
	IOS,      ## iOS
	WEB       ## Web
}

## 预期平台
var platform: Platform = Platform.WINDOWS:
	set(value):
		platform = value
		_update_resource_name()

## 更新资源名称
func _update_resource_name() -> void:
	var name = _get_platform_name(platform)
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_PLATFORM_FORMAT", {
		"platform": name
	})

func _get_platform_name(p: Platform) -> String:
	match p:
		Platform.WINDOWS: return "Windows"
		Platform.MACOS: return "macOS"
		Platform.LINUX: return "Linux"
		Platform.ANDROID: return "Android"
		Platform.IOS: return "iOS"
		Platform.WEB: return "Web"
	return "?"

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	var os_name = OS.get_name()
	match platform:
		Platform.WINDOWS: return os_name == "Windows"
		Platform.MACOS: return os_name == "macOS"
		Platform.LINUX: return os_name == "Linux"
		Platform.ANDROID: return os_name == "Android"
		Platform.IOS: return os_name == "iOS"
		Platform.WEB: return os_name == "Web"
	return false

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "check_platform"

## 获取条件分类
func get_condition_category() -> String:
	return "system"

## 获取条件描述
func get_description() -> String:
	var name = _get_platform_name(platform)
	return FuseLocalization.translate_format("FUSE_CONDITION_PLATFORM_DESCRIPTION", {
		"platform": name
	})

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()
	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"platform": platform
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("platform"):
		platform = parameters["platform"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_PLATFORM_NAME"
	metadata.category_key = "FUSE_CATEGORY_SYSTEM"
	metadata.description_key = "FUSE_CONDITION_PLATFORM_DESC"
	metadata.keywords = ["平台", "platform", "系统", "system", "操作系统", "OS", "Windows", "macOS", "Linux", "Android", "iOS", "Web"]
	metadata.builtin_icon = "OS"
	return metadata
