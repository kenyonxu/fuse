# Timeline Editor Universal Target Selection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 Timeline Editor 的目标选择功能扩展到所有轨道类型，通过拆分智能操作区域为"全局功能"和"轨道专属"两个区域，提供统一且可扩展的用户体验。

**Architecture:**
- 拆分 `context_actions_container` 为两个独立容器：`global_actions_container`（全局功能，不重建）和 `track_specific_container`（轨道专属，动态重建）
- 全局功能区域包含目标选择按钮和目标提示，使用 VSeparator 与轨道专属区域分隔
- 保持向后兼容，不影响现有轨道类型的特殊功能

**Tech Stack:**
- Godot 4.5 GDScript
- Editor UI (Control, Button, Panel, Label, VSeparator)
- 现有的 JuicyTrack 资源系统

---

## Task 1: 重构 `_create_context_actions()` 创建双容器架构

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_editor.gd:631-647`

**Step 1: 理解现有代码结构**

阅读当前 `_create_context_actions()` 的实现：
- 创建 `context_separator` 和 `context_actions_container`
- 添加初始提示文本
- 返回 None

**Step 2: 修改 `_create_context_actions()` 创建双容器**

```gdscript
func _create_context_actions(parent: HBoxContainer):
	"""创建智能操作区域（双容器架构：全局功能 + 轨道专属）"""
	var editor_theme = EditorInterface.get_editor_theme()

	# 添加分隔符
	context_separator = VSeparator.new()
	parent.add_child(context_separator)

	# 创建智能操作主容器
	context_actions_container = HBoxContainer.new()
	parent.add_child(context_actions_container)

	# 🔥 新增：创建全局功能容器（只创建一次，不重建）
	global_actions_container = HBoxContainer.new()
	context_actions_container.add_child(global_actions_container)

	# 🔥 新增：创建轨道专属容器（根据轨道类型动态重建）
	track_specific_container = HBoxContainer.new()
	context_actions_container.add_child(track_specific_container)

	# 🔥 新增：添加分隔符（视觉分隔两个区域）
	var actions_separator = VSeparator.new()
	context_actions_container.add_child(actions_separator)

	# 初始化全局功能区域
	_initialize_global_actions()

	# 初始化轨道专属区域（显示提示）
	var hint_label = Label.new()
	hint_label.text = "选择轨道查看相关操作"
	hint_label.modulate = Color.GRAY
	track_specific_container.add_child(hint_label)
```

**Step 3: 添加类成员变量**

在文件顶部的变量声明区域（约 line 46-54）添加：

```gdscript
# 智能操作区域（双容器架构）
var context_actions_container: HBoxContainer
var global_actions_container: HBoxContainer    # 全局功能容器（不重建）
var track_specific_container: HBoxContainer   # 轨道专属容器（动态重建）
var context_separator: VSeparator
var _target_node_button: Button                # 保存目标选择按钮引用
```

**Step 4: 提交**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd
git commit -m "refactor(timeline): 创建双容器架构（全局功能 + 轨道专属）

- 拆分 context_actions_container 为两个独立容器
- global_actions_container: 全局功能，不重建
- track_specific_container: 轨道专属，动态重建
- 添加 VSeparator 视觉分隔
"
```

---

## Task 2: 实现 `_initialize_global_actions()` 创建目标选择功能

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_editor.gd`（在 `_create_context_actions()` 后添加新函数）

**Step 1: 实现 `_initialize_global_actions()` 函数**

在 `_create_context_actions()` 函数后添加：

```gdscript
func _initialize_global_actions():
	"""初始化全局功能区域（只调用一次）

	全局功能对所有轨道类型都可见，不随轨道切换重建
	"""
	var editor_theme = EditorInterface.get_editor_theme()

	# 创建目标节点选择按钮
	_target_node_button = Button.new()
	_target_node_button.icon = editor_theme.get_icon("Node", "EditorIcons")
	_target_node_button.tooltip_text = "选择目标节点"
	_target_node_button.custom_minimum_size = Vector2(30, 0)
	_target_node_button.pressed.connect(_on_target_node_picker_pressed)
	_target_node_button.visible = true  # 始终可见
	global_actions_container.add_child(_target_node_button)

	# 创建目标节点提示（占位符，稍后由 _update_target_node_hint_display 更新）
	# 目标节点提示已由 _create_target_node_hint() 创建，这里只需要确保它正确显示
	# 提示框会浮动显示在 global_actions_container 右方
