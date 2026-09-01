# Movement Integration Tests

移动系统集成测试，用于验证多玩家移动、对角线移动、输入系统等功能。

## 测试概述

这个集成测试套件验证以下功能：

1. **单玩家移动** - 验证基本的角色移动功能
2. **对角线移动** - 验证对角线移动和速度归一化
3. **多玩家移动** - 验证多个玩家可以独立控制
4. **移动模式** - 验证不同的移动模式配置（DIRECT, SMOOTH, ACCELERATION）
5. **输入系统** - 验证输入系统集成

## 场景创建

在 Godot 编辑器中创建 `test_movement_integration.tscn` 场景，结构如下：

```
TestMovementIntegration (Node)
├── Player1 (CharacterBody2D)
│   ├── CollisionShape2D
│   ├── Sprite2D (Modulate = Red, 以便区分)
│   └── Trigger (Node)
│       ├── OnInputActionComposite (Resource)
│       │   └── Actions: [ui_up=W, ui_down=S, ui_left=A, ui_right=D]
│       └── ActionRunner (Node)
│           └── MoveCharacterBody2DComposite (Instruction)
│               ├── target: ^..
│               ├── mode: SMOOTH (或 DIRECT/ACCELERATION)
│               ├── speed: 200.0
│               └── actions: [up=ui_up, down=ui_down, left=ui_left, right=ui_right]
│
├── Player2 (CharacterBody2D) [可选]
│   ├── CollisionShape2D
│   ├── Sprite2D (Modulate = Blue, 以便区分)
│   └── Trigger (Node)
│       ├── OnInputActionComposite (Resource)
│       │   └── Actions: [ui_up=ui_up, ui_down=ui_down, ui_left=ui_left, ui_right=ui_right]
│       └── ActionRunner (Node)
│           └── MoveCharacterBody2DComposite (Instruction)
│               ├── target: ^..
│               ├── mode: SMOOTH
│               ├── speed: 200.0
│               └── actions: [up=ui_up, down=ui_down, left=ui_left, right=ui_right]
│
└── TestController (Node)
    └── Script: test_movement_integration.gd
```

## 快速设置指南

### 方式 1：手动创建场景

1. 在 Godot 编辑器中，创建新场景
2. 添加根节点 `Node`，命名为 `TestMovementIntegration`
3. 创建 `Player1` 节点：
   - 添加 `CharacterBody2D` 节点，命名为 `Player1`
   - 添加 `CollisionShape2D` 子节点，创建 Shape（如 RectangleShape2D）
   - 添加 `Sprite2D` 子节点，设置 Modulate 为红色（以便区分）
   - 添加 `Trigger` 子节点（类型为 `Node`）
   - 在 Trigger 下添加 `OnInputActionComposite` 资源
   - 在 Trigger 下添加 `ActionRunner` 子节点
   - 在 ActionRunner 中添加 `MoveCharacterBody2DComposite` 指令
4. 重复步骤 3 创建 `Player2`（可选）
5. 在根节点下添加 `TestController` 节点，附加测试脚本

### 方式 2：使用现有测试场景

如果已经有工作的玩家移动场景，可以：

1. 复制现有场景
2. 重命名为 `test_movement_integration.tscn`
3. 添加 `TestController` 节点并附加测试脚本
4. 确保玩家节点命名为 `Player1` 和 `Player2`

## 运行测试

### 在编辑器中运行

1. 打开 `test_movement_integration.tscn` 场景
2. 按 **F5** 运行场景
3. 按照控制台提示操作：
   - 测试 1：按 `D` 或 `→` 键移动 Player1
   - 测试 2：同时按 `D` + `S` 进行对角线移动
   - 测试 3：使用 WASD 和方向键同时移动两个玩家
4. 查看控制台输出的测试结果

### 查看测试结果

测试结果会在控制台中显示，格式如下：

```
=== Movement Integration Test Started ===

[Test] Single Player Movement
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
→ Initial Position: (0, 0)
→ Press 'D' or 'Right Arrow' to move Player1
→ Test duration: 2 seconds

→ Final Position: (400, 0)
→ Movement Vector: (400, 0)
→ Distance: 400.00 pixels

✓ PASS: Single Player Movement
  → Player moved 400.00 pixels

==================================================
           MOVEMENT INTEGRATION TEST RESULTS
==================================================

Test Summary:
  Total Tests:  5
  Passed:       5
  Failed:       0
  Success Rate: 100.0%

Detailed Results:
────────────────────────────────────────────────────
✓ Single Player Movement       : Player moved 400.00 pixels
✓ Diagonal Movement            : Correct diagonal movement (ratio: 0.707)
✓ Multi-Player Movement        : Players moved independently
✓ Movement Modes               : Movement system configuration validated
✓ Input System                 : Input system properly configured

==================================================
```

