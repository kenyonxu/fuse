## FuseNodeUtils 缓存测试脚本
##
## 使用方法：
## 1. 在编辑器中打开任意包含 Trigger 的场景
## 2. 创建一个 Node，附加此脚本
## 3. 运行场景或按 F6 运行当前场景
## 4. 查看控制台输出，观察缓存命中情况

extends Node

func _ready():
	print("\n")
	print("=".repeat(60))
	print("FuseNodeUtils 缓存测试")
	print("=".repeat(60))

	# 获取当前场景根节点
	var root = get_tree().current_scene
	if not root:
		print("❌ 无法获取当前场景根节点")
		return

	print("✅ 场景根节点: ", root.name)

	# 打印初始缓存统计
	print("\n--- 初始缓存统计 ---")
	FuseNodeUtils.print_cache_stats()

	# 测试 1: 多次查找同一个节点（应该命中缓存）
	print("\n--- 测试 1: 重复查找同一节点 ---")
	var test_path = NodePath("../../TitleHint/HintBreath")

	print("第 1 次查找...")
	var node1 = FuseNodeUtils.find_node_by_relative_path(root, test_path)
	if node1:
		print("✅ 找到节点: ", node1.name)
	else:
		print("❌ 未找到节点")

	print("第 2 次查找（应该命中缓存）...")
	var node2 = FuseNodeUtils.find_node_by_relative_path(root, test_path)
	if node2:
		print("✅ 找到节点: ", node2.name)
	else:
		print("❌ 未找到节点")

	print("第 3 次查找（应该命中缓存）...")
	var node3 = FuseNodeUtils.find_node_by_relative_path(root, test_path)
	if node3:
		print("✅ 找到节点: ", node3.name)
	else:
		print("❌ 未找到节点")

	# 打印缓存统计
	print("\n--- 测试 1 后的缓存统计 ---")
	FuseNodeUtils.print_cache_stats()

	# 测试 2: 查找不同节点（应该未命中）
	print("\n--- 测试 2: 查找不同节点 ---")
	var test_path2 = NodePath("../../Title")

	print("查找节点: ", str(test_path2))
	var node4 = FuseNodeUtils.find_node_by_relative_path(root, test_path2)
	if node4:
		print("✅ 找到节点: ", node4.name)
	else:
		print("❌ 未找到节点")

	# 打印缓存统计
	print("\n--- 测试 2 后的缓存统计 ---")
	FuseNodeUtils.print_cache_stats()

	# 测试 3: 清除缓存后再次查找
	print("\n--- 测试 3: 清除缓存后查找 ---")
	print("清除所有缓存...")
	FuseNodeUtils.clear_all_cache()

	print("再次查找节点（应该未命中）...")
	var node5 = FuseNodeUtils.find_node_by_relative_path(root, test_path)
	if node5:
		print("✅ 找到节点: ", node5.name)
	else:
		print("❌ 未找到节点")

	# 打印最终缓存统计
	print("\n--- 最终缓存统计 ---")
	FuseNodeUtils.print_cache_stats()

	print("\n" + "=".repeat(60))
	print("测试完成")
	print("=".repeat(60))
