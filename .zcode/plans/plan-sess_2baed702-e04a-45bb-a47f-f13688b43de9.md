# Fuse 子树批量设置输出级别（右键菜单）+ 日志阈值化

## 背景与结论

原型完成后一键把选中节点子树内所有 Fuse 组件的 `log_level` 设为 NONE（或其他级别）。两件事：

1. `FuseLogger.should_log` 改阈值式语义，NONE 放行 ERROR（真错误不静音）
2. 场景树右键菜单加"Fuse: 输出级别"级联子菜单（NONE/WARNING/INFO/DEBUG），递归收集子树内组件批量修改，走 UndoRedo，外部 .tres 与实例化子场景跳过并报告

## 1. FuseLogger 阈值化（`core/logging/fuse_logger.gd`）

枚举 int 值不动（NONE=0/INFO=1/WARNING=2/ERROR=3/DEBUG=4），已序列化的 22 个 .tscn/.tres 完全兼容。新增详细度排名表 + 重写 `should_log`：

```gdscript
## 消息详细度排名（阈值式过滤用，NONE 不进表、单独处理）
const _LEVEL_RANK := {
    LogLevel.ERROR: 1, LogLevel.WARNING: 2, LogLevel.INFO: 3, LogLevel.DEBUG: 4,
}

static func should_log(component_level: LogLevel, message_level: LogLevel) -> bool:
    # NONE 只放行 ERROR：静音组件仍能看到真错误
    if component_level == LogLevel.NONE:
        return message_level == LogLevel.ERROR
    return _LEVEL_RANK.get(message_level, 0) <= _LEVEL_RANK.get(component_level, 0)
```

语义矩阵（写进文档注释）：NONE→仅 ERROR；ERROR→仅 ERROR；WARNING→ERROR+WARNING；INFO→ERROR+WARNING+INFO；DEBUG→全部。
**行为变化（有意修正）**：原"精确匹配"下 INFO 组件看不到 warning/error、WARNING 组件看不到 error，新语义下都能看到。

## 2. 新建 `editor/context_menu/log_level_batch_setter.gd`

`@tool class_name LogLevelBatchSetter extends RefCounted`，照 TriggerMerger 模式（`_init(editor_interface, undo_redo)` 注入依赖）。

**收集逻辑做成 static 纯函数（可 headless 测试）**：

```gdscript
static func collect_components(root: Node, scene_root: Node) -> Dictionary
# 返回 {
#   "applicable": Array[Dictionary]  # {target: Object, holder: Node, current_level: int}
#   "skipped_external": Array[Dictionary]  # {target, path: String}
#   "skipped_nested_count": int,
# }
```

**通用递归遍历**（不维护属性白名单——项目已有 3 份子指令名单互相不同步、17d24ff 刚修过嵌套漏解析的坑，白名单必漏）：

- 节点层：递归子树；`"log_level" in obj` 即视为可收集组件（覆盖 BaseTrigger/Runner/GlobalVariableAssistant 节点）
- 资源层：`get_property_list()` 枚举属性（天然包含 `_get_property_list` 动态注册的如 `EventBinding.conditions`、`loop_instructions`），取值递归：
  - Fuse 类型（BaseEvent/BaseInstruction/BaseCondition/ActionRunner/EventBinding 及有 log_level 的资源）→ 归属判定后记录并继续下钻
  - Array/Dictionary → 逐元素递归
  - 非 Fuse 的 Resource → 不深入（避免钻 SpriteFrames 等引擎资源）
  - **特判 CheckComposite**：钻 `_root_node` 内部类 LogicNode（RefCounted 非 Resource，沿 `.condition` + `.operands[]` 递归）
- visited Set 防环 + 递归深度上限

**归属判定**（两处现有模式）：
- 外部 .tres：`resource_path` 非空且不含 `"::"` → skipped_external（模式抄 `preset_value_codec.gd:169`）
- 实例化子场景：持有节点 `node != scene_root and node.owner != scene_root` → skipped_nested_count（模式抄 `instruction_analyzer.gd:435`）