## 测试场景配置

### OnInputActionComposite 资源配置

**Player1 (WASD 控制):**
```
actions = {
	"up": "ui_up",
	"down": "ui_down",
	"left": "ui_left",
	"right": "ui_right"
}

action_mappings = {
	"ui_up": ["W"],
	"ui_down": ["S"],
	"ui_left": ["A"],
	"ui_right": ["D"]
}
```

**Player2 (方向键控制):**
```
actions = {
	"up": "ui_up",
	"down": "ui_down",
	"left": "ui_left",
	"right": "ui_right"
}

# 使用默认的方向键映射（在项目设置中配置）
```

### MoveCharacterBody2DComposite 指令配置

**基本配置:**
```
target: NodePath("^..")  # 指向 CharacterBody2D 父节点
mode: enum { DIRECT, SMOOTH, ACCELERATION }
speed: 200.0
actions: Dictionary {
	"up": "ui_up",
	"down": "ui_down",
	"left": "ui_left",
	"right": "ui_right"
}
```

**移动模式说明:**

- **DIRECT**: 直接移动，无平滑
  - 立即达到最大速度
  - 适合精确控制

- **SMOOTH**: 平滑移动，使用线性插值
  - 逐渐加速和减速
  - 更自然的移动感
  - 对角线速度自动归一化

- **ACCELERATION**: 物理加速移动
  - 基于加速度和摩擦力
  - 最真实的移动感
  - 需要配置 acceleration 和 friction 参数

## 自定义测试

### 修改测试参数

可以在 `test_movement_integration.gd` 中修改以下参数：

```gdscript
# 测试持续时间
await get_tree().create_timer(2.0).timeout  # 改为其他值

# 移动距离阈值
if distance > 10:  # 调整灵敏度

# 对角线速度验证
if abs(speed_ratio - 0.707) < 0.2:  # 调整误差容忍度
```

### 添加新测试

在脚本中添加新的测试方法：

```gdscript
func _test_custom_feature():
	print("\n[Test] Custom Feature")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# 你的测试逻辑
	var result = your_test_function()

	if result:
		_record_test("Custom Feature", true, "Test passed")
		test_passed += 1
	else:
		_record_test("Custom Feature", false, "Test failed")
		test_failed += 1
```

然后在 `_ready()` 函数中调用：

```gdscript
func _ready():
	# ... 其他测试
	await get_tree().create_timer(2.0).timeout
	_test_custom_feature()  # 添加你的测试
	await get_tree().create_timer(2.0).timeout
	_print_test_results()
```

## 常见问题

### Q: 测试显示"Player node not found"

**A:** 确保场景中的玩家节点命名为 `Player1` 和 `Player2`，与脚本中的节点名称匹配。

### Q: 移动距离为 0

**A:**
1. 检查 `OnInputActionComposite` 事件是否正确配置
2. 确认输入映射在项目设置中正确配置
3. 验证 `MoveCharacterBody2DComposite` 指令的 target 路径正确

### Q: 对角线移动速度过快

**A:** 确保 `MoveCharacterBody2DComposite` 指令的 `mode` 设置为 `SMOOTH` 或 `ACCELERATION`，这些模式会自动归一化对角线速度。

### Q: 多玩家无法独立控制

**A:**
1. 确保每个玩家的 Trigger 节点是独立的
2. 检查输入映射不冲突（Player1 使用 WASD，Player2 使用方向键）
3. 验证每个玩家的 ActionRunner 独立配置

## 扩展阅读

- [MoveCharacterBody2DComposite 指令文档](../../docs/instructions/movement.md)
- [OnInputActionComposite 事件文档](../../docs/events/input.md)
- [Fuse 系统架构](../../docs/system/architecture.md)

## 贡献

如果你发现测试有问题或有改进建议，请：

1. 记录问题和复现步骤
2. 提供修复建议或代码
3. 提交 Pull Request 到项目仓库

## 版本历史

- **v1.0** (2026-02-08): 初始版本
  - 基本移动测试
  - 对角线移动验证
  - 多玩家支持
