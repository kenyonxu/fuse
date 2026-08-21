# addons/fuse/editor/preset_ai/eval_runner_cli.gd
extends Node

## Eval runner CLI 入口（Task 9）
## 用法: godot --headless --path . res://addons/fuse/editor/preset_ai/eval_runner.tscn \
##        -- --workspace <dir> --iteration <name> [--report <dir>] [--live]
## 退出码：0 = 无回归；1 = 有回归（baseline 应过实败）；2 = 参数错误
## 产物失败但基线未要求过 → 0（允许「飘红但不回归」的状态存在于早期）

const EvalRunner := preload("res://addons/fuse/editor/preset_ai/eval_runner.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var workspace := ""
	var iteration := ""
	var report := ""
	var live := false
	var i := 0
	while i < args.size():
		match args[i]:
			"--workspace":
				i += 1
				if i < args.size():
					workspace = args[i]
			"--iteration":
				i += 1
				if i < args.size():
					iteration = args[i]
			"--report":
				i += 1
				if i < args.size():
					report = args[i]
			"--live":
				live = true
			"--":
				pass
		i += 1
	if workspace == "" or iteration == "":
		printerr("用法: eval_runner.tscn -- --workspace <dir> --iteration <name> [--report <dir>] [--live]")
		get_tree().quit(2)
		return
	var result: Dictionary
	if live:
		result = await EvalRunner.run_live(workspace, iteration, report)  # Task 12
	else:
		result = EvalRunner.run_replay(workspace, iteration, report)
	print("summary: %s" % JSON.stringify(result.summary))
	for r in result.regressions:
		printerr("REGRESSION: %s / %s" % [r["case"], r["path"]])
	get_tree().quit(1 if result.summary.regressions > 0 else 0)
