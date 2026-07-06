# Fuse 仓库清理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 fuse 仓库清理为纯净的、可独立发布到 Godot Asset Library 的单一插件仓库（仅 `addons/fuse` 及其支撑文件）。

**Architecture:** 7 个有序任务，按「低风险删除 → 高风险编辑 → 最终验证」推进。每个任务独立 commit，可单独 revert。删除任务用 `git rm` 让 Git 跟踪；编辑任务用最小 diff。

**Tech Stack:** Godot 4.7, GDScript 2.0, git, Git Bash (POSIX)

**基于 spec:** [2026-07-06-fuse-cleanup-spec.md](../specs/2026-07-06-fuse-cleanup-spec.md)

**编写本计划时的补充发现（spec 未完整覆盖）：**
- `project.godot` 除 `editor_plugins.enabled` 外还有 4 处残留（项目名 / MCPRuntime autoload / dotnet assembly_name / movie_file 旧硬编码路径）
- `README.md` 整篇是 Juicy Mixer 的内容（不是部分引用），需完全重写为 Fuse README
- `AGENTS.md` 还需修正 Godot 版本（4.5 → 4.7）与测试示例中的 `juicy_mixer` 路径
- `addons/fuse/localization/translations.csv` 中 juicy 部分精确定位在第 4514-4516 行（注释 + 2 个 `FUSE_ERROR_FEEDBACK_*` 验证键）

**前置约定：**
- Godot 可执行：`/e/Godot/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe`（下文记作 `$GODOT`）
- 命令默认在仓库根 `e:/GitHub/fuse` 执行
- 当前在 `master` 分支，仓库仅 1 个 initial commit；如倾向分支隔离，先 `git checkout -b cleanup/strip-residue`
- Commit 类型用 `chore:`（清理）/ `docs:`（文档）

---

## File Structure

| 路径 | 操作 | 责任 |
|---|---|---|
| `addons/juicy_mixer/` `addons/godot_mcp_editor/` `addons/godot_mcp_runtime/` | 删除 | 非 fuse 插件 |
| `project.godot` | 编辑 | 项目名 / autoload / enabled / assembly / movie 路径 |
| `addons/fuse/integration/juicy_mixer/` | 删除 | fuse 内部 juicy 集成指令 |
| `addons/fuse/localization/translations.csv` | 编辑（删 3 行） | 移除集成指令的验证错误键 |
| `addons/fuse/docs/user_docs/guides/play_juicy_effect_examples.md` | 删除 | 集成指令用户文档 |
| `demos/juicy_audio_demo.tscn` `demos/fuse_juicy_demo.tscn` `demos/editor_tools_demo.gd(+.uid)` | 删除 | juicy / mcp demo |
| `plans/juicy_godot_plugin_plan.md` `plans/fix_abc_to_midi.md` | 删除 | juicy 计划文档 |
| `docs/juicy_*.md`(6) `docs/feel/` `docs/analysis/juicy_*.md`(2) | 删除 | juicy 设计文档 / Feel 参考文档 |
| `skills/project-juicy-godot-patterns.md` | 删除 | juicy 技能 |
| `godot_src/` `fuse_generated/` | 删除（空目录） | 残留空目录 |
| `test_scripts/*audio_manager*` `*audio_binding*` `*audio_category*` | 删除 | 失效测试（被测对象已不在） |
| `README.md` | 重写 | fuse-only README |
| `CLAUDE.md` | 编辑 | 移除 Juicy Mixer 段，标题改为 Fuse |
| `AGENTS.md` | 编辑 | 项目结构段 + 测试示例 + 版本号 |

---

## Task 1: 删除其他插件目录 + project.godot 清理

**Files:**
- Delete: `addons/juicy_mixer/`, `addons/godot_mcp_editor/`, `addons/godot_mcp_runtime/`
- Modify: `project.godot:17`, `project.godot:30`, `project.godot:42`, `project.godot:48`, `project.godot:52`

- [ ] **Step 1: 删除三个插件目录**

```bash
git rm -r addons/juicy_mixer addons/godot_mcp_editor addons/godot_mcp_runtime
```

预期：列出删除的文件，无 error。

- [ ] **Step 2: 验证目录已删**

```bash
ls addons/
```

预期输出仅：`fuse/`

- [ ] **Step 3: 修改 project.godot 项目名（第 17 行）**

