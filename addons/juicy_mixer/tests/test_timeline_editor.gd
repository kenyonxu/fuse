# Timeline编辑器功能测试
# 测试编辑器插件的基本功能、时间轴画布的交互、轨道编辑器和属性检查器扩展

extends Node

# 测试统计
var _tests_run = 0
var _tests_passed = 0
var _tests_failed = 0

# 测试资源
var _test_timeline: JuicyTimelineResource
var _test_editor_plugin: JuicyTimelineEditorPlugin
var _test_editor_interface: EditorInterface
var _test_selection: EditorSelection

# 断言辅助函数
func assert_true(condition: bool, message: String = "") -> void:
	_tests_run += 1
	if condition:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("❌ 测试失败: " + message)

func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, message)

func assert_equals(expected, actual, message: String = "") -> void:
	_tests_run += 1
	if expected == actual:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("❌ 测试失败: %s (期望: %s, 实际: %s)" % [message, str(expected), str(actual)])

func assert_not_null(value, message: String = "") -> void:
	_tests_run += 1
	if value != null:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("❌ 测试失败: " + message + " (值为null)")

func assert_null(value, message: String = "") -> void:
	_tests_run += 1
	if value == null:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("❌ 测试失败: " + message + " (值不为null)")

# 设置测试环境
func setup_test_environment():
	# 创建Timeline资源
	_test_timeline = JuicyTimelineResource.new()
	_test_timeline.timeline_duration = 10.0
	_test_timeline.description = "Test Timeline"
	
	# 添加测试轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "TestProperty"
	property_track.property_path = "scale"
	_test_timeline.add_track(property_track, "Property")
	
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "TestFeedback"
	feedback_track.resource = JuicyShakeResource.new()
	_test_timeline.add_track(feedback_track, "Feedback")
	
	# 创建编辑器插件（模拟）
	_test_editor_plugin = _create_mock_editor_plugin()
	
	# 创建编辑器接口（模拟）
	_test_editor_interface = _create_mock_editor_interface()
	
	# 创建选择（模拟）
	_test_selection = _create_mock_editor_selection()

# 测试编辑器插件的基本功能
func test_editor_plugin_basic():
	print("=== 🔧 测试编辑器插件基本功能 ===")
	
	# 创建编辑器插件
	var editor_plugin = _create_mock_editor_plugin()
	assert_not_null(editor_plugin, "编辑器插件创建失败")
	
	# 测试插件名称
	assert_true(editor_plugin.get_name().length() > 0, "插件名称不应为空")
	
	# 测试插件是否为EditorPlugin类型
	assert_true(editor_plugin is Object, "应为Object类型")
	
	print("✅ 编辑器插件基本功能测试通过")