```

**Step 2: 提交**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd
git commit -m "feat(timeline): 添加全局功能区域初始化

- 实现 _initialize_global_actions() 创建目标选择按钮
- 目标选择按钮对所有轨道类型可见
- 按钮引用保存在 _target_node_button 成员变量
"
```

---

## Task 3: 重构 `_update_context_actions()` 只更新轨道专属区域

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_editor.gd:649-704`

**Step 1: 修改 `_update_context_actions()` 函数**

替换现有实现为：

```gdscript
func _update_context_actions(track: JuicyTrack):
	"""根据选中的轨道类型更新轨道专属操作按钮

	全局功能区域不重建，只更新轨道专属区域
	"""
	if not track_specific_container:
		print("Editor: track_specific_container为null，跳过")
		return

	# 🔥 优化：更新全局目标提示（所有轨道类型都支持 target）
	if track:
		update_target_node_hint_from_track(track)
	else:
		_update_target_node_hint_display("")

	# 清空轨道专属容器（不影响全局功能容器）
	for child in track_specific_container.get_children():
		track_specific_container.remove_child(child)
		child.queue_free()

	# 立即重置轨道专属按钮变量为null，避免引用已删除的对象
	_edit_mode_button = null
	_drag_mode_button = null
	_batch_drag_button = null

	# 根据轨道类型创建不同的按钮（仅轨道专属功能）
	match track.get_track_type():
		"Feedback":
			_create_feedback_track_actions(track)
		"Property":
			_create_property_track_actions(track)
		"Method":
			_create_method_track_actions(track)
		"Event":
			_create_event_track_actions(track)
		_:
			# 未选中轨道，显示提示
			var hint_label = Label.new()
			hint_label.text = "选择轨道查看相关操作"
			hint_label.modulate = Color.GRAY
			track_specific_container.add_child(hint_label)
```

**Step 2: 提交**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd
git commit -m "refactor(timeline): 重构 _update_context_actions 只更新轨道专属区域

- 全局功能区域不重建，避免闪烁
- 所有轨道类型都更新目标节点提示
- 轨道专属容器独立管理，不影响全局功能
"
```

---

## Task 4: 移除 `_create_property_track_actions()` 中的目标选择按钮

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_editor.gd:726-776`

**Step 1: 修改 `_create_property_track_actions()` 移除目标选择代码**

移除 line 768-776 的目标选择按钮相关代码：

```gdscript
func _create_property_track_actions(editor_theme: Theme, track: JuicyPropertyTrack):
	"""创建Property Track的操作按钮（轨道专属功能）"""

	# 添加关键帧按钮
	var add_keyframe_button = Button.new()
	add_keyframe_button.icon = editor_theme.get_icon("KeyNext", "EditorIcons")
	add_keyframe_button.tooltip_text = "在播放头位置添加关键帧"
	add_keyframe_button.custom_minimum_size = Vector2(30, 0)
	add_keyframe_button.pressed.connect(_on_add_keyframe_pressed)
	track_specific_container.add_child(add_keyframe_button)

	# 添加拖动模式切换按钮
	var drag_mode_button = Button.new()
	drag_mode_button.custom_minimum_size = Vector2(30, 0)
	drag_mode_button.tooltip_text = "拖动模式：点击切换时间/值拖动"
	drag_mode_button.pressed.connect(_on_drag_mode_toggled)
	drag_mode_button.visible = true
	track_specific_container.add_child(drag_mode_button)

	# 立即保存按钮引用（在添加到容器后）
	_drag_mode_button = drag_mode_button

	# 根据当前拖动模式设置图标
	var current_drag_mode = timeline_canvas.get_drag_mode() if timeline_canvas else 0
	_update_drag_mode_button_icon(current_drag_mode)

	# 添加批量拖动模式切换按钮
	var batch_drag_button = Button.new()
	batch_drag_button.custom_minimum_size = Vector2(30, 0)
	batch_drag_button.tooltip_text = "批量拖动模式：点击启用/禁用"
	batch_drag_button.pressed.connect(_on_batch_drag_toggled)
	batch_drag_button.visible = true
	track_specific_container.add_child(batch_drag_button)

	# 立即保存按钮引用（在添加到容器后）
	_batch_drag_button = batch_drag_button

	# 根据当前批量拖动模式设置图标
	var batch_enabled = timeline_canvas.get_batch_drag_enabled() if timeline_canvas else false
	_update_batch_drag_button_icon(batch_enabled)

	# 🔥 移除：目标节点选择按钮（已移至全局功能区域）
	# 🔥 移除：直接更新目标节点提示（已在 _update_context_actions 中统一处理）