将：
```ini
config/name="project_juicy_godot"
```
改为：
```ini
config/name="Fuse Visual Programming"
```

- [ ] **Step 4: 删除 MCPRuntime autoload（第 30 行）**

将：
```ini
[autoload]

FuseEventBus="*uid://ptmsqnuut75p"
FuseRuntimeBridge="*uid://c6iequlsnctd7"
MCPRuntime="*uid://b7qx8f01pxijd"
```
改为：
```ini
[autoload]

FuseEventBus="*uid://ptmsqnuut75p"
FuseRuntimeBridge="*uid://c6iequlsnctd7"
```

- [ ] **Step 5: 修改 dotnet assembly_name（第 42 行）**

将：
```ini
project/assembly_name="project_juicy_godot"
```
改为：
```ini
project/assembly_name="fuse"
```

- [ ] **Step 6: 清理 movie_file 旧路径（第 48 行）**

将：
```ini
movie_writer/movie_file="E:/Godot/GodotProjects/project-juicy-godot/recordings/record_test.avi"
```
改为：
```ini
movie_writer/movie_file="res://recordings/record_test.avi"
```

- [ ] **Step 7: 修改 editor_plugins.enabled 列表（第 52 行）**

将：
```ini
enabled=PackedStringArray("res://addons/fuse/plugin.cfg", "res://addons/godot_mcp_editor/plugin.cfg", "res://addons/godot_mcp_runtime/plugin.cfg", "res://addons/juicy_mixer/plugin.cfg")
```
改为：
```ini
enabled=PackedStringArray("res://addons/fuse/plugin.cfg")
```

- [ ] **Step 8: 复核 project.godot 无残留**

```bash
git grep -niE "juicy|godot_mcp|MCPRuntime" project.godot
```

预期：0 命中。

- [ ] **Step 9: Godot headless 启动验证**

```bash
$GODOT --headless --quit 2>&1 | grep -iE "error|script error" | head
```

预期：无输出（或仅与 juicy/mcp 无关的既有 warning）。

- [ ] **Step 10: Commit**

```bash
git add project.godot
git commit -m "chore: remove juicy_mixer and godot_mcp plugins, fix project.godot"
```

---

## Task 2: 删除 fuse 内部 juicy_mixer 集成指令

**Files:**
- Delete: `addons/fuse/integration/juicy_mixer/`（整个目录）
- Delete: `addons/fuse/docs/user_docs/guides/play_juicy_effect_examples.md`
- Modify: `addons/fuse/localization/translations.csv:4514-4516`

- [ ] **Step 1: 删除集成指令目录**

```bash
git rm -r addons/fuse/integration/juicy_mixer
```

预期：删除 `play_juicy_mixer_feedback.gd` + `.uid`。

- [ ] **Step 2: 删除用户文档**

```bash
git rm addons/fuse/docs/user_docs/guides/play_juicy_effect_examples.md
```

- [ ] **Step 3: 编辑 translations.csv 删除 3 行（4514-4516）**

删除以下 3 行：
```
# PlayJuicyMixerFeedback 集成指令验证错误
FUSE_ERROR_FEEDBACK_RESOURCE_EMPTY,反馈资源不能为空,Feedback resource cannot be empty
FUSE_ERROR_TARGET_NODE_PATH_EMPTY,目标节点路径不能为空,Target node path cannot be empty
```
（位于 `FUSE_INSTRUCTION_GENERATOR_SKIP,跳过,Skip` 与空行 + `# InstructionValidator 静态分析错误` 之间）

- [ ] **Step 4: 验证 fuse 内部无 juicy_mixer 引用（除 archive）**

```bash
git grep -iE "juicy_mixer|PlayJuicyMixer" -- addons/fuse/ ':!addons/fuse/docs/**/archive/*'
```

预期：0 命中。

- [ ] **Step 5: 验证 translations.csv 不再含 PlayJuicyMixer 相关键**

```bash
git grep -iE "FEEDBACK_RESOURCE_EMPTY|TARGET_NODE_PATH_EMPTY|PlayJuicyMixer" addons/fuse/localization/translations.csv
```

预期：0 命中。

- [ ] **Step 6: Commit**

```bash
git add addons/fuse/integration addons/fuse/docs/user_docs/guides/play_juicy_effect_examples.md addons/fuse/localization/translations.csv
git commit -m "chore: remove fuse juicy_mixer integration instruction and its i18n keys"
```

