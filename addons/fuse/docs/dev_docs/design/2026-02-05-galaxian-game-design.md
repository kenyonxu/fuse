# Galaxian 游戏设计方案（使用 Fuse 插件）

**创建日期：** 2026-02-05
**复杂度：** 极简版
**视觉风格：** 占位符素材
**数据持久化：** 本地最高分记录
**交互方式：** 键盘控制

---

## 1. 整体架构与场景结构

### 三个主要场景

#### 1.1 title_screen.tscn - 标题界面
- 显示游戏标题 "GALAXIAN"
- 显示最高分记录
- "开始游戏" 和 "退出" 按钮（可通过键盘选择）

#### 1.2 game_level.tscn - 游戏主场景
- 玩家飞船（底部左右移动）
- 敌人编队（顶部左右移动 + 俯冲攻击）
- 子弹系统（玩家和敌人）
- HUD（分数、生命值、关卡）

#### 1.3 result_screen.tscn - 结算界面
- 显示本局得分
- 显示最高分（如有新纪录）
- "再玩一次" / "返回标题" 选项

### 数据流设计
- **GlobalVariableManager** 存储跨场景数据（当前分数、最高分、关卡进度）
- **Fuse Trigger + Event** 处理所有游戏逻辑（碰撞检测、输入响应、状态变化）
- **场景切换** 使用 Fuse 的 ChangeScene 指令

### 技术特点
- 所有游戏逻辑通过 Fuse 可视化脚本实现，无需编写 GDScript 代码
- 充分展示 Fuse 的事件驱动架构（OnCollision、OnInput、OnVariableChanged）

---

## 2. 游戏核心机制与 Fuse 组件配置

### 2.1 玩家飞船控制

**移动：**
- **事件：** `OnInputAction` - 监听 "ui_left" 和 "ui_right" 输入
- **指令：** `MoveBy` - 根据输入持续移动飞船
- **约束：** 使用 `ClampValue` 限制飞船在屏幕范围内
- **配置：** 移动速度 = 300 像素/秒

**射击：**
- **事件：** `OnInputAction` - 监听 "ui_accept"（空格键）
- **指令：** `InstantiateScene` - 生成子弹场景
- **指令：** `SetVelocity` - 给子弹施加向上速度
- **指令：** `PlaySound` - 播放射击音效
- **冷却：** 使用 `OnCooldownFinished` 事件限制射速（0.3秒间隔）

### 2.2 敌人编队行为

**编队整体移动：**
- **事件：** `OnPhysicsProcess` - 持续更新编队位置
- **逻辑：**
  - 使用 `SetPosition` 让整个编队左右平移
  - 当到达屏幕边缘时，使用 `SetPropertyValue` 改变移动方向
  - 移动速度 = 100 像素/秒，方向通过全局变量 `enemy_direction` 控制（1 或 -1）

**敌人俯冲攻击：**
- **事件：** `OnCountdown` - 每 2-3 秒触发一次
- **条件检查：** 使用 `IfElse` + 随机数判断（30%概率）
- **指令：** 随机选择一个未俯冲的敌人
- **俯冲行为：**
  - 设置敌人状态为 `is_diving = true`
  - 使用 `SetVelocity` 向下俯冲（速度 = 200 像素/秒）
  - 同时保留左右分量，形成斜向移动
- **俯冲结束：**
  - **事件：** `OnScreenExited` - 俯冲的敌人离开屏幕后
  - **指令：** `QueueFreeNode` - 销毁敌人

**状态管理：**
- 使用全局变量 `diving_enemies: Array` 跟踪正在俯冲的敌人
- 使用 `SetVariable` 和 `GetVariable` 管理每个敌人的状态

### 2.3 碰撞检测系统

**事件：** `OnBodyEntered`（Area2D）

**碰撞类型：**
1. **子弹击中敌人：**
   - 敌人销毁
   - 分数 +100
   - 播放爆炸特效
   - 播放音效

2. **敌人撞击玩家：**
   - 玩家生命 -1
   - 屏幕震动
   - 播放受伤音效

3. **敌人到达底部：**
   - 玩家生命 -1

---

## 3. 场景切换与游戏状态管理