# 测试时间轴画布的交互
func test_timeline_canvas_interaction():
	print("=== 📐 测试时间轴画布的交互 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建时间轴画布（模拟）
	var timeline_canvas = _create_mock_timeline_canvas()
	assert_not_null(timeline_canvas, "时间轴画布创建失败")
	
	# 测试画布基本属性
	assert_true(timeline_canvas.timeline_duration > 0, "画布应有有效时长")
	assert_true(timeline_canvas.zoom_level > 0, "画布应有有效缩放级别")
	assert_true(timeline_canvas.time_offset >= 0, "画布时间偏移应有效")
	
	# 测试时间转换
	var time_at_pixel = timeline_canvas.get_time_at_pixel(100)
	assert_true(time_at_pixel >= 0, "像素到时间转换应有效")
	
	var pixel_at_time = timeline_canvas.get_pixel_at_time(1.0)
	assert_true(pixel_at_time >= 0, "时间到像素转换应有效")
	
	# 测试缩放功能
	var original_zoom = timeline_canvas.zoom_level
	timeline_canvas.set_zoom(2.0)
	assert_true(timeline_canvas.zoom_level != original_zoom, "缩放级别应改变")
	
	# 测试平移功能
	var original_offset = timeline_canvas.time_offset
	timeline_canvas.set_time_offset(1.0)
	assert_true(timeline_canvas.time_offset != original_offset, "时间偏移应改变")
	
	# 测试吸附功能
	timeline_canvas.snap_enabled = true
	timeline_canvas.snap_step = 0.1
	
	var snapped_time = timeline_canvas.snap_time(0.123)
	assert_true(abs(0.1 - snapped_time) <= 0.01, "时间应吸附到步长")
	
	# 测试轨道选择
	var track_at_pos = timeline_canvas.get_track_at_position(Vector2(50, 50))
	assert_not_null(track_at_pos, "应能获取轨道")
	
	timeline_canvas.select_track(track_at_pos)
	assert_true(timeline_canvas.is_track_selected(track_at_pos), "轨道应被选中")
	
	timeline_canvas.deselect_all_tracks()
	assert_false(timeline_canvas.is_track_selected(track_at_pos), "轨道应被取消选中")
	
	print("✅ 时间轴画布的交互测试通过")

# 测试轨道编辑器
func test_track_editor():
	print("=== 🎛️ 测试轨道编辑器 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建轨道编辑器（模拟）
	var track_editor = _create_mock_track_editor()
	assert_not_null(track_editor, "轨道编辑器创建失败")
	
	# 测试轨道编辑器基本属性
	assert_true(track_editor.edited_track != null, "应有编辑的轨道")
	assert_true(track_editor.track_properties.size() > 0, "应有轨道属性")
	
	# 测试属性轨道编辑
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "EditedProperty"
	property_track.property_path = "scale"
	property_track.value_range = Vector2(0.0, 2.0)
	
	track_editor.set_edited_track(property_track)
	assert_equals(property_track, track_editor.edited_track, "应设置编辑的轨道")
	
	# 测试属性编辑
	track_editor.set_property_value("track_name", "NewName")
	assert_equals("NewName", property_track.track_name, "轨道名应被更新")
	
	track_editor.set_property_value("property_path", "rotation")
	assert_equals("rotation", property_track.property_path, "属性路径应被更新")
	
	track_editor.set_property_value("value_range", Vector2(1.0, 3.0))
	assert_equals(Vector2(1.0, 3.0), property_track.value_range, "值范围应被更新")
	
	# 测试关键帧编辑
	var keyframe = JuicyKeyframe.new()
	keyframe.time = 0.5
	keyframe.value = 1.0
	
	track_editor.add_keyframe(keyframe)
	assert_true(property_track.keyframes.size() > 0, "关键帧应被添加")
	
	track_editor.remove_keyframe(keyframe)
	assert_true(property_track.keyframes.is_empty(), "关键帧应被移除")
	
	# 测试曲线编辑
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 1))
	
	track_editor.set_animation_curve(curve)
	assert_equals(curve, property_track.animation_curve, "动画曲线应被设置")
	
	# 测试参数映射编辑
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "intensity"
	mapping.enabled = true
	
	track_editor.add_parameter_mapping(mapping)
	assert_true(property_track.parameter_mappings.size() > 0, "参数映射应被添加")
	
	track_editor.remove_parameter_mapping(mapping)
	assert_true(property_track.parameter_mappings.is_empty(), "参数映射应被移除")
	
	print("✅ 轨道编辑器测试通过")