---

## Task 3: 删除 demos/plans/docs/skills 残留 + 空目录

**Files:**
- Delete: 见下方各组命令
- 保留：`demos/fuse/`、`demos/fuse_debug.tscn`、所有 `plans/bricks-*`/`condition-*`/`expression-*`/`property-*`/`nodepath-*`/`variable-*`、`skills/bricks-instincts.yaml`、`skills/godot-gdscript-bricks-patterns.md`、`skills/instincts.yml`

- [ ] **Step 1: 删除 demos 残留**

```bash
git rm demos/juicy_audio_demo.tscn demos/fuse_juicy_demo.tscn demos/editor_tools_demo.gd demos/editor_tools_demo.gd.uid
```

- [ ] **Step 2: 删除 plans 残留**

```bash
git rm plans/juicy_godot_plugin_plan.md plans/fix_abc_to_midi.md
```

- [ ] **Step 3: 删除 docs 顶层 juicy 文档 + feel 目录**

```bash
git rm docs/juicy_animation_play_diagrams.md \
       docs/juicy_animation_play_driver_design.md \
       docs/juicy_animation_play_examples.md \
       docs/juicy_animation_tree_driver_design.md \
       docs/juicy_mixer_timeline_editor_supplement.md \
       docs/juicy_mixer_vs_feel_comparison.md
git rm -r docs/feel
```

- [ ] **Step 4: 删除 docs/analysis 中的 juicy 分析文档**

先确认清单：
```bash
ls docs/analysis/ | grep -i juicy
```
预期命中：`juicy_mixer_driver_state_pollution_audit.md`、`juicy_mixer_state_pollution_analysis.md`

```bash
git rm docs/analysis/juicy_mixer_driver_state_pollution_audit.md docs/analysis/juicy_mixer_state_pollution_analysis.md
```

- [ ] **Step 5: 删除 skills 中的 juicy 技能**

```bash
git rm skills/project-juicy-godot-patterns.md
```

- [ ] **Step 6: 删除空目录**

```bash
rmdir godot_src fuse_generated 2>/dev/null; ls -d godot_src fuse_generated 2>&1
```

预期：`ls: cannot access ...`（目录已不存在；它们未被 git 跟踪，无需 `git rm`）。

- [ ] **Step 7: 验证保留项仍在**

```bash
ls plans/ | grep -E "bricks|condition|expression|property|nodepath|variable"
ls skills/
ls demos/
```

预期：plans 保留 bricks/condition 等系列；skills 保留 3 个 fuse 相关文件；demos 保留 `fuse/` 与 `fuse_debug.tscn`。

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "chore: remove juicy/feel docs, plans, demos, skills residue"
```

---

## Task 4: 删除 test_scripts/ 中的 audio_manager 残留

**Files:**
- Delete: `test_scripts/` 下所有 audio_manager / audio_binding / audio_category 相关文件

被测对象 `audio_manager` / `sound_manager` 已不在仓库，这些是失效测试。

- [ ] **Step 1: 列出待删文件确认**

```bash
ls test_scripts/ | grep -iE "audio_manager|audio_binding|audio_category|demo_audio"
```

预期命中（12 项）：
```
demo_audio_binding.tres
test_audio_category_quick.gd
test_audio_category_quick.gd.uid
test_audio_manager.tscn
test_audio_manager_quick.gd
test_audio_manager_quick.gd.uid
verify_audio_binding.gd
verify_audio_binding.gd.uid
verify_audio_binding.tscn
verify_audio_manager.gd
verify_audio_manager.gd.uid
verify_audio_manager_fixes.gd
verify_audio_manager_fixes.gd.uid
```

- [ ] **Step 2: 删除这些文件**

```bash
git rm test_scripts/demo_audio_binding.tres \
       test_scripts/test_audio_category_quick.gd test_scripts/test_audio_category_quick.gd.uid \
       test_scripts/test_audio_manager.tscn \
       test_scripts/test_audio_manager_quick.gd test_scripts/test_audio_manager_quick.gd.uid \
       test_scripts/verify_audio_binding.gd test_scripts/verify_audio_binding.gd.uid test_scripts/verify_audio_binding.tscn \
       test_scripts/verify_audio_manager.gd test_scripts/verify_audio_manager.gd.uid \
       test_scripts/verify_audio_manager_fixes.gd test_scripts/verify_audio_manager_fixes.gd.uid
