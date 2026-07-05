# MIDI Composer 设计文档

## 概述

MIDI Composer 是一个 Godot 编辑器插件，通过固定格式的 JSON 文件生成标准 MIDI (.mid) 文件。

**类型：** 编辑器离线工具
**输出：** SMF Type 1（多音轨）标准 MIDI 文件
**依赖：** 零外部依赖，独立实现 MIDI 二进制编码

## 文件结构

```
addons/midi_composer/
├── plugin.cfg                    # 插件配置
├── plugin.gd                     # EditorPlugin，右键菜单注册
├── converter.gd                  # JSON → MidiData 转换 + 格式校验
├── midi_writer.gd                # MIDI 二进制编码器（独立实现）
├── midi_types.gd                 # MidiData / TrackData / NoteData
└── templates/
    └── default.json              # 格式模板
```

## 数据流

```
.json 文件
    ↓ (JSON.parse)
Dictionary (Godot 原生)
    ↓ (converter.gd)
MidiData (内部数据结构)
    ↓ (midi_writer.gd)
PackedByteArray (标准 MIDI 二进制)
    ↓ (FileAccess)
.mid 文件
```

## JSON 格式规范 (v1.0)

```json
{
  "format_version": "1.0",
  "tempo": 140,
  "tracks": [
    {
      "name": "Melody (Square Wave)",
      "channel": 0,
      "instrument": 80,
      "notes": [
        {"pitch": 60, "start": 0.0, "duration": 0.5, "velocity": 100}
      ]
    }
  ]
}
```

### 字段说明

| 字段 | 类型 | 必须 | 说明 |
|------|------|------|------|
| `format_version` | string | 是 | 格式版本号，当前为 `"1.0"` |
| `tempo` | int | 是 | 速度 (BPM) |
| `tracks` | array | 是 | 音轨数组 |

### Track 字段

| 字段 | 类型 | 必须 | 说明 |
|------|------|------|------|
| `name` | string | 否 | 轨道名称 |
| `channel` | int | 是 | MIDI 通道 (0-15)，鼓组使用 9 |
| `instrument` | int | 是 | GM Program 编号 (0-127) |
| `notes` | array | 是 | 音符数组 |

### Note 字段

| 字段 | 类型 | 必须 | 说明 |
|------|------|------|------|
| `pitch` | int | 是 | MIDI 音高 (0-127) |
| `start` | float | 是 | 起始时间（秒） |
| `duration` | float | 是 | 持续时间（秒） |
| `velocity` | int | 是 | 力度 (0-127) |

### 格式扩展机制

- 通过 `format_version` 区分版本
- 转换器对未知字段静默忽略，保证向后兼容
- 未来版本可扩展：`time_signature`、`key_signature`、控制变化（CC）等

## MIDI 编码器 (midi_writer.gd)

### SMF Type 1 文件结构

```
[MThd] Header Chunk
  - 格式: Type 1 (多音轨)
  - 音轨数: N + 1（含 Tempo 轨）
  - 分辨率: 480 ticks/quarter note

[Track 0] Tempo / Meta 轨
  - 时间签名 (4/4)
  - 速度标记

[Track 1..N] 音轨
  - 轨道名称
  - Program Change (乐器)
  - Note On / Note Off 事件
```

### 秒 → ticks 转换

```
ticks = seconds × (tempo / 60) × 480
```

### 核心方法

| 方法 | 作用 |
|------|------|
| `write(midi_data: MidiData) -> PackedByteArray` | 入口，输出完整 MIDI 字节流 |
| `_write_header(track_count: int) -> PackedByteArray` | MThd 头块 |
| `_write_tempo_track(midi_data: MidiData) -> PackedByteArray` | 全局速度轨 |
| `_write_track(track: TrackData) -> PackedByteArray` | 单个音轨 |
| `_encode_delta_time(ticks: int) -> PackedByteArray` | 可变长度时间编码 |
| `_encode_event(event) -> PackedByteArray` | 事件编码 |

## 编辑器集成 (plugin.gd)

### 交互方式

文件系统面板右键 `.json` 文件 → "Compose MIDI" → 同目录生成 `.mid`

### 错误处理

- 非 `.json` 文件 → 菜单项禁用
- JSON 解析失败 → 弹出具体错误
- 格式不合法 → 列出缺失字段
- 转换成功 → 底部提示输出路径

## 模块职责

| 模块 | 职责 |
|------|------|
| `plugin.gd` | 编辑器插件，右键菜单注册与触发 |
| `converter.gd` | JSON 解析、格式校验、转 MidiData |
| `midi_writer.gd` | MidiData → MIDI 二进制字节流 |
| `midi_types.gd` | 数据类定义 (MidiData, TrackData, NoteData) |
| `default.json` | 用户参考的格式模板 |

## 参考实现

- `addons/midi/SMF.gd` — MIDI 读写参考（arlez80），编码器参考其逻辑但不直接依赖
- 标准 MIDI 文件格式规范 (SMF)

---

**创建日期:** 2026-03-24
**状态:** 设计完成，待实现
