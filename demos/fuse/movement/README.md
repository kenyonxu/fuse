# Movement Demo 使用说明

## 场景创建

在 Godot 编辑器中创建 `movement_demo.tscn` 场景，结构如下：

```
MovementDemo (Node)
├── Player (CharacterBody2D)
│   ├── CollisionShape2D (Shape: RectangleShape2D)
│   │   └── Size: (32, 32)
│   └── Sprite2D
│       └── Modulate: Color(1, 0, 0) # 红色方块用于可视化
└── Camera2D
    └── Make Current: true
```

## Trigger 配置

在 Player 节点下添加 Trigger：

```
Player (CharacterBody2D)
└── Trigger
    ├── Event: OnInputActionComposite
    │   ├── action_up = "move_up"
    │   ├── action_down = "move_down"
    │   ├── action_left = "move_left"
    │   └── action_right = "move_right"
    └── ActionRunner
        └── MoveCharacterBody2DComposite
            ├── target_node = ..
            ├── speed = 200.0
            └── move_mode = DIRECT
```

## 测试

1. 运行项目中的 InputMap 配置脚本（`input_map_example.gd`）
2. 运行此场景
3. 使用 WASD 或方向键移动红色方块