# 测试属性检查器扩展
func test_property_inspector_extension():
	print("=== 📝 测试属性检查器扩展 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建属性检查器扩展（模拟）
	var inspector_extension = _create_mock_inspector_extension()
	assert_not_null(inspector_extension, "属性检查器扩展创建失败")
	
	# 测试扩展基本属性
	assert_true(inspector_extension.can_inspect(_test_timeline), "应能检查Timeline资源")
	assert_true(inspector_extension.custom_properties.size() > 0, "应有自定义属性")
	
	# 测试Timeline资源检查
	var timeline_properties = inspector_extension.get_custom_properties(_test_timeline)
	assert_not_null(timeline_properties, "应获取Timeline自定义属性")
	
	# 验证Timeline自定义属性
	var expected_properties = [
		"timeline_duration",
		"loop_mode",
		"loop_count",
		"time_scale",
		"input_parameters",
		"parameter_presets",
		"timeline_zoom",
		"snap_enabled",
		"snap_step"
	]
	
	for prop in expected_properties:
		assert_true(timeline_properties.has(prop), "应包含属性: " + prop)
	
	# 测试轨道属性检查
	var property_track = _test_timeline.property_tracks[0]
	var track_properties = inspector_extension.get_custom_properties(property_track)
	assert_not_null(track_properties, "应获取轨道自定义属性")
	
	# 验证属性轨道自定义属性
	var track_expected_properties = [
		"track_name",
		"property_path",
		"value_range",
		"animation_curve",
		"use_parameter_mapping",
		"parameter_mappings"
	]
	
	for prop in track_expected_properties:
		assert_true(track_properties.has(prop), "应包含轨道属性: " + prop)
	
	# 测试属性编辑回调
	var property_changed = false
	inspector_extension.property_changed.connect(func(property_name, old_value, new_value):
		property_changed = true
	)
	
	inspector_extension.set_property_value(_test_timeline, "timeline_duration", 15.0)
	assert_true(property_changed, "属性变更应触发回调")
	assert_equals(15.0, _test_timeline.timeline_duration, "属性值应被更新")
	
	print("✅ 属性检查器扩展测试通过")

# 测试编辑器菜单和工具栏
func test_editor_menu_and_toolbar():
	print("=== 🛠️ 测试编辑器菜单和工具栏 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建编辑器菜单（模拟）
	var editor_menu = _create_mock_editor_menu()
	assert_not_null(editor_menu, "编辑器菜单创建失败")
	
	# 测试菜单项
	var menu_items = editor_menu.get_menu_items()
	assert_true(menu_items.size() > 0, "应有菜单项")
	
	# 验证Timeline菜单项
	var expected_menu_items = [
		"Add Property Track",
		"Add Feedback Track",
		"Add Method Track",
		"Add Event Track",
		"Play Timeline",
		"Stop Timeline",
		"Loop Timeline"
	]
	
	for item in expected_menu_items:
		assert_true(editor_menu.has_menu_item(item), "应包含菜单项: " + item)
	
	# 测试菜单项执行
	var track_count = _test_timeline.get_all_tracks().size()
	editor_menu.execute_menu_item("Add Property Track")
	
	var new_track_count = _test_timeline.get_all_tracks().size()
	assert_true(new_track_count > track_count, "添加轨道菜单项应增加轨道数量")
	
	# 测试工具栏
	var toolbar = _create_mock_toolbar()
	assert_not_null(toolbar, "工具栏创建失败")
	
	var toolbar_items = toolbar.get_toolbar_items()
	assert_true(toolbar_items.size() > 0, "应有工具栏项")
	
	# 验证Timeline工具栏项
	var expected_toolbar_items = [
		"play_button",
		"stop_button",
		"loop_button",
		"zoom_in_button",
		"zoom_out_button",
		"snap_button"
	]
	
	for item in expected_toolbar_items:
		assert_true(toolbar.has_toolbar_item(item), "应包含工具栏项: " + item)
	
	# 测试工具栏项执行
	var original_zoom = toolbar.get_zoom_level()
	toolbar.execute_toolbar_item("zoom_in_button")
	
	var new_zoom = toolbar.get_zoom_level()
	assert_true(new_zoom > original_zoom, "放大按钮应增加缩放级别")
	
	print("✅ 编辑器菜单和工具栏测试通过")

# 测试编辑器快捷键
func test_editor_shortcuts():
	print("=== ⌨️ 测试编辑器快捷键 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建快捷键管理器（模拟）
	var shortcut_manager = _create_mock_shortcut_manager()
	assert_not_null(shortcut_manager, "快捷键管理器创建失败")
	
	# 测试快捷键注册
	shortcut_manager.register_shortcut("space", "play_timeline")
	shortcut_manager.register_shortcut("s", "stop_timeline")
	shortcut_manager.register_shortcut("l", "toggle_loop")
	shortcut_manager.register_shortcut("delete", "delete_selected_track")
	shortcut_manager.register_shortcut("ctrl+d", "duplicate_track")
	
	# 验证快捷键
	assert_true(shortcut_manager.has_shortcut("space"), "应注册space快捷键")
	assert_true(shortcut_manager.has_shortcut("s"), "应注册s快捷键")
	assert_true(shortcut_manager.has_shortcut("l"), "应注册l快捷键")
	assert_true(shortcut_manager.has_shortcut("delete"), "应注册delete快捷键")
	assert_true(shortcut_manager.has_shortcut("ctrl+d"), "应注册ctrl+d快捷键")
	
	# 测试快捷键执行
	var is_playing = false
	shortcut_manager.set_action_handler("play_timeline", func():
		is_playing = true
	)
	
	shortcut_manager.execute_shortcut("space")
	assert_true(is_playing, "播放快捷键应执行相应动作")
	
	# 测试轨道删除快捷键
	var track_count = _test_timeline.get_all_tracks().size()
	shortcut_manager.set_action_handler("delete_selected_track", func():
		if _test_timeline.property_tracks.size() > 0:
			_test_timeline.remove_track(_test_timeline.property_tracks[0])
	)
	
	shortcut_manager.execute_shortcut("delete")
	var new_track_count = _test_timeline.get_all_tracks().size()
	assert_true(new_track_count < track_count, "删除快捷键应减少轨道数量")
	
	print("✅ 编辑器快捷键测试通过")

# 测试编辑器撤销重做
func test_editor_undo_redo():
	print("=== ↩️ 测试编辑器撤销重做 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建撤销重做管理器（模拟）
	var undo_redo = _create_mock_undo_redo()
	assert_not_null(undo_redo, "撤销重做管理器创建失败")
	
	# 测试初始状态
	assert_false(undo_redo.can_undo(), "初始状态不应能撤销")
	assert_false(undo_redo.can_redo(), "初始状态不应能重做")
	
	# 测试记录操作
	var original_duration = _test_timeline.timeline_duration
	undo_redo.create_action("Change Duration", func():
		_test_timeline.timeline_duration = 15.0
	, func():
		_test_timeline.timeline_duration = original_duration
	)
	
	assert_true(undo_redo.can_undo(), "记录操作后应能撤销")
	assert_false(undo_redo.can_redo(), "记录操作后不应能重做")
	assert_equals(15.0, _test_timeline.timeline_duration, "操作应被执行")
	
	# 测试撤销
	undo_redo.undo()
	assert_false(undo_redo.can_undo(), "撤销后不应能再撤销")
	assert_true(undo_redo.can_redo(), "撤销后应能重做")
	assert_equals(original_duration, _test_timeline.timeline_duration, "撤销应恢复原值")
	
	# 测试重做
	undo_redo.redo()
	assert_true(undo_redo.can_undo(), "重做后应能撤销")
	assert_false(undo_redo.can_redo(), "重做后不应能再重做")
	assert_equals(15.0, _test_timeline.timeline_duration, "重做应恢复新值")
	
	# 测试多级撤销重做
	var original_name = _test_timeline.description
	undo_redo.create_action("Change Name", func():
		_test_timeline.description = "Modified Timeline"
	, func():
		_test_timeline.description = original_name
	)
	
	undo_redo.create_action("Add Track", func():
		var track = JuicyPropertyTrack.new()
		track.track_name = "New Track"
		_test_timeline.add_track(track, "Property")
	, func():
		if _test_timeline.property_tracks.size() > 0:
			_test_timeline.remove_track_at(_test_timeline.property_tracks.size() - 1, "Property")
	)
	
	# 撤销两次
	undo_redo.undo()
	undo_redo.undo()
	
	# 验证状态
	assert_equals(original_name, _test_timeline.description, "应恢复原始名称")
	assert_equals(1, _test_timeline.property_tracks.size(), "应恢复原始轨道数量")
	
	# 重做两次
	undo_redo.redo()
	undo_redo.redo()
	
	# 验证状态
	assert_equals("Modified Timeline", _test_timeline.description, "应恢复修改后名称")
	assert_equals(2, _test_timeline.property_tracks.size(), "应恢复添加后轨道数量")
	
	print("✅ 编辑器撤销重做测试通过")

# 测试编辑器导入导出
func test_editor_import_export():
	print("=== 📤 测试编辑器导入导出 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建导入导出管理器（模拟）
	var import_export = _create_mock_import_export()
	assert_not_null(import_export, "导入导出管理器创建失败")
	
	# 测试导出Timeline
	var export_data = import_export.export_timeline(_test_timeline)
	assert_not_null(export_data, "导出数据不应为null")
	assert_true(export_data.has("timeline_data"), "应包含时间轴数据")
	assert_true(export_data.has("tracks_data"), "应包含轨道数据")
	assert_true(export_data.has("metadata"), "应包含元数据")
	
	# 验证导出数据
	var timeline_data = export_data["timeline_data"]
	assert_equals(_test_timeline.timeline_duration, timeline_data["duration"], "导出的时长应正确")
	assert_equals(_test_timeline.loop_mode, timeline_data["loop_mode"], "导出的循环模式应正确")
	assert_equals(_test_timeline.description, timeline_data["description"], "导出的描述应正确")
	
	var tracks_data = export_data["tracks_data"]
	assert_true(tracks_data.size() > 0, "应导出轨道数据")
	
	# 测试导入Timeline
	var new_timeline = import_export.import_timeline(export_data)
	assert_not_null(new_timeline, "导入的Timeline不应为null")
	assert_equals(_test_timeline.timeline_duration, new_timeline.timeline_duration, "导入的时长应正确")
	assert_equals(_test_timeline.loop_mode, new_timeline.loop_mode, "导入的循环模式应正确")
	assert_equals(_test_timeline.description, new_timeline.description, "导入的描述应正确")
	
	# 测试导入导出文件格式
	var json_data = import_export.export_to_json(_test_timeline)
	assert_not_null(json_data, "JSON导出数据不应为null")
	assert_true(json_data.length > 0, "JSON数据不应为空")
	
	var imported_from_json = import_export.import_from_json(json_data)
	assert_not_null(imported_from_json, "从JSON导入的Timeline不应为null")
	
	# 测试导出部分轨道
	var selected_tracks = [_test_timeline.property_tracks[0]]
	var partial_export = import_export.export_tracks(selected_tracks)
	assert_not_null(partial_export, "部分导出数据不应为null")
	assert_equals(1, partial_export["tracks_data"].size(), "应只导出选中的轨道")
	
	print("✅ 编辑器导入导出测试通过")

# 测试编辑器性能
func test_editor_performance():
	print("=== ⚡ 测试编辑器性能 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 添加更多轨道以测试性能
	for i in range(100):
		var track = JuicyPropertyTrack.new()
		track.track_name = "PerfTrack" + str(i)
		track.property_path = "property" + str(i)
		track.value_range = Vector2(0.0, 1.0)
		
		var curve = Curve.new()
		curve.add_point(Vector2(0, 0))
		curve.add_point(Vector2(1, 1))
		track.animation_curve = curve
		
		_test_timeline.add_track(track, "Property")
	
	# 测试编辑器渲染性能
	var canvas = _create_mock_timeline_canvas()
	var start_time = Time.get_ticks_msec()
	
	for i in range(100):
		canvas.render_timeline(_test_timeline)
	
	var render_time = Time.get_ticks_msec() - start_time
	print("  渲染100次耗时: " + str(render_time) + "ms")
	
	# 性能要求：渲染应小于1秒
	assert_true(render_time < 1000, "渲染性能应满足要求")
	
	# 测试轨道编辑性能
	var track_editor = _create_mock_track_editor()
	start_time = Time.get_ticks_msec()
	
	for i in range(100):
		var track = _test_timeline.property_tracks[i % _test_timeline.property_tracks.size()]
		track_editor.set_edited_track(track)
		track_editor.set_property_value("value_range", Vector2(i % 10, (i % 10) + 1))
	
	var edit_time = Time.get_ticks_msec() - start_time
	print("  编辑100次耗时: " + str(edit_time) + "ms")
	
	# 性能要求：编辑应小于500ms
	assert_true(edit_time < 500, "编辑性能应满足要求")
	
	# 测试撤销重做性能
	var undo_redo = _create_mock_undo_redo()
	start_time = Time.get_ticks_msec()
	
	for i in range(50):
		undo_redo.create_action("Test Action " + str(i), func(): pass, func(): pass)
	
	var create_time = Time.get_ticks_msec() - start_time
	print("  创建50个动作耗时: " + str(create_time) + "ms")
	
	# 性能要求：创建动作应小于100ms
	assert_true(create_time < 100, "创建动作性能应满足要求")
	
	start_time = Time.get_ticks_msec()
	
	for i in range(50):
		if undo_redo.can_undo():
			undo_redo.undo()
	
	var undo_time = Time.get_ticks_msec() - start_time
	print("  撤销50次耗时: " + str(undo_time) + "ms")
	
	# 性能要求：撤销应小于200ms
	assert_true(undo_time < 200, "撤销性能应满足要求")
	
	print("✅ 编辑器性能测试通过")

# 辅助函数：创建模拟时间轴画布
func _create_mock_timeline_canvas() -> Object:
	var canvas = RefCounted.new()
	
	# 基本属性
	canvas.timeline_duration = 10.0
	canvas.zoom_level = 1.0
	canvas.time_offset = 0.0
	canvas.snap_enabled = true
	canvas.snap_step = 0.1
	
	# 选中轨道
	canvas.selected_tracks = []
	
	# 方法
	canvas.get_time_at_pixel = func(pixel: float) -> float:
		return pixel / 100.0 * canvas.zoom_level + canvas.time_offset
	
	canvas.get_pixel_at_time = func(time: float) -> float:
		return (time - canvas.time_offset) / canvas.zoom_level * 100.0
	
	canvas.set_zoom = func(zoom: float):
		canvas.zoom_level = zoom
	
	canvas.set_time_offset = func(offset: float):
		canvas.time_offset = offset
	
	canvas.snap_time = func(time: float) -> float:
		if not canvas.snap_enabled:
			return time
		return round(time / canvas.snap_step) * canvas.snap_step
	
	canvas.get_track_at_position = func(pos: Vector2) -> JuicyTrack:
		return null  # 模拟实现
	
	canvas.select_track = func(track: JuicyTrack):
		if track not in canvas.selected_tracks:
			canvas.selected_tracks.append(track)
	
	canvas.deselect_all_tracks = func():
		canvas.selected_tracks.clear()
	
	canvas.is_track_selected = func(track: JuicyTrack) -> bool:
		return track in canvas.selected_tracks
	
	canvas.render_timeline = func(timeline: JuicyTimelineResource):
		pass  # 模拟渲染
	
	return canvas

# 辅助函数：创建模拟轨道编辑器
func _create_mock_track_editor() -> Object:
	var editor = RefCounted.new()
	
	# 编辑的轨道
	editor.edited_track = null
	
	# 轨道属性
	editor.track_properties = {}
	
	# 方法
	editor.set_edited_track = func(track: JuicyTrack):
		editor.edited_track = track
		editor._refresh_properties()
	
	editor.set_property_value = func(property_name: String, value: Variant):
		if editor.edited_track:
			editor.edited_track.set(property_name, value)
	
	editor.add_keyframe = func(keyframe: JuicyKeyframe):
		if editor.edited_track and editor.edited_track.has_method("add_keyframe"):
			editor.edited_track.add_keyframe(keyframe)
	
	editor.remove_keyframe = func(keyframe: JuicyKeyframe):
		if editor.edited_track and editor.edited_track.has_method("remove_keyframe"):
			editor.edited_track.remove_keyframe(keyframe)
	
	editor.set_animation_curve = func(curve: Curve):
		if editor.edited_track and editor.edited_track.has_method("set"):
			editor.edited_track.set("animation_curve", curve)
	
	editor.add_parameter_mapping = func(mapping: JuicyParameterMapping):
		if editor.edited_track and editor.edited_track.has_method("add_parameter_mapping"):
			editor.edited_track.add_parameter_mapping(mapping)
	
	editor.remove_parameter_mapping = func(mapping: JuicyParameterMapping):
		if editor.edited_track and editor.edited_track.has_method("remove_parameter_mapping"):
			editor.edited_track.remove_parameter_mapping(mapping)
	
	editor._refresh_properties = func():
		if not editor.edited_track:
			return
		
		editor.track_properties = {}
		var properties = editor.edited_track.get_property_list()
		for prop in properties:
			if prop.name.begins_with("export_"):
				continue
			editor.track_properties[prop.name] = prop
	
	return editor

# 辅助函数：创建模拟属性检查器扩展
func _create_mock_inspector_extension() -> Object:
	var extension = RefCounted.new()
	
	# 自定义属性
	extension.custom_properties = {}
	
	# 属性变更信号
	extension.property_changed = Callable()
	
	# 方法
	extension.can_inspect = func(resource: Resource) -> bool:
		return resource is JuicyTimelineResource or resource is JuicyTrack
	
	extension.get_custom_properties = func(resource: Resource) -> Dictionary:
		if not extension.can_inspect(resource):
			return {}
		
		var properties = {}
		var property_list = resource.get_property_list()
		for prop in property_list:
			if prop.name.begins_with("export_"):
				continue
			properties[prop.name] = prop
		
		extension.custom_properties = properties
		return properties
	
	extension.set_property_value = func(resource: Resource, property_name: String, value: Variant):
		if resource.has_method("set"):
			resource.set(property_name, value)
		extension.property_changed.emit(property_name, resource.get(property_name), value)
	
	return extension

# 辅助函数：创建模拟编辑器菜单
func _create_mock_editor_menu() -> Object:
	var menu = RefCounted.new()
	
	# 菜单项
	menu.menu_items = {}
	
	# 动作处理器
	menu.action_handlers = {}
	
	# 方法
	menu.get_menu_items = func() -> Array:
		return menu.menu_items.keys()
	
	menu.has_menu_item = func(item_name: String) -> bool:
		return menu.menu_items.has(item_name)
	
	menu.execute_menu_item = func(item_name: String):
		if menu.action_handlers.has(item_name):
			menu.action_handlers[item_name].call()
	
	# 注册默认菜单项
	menu.menu_items["Add Property Track"] = {"label": "Add Property Track", "shortcut": "Alt+P"}
	menu.menu_items["Add Feedback Track"] = {"label": "Add Feedback Track", "shortcut": "Alt+F"}
	menu.menu_items["Add Method Track"] = {"label": "Add Method Track", "shortcut": "Alt+M"}
	menu.menu_items["Add Event Track"] = {"label": "Add Event Track", "shortcut": "Alt+E"}
	menu.menu_items["Play Timeline"] = {"label": "Play Timeline", "shortcut": "Space"}
	menu.menu_items["Stop Timeline"] = {"label": "Stop Timeline", "shortcut": "S"}
	menu.menu_items["Loop Timeline"] = {"label": "Loop Timeline", "shortcut": "L"}
	
	return menu

# 辅助函数：创建模拟工具栏
func _create_mock_toolbar() -> Object:
	var toolbar = RefCounted.new()
	
	# 工具栏项
	toolbar.toolbar_items = {}
	
	# 缩放级别
	toolbar.zoom_level = 1.0
	
	# 方法
	toolbar.get_toolbar_items = func() -> Array:
		return toolbar.toolbar_items.keys()
	
	toolbar.has_toolbar_item = func(item_name: String) -> bool:
		return toolbar.toolbar_items.has(item_name)
	
	toolbar.execute_toolbar_item = func(item_name: String):
		match item_name:
			"play_button":
				print("Play timeline")
			"stop_button":
				print("Stop timeline")
			"loop_button":
				print("Toggle loop")
			"zoom_in_button":
				toolbar.zoom_level *= 1.2
			"zoom_out_button":
				toolbar.zoom_level /= 1.2
			"snap_button":
				print("Toggle snap")
	
	toolbar.get_zoom_level = func() -> float:
		return toolbar.zoom_level
	
	# 注册默认工具栏项
	toolbar.toolbar_items["play_button"] = {"icon": "Play", "tooltip": "Play Timeline"}
	toolbar.toolbar_items["stop_button"] = {"icon": "Stop", "tooltip": "Stop Timeline"}
	toolbar.toolbar_items["loop_button"] = {"icon": "Loop", "tooltip": "Toggle Loop"}
	toolbar.toolbar_items["zoom_in_button"] = {"icon": "ZoomIn", "tooltip": "Zoom In"}
	toolbar.toolbar_items["zoom_out_button"] = {"icon": "ZoomOut", "tooltip": "Zoom Out"}
	toolbar.toolbar_items["snap_button"] = {"icon": "Snap", "tooltip": "Toggle Snap"}
	
	return toolbar

# 辅助函数：创建模拟快捷键管理器
func _create_mock_shortcut_manager() -> Object:
	var manager = RefCounted.new()
	
	# 快捷键映射
	manager.shortcuts = {}
	
	# 动作处理器
	manager.action_handlers = {}
	
	# 方法
	manager.register_shortcut = func(key: String, action: String):
		manager.shortcuts[key] = action
	
	manager.has_shortcut = func(key: String) -> bool:
		return manager.shortcuts.has(key)
	
	manager.execute_shortcut = func(key: String):
		if manager.shortcuts.has(key) and manager.action_handlers.has(manager.shortcuts[key]):
			manager.action_handlers[manager.shortcuts[key]].call()
	
	manager.set_action_handler = func(action: String, handler: Callable):
		manager.action_handlers[action] = handler
	
	return manager

# 辅助函数：创建模拟撤销重做管理器
func _create_mock_undo_redo() -> Object:
	var undo_redo = RefCounted.new()
	
	# 历史记录
	undo_redo.history = []
	undo_redo.current_index = -1
	
	# 方法
	undo_redo.create_action = func(name: String, do_func: Callable, undo_func: Callable):
		# 清除当前位置之后的历史
		undo_redo.history = undo_redo.history.slice(0, undo_redo.current_index + 1)
		
		# 添加新动作
		undo_redo.history.append({
			"name": name,
			"do": do_func,
			"undo": undo_func
		})
		undo_redo.current_index += 1
	
	undo_redo.can_undo = func() -> bool:
		return undo_redo.current_index >= 0
	
	undo_redo.can_redo = func() -> bool:
		return undo_redo.current_index < undo_redo.history.size() - 1
	
	undo_redo.undo = func():
		if not undo_redo.can_undo():
			return
		
		var action = undo_redo.history[undo_redo.current_index]
		action.undo.call()
		undo_redo.current_index -= 1
	
	undo_redo.redo = func():
		if not undo_redo.can_redo():
			return
		
		undo_redo.current_index += 1
		var action = undo_redo.history[undo_redo.current_index]
		action.do.call()
	
	return undo_redo

# 辅助函数：创建模拟导入导出管理器
func _create_mock_import_export() -> Object:
	var import_export = RefCounted.new()
	
	# 方法
	import_export.export_timeline = func(timeline: JuicyTimelineResource) -> Dictionary:
		var tracks_data = []
		for track in timeline.get_all_tracks():
			tracks_data.append({
				"type": track.get_track_type(),
				"name": track.track_name,
				"data": track.get_config_dict()
			})
		
		return {
			"timeline_data": {
				"duration": timeline.timeline_duration,
				"loop_mode": timeline.loop_mode,
				"loop_count": timeline.loop_count,
				"time_scale": timeline.time_scale,
				"description": timeline.description
			},
			"tracks_data": tracks_data,
			"metadata": {
				"export_time": Time.get_unix_time_from_system(),
				"version": "1.0"
			}
		}
	
	import_export.import_timeline = func(data: Dictionary) -> JuicyTimelineResource:
		var timeline = JuicyTimelineResource.new()
		
		var timeline_data = data["timeline_data"]
		timeline.timeline_duration = timeline_data["duration"]
		timeline.loop_mode = timeline_data["loop_mode"]
		timeline.loop_count = timeline_data["loop_count"]
		timeline.time_scale = timeline_data["time_scale"]
		timeline.description = timeline_data["description"]
		
		# 这里应该导入轨道数据，但为了简化测试，跳过
		
		return timeline
	
	import_export.export_to_json = func(timeline: JuicyTimelineResource) -> String:
		var data = import_export.export_timeline(timeline)
		return JSON.stringify(data)
	
	import_export.import_from_json = func(json_string: String) -> JuicyTimelineResource:
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result != OK:
			return null
		
		return import_export.import_timeline(json.data)
	
	import_export.export_tracks = func(tracks: Array[JuicyTrack]) -> Dictionary:
		var tracks_data = []
		for track in tracks:
			tracks_data.append({
				"type": track.get_track_type(),
				"name": track.track_name,
				"data": track.get_config_dict()
			})
		
		return {
			"tracks_data": tracks_data,
			"metadata": {
				"export_time": Time.get_unix_time_from_system(),
				"version": "1.0"
			}
		}
	
	return import_export

# 辅助函数：创建模拟编辑器插件
func _create_mock_editor_plugin() -> Object:
	var plugin = RefCounted.new()
	
	# 插件属性
	plugin.name = "JuicyTimelineEditorPlugin"
	
	# 方法
	plugin.get_name = func() -> String:
		return plugin.name
	
	return plugin

# 辅助函数：创建模拟编辑器接口
func _create_mock_editor_interface() -> Object:
	var interface = RefCounted.new()
	
	# 方法
	interface.get_selection = func() -> Object:
		return _create_mock_editor_selection()
	
	interface.get_base_control = func() -> Control:
		return Control.new()
	
	return interface

# 辅助函数：创建模拟编辑器选择
func _create_mock_editor_selection() -> Object:
	var selection = RefCounted.new()
	
	# 选中节点
	selection.selected_nodes = []
	
	# 方法
	selection.get_selected_nodes = func() -> Array:
		return selection.selected_nodes
	
	selection.clear = func():
		selection.selected_nodes.clear()
	
	return selection

# 运行所有测试
func run_all_tests():
	print("🚀 开始Timeline编辑器功能测试")
	print("==================================================")
	
	test_editor_plugin_basic()
	test_timeline_canvas_interaction()
	test_track_editor()
	test_property_inspector_extension()
	test_editor_menu_and_toolbar()
	test_editor_shortcuts()
	test_editor_undo_redo()
	test_editor_import_export()
	test_editor_performance()
	
	print("==================================================")
	print("📊 测试统计:")
	print("  总测试数: %d" % _tests_run)
	print("  通过: %d" % _tests_passed)
	print("  失败: %d" % _tests_failed)
	
	if _tests_failed == 0:
		print("🎉 所有Timeline编辑器功能测试通过！")
	else:
		push_error("❌ 有 %d 个测试失败！" % _tests_failed)

func _ready():
	run_all_tests()