# 音频系统

欢迎来到 JuicyMixer 音频系统文档！音频管理系统提供了完整的音乐和音效播放、管理、过渡功能。

## 📚 文档目录

### 用户指南
1. [用户指南](user_guide.md) - 音频系统使用指南
2. [播放器指南](player_guide.md) - MusicPlayer 详细说明

### 管理器文档
3. [音频管理器](manager/user_guide.md) - AudioManager 使用指南

## 🎵 核心功能

### 音乐管理器 (MusicManager)
- Intro-Loop 机制（引入-循环）
- Crossfade 过渡
- 音乐层叠加
- 三种中断模式：
  - `STOP_AND_RESTART` - 停止并重新开始
  - `PAUSE_AND_RESUME` - 暂停并恢复
  - `KEEP_PLAYING_SILENTLY` - 静音播放

### 虚拟语音管理 (VirtualVoiceManager)
- 音频虚拟化系统
- 语音优先级管理
- 性能优化

## 🚀 快速开始

```gdscript
# 获取音乐管理器
var music_manager = MusicManager.instance

# 播放音乐
music_manager.play_music("battle_theme", MusicManager.InterruptionMode.STOP_AND_RESTART)

# 过渡到其他音乐
music_manager.transition_to("victory_theme", 2.0)  # 2秒淡入淡出
```

## 📖 相关文档

- [用户文档](../user_docs/) - JuicyMixer 通用文档
- [开发文档](../dev_docs/audio_manager_*.md) - 音频系统开发文档

---

**返回**: [文档中心](../README.md)
