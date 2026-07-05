# Bricks → Fuse 重命名计划

## 决策摘要

| 项目 | 内容 |
|------|------|
| 新名称 | **Fuse** |
| 插件全名 | Fuse Visual Programming |
| 简称 | Fuse |
| 原因 | Godot Asset Library 已有 "Logic Bricks" 插件（BriThe3DGuy），避免用户混淆 |
| 风格 | 简短有力，与 Juicy 品牌风格兼容 |
| 品牌含义 | Fuse（融合）— 将 Events/Instructions/Conditions 连接融合；Fuse（点燃/触发）— 引爆事件链反应 |

## 重命名范围

| 维度 | 数量 |
|------|------|
| `bricks` 出现次数（不区分大小写） | ~13,449 次 / 324 文件 |
| `BRICKS_` 本地化键 | ~825 次 |
| `Bricks*` class_name | 18 个 |
| `bricks_*` 文件名 | ~37 个 |
| 引用 `addons/bricks/` 的 .tscn 文件 | 155 个 |
| demos/bricks/ 文件 | 37 个 |
| addons/bricks/ 子目录 | 14 个 |

## 跨插件依赖

- **juicy_mixer**: 无任何 `bricks` 引用 ✅ 完全解耦
- **sound_manager**: 待检查（如有引用需同步更新）
- **demos/**: 多个 demo 文件引用 `addons/bricks/`

---

## 执行阶段

### Phase 1: 目录与配置（低风险）

**目标**: 重命名顶层目录和插件配置

1. 重命名目录
   - `addons/bricks/` → `addons/fuse/`
   - `demos/bricks/` → `demos/fuse/`
   - `demos/brick_debug.tscn` → `demos/fuse_debug.tscn` （如有）
   - `demos/bricks_juicy_demo.tscn` → `demos/fuse_juicy_demo.tscn`（如有）

2. 更新 `addons/fuse/plugin.cfg`
   ```
   name="Fuse Visual Programming"
   description="A visual programming system for Godot 4.x"
   author="Fuse Team"
   ```

3. 更新图标路径
   - `addons/fuse/icons/bricks_icon.svg` → `addons/fuse/icons/fuse_icon.svg`
   - 更新 plugin.cfg 中的 icon path

4. 删除旧 `.uid` 文件（Godot 会自动重新生成）
   - 所有 `*.gd.uid` 文件需在 Godot 重新导入后重新生成

---

### Phase 2: class_name 与文件名（中风险）

**目标**: 重命名所有 `Bricks*` class_name 和 `bricks_*` 文件

#### 2.1 class_name 映射表

| 原名 | 新名 |
|------|------|
| `BricksLocalization` | `FuseLocalization` |
| `BricksNodeUtils` | `FuseNodeUtils` |
| `BricksPerformanceTracker` | `FusePerformanceTracker` |
| `BricksIconManager` | `FuseIconManager` |
| `BricksIconLibrary` | `FuseIconLibrary` |
| `BricksMetadata` | `FuseMetadata` |
| `BricksContextMenuPlugin` | `FuseContextMenuPlugin` |
| `BricksThreadSafe` | `FuseThreadSafe` |
| `BricksThreadingConfig` | `FuseThreadingConfig` |
| `BricksTaskManager` | `FuseTaskManager` |
| `BricksEventBus` | `FuseEventBus` |
| `BricksAudioContainer` | `FuseAudioContainer` |
| `BricksPoolManager` | `FusePoolManager` |
| `BricksObjectPool` | `FuseObjectPool` |
| `BricksPoolItem` | `FusePoolItem` |
| `BricksRecycleTimer` | `FuseRecycleTimer` |
| `BricksLogger` | `FuseLogger` |
| `BricksError` | `FuseError` |
| `BrickButton` | `FuseButton` |

#### 2.2 文件名映射表（GDScript）

| 原路径 | 新路径 |
|--------|--------|
| `bricks_localization.gd` | `fuse_localization.gd` |
| `bricks_node_utils.gd` | `fuse_node_utils.gd` |
| `bricks_icon_manager.gd` | `fuse_icon_manager.gd` |
| `bricks_icon_library.gd` | `fuse_icon_library.gd` |
| `bricks_metadata.gd` | `fuse_metadata.gd` |
| `bricks_inspector_plugin.gd` | `fuse_inspector_plugin.gd` |
| `bricks_context_menu_plugin.gd` | `fuse_context_menu_plugin.gd` |
| `bricks_thread_safe.gd` | `fuse_thread_safe.gd` |
| `bricks_task_manager.gd` | `fuse_task_manager.gd` |
| `bricks_threading_config.gd` | `fuse_threading_config.gd` |
| `bricks_event_bus.gd` | `fuse_event_bus.gd` |
| `bricks_audio_container.gd` | `fuse_audio_container.gd` |
| `bricks_pool_manager.gd` | `fuse_pool_manager.gd` |
| `bricks_object_pool.gd` | `fuse_object_pool.gd` |
| `bricks_pool_item.gd` | `fuse_pool_item.gd` |
| `bricks_recycle_timer.gd` | `fuse_recycle_timer.gd` |
| `bricks_logger.gd` | `fuse_logger.gd` |
| `bricks_error.gd` | `fuse_error.gd` |
| `brick_button.gd` | `fuse_button.gd` |

#### 2.3 文件名映射表（文档/资源）

| 原路径 | 新路径 |
|--------|--------|
| `bricks_optimization_*.md` | `fuse_optimization_*.md` |
| `bricks_architecture_*.md` | `fuse_architecture_*.md` |
| `bricks_core_analysis_report.md` | `fuse_core_analysis_report.md` |

#### 2.4 代码内引用更新

所有 GDScript 文件中的以下引用需批量替换：
- `BricksLocalization` → `FuseLocalization`
- `BricksNodeUtils` → `FuseNodeUtils`
- `BricksMetadata` → `FuseMetadata`
- ...（所有 class_name 引用）
- 注释中的 `Bricks` / `bricks` → `Fuse` / `fuse`
- 字符串中的 `bricks` → `fuse`（需人工审核，避免误改）

---

### Phase 3: 本地化（中风险）

**目标**: 重命名所有本地化键前缀

1. `BRICKS_*` → `FUSE_*` 全局替换
   - `addons/fuse/localization/translations.csv`
   - 所有引用 `BRICKS_` 键的 `.gd` 文件

2. 更新本地化系统代码
   - `fuse_localization.gd` 中的键前缀
   - `translation_keys.md` 文档
   - `translation_checker.gd` 工具

3. 本地化键映射示例
   ```
   BRICKS_PLUGIN_NAME → FUSE_PLUGIN_NAME
   BRICKS_PLUGIN_DESCRIPTION → FUSE_PLUGIN_DESCRIPTION
   BRICKS_INSTRUCTION_* → FUSE_INSTRUCTION_*
   BRICKS_EVENT_* → FUSE_EVENT_*
   BRICKS_CONDITION_* → FUSE_CONDITION_*
   BRICKS_ERROR_* → FUSE_ERROR_*
   BRICKS_LOG_* → FUSE_LOG_*
   ```

---

### Phase 4: 场景文件（高风险）

**目标**: 更新所有 .tscn 文件中的路径引用

1. 路径替换
   - `res://addons/bricks/` → `res://addons/fuse/`
   - `addons/bricks/` → `addons/fuse/`

2. 涉及 155 个 .tscn 文件，包括：
   - `addons/fuse/tests/` 下的测试场景
   - `demos/fuse/` 下的演示场景
   - `demos/fuse/brickian/` 子目录
   - `demos/juicy_audio_demo.tscn`（如引用 bricks）

3. NodePath 引用检查
   - 场景中的 `[ext_resource]` 路径
   - 脚本引用路径

4. 刷新 `.import` 和 `.uid` 文件
   - 在 Godot 中打开项目，触发自动重新导入

---

### Phase 5: 文档与品牌（低风险）

**目标**: 更新所有文档和品牌相关内容

1. 插件内文档
   - `addons/fuse/docs/` 下所有 `.md` 文件中的 "Bricks" → "Fuse"
   - `addons/fuse/localization/` 下文档
   - `addons/fuse/editor/` 下文档

2. 项目级文档
   - `CLAUDE.md` — Bricks 系统描述
   - `docs/plans/` 下历史文档（仅标注，不改名）
   - `docs/development/` 下文档

3. Demo 文件名（可选，品牌统一）
   - `demos/fuse/brickian/` → `demos/fuse/fuseian/`（或保留，作为 demo 名字）
   - `demos/fuse/brick_demo_*.tscn` → `demos/fuse/fuse_demo_*.tscn`
   - `demos/fuse/brick_test*.tscn` → `demos/fuse/fuse_test*.tscn`
   - `demos/fuse/brick_expressions.tscn` → `demos/fuse/fuse_expressions.tscn`

4. 技能文件（Claude Code）
   - `/bricks-instruction-generator` → `/fuse-instruction-generator`
   - `/bricks-event-generator` → `/fuse-event-generator`
   - `/bricks-condition-generator` → `/fuse-condition-generator`
   - `/brick_event_runtime_instance_migration` — 更新描述

5. CLAUDE.md 更新
   - "Bricks" → "Fuse" 在所有引用中
   - 系统描述更新
   - 技能引用更新

---

### Phase 6: 验证

**目标**: 确保重命名后一切正常

1. Godot 项目验证
   - [ ] 打开 Godot 项目，无错误
   - [ ] 插件在 Project → Project Settings → Plugins 中显示为 "Fuse Visual Programming"
   - [ ] 所有场景文件加载正常（无 missing resource 警告）

2. 功能测试
   - [ ] Trigger 节点可正常创建和配置
   - [ ] Event/Instruction/Condition 选择器正常工作
   - [ ] 本地化显示正确（中文/英文）
   - [ ] 断点调试系统正常
   - [ ] 对象池系统正常

3. 运行测试场景
   - [ ] `addons/fuse/tests/` 下关键测试通过
   - [ ] `demos/fuse/` 下演示场景可运行

4. 跨插件集成
   - [ ] `play_juicy_mixer_feedback.gd` 中的 JuicyMixer 集成正常

---

## 风险与缓解

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| .uid 文件失效 | 高 | 删除旧 .uid，让 Godot 重新生成 |
| .import 文件失效 | 中 | 删除旧 .import，重新导入资源 |
| 场景资源丢失 | 高 | 使用 Godot 打开项目触发自动修复；提前 git commit |
| 字符串中误改 "bricks" | 中 | 仅替换代码引用，翻译字符串人工审核 |
| 历史 plan 文档混淆 | 低 | 历史文档不改名，仅标注 "原 Bricks 系统" |

## 执行前检查清单

- [ ] 创建新分支 `refactor/bricks-to-fuse`
- [ ] 确保当前代码已提交，无未保存更改
- [ ] 备份 `.uid` 文件列表（可选，用于比对）
- [ ] 准备好新的 Fuse 图标（SVG）

## 注意事项

1. **`demos/bricks/brickian/`** — 这是 demo 游戏名字（"Brickian" = 打砖块），可以保留不变
2. **历史 plan 文档** — `docs/plans/` 下大量文件名含 "bricks"，建议不改名，仅在内容中标注
3. **Git 历史** — 重命名会破坏 `git log --follow`，考虑使用 `git mv` 保留历史
4. **Asset Library 发布** — 重命名后需要作为新插件提交（或联系 Asset Library 管理员更名）

---

**创建日期**: 2026-03-23
**状态**: 待执行
**预计改动文件**: ~350+
