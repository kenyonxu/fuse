# Stage 9 图标补全 — 实施记录

**日期:** 2026-06-29
**状态:** ✅ 已完成

---

## 1. 审计发现

### 1.1 图标文件缺失

153 个唯一 `builtin_icon` 名中，42 个在 `icons/builtin/` 目录下无对应文件。
这些组件的 `@icon` 装饰器指向不存在文件 → Godot 文件系统中显示默认图标。

缺失清单：`Add`, `Area2D`, `Array`, `ArrowLeft`, `AudioStreamRandomizer`, `Bool`, `Boolean`, `CanvasItem`, `CharacterBody2D`, `Children`, `Code`, `ColorRect`, `Control`, `Dice`, `Dictionary`, `Duplicate`, `Enumeration`, `Get`, `GroupList`, `JSON`, `Keyboard`, `List`, `Max`, `Min`, `NavigationAgent2D`, `Node2D`, `OS`, `OmniLight3D`, `Particles`, `Refresh`, `Remotes`, `ResourcePreloader`, `RigidBody2D`, `Set`, `ShaderMaterial`, `Sort`, `Sprite2D`, `String`, `Terrain3D`, `TimeScreen`, `Vector3i`, `VisibleOnScreenNotifier2D`

### 1.2 语义错误

6 个指令的 `builtin_icon` 取值与功能语义不匹配：

| 文件 | 旧图标 | 问题 |
|------|--------|------|
| `get_group_count.gd` | `Hash` | Hash=字典 |
| `get_child_count.gd` | `Hash` | 同上 |
| `array_size.gd` | `Signal` | Signal=信号 |
| `dict_size.gd` | `Signal` | 同上 |
| `swap_variables.gd` | `Loop` | Loop=循环 |
| `array_random.gd` | `HashArray` | 无语义关联 |

### 1.3 static var 共享 bug

`BaseInstruction.metadata` 是 `static var`，被所有指令实例共享。最后一个调用 `_get_instruction_metadata()` 的类型会覆盖它。

- 组件选择器：直接调 script 静态方法 → 正确 ✓
- 指令列表 (Inspector)：读 `instruction.metadata`（共享 static var）→ 可能显示错误图标 ✗

### 1.4 坏图标

22 个 PNG 文件（EditorTheme 提取）未被任何组件引用，图案相同且无辨识度，全部删除。

### 1.5 API 不一致

- `BaseCondition.get_icon()`：硬编码 `condition.svg`，忽略 metadata
- `BaseEvent.get_event_icon()`：只读 `icon_name`/`icon` 实例变量，不读 metadata
- `BaseInstruction.get_icon()`：正确读 metadata（但受 static var 共享 bug 影响）

---

## 2. 实施方案

### 2.1 at-icons 集成（44 个 SVG）

来源：`addons/at-icons`（本地素材，不提交到仓库）

颜色规则：
- `control/`（绿色）→ Conditions
- `node2d/`（蓝色）→ Instructions
- `node3d/`（红色）→ Events

映射表（42 缺失 + 2 新增）：

| builtin_icon | at-icon 源 | 颜色文件夹 |
|-------------|-----------|-----------|
| Add | plus.svg | node2d |
| Area2D | area.svg | control |
| Array | layers.svg | node2d |
| ArrowLeft | arrow_left.svg | node2d |
| AudioStreamRandomizer | arrow_shuffle.svg | node2d |
| Bool | checkmark_in_square.svg | node2d |
| Boolean | checkmark.svg | node2d |
| CanvasItem | image.svg | node2d |
| CharacterBody2D | human.svg | node2d |
| Children | layers.svg | control |
| Code | script.svg | node2d |
| ColorRect | palette.svg | node2d |
| Control | window.svg | node2d |
| Dice | dice.svg | node2d |
| Dictionary | book.svg | node2d |
| Duplicate | duplicate.svg | node2d |
| Enumeration | dropdown.svg | node2d |
| Get | arrow_down_to_line.svg | node2d |
| GroupList | files.svg | control |
| Groups | layers.svg | node2d |
| JSON | file.svg | node2d |
| Keyboard | keyboard.svg | control |
| List | clipboard.svg | node2d |
| Max | arrow_up.svg | node2d |
| Min | arrow_down.svg | node2d |
| NavigationAgent2D | compass.svg | node2d |
| Node2D | pin.svg | node2d |
| OS | cpu.svg | control |
| OmniLight3D | lightbulb.svg | node2d |
| Particles | emitter.svg | node2d |
| Refresh | arrow_clockwise.svg | node2d |
| Remotes | globe.svg | node2d |
| ResourcePreloader | archive.svg | node2d |
| RigidBody2D | box.svg | node2d |
| Set | arrow_up_to_line.svg | node2d |
| ShaderMaterial | magic_wand.svg | node2d |
| Sort | arrow_down_arrow_up.svg | node2d |
| Sprite2D | image.svg | node2d |
| String | font.svg | node2d |
| Swap | arrow_right_arrow_left.svg | node2d |
| Terrain3D | mountains.svg | control |
| TimeScreen | clock.svg | node2d |
| Vector3i | cube.svg | node2d |
| VisibleOnScreenNotifier2D | eye.svg | control |

### 2.2 修改的文件

**核心基类（4 文件）：**
- `core/base/base_condition.gd` — `get_icon()` 改为从 script 静态方法获取 metadata
- `core/base/base_event.gd` — `get_event_icon()` 同上
- `core/base/base_instruction.gd` — `get_icon()` 修复 static var 共享 bug
- `core/utils/fuse_icon_manager.gd` — 优先级改为 本地文件 > EditorTheme；新增 `.svg`/`.png` 回退

**编辑器（1 文件）：**
- `editor/instruction_selector/instructions_array_property.gd` — 改为调用 `get_icon()`

**组件（~90 处 @icon 修正 + 6 处语义替换）：**
- `@icon` 装饰器：`.png`↔`.svg` 扩展名匹配、4 条件 `condition.svg`→专属图标
- 语义替换：`Hash`→`Groups`/`Children`、`Signal`→`Array`/`Dictionary`、`Loop`→`Swap`、`HashArray`→`Dice`

**工具脚本（3 文件）：**
- `tools/update_instruction_icon_decorators.gd`
- `tools/update_event_icon_decorators.gd`
- `tools/update_condition_icon_decorators.gd`
- 均改为：优先 `.svg`，回退 `.png`

**配置：**
- `.gitignore` — 新增 `addons/at-icons/`

**新增文件：**
- 45 个 `.svg` + 45 个 `.svg.import`（Godot 自动生成）

**删除文件：**
- 23 个 `.png`（1 个同名冲突 `Groups.png` + 22 个坏图标）

### 2.3 最终统计

| 指标 | 值 |
|------|-----|
| 指令 | 174 |
| 事件 | 69 |
| 条件 | 55 |
| SVG 图标 | 45 |
| PNG 图标 | 111 |
| 图标总计 | 156 |
| `@icon` ↔ `builtin_icon` 一致性 | 100% |

---

## 3. 关键技术决策

1. **本地文件优先于 EditorTheme**：`FuseIconManager.get_builtin_icon()` 先查本地文件再查 EditorTheme，确保 at-icons 不被同名 Godot 内置图标覆盖
2. **`get_icon()` 不走 static var**：改为 `get_script()._get_*_metadata()` 直接获取，避免共享状态被覆盖
3. **at-icons 不提交远程**：`addons/at-icons/` 加入 `.gitignore`，仅本地开发用
4. **`.svg` 优先于 `.png`**：图标解析时先找 `.svg`（at-icons），再找 `.png`（EditorTheme 提取）
