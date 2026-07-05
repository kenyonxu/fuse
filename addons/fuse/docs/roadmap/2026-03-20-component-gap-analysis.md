# Fuse 组件缺口分析

**创建日期:** 2026-03-20
**范围:** 2D/3D 动作游戏、RPG 游戏开发
**用户定位:** 初学者 + 独立开发者兼顾
**策略:** 填平现有分类缺口 + 增加新分类

---

## 现状

| 类型 | 数量 | 分类数 |
|------|------|--------|
| 指令 | 129 | 23 |
| 事件 | 65 | 14 |
| 条件 | 43 | 14 |

## 分析方法

基于实际游戏开发场景（2D/3D 动作游戏、RPG），识别现有组件中阻碍常见游戏模式的缺口，以及需要新增的分类。

---

## 一、现有分类缺口

### 物理（当前 5 指令，缺口较大）

**缺失指令：**
- `SetGravityScale` — 修改重力倍率（低重力区域、跳跃手感调整）
- `SetGravityDirection` — 旋转重力（平台游戏高级机制）
- `GroundSnap` — 强制贴地（防止斜坡离开地面）
- `SetCollisionMask` — 动态切换碰撞层（穿墙、隐藏敌人）
- `EnableDisableCollision` — 临时关闭/开启碰撞（无敌帧、闪避）

**缺失条件：**
- `CheckOverlapArea` — 检测区域内是否有特定碰撞体
- `CheckSlope` — 检测斜坡角度

**缺失事件：**
- `OnOverlapArea` — Area 对 Area 的进入/离开检测
- `OnGroundStateChanged` — 地面状态切换（落地/离地）

### 动画（当前 4 指令 / 6 事件 / 4 条件，缺口中等）

**缺失指令：**
- `SetAnimationTreeParameter` — 通用动画树参数设置（角色状态驱动核心）
- `SetAnimationBlendPosition` — 控制 Blend Space 位置
- `SetSpriteFrame` — 直接设置 Sprite2D 帧
- `SetSpriteFlip` — 翻转精灵（2D 基本操作）

**缺失条件：**
- `CheckAnimationTreeParameter` — 检查动画树参数值
- `CheckSpriteFrame` — 当前帧是否为指定帧

### UI（当前 4 指令 / 5 事件，缺口较大）

**缺失指令：**
- `AddRemoveUIChild` — 动态添加/移除 UI 子节点
- `SetUIColor` — 修改 UI 颜色
- `TweenUIValue` — UI 数值渐变
- `SetUIStylebox` — 修改样式
- `DuplicateUINode` — 克隆 UI 节点

**缺失事件：**
- `OnUIMouseEntered` / `OnUIMouseExited` — 悬停（tooltip）
- `OnUIDragStarted` / `OnUIDragEnded` — 拖拽
- `OnUIModalShown` / `OnUIModalHidden` — 弹窗

**缺失条件：**
- `CheckUIVisible` — UI 是否可见
- `CheckUIMouseHovering` — 鼠标是否悬停在 UI 上

### Tween（当前 14 指令 / 1 事件）

**缺失指令：**
- `TweenPause` / `TweenResume` — 暂停/继续 tween
- `TweenKillAll` / `TweenKillByGroup` — 批量取消 tween

### 变量（当前 9 指令）

**缺失指令：**
- `AddVariable` — 变量自增/自减
- `ToggleVariable` — 布尔切换
- `SwapVariables` — 交换两个变量

### 相机（当前 4 指令）

**缺失指令：**
- `CameraFadeIn` / `CameraFadeOut` — 淡入淡出
- `SetCameraOffset` — 镜头偏移

### 音频（当前 7 指令 / 5 事件，缺口较小）

**缺失指令：**
- `PlaySoundAtPosition` — 在指定位置播放音效
- `SetAudioPitch` — 修改音调

### 变换（当前 7 指令）

**缺失指令：**
- `SetGlobalPosition` / `SetGlobalRotation` — 全局变换

---

## 二、新增分类

### 1. 字符串操作（String）— RPG 必备

**指令：**
- `StringFormat` — 格式化字符串（`"HP: {hp}/{max_hp}"`）
- `StringSplit` / `StringJoin` — 分割/合并
- `StringContains` / `StringReplace` — 查找/替换
- `StringLength` — 获取长度

**条件：**
- `CheckStringContains` — 是否包含子串
- `CheckStringLength` — 长度比较

### 2. 渲染/视觉控制（Rendering）— 视觉效果核心

**指令：**
- `SetMaterialProperty` — 修改材质/着色器参数
- `SetSpriteFlip` — 翻转精灵（H/V）
- `SetZIndex` / `SetZAsRelative` — 渲染层级
- `ControlParticles` — 启动/停止 GPUParticles
- `SetLight` — 控制 Light2D/3D
- `ScreenFlash` — 全屏闪烁效果

**条件：**
- `CheckIsOnScreen` — 节点是否在视口内
- `CheckNodeVisible` — 节点可见性

### 3. 导航/寻路（Navigation）— AI 必备

**指令：**
- `NavigateToPosition` — NavigationAgent 移动到目标点
- `NavigateToTarget` — 追踪移动目标
- `StopNavigation` — 停止导航
- `GetNavigationPath` — 获取路径信息

**事件：**
- `OnNavigationTargetReached` — 到达目的地
- `OnNavigationFailed` — 寻路失败

**条件：**
- `CheckPathAvailable` — 是否存在可达路径
- `CheckTargetReachable` — 目标是否可达

### 4. 输入增强（Input Advanced）— 动作游戏手感