```

**Step 2: 提交**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd
git commit -m "refactor(timeline): 移除 Property Track 的目标选择按钮

- 目标选择功能已移至全局功能区域
- Property Track 只保留轨道专属按钮（关键帧、拖动模式）
- 简化轨道专属功能代码
"
```

---

## Task 5: 修改 `_on_target_node_picker_pressed()` 支持所有轨道类型

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_editor.gd:835-899`

**Step 1: 修改函数签名和实现**

将函数改为接受通用的 `JuicyTrack` 类型：

```gdscript
func _on_target_node_picker_pressed(track: JuicyTrack = null):
	"""打开目标节点选择器（支持所有轨道类型）

	@param track: 如果为null，使用当前选中的轨道
	"""

	# 如果没有传入轨道，使用当前选中的轨道
	if not track:
		track = timeline_canvas.get_selected_track() if timeline_canvas else null

	if not track:
		_update_status_bar("请先选择一个轨道")
		return

	# 获取当前编辑的场景
	var editor_interface = Engine.get_singleton("EditorInterface")
	var edited_root = editor_interface.get_edited_scene_root()

	if edited_root:
		# 创建节点树对话框
		var node_dialog = AcceptDialog.new()
		node_dialog.title = "选择目标节点"
		node_dialog.size = Vector2(400, 500)
		node_dialog.unresizable = false

		var vbox = VBoxContainer.new()
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		node_dialog.add_child(vbox)

		var label = Label.new()
		label.text = "选择要控制的目标节点:"
		vbox.add_child(label)

		var tree = Tree.new()
		tree.set_columns(1)
		tree.set_column_titles_visible(false)
		tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(tree)

		# 填充节点树
		_populate_node_tree(tree, edited_root)

		# AcceptDialog默认自带"确定"按钮，这里只添加"取消"按钮
		node_dialog.add_button("取消", false)

		# 存储对话框引用以便在关闭时清理
		node_dialog.set_meta("track", track)

		# 保存当前选中的轨道，以便在对话框关闭后恢复
		var current_track = track

		node_dialog.confirmed.connect(func():
			var selected = tree.get_selected()
			if selected:
				var node_path = selected.get_metadata(0)
				current_track.target = node_path
				_update_status_bar("已设置目标节点: " + str(node_path))
				# 重绘画布和状态栏
				if timeline_canvas:
					timeline_canvas.queue_redraw()
				# 延迟重新选择轨道，确保对话框完全关闭后再重建按钮
				# 同时也延迟更新目标节点提示，避免线程安全问题
				call_deferred("_reselect_track_after_dialog", current_track)
				call_deferred("update_target_node_hint_from_track", current_track)
		)

		# 将对话框添加到编辑器主窗口而不是场景树
		var base_control = editor_interface.get_base_control()
		if base_control:
			base_control.add_child(node_dialog)
			# 使用popup_centered而不是popup_exclusive_centered，避免重复父节点错误
			node_dialog.popup_centered()
			# 在对话框关闭时自动清理（延迟执行，确保对话框操作完成）
			node_dialog.close_requested.connect(func():
				call_deferred("_cleanup_dialog", node_dialog)
			)
```

**Step 2: 修改 `_initialize_global_actions()` 中的按钮连接**

更新 Task 2 中创建的按钮连接，不传递参数：

```gdscript
	_target_node_button.pressed.connect(_on_target_node_picker_pressed.bind(null))