### 3.1 Title Screen → Game Level

**事件：** `OnButtonPressed`（或 `OnInputAction` 监听 Enter 键）

**指令序列：**
1. `CreateVariable` - 初始化本局变量（score=0, lives=3, level=1）
2. `SetUIProgress` - 更新 UI 生命值显示
3. `SetUIText` - 重置分数显示
4. `PlayMusic` - 播放游戏背景音乐
5. `ChangeScene` - 切换到 game_level.tscn

### 3.2 Game Level → Result Screen

**事件：** `OnVariableChanged`（监听 lives 变量）

**条件：** 使用 `IfElse` 检查 `lives <= 0`

**指令序列：**
1. `PauseGame` - 暂停游戏
2. `Wait` - 延迟 1 秒
3. `PlaySound` - 播放游戏结束音效
4. `MathOperation` (Subtract) - current_score - highscore → diff
5. `IfElse` (diff > 0) - 检查是否打破最高分记录
   - `SetVariable` - highscore = current_score
   - `PlaySound` - 播放新纪录音效
   - `TweenShakeAnimation` - UI 震动特效
6. `ChangeScene` - 切换到 result_screen.tscn

### 3.3 Result Screen 操作

**再玩一次：**
- 重新初始化变量（score=0, lives=3）
- 直接切换回 game_level.tscn

**返回标题：**
- 切换到 title_screen.tscn
- 使用 `LoadFromDict` 从 GlobalVariableManager 恢复 highscore

### 3.4 全局数据持久化

使用 `GlobalVariableManager` 存储：
- `highscore: int` - 最高分（跨场景保持）
- `current_score: int` - 当前分数
- `player_lives: int` - 玩家生命
- `current_level: int` - 当前关卡

---

## 4. 需要新增的 Fuse 组件

### 4.1 事件：`OnGroupEmpty`

**用途：** 当指定组的成员数量变为0时触发

**参数：**
- `group_name: StringName` - 要监听的组名
- `check_interval: float` - 检查间隔（默认0.1秒）

**通用场景：**
- 所有敌人被消灭 → 触发下一关
- 所有道具被收集
- 所有障碍物被清除

**实现位置：** `addons/fuse/events/node/on_group_empty.gd`

### 4.2 最高分更新 - 使用现有组件组合

不添加新组件，使用现有指令组合：

```
事件：OnVariableChanged (lives <= 0)
指令序列：
├── MathOperation (Subtract) - current_score - highscore → diff
├── IfElse (diff > 0)
│   ├── SetVariable - highscore = current_score
│   ├── PlaySound - "new_record" 音效
│   └── TweenShakeAnimation - UI 震动特效
└── ChangeScene - result_screen.tscn
```

---

## 5. 使用 Fuse 自身的反馈系统

### 5.1 反馈效果对照表

| 效果类型 | Fuse 指令 | 应用场景 |
|---------|------------|---------|
| **音效** | `PlaySound` | 射击、爆炸、游戏结束 |
| **音乐** | `PlayMusic` | 背景音乐、标题音乐 |
| **UI动画** | `TweenShakeAnimation` | 受伤、新纪录、按钮悬停 |
| **UI动画** | `TweenBounceAnimation` | 敌人被消灭、得分弹出 |
| **UI动画** | `TweenFadeIn/FadeOut` | 场景切换过渡 |
| **UI动画** | `TweenScaleTo` | 按钮点击反馈 |
| **相机** | `CameraShake` | 玩家受伤、爆炸 |
| **UI显示** | `ShowHideUI` | 游戏暂停、显示提示 |
| **文本更新** | `SetUIText` | 实时分数显示 |

### 5.2 敌人销毁反馈流程示例

```
事件：OnBodyEntered (子弹击中敌人)
指令序列：
├── QueueFreeNode - 销毁敌人
├── QueueFreeNode - 销毁子弹
├── SetVariable - score += 100
├── SetUIText - 更新分数显示
├── PlaySound - "explosion"
├── InstantiateScene - 生成爆炸粒子效果
├── CameraShake - 强度 10, 持续 0.2秒
└── TweenBounceAnimation - 分数数字跳动
```

---

## 6. 场景树结构

