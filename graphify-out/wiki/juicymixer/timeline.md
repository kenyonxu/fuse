# JuicyMixer 时间轴

## 核心类

| 类 | 社区 | 说明 |
|----|------|------|
| `juicy_timeline_canvas.gd` | 2 | 时间轴画布组件 |
| `JuicyTimelineEditor` | 7 | 时间轴编辑器 |
| `JuicyTrackEditor` | 7 | 轨道编辑器 |
| `JuicyTimeRuler` | 7 | 时间标尺 |

## 时间轴信号

| 信号 | 说明 |
|------|------|
| `timeline_changed` | 时间轴变化 |
| `playback_time_changed` | 播放时间变化 |
| `track_selected` | 轨道被选中 |

## 社区结构

Community 2 (~181 nodes) 包含:
- juicy_timeline_canvas.gd
- timeline_changed, playback_time_changed, time
- 画布渲染相关节点

Community 7 (~114 nodes) 包含:
- JuicyTimelineEditor
- JuicyTimelineCanvas
- JuicyTrackEditor
- JuicyTimeRuler
- 编辑器 UI 组件

## 关键概念

- **Playback**: 播放控制 (play, pause, stop, seek)
- **Tracks**: 轨道系统 (PropertyTrack, FeedbackTrack, MethodTrack, EventTrack)
- **Keyframes**: 关键帧编辑

## 查询示例

```bash
graphify explain "juicy_timeline_canvas.gd"
graphify explain "JuicyTimelineEditor"
```