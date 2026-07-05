# 预设系统（Preset / Template System）

## 状态

提案

## 动机

很多游戏逻辑是重复模式——角色跳跃、敌人巡逻、UI 弹窗、拾取物品……每次新项目或新场景都要从零搭一遍。用户无法保存和复用自己配置好的逻辑。缺少可复用预设是当前最大的体验痛点之一。

## 核心设计

让用户把一组已配置好的 Trigger/Runner + Instructions 打包为**预设（Preset）**，在项目内复用，或导出为文件分享。

### 预设粒度

**A. 逻辑模板（Logic Template）** — 单个 Trigger 或 Runner 的完整配置

```
# 例：角色二段跳模板
Template: DoubleJump
├── Event: OnInputKey (Space)
├── Condition: CheckVariable (jump_count < 2)
├── Condition: CheckOnFloor OR CheckVariable (coyote_time > 0)
└── Instructions:
    ├── SetVariable (jump_count += 1)
    ├── ApplyImpulse (Y: -jump_force)
    ├── TweenScaleTo (squash: 0.8, duration: 0.1)
    └── PlaySound (jump_sfx)
```

**B. 行为包（Behavior Pack）** — 多个协作的 Trigger/Runner + 变量定义

```
# 例：巡逻敌人行为包
BehaviorPack: PatrolEnemy
├── Variables: {speed: 200, detection_range: 150}
├── Trigger: PatrolController
│   ├── Event: OnTimer (interval: 2s)
│   ├── Instructions: [SetDirection, MoveBy, FlipSprite]
│   └── Conditions: [CheckOnFloor, CheckOnWall]
├── Trigger: PlayerDetection
│   ├── Event: OnBodyEntered (detection_area)
│   └── Instructions: [ChasePlayer, PlaySound]
└── Runner: DeathHandler
    └── Instructions: [TweenFadeOut, QueueFree, DropLoot]
```

### 用户体验

1. **保存：** 编辑器中选中 Trigger → 右键 "Save as Template" → 命名+描述 → 保存到预设库
2. **浏览：** 预设库面板，按分类浏览和搜索
3. **应用：** 拖拽预设到场景节点上 → 自动创建对应的 Trigger/Runner 节点并配置好所有属性
4. **分享：** 导出为 `.brickpreset` 文件（JSON 格式）

### 预设库面板

```
┌─ Fuse Presets ─────────────┐
│ 🔍 Search...                 │
│                              │
│ ▸ Movement                   │
│   ▸ DoubleJump               │
│   ▸ Dash                     │
│   ▸ WallSlide                │
│ ▸ Combat                     │
│   ▸ MeleeAttack              │
│   ▸ Projectile               │
│ ▸ UI                         │
│   ▸ FadePopup                │
│   ▸ HealthBar               │
│                              │
│ [Import...] [Export All...]  │
└──────────────────────────────┘
```

### 技术方案

- 预设序列化为 `.brickpreset` 文件（JSON），包含所有 Resource 配置
- 预设库存储路径：`res://fuse_presets/`
- 应用预设时：反序列化 → 创建节点树 → 配置属性
- 支持参数映射：预设中的 `jump_force` 等值在应用时可重新指定

## 交付计划

### V1 - 基础预设

- [ ] 预设序列化/反序列化（.brickpreset JSON 格式）
- [ ] 右键菜单 "Save as Template"
- [ ] 预设库面板（分类浏览 + 搜索）
- [ ] 拖拽应用到场景节点
- [ ] 导入/导出功能

### V2 - 行为包与分享

- [ ] 行为包（多 Trigger/Runner + 变量定义打包）
- [ ] 参数映射（应用时替换预设中的占位值）
- [ ] 预设版本管理
- [ ] Asset Library / GitHub 分享集成
