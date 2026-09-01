# 文件：addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/object_pool.gd
## 对象池——Fuse WarmUpPool 所依赖池系统的脱离替代参考实现
##
## 对齐 WarmUpPool 的参数语义（preset 中的配置可直译到同名 @export）：
##   warm_up_mode  IMMEDIATE 一次性预热 / BATCH 按 batch_size 分批、批间 batch_delay 秒
##   warm_up_count 预热实例总数；pool_initial_size / pool_max_size 池容量上下限
## 用法：作为节点 add_child 后调用 warm_up()；取用 acquire()，归还 release(node)。
## 注意：池中实例不在场景树内——acquire() 取出后需自行 add_child 才会渲染/参与场景。
extends Node

enum WarmUpMode { IMMEDIATE, BATCH }

@export var scene_path: String = ""
@export var pool_initial_size: int = 10  ## 初始池规模下限（与 warm_up_count 取大者为预热目标）
@export var pool_max_size: int = 100
@export var warm_up_count: int = 10
@export var warm_up_mode: WarmUpMode = WarmUpMode.IMMEDIATE
@export var batch_size: int = 5
@export var batch_delay: float = 0.1

var _pool: Array[Node] = []
var _created: int = 0


## 预热：IMMEDIATE 一帧内完成；BATCH 分批进行（await，可异步等待）
func warm_up() -> void:
	if scene_path.is_empty():
		push_warning("[object_pool] scene_path 为空，跳过预热")
		return
	var remaining := maxi(warm_up_count, pool_initial_size)
	while remaining > 0:
		var n: int = mini(batch_size, remaining) if warm_up_mode == WarmUpMode.BATCH else remaining
		for i in n:
			# 池已达上限：继续预热只会产生不入池的孤儿实例，直接结束
			if _pool.size() >= pool_max_size:
				return
			var node := _create_instance()
			if node == null:
				continue
			if _pool.size() < pool_max_size:
				_pool.append(node)
				node.set_process(false)
				if node is CanvasItem:
					node.hide()
		remaining -= n
		if warm_up_mode == WarmUpMode.BATCH and remaining > 0:
			await get_tree().create_timer(batch_delay).timeout


## 从池中取一个实例（池空且未达上限则新建；达上限返回 null）
func acquire() -> Node:
	while not _pool.is_empty():
		var node: Node = _pool.pop_back()
		if is_instance_valid(node):
			node.set_process(true)
			if node is CanvasItem:
				node.show()
			return node
	if _created < pool_max_size:
		var node := _create_instance()
		if node != null:
			node.set_process(true)
			if node is CanvasItem:
				node.show()
		return node
	push_warning("[object_pool] 池已达上限 %d，acquire 返回 null" % pool_max_size)
	return null


## 归还实例（隐藏并回池；池满则 queue_free）
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_process(false)
	if node is CanvasItem:
		node.hide()
	if _pool.size() < pool_max_size:
		_pool.append(node)
	else:
		node.queue_free()


## 创建一个新实例（不入池、不隐藏；调用方负责生命周期）
func _create_instance() -> Node:
	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_error("[object_pool] 无法加载场景: %s" % scene_path)
		return null
	var node := scene.instantiate()
	_created += 1
	return node
