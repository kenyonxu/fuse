# JuicyMixer 轨道系统

## 核心类

| 类 | 社区 | 说明 |
|----|------|------|
| `JuicyPropertyTrack` | 10 | 属性轨道 |
| `JuicyCurveFactory` | 16 | 曲线工厂 |
| `CurvePresetCategory` | 16 | 曲线预设类别 |

## EditMode 枚举

| 值 | 说明 |
|----|------|
| `CURVE_BASED` | 基于曲线 |
| `KEYFRAME_BASED` | 基于关键帧 |

## 轨道类型

| 类型 | 说明 |
|------|------|
| `PropertyTrack` | 属性轨道 - 修改节点属性 |
| `FeedbackTrack` | 反馈轨道 - 播放特效 |
| `MethodTrack` | 方法轨道 - 调用节点方法 |
| `EventTrack` | 事件轨道 - 触发事件 |

## JuicyCurveFactory

**职责**: 创建和管理插值曲线

**CurvePresetCategory 预设**:
- `BASIC` - 基础曲线
- `ELASTIC` - 弹性曲线
- `BOUNCE` - 弹跳曲线
- `ANTICIPATE` - 预备曲线

## 轨道配置

轨道通常配置:
- `property_path` - 目标属性路径
- `curve` - 插值曲线
- `duration` - 持续时间

## 社区结构

Community 10 (~98 nodes) 包含:
- JuicyPropertyTrack
- JuicyCurveFactory
- EditMode 枚举

Community 16 (~78 nodes) 包含:
- CurvePresetCategory (BASIC, ELASTIC)
- 曲线预设定义

## 查询示例

```bash
graphify explain "JuicyPropertyTrack"
graphify explain "JuicyCurveFactory"
```