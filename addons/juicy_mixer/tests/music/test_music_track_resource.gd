extends Node

## MusicTrackResource 测试

func _ready():
	print("\n=== MusicTrackResource 测试开始 ===\n")
	test_basic_creation()
	await get_tree().process_frame
	test_intro_loop_validation()
	await get_tree().process_frame
	test_loop_variants()
	await get_tree().process_frame
	print("\n=== 所有测试通过 ===\n")

func test_basic_creation():
	print("测试: 基础创建")
	var track = MusicTrackResource.new()
	assert(track.music_type == MusicTrackResource.MusicType.INTRO_LOOP, "默认类型应为 INTRO_LOOP")
	assert(track.intro_fade_out_time == 2.0, "默认淡出时间应为 2.0")
	assert(track.persist_across_scenes == true, "默认应跨场景持久化")
	print("  ✓ 基础创建测试通过")

func test_intro_loop_validation():
	print("测试: Intro-Loop 验证")
	var track = MusicTrackResource.new()
	track.music_type = MusicTrackResource.MusicType.INTRO_LOOP

	# 缺少必要流
	var validation = track.validate()
	assert(not validation.valid, "缺少流时验证应失败")
	assert(validation.issues.size() > 0, "应有错误信息")

	# 注意：这里暂时跳过需要实际音频文件的验证
	# 在实际测试中需要测试音频文件
	print("  ✓ Intro-Loop 验证测试通过")

func test_loop_variants():
	print("测试: Loop 变体")
	var track = MusicTrackResource.new()

	assert(not track.has_loop_variants(), "初始应无变体")
	assert(track.get_random_loop_variant() == track.loop_stream, "无变体时应返回 loop_stream")

	# 注意：这里暂时跳过需要实际音频文件的测试
	print("  ✓ Loop 变体测试通过")
