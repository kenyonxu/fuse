@tool
class_name FuseComponentScanner extends RefCounted

## Fuse 组件扫描器
##
## 从 instructions/ events/ conditions/ 目录扫描脚本,
## 验证元数据后注册到 ComponentRegistry(经三个专用 Registry)。
## 不依赖 EditorPlugin 特殊方法,仅用全局 Registry + DirAccess。

const FuseLocalizationClass = preload("res://addons/fuse/localization/fuse_localization.gd")

var _plugin: EditorPlugin

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin

## 扫描并注册所有指令/事件/条件
func setup() -> void:
	_register_all_instructions()
	_register_events()
	_register_conditions()
	# Stage 2.2: 扫描预设
	PresetRegistry.scan_presets()

## 清空所有注册表(插件停用时)
func teardown() -> void:
	InstructionRegistry.clear_all()
	EventRegistry.clear_all_events()
	ConditionRegistry.clear_all_conditions()

## 扫描并注册所有指令
func _register_all_instructions() -> void:
	var folders: Array[String] = [
		"res://addons/fuse/instructions/",
		"res://addons/fuse/integration/",
		"res://fuse_generated/instructions/"
	]
	_register_components_from_folders(
		folders,
		"_get_instruction_metadata",
		"InstructionRegistry",
		"register_instruction",
		"instructions_",
		FuseLocalizationClass.translate("FUSE_SCAN_LABEL_INSTRUCTION")
	)

## 扫描并注册所有事件
func _register_events() -> void:
	_register_components_from_folders(
		["res://addons/fuse/events/"] as Array[String],
		"_get_event_metadata",
		"EventRegistry",
		"register_event",
		"base_",
		FuseLocalizationClass.translate("FUSE_SCAN_LABEL_EVENT")
	)

## 扫描并注册所有条件
func _register_conditions() -> void:
	_register_components_from_folders(
		["res://addons/fuse/conditions/"] as Array[String],
		"_get_condition_metadata",
		"ConditionRegistry",
		"register_condition",
		"base_",
		FuseLocalizationClass.translate("FUSE_SCAN_LABEL_CONDITION")
	)

## 泛型组件注册方法
func _register_components_from_folders(
	folders: Array[String],
	metadata_method: String,
	registry_name: String,
	register_method: String,
	skip_prefix: String,
	component_label: String
) -> void:
	var all_files: Array[String] = []
	for folder in folders:
		var files = _scan_scripts_recursive(folder, skip_prefix)
		all_files.append_array(files)

	# 扫描前重置该类型的重复计数
	var ctype_for_reset: ComponentRegistry.ComponentType
	match registry_name:
		"InstructionRegistry":
			ctype_for_reset = ComponentRegistry.ComponentType.INSTRUCTION
		"EventRegistry":
			ctype_for_reset = ComponentRegistry.ComponentType.EVENT
		"ConditionRegistry":
			ctype_for_reset = ComponentRegistry.ComponentType.CONDITION
		_:
			ctype_for_reset = -1
	if ctype_for_reset != -1:
		ComponentRegistry.reset_duplicate_count(ctype_for_reset)

	var registered_count = 0
	var failed_files: Array[String] = []

	for file_path in all_files:
		var script = load(file_path) as GDScript
		if not script:
			failed_files.append(FuseLocalizationClass.translate_format("FUSE_SCAN_FAIL_LOAD_SCRIPT", {"path": file_path}))
			continue

		if not script.has_method(metadata_method):
			failed_files.append(FuseLocalizationClass.translate_format(
				"FUSE_SCAN_FAIL_MISSING_METHOD", {"path": file_path, "method": metadata_method}
			))
			continue

		var metadata = script.call(metadata_method)
		if not metadata:
			failed_files.append(FuseLocalizationClass.translate_format("FUSE_SCAN_FAIL_METADATA_EMPTY", {"path": file_path}))
			continue

		var has_identifier = (
			(metadata.name_key and not metadata.name_key.is_empty()) or
			(metadata.name and not metadata.name.is_empty())
		)
		if not has_identifier:
			failed_files.append(FuseLocalizationClass.translate_format("FUSE_SCAN_FAIL_NO_IDENTIFIER", {"path": file_path}))
			continue

		# 通过字符串引用注册表，避免 Callable 闭包捕获问题
		match registry_name:
			"InstructionRegistry":
				InstructionRegistry.register_instruction(script)
			"EventRegistry":
				EventRegistry.register_event(script)
			"ConditionRegistry":
				ConditionRegistry.register_condition(script)
		registered_count += 1

	print("Fuse: " + FuseLocalizationClass.translate_format(
		"FUSE_SCAN_REGISTER_SUMMARY",
		{"files": all_files.size(), "count": registered_count, "label": component_label}
	))
	if failed_files.size() > 0:
		print("Fuse: " + FuseLocalizationClass.translate_format(
			"FUSE_SCAN_REGISTER_FAILED_HEADER", {"label": component_label}
		))
		for failed_file in failed_files:
			print("  - %s" % failed_file)
	# 输出重复 identifier 统计
	if ctype_for_reset != -1:
		var dup_count = ComponentRegistry.get_duplicate_count(ctype_for_reset)
		if dup_count > 0:
			print("Fuse: " + FuseLocalizationClass.translate_format(
				"FUSE_SCAN_DUPLICATE_FOUND", {"count": dup_count, "label": component_label}
			))

## 递归扫描文件夹中的 GDScript 文件
func _scan_scripts_recursive(folder: String, skip_prefix: String = "") -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(folder)
	if not dir:
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = folder.path_join(file_name)

		if dir.current_is_dir():
			if not file_name.begins_with("."):
				var sub_files = _scan_scripts_recursive(full_path, skip_prefix)
				files.append_array(sub_files)
		elif file_name.ends_with(".gd"):
			if skip_prefix.is_empty() or not file_name.begins_with(skip_prefix):
				files.append(full_path)

		file_name = dir.get_next()

	return files
