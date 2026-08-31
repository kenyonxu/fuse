# addons/fuse/core/graduation/fuse_delegation.gd
class_name FuseDelegation
extends RefCounted

## 毕业导出器桥接面——生成脚本的唯一运行时依赖
##
## 五桥：指令（PresetValueCodec 重建 + ActionRunner 执行）/
## 变量（临时 ExecutionContext）/ 事件（FuseEventBus 透传）/
## 门控（自包含复刻 BaseTrigger 语义）/ 条件（重建 BaseCondition 后统一 check 入口）。
## 注意：ActionRunner.run 结束会 cleanup ctx——run() 每次新建 ctx，勿复用。

const PresetValueCodec := preload("res://addons/fuse/core/serialization/preset_value_codec.gd")

const COOLDOWN_NONE := 0
const COOLDOWN_GLOBAL := 1
const COOLDOWN_PER_OBJECT := 2
const SUBS_META := "fuse_delegated_subscriptions"

# run() 的保活集合：[ActionRunner, _TerminalRelay] 对，终态时由 _release 移除
static var _active_pairs: Array = []


## 从 preset JSON 字典重建委托指令绑定（键 -> Array[BaseInstruction]）
static func build_delegated(bindings_json: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in bindings_json:
		out[key] = PresetValueCodec.deserialize_instructions(bindings_json[key])
	return out


## 执行一段委托指令序列（协程，可 await）。
## 每次新建 ExecutionContext 并同步 event_<key> 局部变量；
## execution_mode：0=SEQUENTIAL / 1=PARALLEL（ActionRunner.ExecutionMode）。
##
## 实现注记：Godot 4.7 中 static 函数内直接 await 实例协程存在恢复时序缺陷
## （实测 await 提前返回、Wait 时长不受尊重），且 GDScript 的 await 不支持
## 信号数组、协程返回值必须经 await 读取——故本函数自身不含 await：
## 经 call_deferred 启动内部 ActionRunner，返回终态转发信号（done），
## 调用方 `await FuseDelegation.run(...)` 即等执行结束（完成/失败/取消任一）。
## deferred 启动保证信号 emit 必然晚于调用方的 await 注册（同帧安全）。
static func run(node: Node, instructions: Array, execution_mode: int, event_args: Dictionary = {}) -> Variant:
	if instructions.is_empty():
		return null  # await null 立即继续（空序列无需等待）
	var ctx := ExecutionContext.new(node)
	ctx.set_variable("event_source", node)
	ctx.set_variable("triggered_node", node)
	for key: Variant in event_args:
		ctx.set_variable("event_%s" % key, event_args[key])
	var runner := ActionRunner.new()
	runner.execution_mode = execution_mode
	# 传入的 instructions 是无类型 Array（Dictionary 取值为 Variant），经 assign 转换后才能赋给类型化数组
	var typed_instructions: Array[BaseInstruction] = []
	typed_instructions.assign(instructions)
	runner.instructions = typed_instructions
	var relay := _TerminalRelay.new(runner)
	# call_deferred / 信号连接对 RefCounted 均为弱引用，必须静态保活至终态，
	# 否则 run() 返回后 runner/relay 即被 GC，deferred 执行与 await 连接都会失效
	_active_pairs.append([runner, relay])
	runner.call_deferred("run", ctx)
	return relay.done


## run() 的终态释放（内部使用）：从保活集合移除 [runner, relay] 对
static func _release(runner: ActionRunner) -> void:
	for i: int in range(_active_pairs.size()):
		if _active_pairs[i][0] == runner:
			_active_pairs.remove_at(i)
			return


## 终态信号转发（内部类，勿外部使用）
##
## 把 ActionRunner 的三个终态信号（完成/失败/取消）合并为单一 done 信号，
## 供 run() 的调用方 await——避免失败/取消路径下 await 挂死。
class _TerminalRelay:
	signal done()

	var _runner: ActionRunner

	func _init(runner: ActionRunner) -> void:
		_runner = runner
		runner.execution_completed.connect(_emit_done)
		runner.execution_failed.connect(_emit_done)
		runner.execution_canceled.connect(_emit_done)

	func _emit_done(_arg: Variant = null) -> void:
		done.emit()
		FuseDelegation._release(_runner)


## 读变量（经临时 ctx；scope ∈ "local"/"scope"/"global"）
static func get_var(node: Node, name: String, scope: String) -> Variant:
	return ExecutionContext.new(node).get_variable(name, null, scope)


## 写变量（经临时 ctx；global 变量不存在时自动创建）
static func set_var(node: Node, name: String, value: Variant, scope: String) -> bool:
	return ExecutionContext.new(node).set_variable(name, value, scope)


## 从 preset JSON 重建条件并以其统一入口 check() 检查（经临时 ctx）。
## node 兼任 target 与 trigger：BaseCondition.check 的 scope 变量 NEAREST 搜索
## 依赖 context.trigger 向上查找 ScopeVariableContainer，双参构造对齐真实
## Trigger 运行时语义。重建失败（未知类型等）返回 false，不中断生成脚本。
static func check_condition(node: Node, cond_json: Dictionary) -> bool:
	var cond: BaseCondition = PresetValueCodec.deserialize_condition(cond_json)
	if cond == null:
		push_warning("[FuseDelegation] 条件重建失败: %s" % str(cond_json.get("type", "?")))
		return false
	var ctx := ExecutionContext.new(node, node)
	return cond.check(ctx)


## 取事件总线 autoload（缺失时 push_warning 并返回 null；所有桥统一走此入口，勿直接引用 autoload 名）
static func _bus() -> Node:
	var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
	if bus == null:
		push_warning("[FuseDelegation] FuseEventBus autoload 不存在，事件桥不可用")
	return bus


## 发送总线事件
static func send_event(event_name: String, args: Dictionary = {}) -> void:
	var bus: Node = _bus()
	if bus != null:
		bus.send_event(event_name, args)


## 订阅总线事件（回调收 args: Dictionary）；总线缺失返回 null
static func subscribe(event_name: String, cb: Callable) -> Variant:
	var bus: Node = _bus()
	if bus == null:
		return null
	return bus.subscribe(event_name, cb)


## 退订（subscription 由生成代码持有；null 安全）
static func unsubscribe(subscription: Variant) -> void:
	var bus: Node = _bus()
	if bus != null and subscription != null:
		bus.unsubscribe(subscription)


## 门控（检查并更新）：复刻 BaseTrigger._check_cooldown + trigger_once 语义。
## state 由生成脚本持有（成员 Dictionary）；key 为触发器绑定键。
## trigger_once 已触发 -> false；GLOBAL/PER_OBJECT 冷却未到 -> false；
## 放行则记录时间戳与 once 标记。时间源 Time.get_ticks_msec()/1000.0。
static func gate_allows(state: Dictionary, key: String, trigger_once: bool,
		cooldown_mode: int, cooldown_time: float, object_id: int) -> bool:
	var once_key := "%s:once" % key
	if trigger_once and state.get(once_key, false):
		return false
	if cooldown_mode != COOLDOWN_NONE and cooldown_time > 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		match cooldown_mode:
			COOLDOWN_GLOBAL:
				var last: float = state.get("%s:last" % key, -1e9)
				if now - last < cooldown_time:
					return false
				state["%s:last" % key] = now
			COOLDOWN_PER_OBJECT:
				var per: Dictionary = state.get("%s:objects" % key, {})
				var last_o: float = per.get(object_id, -1e9)
				if now - last_o < cooldown_time:
					return false
				per[object_id] = now
				state["%s:objects" % key] = per
	state[once_key] = true
	return true


## 清理 node 上的委托订阅 meta。
## 订阅本体由生成代码持有 Subscription 并在 _exit_tree 自行退订（对齐 OnReceiveEvent terminate 语义）；
## 此处仅清预留 meta 挂点。
static func teardown(node: Node) -> void:
	if node.has_meta(SUBS_META):
		node.remove_meta(SUBS_META)