```

**Step 3: 提交**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd
git commit -m "feat(timeline): 目标选择器支持所有轨道类型

- _on_target_node_picker_pressed 改为接受通用 JuicyTrack
- 未传入轨道时自动使用当前选中的轨道
- 所有轨道类型都可以使用全局目标选择按钮
"
```

---

## Task 6: 调整目标提示显示位置到全局功能区域右方

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_editor.gd:1236-1262`

**Step 1: 修改 `_update_target_node_hint_display()` 计算位置**

更新目标提示框的位置计算逻辑（约 line 1247-1260）：

```gdscript
	# 如果有文本，设置位置和大小
	if not text.is_empty():
		# 计算文本大小
		var font = ThemeDB.fallback_font
		var text_size = font.get_string_size(text)

		# 计算背景框尺寸
		var bg_size = Vector2(text_size.x + 10, text_size.y + 6)

		# 设置Panel的大小
		_target_node_hint.set_size(bg_size)

		# 🔥 修改：设置位置（显示在 global_actions_container 右方）
		if global_actions_container:
			# 获取 global_actions_container 的全局位置和大小
			var container_global_pos = global_actions_container.get_global_position()
			var container_size = global_actions_container.get_size()

			# 计算提示框位置（在 global_actions_container 右方，垂直对齐）
			var hint_pos = container_global_pos + Vector2(container_size.x + 5, 0)
			_target_node_hint.set_global_position(hint_pos)

			# 设置高度与 container 一致
			_target_node_hint.set_size(Vector2(bg_size.x, container_size.y))

			print("TimelineEditor: 提示框位置设置为: ", hint_pos, " 大小: ", _target_node_hint.get_size())
		else:
			print("TimelineEditor: _update_target_node_hint_display() 警告 - global_actions_container为null")
	else:
		print("TimelineEditor: 提示框已隐藏（文本为空）")
```

**Step 2: 提交**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd
git commit -m "fix(timeline): 调整目标提示显示位置到全局功能区域右方

- 提示框紧跟 global_actions_container
- 使用全局位置计算确保正确对齐
- 与新的双容器架构一致
"
```

---

## Task 7: 更新 `update_target_node_hint_from_track()` 支持所有轨道类型

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_editor.gd:1267-1316`

**Step 1: 修改函数签名和实现**

将函数从接受 `JuicyPropertyTrack` 改为接受通用的 `JuicyTrack`：

```gdscript
func update_target_node_hint_from_track(track: JuicyTrack):
	"""从轨道直接更新目标节点提示，避免依赖get_selected_track()的返回值

	支持所有轨道类型（Feedback/Method/Event/Property）

	@param track: 选中的轨道
	"""
	print("TimelineEditor: update_target_node_hint_from_track() 被调用，track = ", track.track_name if track else "null")

	if not track:
		_update_target_node_hint_display("")
		return

	if not track.target.is_empty():
		# 获取当前编辑的场景
		var editor_interface = Engine.get_singleton("EditorInterface")
		if editor_interface:
			var edited_root = editor_interface.get_edited_scene_root()
			if edited_root:
				# 尝试获取目标节点并计算相对路径
				var display_path = str(track.target)

				# 使用 get_node_or_null 避免错误抛出
				var target_node = edited_root.get_node_or_null(track.target)
				if target_node:
					# 获取从场景根节点到目标节点的相对路径
					var relative_path = edited_root.get_path_to(target_node)
					if not relative_path.is_empty():
						display_path = str(relative_path)
				else:
					# 如果目标节点不存在，尝试从路径中提取
					var scene_root_pattern = ":root/"
					var root_pattern = "/root/"

					# 修复：将 NodePath 转换为 String 后再调用 find()
					var path_string = str(display_path)
					var scene_root_idx = path_string.find(scene_root_pattern)
					var root_idx = path_string.find(root_pattern)

					if scene_root_idx >= 0:
						# 从场景根节点开始截取
						display_path = path_string.substr(scene_root_idx + scene_root_pattern.length())
					elif root_idx >= 0:
						# 从根节点开始截取
						display_path = path_string.substr(root_idx + root_pattern.length())
					else:
						# 尝试从第一个 "/" 开始截取（去除开头的斜杠）
						var first_slash = path_string.find("/")
						if first_slash >= 0:
							display_path = path_string.substr(first_slash + 1)

				# 调用_update_target_node_hint_display显示提示
				var hint_text = "目标: " + display_path
				_update_target_node_hint_display(hint_text)
				print("TimelineEditor: update_target_node_hint_from_track() 已更新提示: ", hint_text)
	else:
		# target为空，隐藏提示
		_update_target_node_hint_display("")
		print("TimelineEditor: update_target_node_hint_from_track() target为空，隐藏提示")
