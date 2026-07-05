@tool
class_name UndoRedoManager
extends RefCounted

## UndoRedoManager
## 管理撤销/重做操作

signal undo_redo_changed(can_undo: bool, can_redo: bool)

# 操作历史栈
var undo_stack: Array = []
var redo_stack: Array = []

# 最大历史记录数量
var max_history: int = 100

# 是否正在执行撤销/重做操作
var is_executing: bool = false

## 添加操作到历史记录
func add_action(action: Dictionary) -> void:
	"""添加一个新的可撤销操作
	
	参数:
		action: 操作字典，包含以下字段:
			- name: 操作名称 (String)
			- do_func: 执行函数 (Callable)
			- undo_func: 撤销函数 (Callable)
			- data: 操作数据 (可选)
	"""
	if is_executing:
		return
	
	# 添加到撤销栈
	undo_stack.append(action)
	
	# 清空重做栈
	redo_stack.clear()
	
	# 限制历史记录数量
	if undo_stack.size() > max_history:
		undo_stack.pop_front()
	
	# 通知状态改变
	_notify_changed()

## 执行撤销
func undo() -> bool:
	"""执行撤销操作
	
	返回:
		bool: 是否成功撤销
	"""
	if undo_stack.is_empty() or is_executing:
		return false
	
	is_executing = true
	
	# 获取最后一个操作
	var action = undo_stack.pop_back()
	
	# 执行撤销函数
	if action.has("undo_func") and action.undo_func.is_valid():
		action.undo_func.call()
	
	# 添加到重做栈
	redo_stack.append(action)
	
	is_executing = false
	
	_notify_changed()
	return true

## 执行重做
func redo() -> bool:
	"""执行重做操作
	
	返回:
		bool: 是否成功重做
	"""
	if redo_stack.is_empty() or is_executing:
		return false
	
	is_executing = true
	
	# 获取最后一个重做操作
	var action = redo_stack.pop_back()
	
	# 执行操作函数
	if action.has("do_func") and action.do_func.is_valid():
		action.do_func.call()
	
	# 添加回撤销栈
	undo_stack.append(action)
	
	is_executing = false
	
	_notify_changed()
	return true

## 清空历史记录
func clear() -> void:
	"""清空所有撤销/重做历史"""
	undo_stack.clear()
	redo_stack.clear()
	_notify_changed()

## 检查是否可以撤销
func can_undo() -> bool:
	"""检查是否有可以撤销的操作"""
	return not undo_stack.is_empty()

## 检查是否可以重做
func can_redo() -> bool:
	"""检查是否有可以重做的操作"""
	return not redo_stack.is_empty()

## 获取撤销栈大小
func get_undo_count() -> int:
	return undo_stack.size()

## 获取重做栈大小
func get_redo_count() -> int:
	return redo_stack.size()

## 设置最大历史记录数量
func set_max_history(count: int) -> void:
	max_history = count
	# 如果当前历史超过新的限制，裁剪
	while undo_stack.size() > max_history:
		undo_stack.pop_front()

## 创建关键帧添加操作
func create_add_keyframe_action(track: JuicyPropertyTrack, keyframe: JuicyKeyframe) -> Dictionary:
	"""创建添加关键帧的操作"""
	return {
		name = "添加关键帧",
		track = track,
		keyframe = keyframe,
		do_func = func():
			if not track.keyframes.has(keyframe):
				track.keyframes.append(keyframe),
		undo_func = func():
			track.keyframes.erase(keyframe)
	}

## 创建关键帧删除操作
func create_delete_keyframe_action(track: JuicyPropertyTrack, keyframe: JuicyKeyframe) -> Dictionary:
	"""创建删除关键帧的操作"""
	return {
		name = "删除关键帧",
		track = track,
		keyframe = keyframe,
		do_func = func():
			track.keyframes.erase(keyframe),
		undo_func = func():
			if not track.keyframes.has(keyframe):
				track.keyframes.append(keyframe)
	}

## 创建关键帧移动操作
func create_move_keyframe_action(track: JuicyPropertyTrack, keyframe: JuicyKeyframe, old_time: float, new_time: float) -> Dictionary:
	"""创建移动关键帧的操作"""
	return {
		name = "移动关键帧",
		track = track,
		keyframe = keyframe,
		old_time = old_time,
		new_time = new_time,
		do_func = func():
			keyframe.time = new_time,
		undo_func = func():
			keyframe.time = old_time
	}

## 创建关键帧值修改操作
func create_change_keyframe_value_action(track: JuicyPropertyTrack, keyframe: JuicyKeyframe, old_value: float, new_value: float) -> Dictionary:
	"""创建修改关键帧值的操作"""
	return {
		name = "修改关键帧值",
		track = track,
		keyframe = keyframe,
		old_value = old_value,
		new_value = new_value,
		do_func = func():
			keyframe.value = new_value,
		undo_func = func():
			keyframe.value = old_value
	}

## 创建批量关键帧移动操作
func create_move_keyframes_action(keyframes_data: Array, time_delta: float) -> Dictionary:
	"""创建批量移动关键帧的操作
	
	keyframes_data: Array of {track, keyframe, original_time}
	"""
	var original_times = []
	for data in keyframes_data:
		original_times.append(data.original_time)
	
	return {
		name = "批量移动关键帧",
		keyframes = keyframes_data,
		time_delta = time_delta,
		original_times = original_times,
		do_func = func():
			for i in range(keyframes_data.size()):
				keyframes_data[i].keyframe.time = original_times[i] + time_delta,
		undo_func = func():
			for i in range(keyframes_data.size()):
				keyframes_data[i].keyframe.time = original_times[i]
	}

## 创建批量关键帧删除操作
func create_delete_keyframes_action(keyframes_data: Array) -> Dictionary:
	"""创建批量删除关键帧的操作
	
	keyframes_data: Array of {track, keyframe}
	"""
	return {
		name = "批量删除关键帧",
		keyframes = keyframes_data,
		do_func = func():
			for data in keyframes_data:
				data.track.keyframes.erase(data.keyframe),
		undo_func = func():
			for data in keyframes_data:
				if not data.track.keyframes.has(data.keyframe):
					data.track.keyframes.append(data.keyframe)
	}

## 创建轨道添加操作
func create_add_track_action(timeline: JuicyTimelineResource, track: JuicyTrack) -> Dictionary:
	"""创建添加轨道的操作"""
	return {
		name = "添加轨道",
		timeline = timeline,
		track = track,
		do_func = func():
			timeline.add_track(track),
		undo_func = func():
			timeline.remove_track(track)
	}

## 创建轨道删除操作
func create_delete_track_action(timeline: JuicyTimelineResource, track: JuicyTrack) -> Dictionary:
	"""创建删除轨道的操作"""
	return {
		name = "删除轨道",
		timeline = timeline,
		track = track,
		do_func = func():
			timeline.remove_track(track),
		undo_func = func():
			timeline.add_track(track)
	}

## 通知状态改变
func _notify_changed() -> void:
	undo_redo_changed.emit(can_undo(), can_redo())
