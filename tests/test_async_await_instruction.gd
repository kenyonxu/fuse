extends BaseInstruction
class_name TestAsyncAwaitInstruction

## 测试用异步指令 - 包含 await

func _update_resource_name():
	resource_name = "TestAsyncAwait"

func _setup_metadata():
	metadata.name = "TestAsyncAwait"
	metadata.description = "测试异步指令"

func execute(context: ExecutionContext):
	_start_execution(context)
	# 这个指令会在测试场景中被实际执行
	# 注意：这里使用 context 的 tree，因为在 Resource 中不能直接调用 get_tree()
	if context and context.tree:
		await context.tree.process_frame
	_on_execution_completed()
