# Fuse 变量监视器 V1 设计文档

**日期:** 2026-06-17
**状态:** 设计完成,待审核
**关联:** [Fuse 新特性路线图](../roadmap/20206-03-20-future-features-roadmap.md)、[Fuse 推进路线图](../roadmap/2026-06-16-fuse-development-roadmap.md) Stage 2c

---

## 1. 核心目标

运行时 Bottom Dock 面板,以 0.5s 间隔轮询场景树中所有活跃 Runner,通过 EC 三层门面(VariableContext)读取 local/scope/global 变量,实时显示变量名+值+类型。V1 只读,V2 加编辑和折线图。

---

## 2. 架构

### 2.1 数据流

```
Timer (0.5s)
  ↓
遍历场景树 → find_children("*","Runner")
  ↓
Runner.current_execution_context (新增公开属性)
  ↓
EC._variable_context
  ├── get_all_local_variables_snapshot()   → Dictionary
  ├── get_all_scope_variables_snapshot()   → Dictionary
  └── (global 另路: GlobalVariableService)
  ↓
变量监视器 UI 刷新
```

### 2.2 全局变量

全局变量不走 EC(不属于单个 Runner),直接调 `GlobalVariableService.new().get_all_global_variables_info()`,返回 `{name: {value, type, persistent}}`。

### 2.3 Runner 改动(2 行)

`runner.gd` 新增公开属性,供变量监视器读取:

```gdscript
## 当前执行上下文(运行时设置,变量监视器读取)
var current_execution_context: ExecutionContext = null
```

在 `run()` 方法中(行 311 后):

```gdscript
current_execution_context = execution_context
```

> 执行完成后 EC 被 cleanup(),`current_execution_context` 仍指向旧引用但变量为空。变量监视器检查 `ec._variable_context.local_variables.is_empty()` 判断是否活跃。也可在 Runner 完成回调中清空(可选优化)。

### 2.4 刷新策略

- **频率:** 0.5 秒 `Timer`
- **开销控制:** 仅刷新当前可见的 Runner(每个 Runner 调 3 次快照,单次耗时 <1ms;50 个 Runner 约 50ms,远低于 500ms 间隔)
- **去重:** 同一 Runner 不重复处理;Runner 的 EC 为 null 时跳过
- **编辑器外:** 变量监视器仅在 `Engine.is_editor_hint() == false` 时活跃(运行时使用)。编辑器内也可以通过 Godot 的"运行当前场景"使用

---

## 3. UI 设计

### 3.1 入口

`plugin.gd` 在 `_enter_tree()` 中添加 Bottom Dock:

```gdscript
var _watcher: FuseVariableWatcher = null

# 在 EditorBootstrap 或 RuntimeBootstrap 末尾:
_watcher = preload("res://addons/fuse/editor/debugging/variable_watcher.gd").new()
add_control_to_bottom_panel(_watcher, "Fuse Variables")
```

### 3.2 UI 布局

```
┌─────────────────────────────────────────┐
│ 变量监视器          刷新:0.5s  Runner:2 │
├─────────────────────────────────────────┤
│ 🔍 搜索变量...                          │
├─────────────────────────────────────────┤
│ ▾ Local (3)                             │
│   temp_score    100       int           │
│   count          3        int           │
│   is_active     true      bool          │
│ ▾ Scope (1)                             │
│   player_health  85.5     float         │
│ ▾ Global (2)                            │
│   game_level     5        int           │
│   high_score     9999     int           │
├─────────────────────────────────────────┤
│ 当前: Trigger "PlayBGM"    [📌固定] [📸快照] │
└─────────────────────────────────────────┘
```

- 三段折叠:Local / Scope / Global(用 `Tree` 控件,可折叠的 root item)
- 每行:变量名 | 值 | 类型
- 搜索框:实时过滤变量名
- 底部状态栏:当前选中的 Runner 名称
- "📸快照"按钮:导出当前变量快照 JSON(为 Stage 5 录播预留)

### 3.3 实现类

`addons/fuse/editor/debugging/variable_watcher.gd`:

```gdscript
@tool
class_name FuseVariableWatcher
extends Control

var _timer: Timer
var _refresh_interval: float = 0.5
var _tree: Tree
var _search_input: LineEdit
var _status_label: Label
var _selected_runner: String = ""


func _init() -> void:
    # 创建 UI 布局
    # 创建 Timer
    _timer = Timer.new()
    _timer.wait_time = _refresh_interval
    _timer.timeout.connect(_refresh)
    add_child(_timer)
    _timer.start()


func _refresh() -> void:
    # 清空 tree
    # 遍历场景树找 Runner
    # 对每个活跃 Runner 读取快照 → 填充 tree
    # 全局变量单独一 zone


func get_snapshot() -> Dictionary:
    ## 返回序列化快照(为 Stage 5 录播预留)
    return {
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "runners": [...]
    }
```

---

## 4. 快照格式(Stage 5 录播预留)

变量监视器的 `get_snapshot()` 返回完整变量快照,Stage 5 指令录播直接复用此格式:

```json
{
  "timestamp": 1706000100.5,
  "runners": [
    {
      "runner": "PlayBGM",
      "execution_id": "exec_17060000_12345",
      "local": {"temp_score": {"value":100, "type":"int"}},
      "scope": {"player_health": {"value":85.5, "type":"float"}},
      "global": {"game_level": {"value":5, "type":"int"}}
    }
  ]
}
```

> Stage 5 录播可定时(0.1s间隔)调用 `get_snapshot()` 生成快照序列,用于回放。

---

## 5. 不做什么(V1)

- ❌ 运行时修改变量(双击编辑) → V2
- ❌ 历史折线图 → V2
- ❌ 自定义监视列表(用户添加特定变量) → V2
- ❌ 变量 diff 高亮(值变化时闪烁)
- ❌ 跨帧变量比较

---

## 6. 依赖关系

| 依赖 | 状态 | 说明 |
|------|:---:|------|
| Runner 暴露 EC | 🔧 需改动 | `runner.gd` +2 行(`current_execution_context`) |
| EC 三层快照 API | ✅ 已有 | Phase 4 VariableContext 的 `get_all_*_snapshot()` |
| GlobalVariableService | ✅ 已有 | Phase 3 实现 |
| Bottom Dock 注册 | ✅ 已有 | `EditorPlugin.add_control_to_bottom_panel()` |

---

## 7. 验收标准

- [ ] Godot 运行场景时,底部出现"Fuse Variables"面板
- [ ] 0.5s 间隔自动刷新变量显示
- [ ] 三层作用域(Local/Scope/Global)分类折叠显示
- [ ] 变量显示:名称+值+类型
- [ ] 搜索框过滤变量名
- [ ] 无活跃 Runner 时显示"(无活跃 Runner)"
- [ ] 有多个 Runner 时全部显示
- [ ] "📸快照"按钮导出完整 JSON
- [ ] Runner 新增 `current_execution_context` 属性,不影响现有执行逻辑

---

**文档版本:** 1.0
**最后更新:** 2026-06-17
**审核状态:** 待审核