```

**Step 2: 提交**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd
git commit -m "refactor(timeline): update_target_node_hint_from_track 支持所有轨道类型

- 函数签名改为接受通用 JuicyTrack
- 所有轨道类型（Feedback/Method/Event/Property）都显示目标提示
- 简化逻辑，移除 Property Track 特定代码
"
```

---

## Task 8: 手动测试所有轨道类型的目标选择功能

**Files:**
- Test: 在 Godot Editor 中手动测试

**Step 1: 测试 Property Track 目标选择**

1. 打开 `demos/bricks_juicy_demo.tscn`
2. 打开 Timeline Editor
3. 选择一个 Property Track
4. 验证：
   - [ ] 全局功能区域显示目标选择按钮
   - [ ] 轨道专属区域显示关键帧、拖动模式按钮
   - [ ] VSeparator 正确分隔两个区域
   - [ ] 点击目标选择按钮，弹出节点选择对话框
   - [ ] 选择目标节点后，提示正确显示在全局区域右方
   - [ ] 切换到其他轨道再切回，目标提示仍然正确

**Step 2: 测试 Feedback Track 目标选择**

1. 选择或创建一个 Feedback Track
2. 验证：
   - [ ] 全局功能区域显示目标选择按钮
   - [ ] 轨道专属区域显示编辑模式切换按钮
   - [ ] 点击目标选择按钮可以正常工作
   - [ ] 选择目标后，target 属性正确保存

**Step 3: 测试 Method Track 目标选择**

1. 选择或创建一个 Method Track
2. 验证：
   - [ ] 全局功能区域显示目标选择按钮
   - [ ] 轨道专属区域显示编辑方法按钮
   - [ ] 目标选择功能正常工作

**Step 4: 测试 Event Track 目标选择**

1. 选择或创建一个 Event Track
2. 验证：
   - [ ] 全局功能区域显示目标选择按钮
   - [ ] 轨道专属区域显示编辑事件按钮
   - [ ] 目标选择功能正常工作

**Step 5: 测试轨道切换时的 UI 稳定性**

1. 快速切换不同类型的轨道
2. 验证：
   - [ ] 全局功能区域不闪烁/重建
   - [ ] 轨道专属区域正确切换内容
   - [ ] 目标提示根据选中的轨道正确更新
   - [ ] 没有错误日志输出

**Step 6: 测试未选择轨道时的状态**

1. 取消选择所有轨道
2. 验证：
   - [ ] 全局功能区域仍然显示目标选择按钮
   - [ ] 目标提示隐藏（或显示占位文本）
   - [ ] 轨道专属区域显示"选择轨道查看相关操作"

**Step 7: 记录测试结果**

如果有任何问题，记录在 `docs/plans/2026-01-12-timeline-editor-universal-target-selection-test-notes.md`

**Step 8: 提交测试结果**

```bash
# 如果测试通过
git commit --allow-empty -m "test(timeline): 手动测试所有轨道类型的目标选择功能

- ✅ Property Track 目标选择
- ✅ Feedback Track 目标选择
- ✅ Method Track 目标选择
- ✅ Event Track 目标选择
- ✅ 轨道切换 UI 稳定性
- ✅ 未选择轨道时的状态
"
```

---