**事件：**
- `OnInputBuffered` — 输入缓冲（跳跃缓冲、攻击缓冲）
- `OnInputCombo` — 搓招检测
- `OnDirectionalInputChanged` — 方向输入变化

**条件：**
- `CheckInputDirection` — 当前摇杆方向
- `CheckInputMagnitude` — 输入量（走/跑区分）

### 5. 通用补充

**指令：**
- `EmitSignal` — 发射自定义信号
- `SetProcessMode` — 修改节点处理模式
- `LoadResourceByPath` — 按路径加载 Resource
- `GetViewportSize` — 获取视口尺寸
- `MouseWorldPosition` — 鼠标世界坐标
- `CloneNode` — 运行时克隆节点

**事件：**
- `OnProcessModeChanged` — 处理模式变更
- `OnVisibilityChanged` — 可见性变化

**条件：**
- `CheckPlatform` — 运行平台
- `CheckFrameRate` — 帧率检查

---

## 三、优先级排序

### P0 — 发布前必须有（14 个）

| 分类 | 类型 | 组件 | 理由 |
|------|------|------|------|
| 物理 | 指令 | `SetGravityScale` | 跳跃手感调整 |
| 物理 | 指令 | `EnableDisableCollision` | 无敌帧、闪避 |
| 物理 | 指令 | `SetCollisionMask` | 动态碰撞切换 |
| 物理 | 条件 | `CheckOverlapArea` | 攻击范围检测 |
| 动画 | 指令 | `SetAnimationTreeParameter` | 角色状态驱动核心 |
| 动画 | 指令 | `SetSpriteFlip` | 2D 基本操作 |
| 变量 | 指令 | `AddVariable` | 变量增减极常用 |
| 变量 | 指令 | `ToggleVariable` | 开关逻辑极常用 |
| UI | 指令 | `SetUIColor` | 血条/警告闪烁 |
| 渲染 | 指令 | `SetMaterialProperty` | 特效控制核心 |
| 渲染 | 条件 | `CheckIsOnScreen` | 视口剔除、AI 优化 |
| 导航 | 指令 | `NavigateToPosition` | AI 移动基础 |
| 输入 | 事件 | `OnInputBuffered` | 动作游戏手感关键 |
| 通用 | 指令 | `SetProcessMode` | 暂停系统核心 |
| 通用 | 指令 | `MouseWorldPosition` | 2D 点击交互必备 |

### P1 — 应该有（23 个）

| 分类 | 类型 | 组件 | 理由 |
|------|------|------|------|
| 物理 | 指令 | `GroundSnap` | 斜坡行走 |
| 物理 | 条件 | `CheckSlope` | 斜坡行为控制 |
| 物理 | 事件 | `OnGroundStateChanged` | 落地效果触发 |
| 动画 | 条件 | `CheckAnimationTreeParameter` | 状态分支判断 |
| Tween | 指令 | `TweenPause`/`TweenResume` | 动画冻结/恢复 |
| 相机 | 指令 | `CameraFadeIn`/`CameraFadeOut` | 场景过渡 |
| UI | 指令 | `AddRemoveUIChild` | 动态 UI |
| UI | 事件 | `OnUIMouseEntered`/`OnUIMouseExited` | Tooltip |
| UI | 条件 | `CheckUIVisible` | 防重复弹窗 |
| 字符串 | 指令 | `StringFormat` | RPG 文本模板 |
| 渲染 | 指令 | `SetLight` | 光照控制 |
| 渲染 | 指令 | `ControlParticles` | 粒子效果 |
| 导航 | 事件 | `OnNavigationTargetReached` | AI 行为链 |
| 导航 | 条件 | `CheckPathAvailable` | 寻路可行性 |
| 输入 | 条件 | `CheckInputMagnitude` | 走/跑区分 |
| 输入 | 事件 | `OnDirectionalInputChanged` | 转向检测 |
| 通用 | 指令 | `EmitSignal` | 跨系统通信 |
| 通用 | 指令 | `GetViewportSize` | UI 自适应 |
| 通用 | 指令 | `CloneNode` | 运行时生成 |
| 变量 | 指令 | `SwapVariables` | 交换值 |

### P2 — 最好有（17 个）

| 分类 | 类型 | 组件 |
|------|------|------|
| 物理 | 指令 | `SetGravityDirection` |
| 动画 | 指令 | `SetAnimationBlendPosition` |
| 动画 | 指令 | `SetSpriteFrame` |
| 字符串 | 指令 | `StringSplit`/`StringJoin`/`StringContains`/`StringReplace` |
| 字符串 | 条件 | `CheckStringContains`/`CheckStringLength` |
| 渲染 | 指令 | `SetZIndex` |
| 渲染 | 指令 | `ScreenFlash` |
| 输入 | 事件 | `OnInputCombo` |
| 输入 | 条件 | `CheckInputDirection` |
| 通用 | 指令 | `LoadResourceByPath` |
| 通用 | 指令 | `SetGlobalPosition` |
| 通用 | 条件 | `CheckPlatform` |
| 通用 | 条件 | `CheckFrameRate` |

### 统计

| 优先级 | 指令 | 事件 | 条件 | 合计 |
|--------|------|------|------|------|
| P0 | 11 | 1 | 2 | **14** |
| P1 | 16 | 4 | 3 | **23** |
| P2 | 12 | 1 | 4 | **17** |
| **合计** | **39** | **6** | **9** | **54** |

### 工时估算

- P0（14 个）：约 3-5 天（含测试 + 本地化）
- P1（23 个）：约 5-8 天（含测试 + 本地化）
- P2（17 个）：约 4-6 天（含测试 + 本地化）