```

- [ ] **Step 3: 验证剩余 test_scripts 无 audio 残留**

```bash
ls test_scripts/ | grep -iE "audio_manager|audio_binding|audio_category"
```

预期：0 命中。

- [ ] **Step 4: 验证保留的 fuse 测试仍在（抽样）**

```bash
ls test_scripts/ | grep -E "^test_phase|^test_base_event|^verify_phase|^verify_icon"
```

预期：列出多个 phase/event/icon 相关测试。

- [ ] **Step 5: Commit**

```bash
git commit -am "chore: drop orphaned audio_manager test scripts (target addon removed)"
```

---

## Task 5: 完全重写 README.md

**Files:**
- Rewrite: `README.md`

当前 README 整篇是 Juicy Mixer 的内容（标题、特性、安装、用法、更新历史全是 juicy），需完全重写为 Fuse 的 README。

- [ ] **Step 1: 用以下内容完整覆盖 README.md**

```markdown
# Fuse — Godot 可视化编程系统

一个用于 Godot 4.7 的可视化编程 / 事件系统插件，灵感来源于 Game Creator 的无代码脚本系统。通过 Event / Instruction / Condition 三类砖块（Brick）组合，无需编写代码即可搭建游戏逻辑。

## 核心特性

- **事件驱动**：65+ 种事件（输入、碰撞、动画、信号、生命周期…）
- **指令编排**：130+ 种指令（变量、流程、动画、物理、UI、导航…）
- **条件分支**：43+ 种条件，支持复合条件与表达式求值
- **变量系统**：global / local / scope 三层变量，运行时监视与编辑
- **组件自动注册**：在 `instructions/` / `events/` / `conditions/` 放 `.gd` 文件即自动扫描注册
- **本地化**：基于 Godot TranslationDomain，内置 zh_CN / en
- **多线程支持**：ExecutionContext 门面，安全跨线程
- **运行时调试**：变量监视器 V2（历史折线图 + 静态声明分析）+ TCP 变量桥

## 架构

```
Event（何时）──▶ Instruction（做什么）──▶ Condition（是否）
                        │
                        ▼
                ExecutionContext（运行时上下文）
                        │
                        ▼
                  ActionRunner（执行器）
```

**关键基类：**
- `BaseEvent` — 事件基类
- `BaseInstruction` — 指令基类
- `BaseCondition` — 条件基类
- `ExecutionContext` — 执行上下文（三层门面）
- `ActionRunner` — 动作运行器

详见 [addons/fuse/docs/](addons/fuse/docs/)。

## 安装

1. 将 `addons/fuse/` 复制到你的 Godot 4.7 项目的 `addons/` 目录
2. 项目设置 → 插件 → 启用 "Fuse Visual Programming"
3. （可选）启用 autoload：`FuseEventBus`、`FuseRuntimeBridge`

## 系统要求

- Godot 4.7+
- 兼容 2D / 3D 项目

## 文档

- [系统文档](addons/fuse/docs/system_docs/)
- [用户文档](addons/fuse/docs/user_docs/)
- [开发者文档](addons/fuse/docs/dev_docs/)
- [多线程指南](addons/fuse/docs/dev_docs/multithreading-developer-guide.md)

## 许可证

MIT License — 详见 [LICENSE](LICENSE)

## 相关链接

- GitHub 仓库：https://github.com/kenyonxu/fuse
- 问题反馈：https://github.com/kenyonxu/fuse/issues
```

- [ ] **Step 2: 验证 README 无 juicy 残留**

```bash
git grep -iE "juicy|sound_manager|feel" README.md
```

预期：0 命中。

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for fuse-only project"
```

---

## Task 6: 更新 CLAUDE.md 与 AGENTS.md

**Files:**
- Modify: `CLAUDE.md`（移除 Juicy Mixer 段、改标题与项目结构）
- Modify: `AGENTS.md`（修正 Godot 版本、测试示例路径、项目结构段）

### Task 6a: CLAUDE.md

- [ ] **Step 1: 改标题与项目概述**

将第 1 行：
```
# Project Juicy Godot - AI 开发规范
```
改为：
```
# Fuse Visual Programming - AI 开发规范
```

