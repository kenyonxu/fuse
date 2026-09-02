> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/16-camera-guide.md)

# 相机系统使用指南

Fuse 相机系统提供 4 个相机指令，涵盖相机跟随、缩放控制、边界限制和屏幕震动效果，适用于 2D 游戏中的常见相机操控需求。

## 指令列表

| 名称 | 功能描述 | 关键参数 |
|------|----------|----------|
| **CameraFollow** | 设置相机跟随目标节点移动 | `target_node`（跟随目标）、`camera_node`（相机节点）、`follow_mode`（跟随模式：Lock/Smooth/Damped）、`smooth_speed`（平滑速度）、`damping`（是否启用阻尼）、`enabled`（是否启用） |
| **SetCameraZoom** | 设置 Camera2D 的缩放级别 | `target_node`（目标 Camera2D）、`zoom_source`（缩放来源：Direct/Variable）、`zoom`（直接缩放值）、`zoom_variable` / `zoom_scope`（从变量读取缩放值） |
| **SetCameraLimit** | 设置 Camera2D 的移动边界限制 | `target_node`（目标 Camera2D）、`limit_side`（边界方向：Top/Bottom/Left/Right）、`limit_value`（边界值，-9999 表示无限制） |
| **CameraShake** | 触发相机抖动效果（异步指令） | `target_node`（目标相机）、`intensity`（抖动强度 0.0-1.0）、`duration`（持续时间，秒） |

### 指令使用说明

**CameraFollow 跟随模式：**
- `LOCK`：相机立即锁定到目标位置，无延迟
- `SMOOTH`：相机以指定速度平滑追踪目标（通过 `smooth_speed` 控制）
- `DAMPED`：使用物理阻尼实现自然的减速跟随效果（通过 `damping` 控制是否启用）

**SetCameraZoom 缩放来源：**
- `DIRECT`：直接指定缩放值
- `VARIABLE`：从变量读取缩放值，支持 Local/Scope/Global 三种作用域

**SetCameraLimit 边界方向：**
- `TOP` / `BOTTOM` / `LEFT` / `RIGHT`：分别设置相机在四个方向上的移动限制
- `limit_value` 设为 `-9999` 时表示该方向无限制

**CameraShake：**
- 异步指令，会在抖动持续时间结束后才标记完成
- 使用随机偏移实现自然的抖动效果，以 30 FPS 运行

---

## 常见用例

### 1. 横版卷轴游戏 - 相机跟随玩家

```
# 游戏初始化时设置相机跟随
CameraFollow → target_node: Player, camera_node: Camera2D, follow_mode: Smooth, smooth_speed: 8.0
```

### 2. 关卡边界限制

```
# 设置相机不能超出关卡范围
SetCameraLimit → target_node: Camera2D, limit_side: Left, limit_value: 0
SetCameraLimit → target_node: Camera2D, limit_side: Right, limit_value: 1920
SetCameraLimit → target_node: Camera2D, limit_side: Top, limit_value: 0
SetCameraLimit → target_node: Camera2D, limit_side: Bottom, limit_value: 1080
```

### 3. 爆炸/受击反馈

```
# 在受击时触发相机震动
CameraShake → target_node: Camera2D, intensity: 0.8, duration: 0.3
```