**apply 实例方法**（照 TriggerMerger undo 模式）：
1. 汇总各选中节点的收集结果 + 备份旧值
2. `create_action("设置 Fuse 输出级别为 %s")` → `add_do_method(_do_apply, targets, level)` / `add_undo_method(_undo_apply, backups)` → `commit_action()`
3. do/undo 对引用 `is_instance_valid()` 防护；undo 恢复各组件旧值
4. 输出面板报告：修改 N 个 / 跳过外部 .tres M 个（列路径）/ 跳过实例内 K 个，提示 Ctrl+S 落盘
5. **不自动保存**（与 merger 一致，避免把其他未保存改动带进落盘）

## 3. 菜单接线（`fuse_context_menu_plugin.gd`）

- `_popup_menu` 末尾：对选中节点跑 `collect_components`，结果缓存到成员变量（回调复用，避免收集两次）；有 applicable 时显示菜单
- 每次**新建** PopupMenu（文档明确 submenu 每次 popup 后被释放），加 4 个级别项，connect `index_pressed`
- `add_context_submenu_item("Fuse: 输出级别", submenu)`（4.7 已确认支持）
- 回调用 `_pending_paths` 解析节点（项目惯例：不用回调参数），调 `LogLevelBatchSetter.apply()`
- `set_editor_plugin` 里实例化 LogLevelBatchSetter；bootstrap 无需改动

## 4. 测试（照 `tests/test_trigger_merger/` 惯例）

- **`tests/core/test_fuse_logger.gd` + `.tscn`**：should_log 全矩阵断言（5 组件级别 × 4 消息级别），重点 NONE 只放 ERROR、INFO 出 i/w/e 不出 DEBUG
- **`tests/test_log_level_batch_setter/` 目录**（.gd + .tscn）：只测 static `collect_components`：
  - 深嵌套：MultiEventTrigger → EventBinding(event + action_runner + conditions[CheckAll/CheckNot 嵌套]) → IfElse(true/false_instructions) + loop_instructions + 指令级 condition → CheckComposite 的 LogicNode 结构，断言全部收集、数量精确
  - 单事件 Trigger（event_definition）、Runner 节点（@export_storage）
  - 实例子场景节点（构造 owner ≠ scene_root）→ skipped_nested
  - 外部资源：user:// 存一个指令 .tres 再加载引用 → skipped_external
  - 互相引用的资源不死循环（visited）
- 两场景结尾 `get_tree().quit(1 if _fail > 0 else 0)` 退出码门禁

## 5. 验证步骤

1. 定位本机 Godot 可执行文件（`where godot` / 常见安装路径）
2. headless 跑两个新测试场景，退出码 0
3. 你在编辑器手动验证：打开 demo 场景（如 `demos/fuse/brick_demo_basic.tscn`）→ 右键节点 → "Fuse: 输出级别" → NONE → 输出面板报告 → Ctrl+S → git diff 确认 `log_level = 0` 落盘 → 运行场景确认常规日志静默、构造一个 error 仍可见 → Ctrl+Z 撤销可用

## 明确不做

- 不改枚举值、不动存量 .tscn/.tres 文件
- 不自动保存场景、不弹确认框（报告留输出面板）
- preset JSON 序列化 / preset_ai_context dump 不受影响（`log_level` 在三处排除表中被过滤；新类非三类组件）
- 硬编码日志调用方（global_variable_manager 等，无 log_level 属性）不在范围内

## 涉及文件

| 操作 | 文件 |
|---|---|
| 修改 | `addons/fuse/core/logging/fuse_logger.gd` |
| 新增 | `addons/fuse/editor/context_menu/log_level_batch_setter.gd` |
| 修改 | `addons/fuse/editor/context_menu/fuse_context_menu_plugin.gd` |
| 新增 | `addons/fuse/tests/core/test_fuse_logger.gd` + `.tscn` |
| 新增 | `addons/fuse/tests/test_log_level_batch_setter/test_log_level_batch_setter.gd` + `.tscn` |