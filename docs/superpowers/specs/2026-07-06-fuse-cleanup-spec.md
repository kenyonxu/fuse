# Fuse 仓库清理 Spec — 移除 Juicy Mixer 及无关插件残留

**日期:** 2026-07-06  
**状态:** 待执行  
**关联:** [2026-06-22-repo-split-design.md](2026-06-22-repo-split-design.md)

---

## 背景

本仓库从 `project-juicy-godot` clone 而来（GitHub 禁 self-fork，改用 clone 重置历史），initial commit `ce2319d` 带入了原 repo 全部内容。Juicy Mixer 已由用户独立处理（另建仓库），本仓库需清理所有 `juicy_mixer` 残留以及与 fuse 无关的 `godot_mcp_*` 插件，使 fuse 成为纯净、可独立发布到 Godot Asset Library 的单一插件仓库。

## 目标

1. 仓库只剩 fuse 相关内容（`addons/fuse` + fuse 的测试/demo/docs/skills）
2. `project.godot` 仅启用 fuse
3. 根目录文档（README / CLAUDE / AGENTS）反映 fuse-only
4. Stage 1-9 全部测试通过
5. 仓库可作为 v1.0 发布到 Godot Asset Library

---

## 依赖分析（已确认）

| fuse 对…的引用 | 代码 | 文档 | 处理 |
|---|---|---|---|
| `juicy_mixer` | 1 处（可选集成指令 `integration/juicy_mixer/`）+ 1 处翻译键 | 14 处（多为 archive） | 见 §I 决策 |
| `godot_mcp_editor/runtime` | **0** | 1 处（feasibility 提及） | 直接删 |
| `sound_manager` | **0** | 0 | n/a |

**结论：** `godot_mcp_*` 可直接删；`juicy_mixer` 集成指令需决策。

---

## 清理范围

### A. 必删 — 其他插件目录
- `addons/juicy_mixer/`
- `addons/godot_mcp_editor/`
- `addons/godot_mcp_runtime/`

### B. 必删 — `project.godot` 启用列表
当前第 52 行：
```ini
enabled=PackedStringArray("res://addons/fuse/plugin.cfg", "res://addons/godot_mcp_editor/plugin.cfg", "res://addons/godot_mcp_runtime/plugin.cfg", "res://addons/juicy_mixer/plugin.cfg")
```
改为：
```ini
enabled=PackedStringArray("res://addons/fuse/plugin.cfg")
```

### C. 必删 — `demos/`
- `demos/juicy_audio_demo.tscn`
- `demos/fuse_juicy_demo.tscn`（依赖 juicy_mixer）
- `demos/editor_tools_demo.gd` + `.uid`（godot_mcp_editor demo — ✅ 已确认删）
- 保留：`demos/fuse/`、`demos/fuse_debug.tscn`

### D. 必删 — `plans/`
- `plans/juicy_godot_plugin_plan.md`（72K，juicy 总规划）
- `plans/fix_abc_to_midi.md`（✅ 已确认删）
- 保留：所有 `bricks-*` / `condition-*` / `expression-*` / `property-*` / `nodepath-*` / `variable-*`（fuse 的）

### E. 必删 — `docs/` 顶层 juicy 文件
- `docs/juicy_animation_play_diagrams.md`
- `docs/juicy_animation_play_driver_design.md`
- `docs/juicy_animation_play_examples.md`
- `docs/juicy_animation_tree_driver_design.md`
- `docs/juicy_mixer_timeline_editor_supplement.md`
- `docs/juicy_mixer_vs_feel_comparison.md`
- `docs/feel/` 整个目录（Unity Feel 插件参考文档，仅服务于 juicy_mixer）
- **执行前确认：** `docs/analysis/juicy_mixer_*.md`（2 个）、`docs/analysis/juicy_mixer_driver_state_pollution_audit.md`

### F. 必删 — `test_scripts/` audio_manager 残留
被测对象（audio_manager / sound_manager）已不在仓库，这些是失效残留：
- `test_audio_manager*.gd/.tscn`、`test_audio_category_quick.gd`
- `verify_audio_manager*.gd`、`verify_audio_binding*`、`demo_audio_binding.tres`
- 保留：所有 `test_phase*` / `test_base_event*` / `test_bricks_*` / `test_localized_*` / `test_icon_*` / `test_node_cache*` / `verify_phase*` / `verify_task_*` / `verify_icon_system*` / `verify_code_quality*`（fuse 的）

