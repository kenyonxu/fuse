# 仓库拆分设计 — Juicy Mixer / Fuse 独立发布

**日期:** 2026-06-22  
**状态:** 设计确认，待 Stage 8 完成后执行

---

## 背景

当前 `project-juicy-godot` 同时包含 Juicy Mixer（游戏特效系统）和 Fuse（可视化编程系统）两个独立 Godot 插件。核心代码零交叉依赖，但共用一个仓库无法独立发布到 Godot Asset Library。

## 决策摘要

| 维度 | 决策 |
|------|------|
| 拆分时机 | Fuse Stage 7 + 8 完成后（约 5-8 天） |
| 拆分方式 | 基于当前仓库 fork 两个新仓库，各自删除另一插件目录 |
| 授权 | MIT |
| 旧仓库 | 归档（README 加跳转链接，不再活跃开发） |

---

## 目标仓库

```
project-juicy-godot (归档/Archive)
    │
    ├── fork → juicy-mixer
    │     └── 删除 addons/fuse/、demos/fuse/、fuse_generated/
    │
    └── fork → fuse
          └── 删除 addons/juicy_mixer/、addons/sound_manager/
```

---

## 插件版本基线

| 插件 | plugin.cfg | 版本 | 文件数 |
|------|-----------|:----:|:-----:|
| Juicy Mixer | `addons/juicy_mixer/plugin.cfg` | 3.0.0 | 267 `.gd` |
| Fuse | `addons/fuse/plugin.cfg` | 1.0.0 | 633 `.gd` |

---

## 依赖处理

### Juicy Mixer → Fuse
**无依赖。** Juicy Mixer 代码中零引用 Fuse 任何类或文件。

### Fuse → Juicy Mixer
**仅一个可选集成指令：**
`addons/fuse/integration/juicy_mixer/play_juicy_mixer_feedback.gd`

该指令运行时通过 `JuicyMixer.instance` 检测 Juicy Mixer 是否存在：

```gdscript
var juicy_mixer = JuicyMixer.instance
if not juicy_mixer:
    _log_error("无法获取JuicyMixer实例")
    return
```

**拆分后行为：** 如果用户只安装 Fuse 没安装 Juicy Mixer，该指令仍可被扫描注册，但执行时会优雅失败（日志警告），不影响其他功能。后续可考虑 `ClassDB.class_exists("JuicyMixer")` 检测，类不存在时跳过注册。

**不需要为此建立 npm 式依赖声明。** Godot Asset Library 目前不支持插件间依赖。

---

## 执行步骤（Stage 8 完成后）

### 1. 前置准备
- [ ] Fuse Stage 8 完成，所有测试通过
- [ ] `fuse-v1.0` 标签打在当前仓库
- [ ] Fuse `PlayJuicyMixerFeedback` 添加 `ClassDB.class_exists("JuicyMixer")` 守护

### 2. 创建 fork 仓库
- [ ] GitHub 上 fork `project-juicy-godot` → `juicy-mixer`
- [ ] GitHub 上 fork `project-juicy-godot` → `fuse`
- [ ] 两个新仓库 clone 到本地

### 3. 清理 juicy-mixer
- [ ] 删除 `addons/fuse/`
- [ ] 删除 `fuse_generated/`
- [ ] 删除 `demos/fuse/`
- [ ] 删除 `addons/sound_manager/`（如有）
- [ ] 删除 `.claude/skills/fuse-*`
- [ ] 更新 `CLAUDE.md`（移除 Fuse 相关内容）
- [ ] 更新 `README.md`
- [ ] 提交 → 推送

### 4. 清理 fuse
- [ ] 删除 `addons/juicy_mixer/`
- [ ] 删除 `addons/sound_manager/`（如有）
- [ ] 删除 `.claude/skills/` 中 Juicy Mixer 相关
- [ ] 更新 `CLAUDE.md`（移除 Juicy Mixer 相关内容）
- [ ] 更新 `README.md`
- [ ] 提交 → 推送

### 5. 归档旧仓库
- [ ] `project-juicy-godot` README 添加 deprecation notice + 跳转链接
- [ ] GitHub 仓库设置 → Archive

### 6. 发布
- [ ] 两个新仓库创建 GitHub Release (基于 fork 时的 tag)
- [ ] 提交到 Godot Asset Library

---

## 后续开发

- **Juicy Mixer** 和 **Fuse** 分别在各自仓库独立迭代
- 两个仓库不再有代码同步需求
- 如未来需要 Fuse ↔ Juicy Mixer 互操作，各自在 `integration/` 目录下做可选集成即可