将第 3-6 行的项目概述：
```
## 项目概述

基于 **Godot 4.7** 的游戏插件开发项目，包含以下核心系统：

- **Juicy Mixer** - 游戏特效系统（震动、弹簧、补间动画、时间线控制）
- **Fuse** - 可视化编程/事件系统（类似 Game Creator 的无代码脚本系统）
```
改为：
```
## 项目概述

基于 **Godot 4.7** 的可视化编程插件项目：

- **Fuse** - 可视化编程/事件系统（类似 Game Creator 的无代码脚本系统）
```

- [ ] **Step 2: 更新项目结构图**

将项目结构代码块中的：
```
project-juicy-godot/
├── addons/
│   ├── juicy_mixer/     # 特效系统
│   ├── fuse/            # 可视化编程系统
│   └── sound_manager/   # 音频系统
```
改为：
```
fuse/
├── addons/
│   └── fuse/            # 可视化编程系统
```

- [ ] **Step 3: 移除「核心系统快速参考」中的 Juicy Mixer 段**

删除以下整段（含空行）：
```
### Juicy Mixer

**架构：** Resource-based, Driver-driven, Track-based, Context-managed

**关键类：**
- `JuicyFeedback` - 反馈资源（入口点）
- `JuicyTrack` - 轨道基类
- `JuicyDriver` - 驱动器基类
- `JuicyContext` - 运行时上下文

**详细文档：** [addons/juicy_mixer/docs/](addons/juicy_mixer/docs/)
```

并删除「JuicyMixer 新 Track/Driver」代码示例整段（在「添加新功能」小节下）。

- [ ] **Step 4: 更新底部元信息**

将：
```
**最后更新:** 2026-03-23 | **Godot 版本:** 4.7 | **开发分支:** Develop_brick
```
改为：
```
**最后更新:** 2026-07-06 | **Godot 版本:** 4.7 | **主分支:** master
```

- [ ] **Step 5: 验证 CLAUDE.md 无 juicy 残留**

```bash
git grep -iE "juicy|sound_manager" CLAUDE.md
```

预期：0 命中。

### Task 6b: AGENTS.md

- [ ] **Step 6: 修正 Godot 版本（第 3 行）**

将：
```
本文档为在此 Godot 4.5 游戏插件项目中工作的 AI 代理提供必要信息。
```
改为：
```
本文档为在此 Godot 4.7 游戏插件项目中工作的 AI 代理提供必要信息。
```

- [ ] **Step 7: 修正测试示例中的 juicy_mixer 路径（第 18-29 行）**

将测试示例代码块：
```gdscript
# 运行单个测试场景：
# 1. 打开 Godot 编辑器
# 2. 打开测试场景（如 res://addons/juicy_mixer/tests/test_example.tscn）
# 3. 按 F5 运行场景

# 以编程方式运行测试：
extends Node
func _ready():
    var test_script = load("res://addons/juicy_mixer/tests/test_example.gd")
    var test_instance = test_script.new()
    add_child(test_instance)
    if test_instance.has_method("run_tests"):
        test_instance.run_tests()
```
改为：
```gdscript
# 运行单个测试场景：
# 1. 打开 Godot 编辑器
# 2. 打开测试场景（如 res://addons/fuse/tests/conditions/test_conditions.tscn）
# 3. 按 F5 运行场景

# 以编程方式运行测试：
extends Node
func _ready():
    var test_script = load("res://addons/fuse/tests/conditions/test_conditions.gd")
    var test_instance = test_script.new()
    add_child(test_instance)
    if test_instance.has_method("run_tests"):
        test_instance.run_tests()
```

- [ ] **Step 8: 更新「项目结构上下文」段（第 298-310 行）**

将：
```
## 项目结构上下文

- **JuicyMixer**: 游戏反馈系统（震动、弹簧、补间、时间线）
- **Bricks**: 可视化编程系统
- **SoundManager**: 音频管理
- **FlowKit**: 事件驱动可视化编程

核心架构使用：
- 基于 Resource 的配置
- 驱动器驱动的执行
- 中间件管道处理
- 对象池优化性能
- 基于 Context 的运行时状态管理
```
改为：
```
## 项目结构上下文

- **Fuse**: 可视化编程系统（Event / Instruction / Condition 三类砖块）

核心架构使用：
- 事件驱动的执行
- 指令编排（ActionRunner）
- 基于 ExecutionContext 的运行时上下文
- 全局变量 Service + Assistant 双层
- 组件自动扫描注册（ComponentScanner）
- 基于 Godot TranslationDomain 的本地化
```