### G. 必删 — `skills/`
- `skills/project-juicy-godot-patterns.md`
- 保留：`skills/bricks-instincts.yaml`、`skills/godot-gdscript-bricks-patterns.md`、`skills/instincts.yml`

### H. 必删 — 空目录
- `godot_src/`（空）
- `fuse_generated/`（空，原 spec 也要求删）

### I. 必删 — fuse 内部 juicy_mixer 集成指令（✅ 已确认选 A：删除）

**目标文件：**
- `addons/fuse/integration/juicy_mixer/`（整个目录，主要是 `play_juicy_mixer_feedback.gd`）
- `addons/fuse/localization/translations.csv` 中 `play_juicy_mixer_feedback` 相关翻译键
- `addons/fuse/docs/user_docs/guides/play_juicy_effect_examples.md`

**理由：** 用户已独立处理 juicy_mixer，桥接指令在本仓库永远不会触发，徒增维护负担。

### J. 文档更新 — 根目录
- `CLAUDE.md`（6.1K，含 juicy 标题与章节）— 移除 Juicy Mixer 章节，标题改 "Fuse Visual Programming"，更新项目结构图
- `README.md`（12.7K，**42 处** juicy 引用）— 重写为 fuse-only，移除 juicy_mixer/sound_manager 章节
- `AGENTS.md`（7.4K，7 处 juicy 引用）— 同步更新

### K. 保留 — 历史 / archive 文档
- `addons/fuse/docs/dev_docs/archive/play_juicy_effect_task_instruction_design.md`（历史设计，不动）
- 其他 `addons/fuse/docs/**/archive/` 下提及 juicy 的文档（历史归档，不删）

> 注：`play_juicy_effect_examples.md` 因 §I 选 A 已转入删除清单。

---

## 执行步骤

> 顺序执行；每步完成后跑该步的验证。

1. **`git rm -r`** §A、§C、§D、§E、§F、§G、§H 的目录与文件
2. **§I**：`git rm -r addons/fuse/integration/juicy_mixer/` + 编辑 `addons/fuse/localization/translations.csv` 移除对应翻译键 + `git rm addons/fuse/docs/user_docs/guides/play_juicy_effect_examples.md`
3. **更新 `project.godot`**（§B）
4. **更新文档**（§J）：`CLAUDE.md` → `README.md` → `AGENTS.md`
5. **跑 fuse 测试**：`addons/fuse/tests/` + `test_scripts/` 中保留项
6. **Godot headless 启动验证**：无插件加载错误，无脚本解析错误
7. **`git grep` 复核**（见验证点）
8. **commit + push**：commit message 如 `chore: strip juicy_mixer and unrelated plugin residue for v1.0 release`

---

## 验证点

```bash
# 1. juicy 仅在 archive 历史文档中残留
git grep -iE "juicy" -- addons/fuse/ ':!addons/fuse/docs/**/archive/*'
# 期望：0 命中（或仅集成指令相关，若选 I-B）

# 2. godot_mcp 零命中
git grep -i "godot_mcp" -- addons/fuse/
# 期望：0 命中

# 3. project.godot 仅 fuse
grep "enabled=PackedStringArray" project.godot
# 期望：仅 fuse/plugin.cfg

# 4. 目录清理
ls addons/   # 期望：仅 fuse/
ls docs/feel 2>/dev/null || echo "OK: feel removed"

# 5. Godot 启动（headless）
# 路径：E:\Godot\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe --headless --quit
# 期望：无 ERROR/SCRIPT ERROR
```

---

## 风险与回滚

| 风险 | 缓解 |
|---|---|
| `test_scripts/` 误删 fuse 测试 | 仅删文件名含 `audio_manager` / `audio_binding` / `audio_category` 的，其余保留 |
| 文档改坏 | README/CLAUDE/AGENTS 单独 commit，便于回滚 |
| `translations.csv` 删键不彻底 | 删后跑 `addons/fuse/tests/` 本地化测试，确认无 missing key 报错 |

**回滚：** 所有删除集中在 1-2 个 commit，`git revert <hash>` 即可。

---

## 待决策（执行前需确认）

> 2026-07-06 已全部确认：
> - §I → A（删除集成指令 + 翻译键 + 用户文档）
> - §D `plans/fix_abc_to_midi.md` → 删除
> - §C `demos/editor_tools_demo.gd` → 删除

无未决项。
