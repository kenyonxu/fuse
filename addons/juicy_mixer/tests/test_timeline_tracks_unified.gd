# JuicyTimelineResource 统一轨道数组单元测试
# 测试 timeline_tracks 与分组数组的双向同步机制

extends Node

func _ready():
	_test_basic_sync()
	_test_sync_loop_protection()
	_test_data_consistency()
	_test_serialization()
	_test_clone()
	_test_legacy_format_migration()

	print("✅ All unified tracks tests passed!")

## 测试 1：基本同步测试
func _test_basic_sync():
	print("Testing basic timeline_tracks sync...")

	var timeline = JuicyTimelineResource.new()

	# 添加轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "Property1"
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "Feedback1"

	timeline.timeline_tracks.append(property_track)
	timeline.timeline_tracks.append(feedback_track)

	# 验证同步
	assert(timeline.timeline_tracks.size() == 2, "Unified array track count incorrect")
	assert(timeline._property_tracks.size() == 1, "Property grouped array track count incorrect")
	assert(timeline._feedback_tracks.size() == 1, "Feedback grouped array track count incorrect")
	assert(timeline._property_tracks[0] == property_track, "Property track sync error")
	assert(timeline._feedback_tracks[0] == feedback_track, "Feedback track sync error")

	print("✅ Basic sync test passed")

## 测试 2：循环同步保护测试
func _test_sync_loop_protection():
	print("Testing sync loop protection...")

	var timeline = JuicyTimelineResource.new()
	var track = JuicyPropertyTrack.new()
	track.track_name = "Track1"

	var start_time = Time.get_ticks_msec()

	# 添加轨道（触发同步）
	timeline.timeline_tracks.append(track)

	var end_time = Time.get_ticks_msec()
	var elapsed = end_time - start_time

	# 如果有循环，elapsed 会超过 1000ms
	assert(elapsed < 100, "Sync operation timeout, possible loop (took %dms)" % elapsed)

	print("✅ Sync loop protection test passed")

## 测试 3：数据一致性测试
func _test_data_consistency():
	print("Testing data consistency...")

	var timeline = JuicyTimelineResource.new()

	# 添加多种类型轨道
	for i in range(5):
		var property_track = JuicyPropertyTrack.new()
		property_track.track_name = "Property%d" % i
		timeline.add_track(property_track)

	for i in range(3):
		var feedback_track = JuicyFeedbackTrack.new()
		feedback_track.track_name = "Feedback%d" % i
		timeline.add_track(feedback_track)

	# 验证一致性
	var unified_count = timeline.timeline_tracks.size()
	var grouped_count = (
		timeline._property_tracks.size() +
		timeline._feedback_tracks.size() +
		timeline._method_tracks.size() +
		timeline._event_tracks.size()
	)

	assert(unified_count == grouped_count, "Data inconsistency: unified=%d, grouped=%d" % [unified_count, grouped_count])

	print("✅ Data consistency test passed")

## 测试 4：序列化测试
func _test_serialization():
	print("Testing serialization...")

	var timeline = JuicyTimelineResource.new()

	# 添加轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "Property1"
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "Feedback1"

	timeline.timeline_tracks.append(property_track)
	timeline.timeline_tracks.append(feedback_track)

	# 序列化
	var config = timeline.get_config_dict()

	# 反序列化
	var new_timeline = JuicyTimelineResource.new()
	new_timeline.load_from_dict(config)

	# 验证
	assert(new_timeline.timeline_tracks.size() == 2, "Deserialized track count incorrect")
	assert(new_timeline._property_tracks.size() == 1, "Deserialized Property grouped array incorrect")
	assert(new_timeline._feedback_tracks.size() == 1, "Deserialized Feedback grouped array incorrect")

	print("✅ Serialization test passed")

## 测试 5：克隆测试
func _test_clone():
	print("Testing clone...")

	var timeline = JuicyTimelineResource.new()

	# 添加轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "Property1"
	timeline.timeline_tracks.append(property_track)

	# 克隆
	var cloned_timeline = timeline.clone()

	# 验证
	assert(cloned_timeline.timeline_tracks.size() == 1, "Cloned track count incorrect")
	assert(cloned_timeline._property_tracks.size() == 1, "Cloned Property grouped array incorrect")
	assert(cloned_timeline.timeline_tracks[0].track_name == "Property1", "Cloned track data incorrect")

	# 验证独立性（修改克隆不应影响原对象）
	cloned_timeline.timeline_tracks[0].track_name = "Property1_Clone"
	assert(timeline.timeline_tracks[0].track_name == "Property1", "Clone not independent")

	print("✅ Clone test passed")

## 测试 6：向后兼容性测试
func _test_legacy_format_migration():
	print("Testing legacy format migration...")

	var timeline = JuicyTimelineResource.new()

	# 模拟旧格式（直接操作内部数组）
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "Property1"
	timeline._property_tracks.append(property_track)

	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "Feedback1"
	timeline._feedback_tracks.append(feedback_track)

	# 模拟旧格式配置字典
	var legacy_config = {
		"property_tracks": [property_track.get_config_dict()],
		"feedback_tracks": [feedback_track.get_config_dict()]
	}

	# 触发迁移
	timeline._migrate_legacy_format(legacy_config)

	# 验证迁移结果
	assert(timeline.timeline_tracks.size() == 2, "Migrated unified array track count incorrect")
	assert(timeline.timeline_tracks[0].track_name == "Property1", "Migrated track data lost")
	assert(timeline.timeline_tracks[1].track_name == "Feedback1", "Migrated track data lost")

	print("✅ Legacy format migration test passed")