## Task 9: 可选 - 为其他轨道类型添加轨道专属按钮

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_editor.gd:706-794`

**Step 1: 分析当前其他轨道类型的按钮**

查看 `_create_feedback_track_actions()`, `_create_method_track_actions()`, `_create_event_track_actions()` 的当前实现

**Step 2: 决定是否需要补充按钮**

根据实际使用情况，可能需要添加：
- Feedback Track: 重复次数、强度等快捷调整
- Method Track: 参数预览
- Event Track: 触发条件预览

**Step 3: 如果不需要额外按钮，跳过此任务**

如果当前按钮已经足够，直接进入下一步。

**Step 4: 如果需要，实现补充按钮并测试**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd
git commit -m "feat(timeline): 为其他轨道类型添加快捷操作按钮

- Feedback Track: 添加 [具体功能]
- Method Track: 添加 [具体功能]
- Event Track: 添加 [具体功能]
"
```

---

## Task 10: 更新文档和代码注释

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_editor.gd`
- Create: `docs/juicy_mixer/timeline-editor-ui-design.md`

**Step 1: 添加文件头注释**

在 `juicy_timeline_editor.gd` 顶部添加：

```gdscript
# JuicyTimelineEditor - Timeline 编辑器
#
# UI 架构:
# - Toolbar: 播放控制、时间显示、视图控制
# - Smart Actions Area: 双容器架构
#   - Global Actions: 全局功能（目标选择、目标提示），不随轨道切换重建
#   - Track Specific: 轨道专属按钮，根据轨道类型动态更新
#   - VSeparator: 视觉分隔两个区域
# - Edit Area: 轨道编辑器 + 时间轴画布
# - Status Bar: 状态信息、轨道数量、时长
#
# 智能操作区域设计:
# - global_actions_container: 存放所有轨道通用的功能按钮
# - track_specific_container: 存放特定轨道类型的操作按钮
# - 这种设计避免了轨道切换时全局功能的闪烁，提供更稳定的用户体验
```

**Step 2: 创建 UI 设计文档**

创建 `docs/juicy_mixer/timeline-editor-ui-design.md`:

````markdown
# Timeline Editor UI 设计文档

## 概述

Timeline Editor 采用模块化的 UI 设计，将功能划分为清晰的区域。

## Toolbar 布局

```
┌──────────────────────────────────────────────────────────────┐
│ [撤销][重做] | [播放][暂停][停止] | 时间: 0.00s | 缩放: 1.0x │
└──────────────────────────────────────────────────────────────┘
```

## 智能操作区域（Smart Actions Area）

### 架构设计

```
context_actions_container (HBoxContainer)
├── global_actions_container (HBoxContainer)
│   ├── target_node_button (目标选择按钮)
│   └── [未来扩展] 其他全局功能
├── VSeparator (视觉分隔)
└── track_specific_container (HBoxContainer)
    └── [动态内容] 根据轨道类型变化
```

### 设计原则

1. **全局功能区域（Global Actions）**
   - 对所有轨道类型可见
   - 不随轨道切换重建
   - 始终启用（即使未选择轨道）

2. **轨道专属区域（Track Specific）**
   - 根据选中的轨道类型动态更新
   - 每次轨道切换时清空并重建
   - 未选择轨道时显示提示文本

3. **视觉分隔**
   - 使用 `VSeparator` 清晰分隔两个区域
   - 帮助用户快速区分功能类型

### 示例布局

**Property Track 选中时:**
```
[🎯目标] [目标: Player]  |  [➕关键帧] [↔️拖动] [📦批量]
 全局功能                  轨道专属功能
```

**Feedback Track 选中时:**
```
[🎯目标] [目标: Camera]  |  [🔄编辑模式]
 全局功能                  轨道专属功能
```

**未选择轨道时:**
```
[🎯目标]  |  选择轨道查看相关操作
 全局功能    提示文本
```

## 目标节点提示

### 显示规则

- 有目标节点：显示节点路径（相对路径）
- 无目标节点：隐藏提示
- 未选择轨道：隐藏提示

### 位置计算

- 显示在 `global_actions_container` 右方
- 垂直对齐容器
- 使用全局位置确保正确显示

### 代码实现

```gdscript
func update_target_node_hint_from_track(track: JuicyTrack):
	# 1. 检查 track 和 track.target
	# 2. 获取目标节点相对路径
	# 3. 更新提示显示
