extends Node

## E3 渲染测试：_refresh_cross_references + _mode_label
##
## 直接构造 mock topology（不经 build_topology），验证 _refresh_cross_references
## 渲染写-读箭头 + 竞态预警（BBCode）。
const FuseTopology = preload("res://addons/fuse/editor/topology/fuse_topology.gd")

var _fail := 0
var _panel: FuseTopology = null


func _ready() -> void:
	_panel = FuseTopology.new()
	add_child(_panel)

	_test_render_write_to_read()
	_test_render_race_warning()
	_test_render_write_only_anomaly()
	_test_render_signal_no_regression()
	_test_mode_label()

	_panel.queue_free()
	print("\n=== 结果: %d 处失败 ===" % _fail)
	if _fail > 0:
		push_error("E3 渲染测试失败: %d 处" % _fail)
	get_tree().quit()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: ", msg)
	else:
		_fail += 1
		push_error("  FAIL: ", msg)


func _test_render_write_to_read() -> void:
	print("\n--- 渲染 variable_write_to_read（📝 + 写-读箭头）---")
	var topology := {
		"cross_references": [{
			"from": "T1", "from_mode": "write",
			"to": "T2", "to_mode": "read",
			"type": "variable_write_to_read",
			"detail": "global_hp"
		}],
		"variable_analysis": []
	}
	_panel._refresh_cross_references(topology)
	var text: String = _panel._cross_ref_label.text
	_check(text.contains("📝"), "含 📝 标记")
	_check(text.contains("T1 (写)"), "含 T1 (写)")
	_check(text.contains("→ [global_hp] →"), "含 → [global_hp] → 箭头")
	_check(text.contains("T2 (读)"), "含 T2 (读)")


func _test_render_race_warning() -> void:
	print("\n--- 渲染 variable_write_to_write（🔥 + 竞态 + BBCode 黄色）---")
	var topology := {
		"cross_references": [{
			"from": "T1", "from_mode": "write",
			"to": "T2", "to_mode": "write",
			"type": "variable_write_to_write",
			"detail": "global_score",
			"warning": true
		}],
		"variable_analysis": []
	}
	_panel._refresh_cross_references(topology)
	var text: String = _panel._cross_ref_label.text
	_check(text.contains("🔥"), "含 🔥 竞态标记")
	_check(text.contains("竞态"), "含 '竞态' 文字")
	_check(text.contains("[color=yellow]"), "含 [color=yellow] BBCode（RichTextLabel 期望解析）")
	_check(text.contains("global_score"), "含 global_score")


func _test_render_write_only_anomaly() -> void:
	print("\n--- 渲染 variable_analysis 孤写（📤 + 黄色 BBCode）---")
	var topology := {
		"cross_references": [],
		"variable_analysis": [{
			"name": "global_orphan",
			"writers": [{"trigger_name": "T1", "mode": "write"}],
			"readers": [],
			"anomaly": "write_only"
		}]
	}
	_panel._refresh_cross_references(topology)
	var text: String = _panel._cross_ref_label.text
	_check(text.contains("📤"), "含 📤 孤写标记")
	_check(text.contains("孤写"), "含 '孤写' 文字")
	_check(text.contains("global_orphan"), "含 global_orphan")
	_check(text.contains("[color=yellow]"), "含 [color=yellow] BBCode")


func _test_render_signal_no_regression() -> void:
	print("\n--- 渲染 signal 关联（回归：BBCode 不破坏）---")
	var topology := {
		"cross_references": [{
			"from": "T1", "to": "T2",
			"type": "signal", "detail": "on_player_died"
		}],
		"variable_analysis": []
	}
	_panel._refresh_cross_references(topology)
	var text: String = _panel._cross_ref_label.text
	_check(text.contains("🔗"), "含 🔗 信号标记")
	_check(text.contains("T1 → T2"), "含 T1 → T2")
	_check(text.contains("on_player_died"), "含 on_player_died")


func _test_mode_label() -> void:
	print("\n--- _mode_label 映射 ---")
	_check(FuseTopology._mode_label("write") == "写", "write → 写")
	_check(FuseTopology._mode_label("read") == "读", "read → 读")
	_check(FuseTopology._mode_label("read_write") == "读写", "read_write → 读写")
	_check(FuseTopology._mode_label("unknown") == "unknown", "未知 mode 原样返回")