### 6.1 game_level.tscn 结构

```
GameLevel (Node2D)
├── Player (Area2D) + Sprite + CollisionShape2D
│   └── Trigger (Trigger)
│       ├── Event: OnInputAction (移动)
│       └── Event: OnInputAction (射击)
│
├── EnemyFormation (Node2D)
│   ├── Enemy1 (Area2D) + Sprite + CollisionShape2D
│   │   └── Trigger (Event: OnPhysicsProcess)
│   ├── Enemy2...Enemy15
│   └── Trigger (Event: OnCountdown - 触发俯冲)
│
├── Bullets (Node)
│   └── Group: "bullets"
│
├── HUD (CanvasLayer)
│   ├── ScoreLabel (Label)
│   ├── LivesLabel (Label)
│   └── HighscoreLabel (Label)
│
└── Background (ColorRect)
```

### 6.2 title_screen.tscn 结构

```
TitleScreen (Node2D)
├── Background (ColorRect)
├── TitleLabel (Label) - "GALAXIAN"
├── HighscoreLabel (Label)
├── StartButton (Button)
│   └── Trigger (Event: OnButtonPressed / OnInputAction)
└── QuitButton (Button)
	└── Trigger (Event: OnButtonPressed / OnInputAction)
```

### 6.3 result_screen.tscn 结构

```
ResultScreen (Node2D)
├── Background (ColorRect)
├── ScoreLabel (Label)
├── HighscoreLabel (Label)
├── NewRecordLabel (Label) - 默认隐藏
├── PlayAgainButton (Button)
│   └── Trigger (Event: OnButtonPressed)
└── BackToTitleButton (Button)
	└── Trigger (Event: OnButtonPressed)
```

---

## 7. 开发里程碑

### 阶段 1：基础场景结构
- [ ] 创建 3 个空场景文件
- [ ] 搭建基础场景树结构
- [ ] 创建占位符素材（Sprite）

### 阶段 2：玩家控制
- [ ] 实现玩家飞船左右移动
- [ ] 实现射击功能
- [ ] 添加射击冷却
- [ ] 添加移动范围限制

### 阶段 3：敌人编队
- [ ] 创建敌人编队（5x3 网格）
- [ ] 实现编队左右移动
- [ ] 实现敌人俯冲攻击
- [ ] 实现俯冲敌人状态管理

### 阶段 4：碰撞与分数
- [ ] 实现子弹击中敌人
- [ ] 实现敌人撞击玩家
- [ ] 实现分数计算
- [ ] 实现 UI 实时更新

### 阶段 5：场景切换
- [ ] 实现 Title → Game 切换
- [ ] 实现 Game → Result 切换
- [ ] 实现 Result → Game/Title 切换
- [ ] 实现全局变量管理

### 阶段 6：反馈效果
- [ ] 添加音效（射击、爆炸、游戏结束）
- [ ] 添加背景音乐
- [ ] 添加 UI 动画（震动、弹跳）
- [ ] 添加相机震动

### 阶段 7：新增组件开发
- [ ] 实现 `OnGroupEmpty` 事件
- [ ] 测试新组件功能
- [ ] 更新文档

---

## 8. 技术约束与注意事项

### 8.1 不使用 JuicyMixer
- 所有反馈效果使用 Fuse 自身指令实现
- 音频使用 Fuse 的 `PlaySound` 和 `PlayMusic`
- 动画使用 Fuse 的 Tween 指令
- 震动使用 Fuse 的 `CameraShake`

### 8.2 使用现有 Fuse 组件
优先使用已有的 Fuse 指令和事件，仅添加：
- `OnGroupEmpty` 事件（无法用现有组件实现）

### 8.3 占位符素材
- 使用简单的 ColorRect 和基础几何图形
- 支持后期资源热重载替换

---

## 9. 参考资源

- **Fuse 文档：** `addons/fuse/docs/`
- **现有事件列表：** `addons/fuse/events/`
- **现有指令列表：** `addons/fuse/instructions/`
- **演示场景：** `demos/brick_debug.tscn`

---

**设计完成日期：** 2026-02-05
**预计开发周期：** 7 个阶段
**Godot 版本：** 4.6