```

## 扩展性

### 添加新的全局功能

1. 在 `_initialize_global_actions()` 中创建按钮
2. 连接到处理函数
3. 按钮会自动对所有轨道类型可见

### 添加新的轨道专属功能

1. 在对应的 `_create_*_track_actions()` 中添加按钮
2. 按钮只在特定轨道类型时显示

## 相关文件

- `addons/juicy_mixer/editor/juicy_timeline_editor.gd` - Timeline Editor 主实现
- `addons/juicy_mixer/resources/juicy_track.gd` - 轨道基类
- `addons/juicy_mixer/resources/juicy_property_track.gd` - Property Track
- `addons/juicy_mixer/resources/juicy_feedback_track.gd` - Feedback Track
- `addons/juicy_mixer/resources/juicy_method_track.gd` - Method Track
- `addons/juicy_mixer/resources/juicy_event_track.gd` - Event Track

## 更新历史

- 2026-01-12: 创建双容器架构，统一目标选择功能
````

**Step 3: 提交文档**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd docs/juicy_mixer/timeline-editor-ui-design.md
git commit -m "docs(timeline): 添加 UI 设计文档和代码注释

- 添加文件头注释说明 UI 架构
- 创建 timeline-editor-ui-design.md 设计文档
- 记录双容器架构的设计原则和扩展方法
"
```

---

## Task 11: 最终验证和清理

**Files:**
- All modified files

**Step 1: 代码审查清单**

- [ ] 所有类成员变量都有注释
- [ ] 所有公开函数都有文档注释
- [ ] 没有调试用的 `print()` 语句残留（除了关键的日志输出）
- [ ] 没有注释掉的代码
- [ ] 代码风格一致（Tab 缩进，命名规范）

**Step 2: 功能验证**

- [ ] 所有轨道类型都能使用目标选择功能
- [ ] UI 布局正确，分隔符位置正确
- [ ] 目标提示正确显示和隐藏
- [ ] 没有控制台错误或警告

**Step 3: 性能检查**

- [ ] 轨道切换时没有明显的延迟
- [ ] 全局功能区域不重建，避免内存抖动
- [ ] 对话框关闭后正确清理，没有内存泄漏

**Step 4: 最终提交**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd
git commit -m "feat(timeline): 完成目标选择功能统一到所有轨道类型

改进内容:
- ✅ 实现双容器架构（全局功能 + 轨道专属）
- ✅ 目标选择按钮对所有轨道类型可见
- ✅ 目标提示统一更新逻辑
- ✅ 轨道切换时全局功能不闪烁
- ✅ 代码注释和文档完善

测试覆盖:
- Property Track: 目标选择、关键帧、拖动模式
- Feedback Track: 目标选择、编辑模式
- Method Track: 目标选择、方法编辑
- Event Track: 目标选择、事件编辑

相关文档:
- docs/juicy_mixer/timeline-editor-ui-design.md
"
```

---

## 总结

### 实现的功能

1. **双容器架构**: 将智能操作区域拆分为全局功能和轨道专属两个容器
2. **统一目标选择**: 所有轨道类型（Feedback/Method/Event/Property）都可以使用目标选择功能
3. **稳定的 UI**: 全局功能区域不随轨道切换重建，提供更好的用户体验
4. **清晰的视觉分隔**: 使用 VSeparator 明确区分两个功能区域
5. **可扩展设计**: 架构支持未来添加更多全局功能和轨道专属功能

### 关键改进

- **Property Track**: 移除了重复的目标选择按钮，只保留轨道专属功能
- **其他轨道类型**: 新增目标选择能力，与 Property Track 功能对等
- **用户体验**: 减少轨道切换时的闪烁，目标提示更稳定

### 相关文件

- `addons/juicy_mixer/editor/juicy_timeline_editor.gd` - 主要修改文件
- `docs/juicy_mixer/timeline-editor-ui-design.md` - 新增设计文档

### 后续优化建议

1. 考虑为其他轨道类型添加更多快捷操作按钮（Task 9）
2. 可以添加目标节点验证，提示无效的目标路径
3. 可以添加目标节点预览功能（快速定位到目标节点）
