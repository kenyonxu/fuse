# 仓库拆分设计 — Juicy Mixer / Fuse 独立发布

**日期:** 2026-06-22  
**状态:** 部分执行中（2026-07-06 更新） — Fuse 仓库已独立，Juicy Mixer 拆分与旧仓库归档待执行

---

## 执行记录（2026-07-06 更新）

> ⚠️ 实际执行时与原设计有偏差，本节记录真实情况，下方"设计"部分保留为历史参考。

### 实际拆分方式：clone（非 fork）

原设计为「GitHub fork 拆分」，但执行时发现 **GitHub 不允许账号 fork 自己的仓库**（`project-juicy-godot` 与新仓库同属 `kenyonxu`）。

最终采用方案：**直接克隆原仓库 → 重置 git 历史作为新仓库 initial commit → push 到独立 remote**。

### 当前进度

| 项 | 状态 | 说明 |
|----|:----:|------|
| Fuse Stage 1-9 | ✅ | 全部完成（超出原计划 Stage 8 的最小门槛） |
| Fuse 独立仓库 | ✅ | `https://github.com/kenyonxu/fuse.git`，单 commit `ce2319d` |
| 首次提交 | ✅ | "initial: Fuse Visual Programming System（从 project-juicy-godot 迁出，Stage 1-9 全部完成）" |
| 清理 fuse 仓库残留 | ⏳ | `addons/juicy_mixer/`、`addons/godot_mcp_editor/`、`addons/godot_mcp_runtime/`、`demos/juicy_*`、`plans/juicy_*` 仍在 |
| 更新 CLAUDE.md / README.md | ⏳ | 项目说明仍含 Juicy Mixer，需移除 |
| juicy-mixer 独立仓库 | ⏳ | 待定（见下方"待决策"） |
| 旧仓库 `project-juicy-godot` 归档 | ⏳ | 待执行 |
| Godot Asset Library 提交 | ⏳ | 待 v1.0 release |

### 待决策（下一步）

1. **juicy-mixer 仓库要不要做？** — 当前 fuse 仓库里仍保留 `addons/juicy_mixer/`，若不做独立仓库，可直接删除残留；若要做，需同样方式 clone 原 repo 再清理 fuse 部分。
2. **fuse 仓库残留清理范围** — `godot_mcp_editor` / `godot_mcp_runtime` 是否属于 fuse（看依赖），还是原项目遗留？
3. **历史保留 vs 干净历史** — 当前是单 commit initial，是否需要用 `git filter-repo` 彻底剥离 juicy_mixer 历史，还是直接 `git rm` 即可？

---

## 背景

当前 `project-juicy-godot` 同时包含 Juicy Mixer（游戏特效系统）和 Fuse（可视化编程系统）两个独立 Godot 插件。核心代码零交叉依赖，但共用一个仓库无法独立发布到 Godot Asset Library。

## 决策摘要

| 维度 | 决策（设计） | 实际执行 |
|------|------|------|
| 拆分时机 | Fuse Stage 7 + 8 完成后（约 5-8 天） | Fuse Stage **1-9** 全完成后（2026-07） |
| 拆分方式 | 基于当前仓库 fork 两个新仓库，各自删除另一插件目录 | **改为 clone**：GitHub 禁 self-fork，直接克隆原 repo 重置历史作为新 repo 首提交 |
| 授权 | MIT | 待定（需在 LICENSE 文件落实） |
| 旧仓库 | 归档（README 加跳转链接，不再活跃开发） | 待执行 |

---

## 目标仓库

**设计（原计划）：**

```
project-juicy-godot (归档/Archive)
    │
    ├── fork → juicy-mixer
    │     └── 删除 addons/fuse/、demos/fuse/、fuse_generated/
    │
    └── fork → fuse
          └── 删除 addons/juicy_mixer/、addons/sound_manager/
```

**实际（2026-07-06）：** GitHub 禁 self-fork，改用 clone 重置历史：

```
project-juicy-godot (待归档)
    │
    ├── clone + 重置历史 → kenyonxu/fuse  ✅ 已建立（Stage 1-9）
    │     └── 待清理：addons/juicy_mixer/、addons/godot_mcp_*、demos/juicy_*、plans/juicy_*
    │
    └── (待定) clone + 重置历史 → juicy-mixer
          └── 待决策是否执行
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

## 执行步骤（原计划，Stage 8 完成后）

> 实际执行见顶部「执行记录」，本节为原始计划，进度以 ✅ / ⏳ / ➖（不适用）标注。

### 1. 前置准备
- [x] ✅ Fuse Stage 8 完成（实际推进到 Stage 9）
- [ ] ⏳ `fuse-v1.0` 标签打在当前仓库
- [ ] ⏳ Fuse `PlayJuicyMixerFeedback` 添加 `ClassDB.class_exists("JuicyMixer")` 守护

### 2. 创建 fork 仓库
- [ ] ➖ GitHub fork（self-fork 被禁，改用 clone 重置历史）
- [x] ✅ `kenyonxu/fuse` 已建立
- [x] ✅ fuse 仓库已 clone 到本地 (`E:\GitHub\fuse`)
- [ ] ⏳ juicy-mixer 仓库待决策

### 3. 清理 juicy-mixer（待 juicy-mixer 仓库建立后）
- [ ] ⏳ 全部待执行（依赖 juicy-mixer 仓库是否建立）

### 4. 清理 fuse
- [ ] ⏳ 删除 `addons/juicy_mixer/`
- [ ] ⏳ 删除 `addons/sound_manager/`（实际为 `addons/godot_mcp_*`，需评估是否 fuse 必需）
- [ ] ⏳ 删除 `.claude/skills/` 中 Juicy Mixer 相关
- [ ] ⏳ 更新 `CLAUDE.md`（移除 Juicy Mixer 相关内容）
- [ ] ⏳ 更新 `README.md`
- [ ] ⏳ 提交 → 推送

### 5. 归档旧仓库
- [ ] ⏳ `project-juicy-godot` README 添加 deprecation notice + 跳转链接
- [ ] ⏳ GitHub 仓库设置 → Archive

### 6. 发布
- [ ] ⏳ 两个新仓库创建 GitHub Release
- [ ] ⏳ 提交到 Godot Asset Library

---

## 后续开发

- **Juicy Mixer** 和 **Fuse** 分别在各自仓库独立迭代
- 两个仓库不再有代码同步需求
- 如未来需要 Fuse ↔ Juicy Mixer 互操作，各自在 `integration/` 目录下做可选集成即可
