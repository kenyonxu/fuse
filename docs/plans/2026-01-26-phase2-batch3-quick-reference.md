# Bricks Phase 2 批次 3 - 快速参考

**最后更新:** 2026-01-26

---

## 📋 指令概览

| 指令 | 评分 | 类别 | 图标 | 异步 | 复杂度 |
|------|------|------|------|------|--------|
| Set Time Scale | 57.0 | Time | Time | ✅ | 中等 |
| Reload Scene | 56.0 | Scene | Reload | ✅ | 低 |
| Add Scene as Child | 56.0 | Scene | MakePacked | ❌ | 低 |

---

## 1️⃣ Set Time Scale (设置时间缩放)

**用途:** 实现慢动作、快进效果

### 基本用法

```
参数配置:
- time_scale: 0.5  (0.5x 速度 = 慢动作)
- duration: 3.0    (3 秒后自动恢复)

效果:
游戏以 50% 速度运行 3 秒，然后恢复正常
```

### 常见场景

**1. 慢动作效果（受伤时）**
```
time_scale = 0.3
duration = 1.0
```

**2. 快进效果（跳过动画）**
```
time_scale = 3.0
duration = 2.0
```

**3. 永久时间缩放**
```
time_scale = 0.8
duration = 0.0  # 永久生效
```

### 参数范围

- **time_scale**: 0.01 - 10.0+ (推荐范围)
- **duration**: 0 - 3600 秒

### 注意事项

- ⚠️ 影响整个游戏（动画、物理、定时器等）
- ⚠️ 不推荐在多人游戏中使用
- ✅ 适合单机游戏特效

---

## 2️⃣ Reload Scene (重载场景)

**用途:** 重新开始游戏/关卡

### 基本用法

```
参数配置:
- delay: 0.0  (立即重载)

效果:
立即重新加载当前场景（相当于重新开始）
```

### 常见场景

**1. 立即重新开始**
```
delay = 0.0
```

**2. 延迟重新开始（显示游戏结束画面后）**
```
delay = 2.0  # 2 秒后重载
```

**3. 无限循环（演示模式）**
```
delay = 10.0  # 每 10 秒重载一次
```

### 参数范围

- **delay**: 0 - 3600 秒

### 注意事项

- ⚠️ 重载会销毁所有节点（包括当前事件和变量）
- ⚠️ 不会保存任何状态
- ✅ 适合重新开始关卡
- ✅ 适合演示循环

---

## 3️⃣ Add Scene as Child (添加场景为子节点)

**用途:** 动态生成游戏对象

### 基本用法

```
参数配置:
- scene_path: "res://scenes/enemy.tscn"
- target_parent: "."  (当前节点)
- new_node_name: ""  (使用默认名称)

效果:
实例化 enemy.tscn 并添加为子节点
```

### 常见场景

**1. 生成敌人**
```
scene_path = "res://scenes/enemy.tscn"
target_parent = "."
new_node_name = ""
```

**2. 生成带自定义名称的对象**
```
scene_path = "res://scenes/particle.tscn"
target_parent = "."
new_node_name = "ExplosionEffect"
```

**3. 添加到特定节点**
```
scene_path = "res://scenes/inventory_item.tscn"
target_parent = "/root/Main/UI/InventoryContainer"
new_node_name = "NewItem"
```

**4. 添加到当前场景（根节点）**
```
scene_path = "res://scenes/global_manager.tscn"
target_parent = ""  # 空路径 = 当前场景
new_node_name = ""
```

### 参数说明

- **scene_path**: 场景文件路径（.tscn 或 .scn）
- **target_parent**: 父节点路径（空 = 当前场景根节点）
- **new_node_name**: 新节点名称（空 = 使用场景默认名称）

### 使用技巧

**1. 变量驱动**
```
scene_path = "{enemy_type_scene}"  # 从变量读取
```

**2. 动态父节点**
```
target_parent = "{spawn_point_path}"  # 从变量读取
```

**3. 唯一命名**
```
new_node_name = "Enemy_{id}"  # 使用变量拼接
```

### 注意事项

- ✅ 场景文件必须存在
- ✅ 父节点必须在场景树中
- ✅ 可以实例化任何场景（2D/3D/UI）
- ⚠️ 不会保存实例 ID（如需保存，使用 Instantiate Scene 指令）

---

## 🔗 相关指令对比

### 场景管理指令

| 指令 | 功能 | 场景切换 | 保存 ID |
|------|------|----------|---------|
| Change Scene | 切换到新场景 | ✅ | ❌ |
| Reload Scene | 重载当前场景 | ✅ | ❌ |
| Instantiate Scene | 实例化场景 | ❌ | ✅ |
| Add Scene as Child | 实例化为子节点 | ❌ | ❌ |

### 时间控制指令

| 指令 | 功能 | 类型 |
|------|------|------|
| Wait | 等待指定时间 | 同步/异步 |
| Wait Until | 等待条件满足 | 异步 |
| Set Time Scale | 设置全局时间缩放 | 异步 |
| Get Delta Time | 获取帧时间 | 同步 |

---

## 💡 使用示例

### 示例 1: 受伤慢动作

```
事件: OnArea2DEnter (玩家进入敌人区域)

指令序列:
1. Set Time Scale
   - time_scale: 0.3
   - duration: 0.5

2. Wait
   - duration: 0.5

3. Set Time Scale
   - time_scale: 1.0
   - duration: 0.0
```

### 示例 2: 游戏结束并重启

```
事件: OnPlayerDies (玩家死亡)

指令序列:
1. Play Sound
   - sound: "game_over.ogg"

2. Wait
   - duration: 2.0

3. Reload Scene
   - delay: 0.0
```

### 示例 3: 动态生成敌人

```
事件: OnInputAction (按下生成键)

指令序列:
1. Add Scene as Child
   - scene_path: "res://scenes/enemy.tscn"
   - target_parent: "."
   - new_node_name: ""

2. Print Variable
   - variable: "enemy_count"
```

---

## 🎓 最佳实践

### Set Time Scale

✅ **推荐用法:**
- 短暂的视觉特效（受伤、爆炸、过关）
- 单机游戏中的时间控制

❌ **避免使用:**
- 多人游戏中的时间控制
- 长时间改变游戏速度
- 需要精确计时的场景

### Reload Scene

✅ **推荐用法:**
- 重新开始关卡
- 游戏结束后的重启
- 演示模式循环

❌ **避免使用:**
- 需要保存状态的场景
- 切换到下一个关卡（使用 Change Scene）

### Add Scene as Child

✅ **推荐用法:**
- 动态生成游戏对象
- 临时特效（粒子、音效）
- UI 元素动态添加

❌ **避免使用:**
- 需要保存实例 ID 的场景（使用 Instantiate Scene）
- 频繁创建销毁的场景（考虑对象池）

---

## 📚 相关文档

- [指令创建指南](../addons/bricks/docs/development/instruction_creation_guide.md)
- [Phase 2 计划](2026-01-26-bricks-phase2-instruction-plan.md)
- [批次 3 实现总结](2026-01-26-phase2-batch3-implementation-summary.md)

---

**文档维护:** Bricks 开发团队
**最后更新:** 2026-01-26