- [ ] **Step 9: 验证 AGENTS.md 无 juicy 残留**

```bash
git grep -iE "juicy|sound_manager" AGENTS.md
```

预期：0 命中。

- [ ] **Step 10: Commit（合并 6a/6b）**

```bash
git add CLAUDE.md AGENTS.md
git commit -m "docs: update CLAUDE.md and AGENTS.md to fuse-only"
```

---

## Task 7: 最终验证 + 可选打 tag

**Files:** 无修改（仅验证）

- [ ] **Step 1: 全仓 juicy/mcp 残留扫描（archive 除外）**

```bash
git grep -iE "juicy|godot_mcp|MCPRuntime|sound_manager" \
  ':!addons/fuse/docs/**/archive/*' \
  ':!docs/superpowers/**' \
  ':!**/*.import'
```

预期：0 命中（superpowers spec/plan 自身的"juicy"字样、archive 历史文档、.import 二进制描述不计）。

- [ ] **Step 2: project.godot 终检**

```bash
git grep -niE "juicy|godot_mcp|MCPRuntime" project.godot
grep "enabled=PackedStringArray" project.godot
```

预期：第一条 0 命中；第二条仅 `fuse/plugin.cfg`。

- [ ] **Step 3: addons 目录终检**

```bash
ls addons/
```

预期：仅 `fuse/`。

- [ ] **Step 4: Godot headless 完整启动**

```bash
$GODOT --headless --quit 2>&1 | tee /tmp/fuse_startup.log
grep -iE "ERROR|SCRIPT ERROR|cannot load" /tmp/fuse_startup.log
```

预期：grep 无输出（或仅既有非 juicy 相关 warning）。

- [ ] **Step 5: 抽样跑 fuse 测试（条件测试场景）**

```bash
$GODOT --headless --quit -- res://addons/fuse/tests/conditions/test_conditions.tscn 2>&1 | tail -20
```

预期：看到测试 print 输出，无 push_error 触发的失败标记。

- [ ] **Step 6: 检查 git 历史（确认 6 个清理 commit）**

```bash
git log --oneline -8
```

预期看到 Task 1-6 对应的 6 个 commit。

- [ ] **Step 7（可选）: 打 v1.0 tag**

```bash
git tag -a v1.0.0 -m "Fuse Visual Programming System v1.0.0 — Stage 1-9 complete, repo cleaned for Asset Library release"
```

- [ ] **Step 8: Push**

```bash
git push origin master
git push origin v1.0.0   # 若 Step 7 执行
```

---

## Self-Review

**1. Spec 覆盖：**
- §A（删其他插件）→ Task 1 ✓
- §B（project.godot）→ Task 1 Step 3-7（且补全了 spec 未列的项目名/autoload/assembly/movie 4 处）✓
- §C（demos）→ Task 3 Step 1 ✓
- §D（plans）→ Task 3 Step 2 ✓
- §E（docs 顶层 juicy + feel）→ Task 3 Step 3-4 ✓
- §F（test_scripts audio）→ Task 4 ✓
- §G（skills）→ Task 3 Step 5 ✓
- §H（空目录）→ Task 3 Step 6 ✓
- §I（fuse 内部集成指令）→ Task 2 ✓（含 translations.csv 具体 3 行）
- §J（CLAUDE/README/AGENTS）→ Task 5 + Task 6 ✓（且发现 README 需完全重写）
- §K（保留 archive）→ 验证步骤中用 `:!addons/fuse/docs/**/archive/*` 排除 ✓

**2. 占位符扫描：** 无 TBD/TODO，所有 Edit 给出完整 old/new，所有删除给出确切路径。

**3. 类型/命名一致：** commit message 风格统一（`chore:` / `docs:`）；Godot 可执行记号 `$GODOT` 全文一致。

**4. 风险控制：**
- Task 1 Step 9 headless 验证 → 任何 project.godot 改坏立即暴露
- Task 2 Step 4-5 双重 grep 防止翻译键遗漏
- Task 4 Step 1 删前先列文件确认
- 每个 Task 独立 commit → 单步出错可 `git revert`
