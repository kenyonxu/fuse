# Fuse Instruction 评估报告

**评估日期:** 2026-01-25
**评估指令总数:** 61 个

---

## 评估方法

使用方案 A（平衡开发型）：
总分 = 需求频率×5 + 即用性×4 + (开发复杂度取反)×3 + (学习曲线取反)×2 + (性能影响取反)×1

---

## P1 级（高优先级）- 8 个指令

| 排名 | 指令 | 类别 | 总分 |
|------|------|------|------|
| 1 | Enable/Disable Node | 节点操作 | 70 |
| 2 | Queue Free Node | 节点操作 | 69 |
| 3 | Stop Audio | 音频控制 | 64 |
| 4 | Play Sound | 音频控制 | 63 |
| 5 | Break Loop | 流程控制 | 63 |
| 6 | Continue Loop | 流程控制 | 63 |
| 7 | Set Audio Volume | 音频控制 | 59 |
| 8 | Pause/Resume Audio | 音频控制 | 59 |

**特点：** 实现简单（1-2天）、高需求、高即用性

---

## P2 级（中优先级）- 47 个指令

### 高分 P2（推荐优先）

- Set Position (65) - 变换操作
- Set Scale (60) - 变换操作
- Set Rotation (60) - 变换操作
- Find Node (60) - 节点操作
- Get Scene Path (58) - 场景管理

### 流程控制

- For Loop (54)
- Wait Until (54)
- If/Else (50)

### 场景管理

- Change Scene (54)

### 音频控制（其余）

- Play Music (56)

### 其他类别

时间控制、物理碰撞、动画控制、相机控制、数学运算、UI控制、数据存取类的大多数指令得分在 57 分左右

---

## P3 级（低优先级）- 6 个指令

- Instantiate Scene (59) - 建议提升为 P2
- Move By (50) - 需要 Tween 系统
- Rotate By (47) - 需要 Tween 系统
- Reparent Node (51) - 特定场景
- While Loop (44) - 死循环风险
- For Each (46) - 需要嵌套管理
- Load Scene Background (38) - 复杂实现
- Set Scene to Save (45) - 依赖存档系统

---

## 第一批开发计划（2-3 周）

### Phase 1A: 基础控制（1 周）

1. Queue Free Node
2. Enable/Disable Node
3. Set Position（提升为 P1）
4. Break Loop
5. Continue Loop
6. Change Scene（提升为 P1）

### Phase 1B: 音频基础（1 周）

7. Play Sound
8. Stop Audio
9. Set Audio Volume
10. Pause/Resume Audio

### Phase 1C: 对象生成（0.5 周）

11. Instantiate Scene（提升为 P2）

---

## 关键建议

1. **优先开发 P1 级** - 快速见效，建立基础能力
2. **提升关键 P2 级** - Instantiate Scene（对象生成核心）、Set Position（最高分 P2）、Change Scene（场景切换核心）
3. **音频先行** - 音频控制类全部 P2，建议在第一批实现
4. **推迟复杂功能** - While Loop、For Each、Move By/Rotate By 需要其他基础功能支持

---

## 依赖关系

```
基础层:
├─ Queue Free Node
├─ Enable/Disable Node
├─ Set Position
└─ 变量系统（已有）

中间层:
├─ Instantiate Scene → Queue Free Node
├─ For Loop → Break/Continue Loop
└─ Change Scene → 存档系统

高级层:
├─ For Each → For Loop + 数组系统
├─ While Loop → For Loop
└─ Move By/Rotate By → Set Position/Set Rotation + Tween
```

---

**预期成果：**

完成第一批开发后，Fuse 将具备：
- ✅ 完整的对象管理能力
- ✅ 基础变换操作
- ✅ 核心流程控制
- ✅ 完整的音频系统
- ✅ 场景切换能力

**支持游戏类型：**
- 基础 2D/3D 游戏
- 简单的物理交互
- 音效和背景音乐
