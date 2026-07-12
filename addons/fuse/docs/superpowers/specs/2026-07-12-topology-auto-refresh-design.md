# Topology 可用性改进 — 自动刷新 + 选中保持 + 防抖 + 双击跳转 设计规格

> 日期：2026-07-12
> 状态：设计已批准，待实现
> 范围：Topology 主屏面板自动刷新（场景切换/保存触发 + 选中保持 + 防抖）+ 双击条目跳转 Inspector

---

## 1. 背景与动机

当前 Topology 需**手动点「刷新」按钮**才能更新树和详情。用户痛点：
- 打开/切换场景后，Topology 显示旧场景数据（不知需手动刷新）
- 保存场景后（指令/变量改了），Topology 未更新
- 刷新后选中项丢失（树重建，需重新找）

调研发现 `EditorPlugin.scene_changed` 信号**项目已连接**（fuse_editor_bootstrap.gd:42，刷新 resource_name），Topology 未连。`_save_external_data()` 虚方法可用于保存触发。

---

## 2. 方案

### 2.1 自动刷新触发（plugin.gd）

**触发点 1：场景切换/打开**（scene_changed 信号）
```gdscript
# plugin.gd _enter_tree 中
scene_changed.connect(_on_topology_scene_changed)

func _on_topology_scene_changed(_scene_root: Node) -> void:
    if _topology:
        _topology.request_refresh()  # 防抖刷新
```

**触发点 2：保存场景**（_save_external_data 虚方法）
```gdscript
# plugin.gd override
func _save_external_data() -> void:
    if _topology:
        _topology.request_refresh()  # 防抖刷新
```

**守卫**：`_topology.visible`（未显示时不刷新——_make_visible(false) 后 Topology 隐藏，scene_changed 仍触发但 refresh 无意义）。在 request_refresh 内判断。

### 2.2 防抖（fuse_topology.gd）

用户快速切换场景或连续保存时，避免频繁 refresh（build_topology 扫描全场景，可能耗时）。

```gdscript
var _refresh_timer: SceneTreeTimer = null
const _REFRESH_DEBOUNCE := 0.5  # 秒

## 请求刷新（防抖：0.5s 内多次请求合并为 1 次）
func request_refresh() -> void:
    if not visible:
        return
    if _refresh_timer != null:
        _refresh_timer = null  # 取消前一次（SceneTreeTimer 自动失效）
    _refresh_timer = get_tree().create_timer(_REFRESH_DEBOUNCE)
    _refresh_timer.timeout.connect(_do_refresh, CONNECT_ONE_SHOT)

## 实际执行刷新（防抖后触发）
func _do_refresh() -> void:
    _refresh_timer = null
    var selected_key := _capture_selection()  # 刷新前捕获选中
    refresh()
    _restore_selection(selected_key)  # 刷新后恢复选中
```

**防抖逻辑**：`request_refresh()` 被多次调用时，每次取消前一次的 SceneTreeTimer（设 null，旧 timer timeout 时 _refresh_timer != self → 不执行）。最后一次调用后 0.5s 才真正 `_do_refresh()`。

**注意**：SceneTreeTimer 无 cancel API，用 `_refresh_timer` 引用判断（timeout 回调检查是否仍是当前 timer）。或用 `Timer` Node（有 stop()）。设计用 Timer Node 更可靠：

```gdscript
var _refresh_timer: Timer

func _init():
    _refresh_timer = Timer.new()
    _refresh_timer.one_shot = true
    _refresh_timer.wait_time = _REFRESH_DEBOUNCE
    _refresh_timer.timeout.connect(_do_refresh)
    add_child(_refresh_timer)

func request_refresh() -> void:
    if not visible:
        return
    _refresh_timer.start()  # start() 自动重置（防抖：多次 start 合并）
```

Timer.start() 重置倒计时——多次 request_refresh 在 0.5s 内 → 最后一次 start 后 0.5s 才 timeout → 1 次 _do_refresh。

### 2.3 选中保持（fuse_topology.gd）

**刷新前捕获选中项**（TreeItem → 唯一标识），刷新后恢复。

**选中标识策略**：Trigger 名 + 节点路径（唯一标识选中节点）。指令项用 Trigger 名 + 指令路径（TreeItem 链）。

```gdscript
## 捕获当前选中项的唯一标识
func _capture_selection() -> String:
    var selected := _tree.get_selected()
    if selected == null:
        return ""
    var meta: Dictionary = selected.get_metadata(0)
    var type: String = meta.get("type", "")
    match type:
        "trigger":
            return "trigger:%s" % meta.get("report", {}).get("trigger_name", "")
        "instruction":
            # Trigger 名 + 指令在树中的路径（parent 链）
            return "instruction:%s:%s" % [meta.get("report", {}).get("trigger_name", ""), _get_tree_path(selected)]
        _:
            return ""

## 恢复选中
func _restore_selection(key: String) -> void:
    if key.is_empty():
        return
    var parts := key.split(":", true, 2)
    if parts.size() < 2:
        return
    var type := parts[0]
    var info := parts[1]
    # 遍历 _tree 根项查找匹配
    var root := _tree.get_root()
    if root == null:
        return
    for trigger_item in root.get_children():
        if type == "trigger" and info == str(trigger_item.get_metadata(0).get("report", {}).get("trigger_name", "")):
            trigger_item.select(0)
            _on_item_selected()  # 触发详情更新
            return
        if type == "instruction":
            # 递归找指令
            var found := _find_tree_item_by_path(trigger_item, info)
            if found:
                found.select(0)
                _on_item_selected()
                return
```

**_get_tree_path**：从 TreeItem 向上遍历到 Trigger 根，记录路径（用 get_text(0) 或 metadata）。

---

## 3. 双击条目跳转 Inspector

用户双击 Topology 树中的条目 → Inspector 跳转到对应节点/资源，方便直接编辑。

Godot Tree 有 `item_activated` 信号（双击触发），当前未连。`EditorInterface.edit_node` / `edit_resource` 是标准 API。

### 实现
```gdscript
# _init 连信号
_tree.item_activated.connect(_on_item_activated)

func _on_item_activated() -> void:
    var item := _tree.get_selected()
    if item == null:
        return
    var meta: Dictionary = item.get_metadata(0)
    match meta.get("type", ""):
        "trigger":
            # report.trigger_path = trigger.get_path()（"/root/Scene/..."）
            var path: String = meta.get("report", {}).get("trigger_path", "")
            if not path.is_empty():
                var node := get_tree().get_node_or_null(NodePath(path))
                if node:
                    EditorInterface.edit_node(node)  # 选中节点 + Inspector 显示
        "instruction":
            var inst = meta.get("inst", null)
            if inst is Resource:
                EditorInterface.edit_resource(inst)  # Inspector 显示指令资源
        "binding":
            var binding = meta.get("binding", null)
            if binding is Resource:
                EditorInterface.edit_resource(binding)
```

- **双击 Trigger** → 选中场景中对应 Trigger 节点（Inspector 显示节点属性）
- **双击指令** → Inspector 显示指令 Resource（编辑指令参数）
- **双击 EventBinding** → 同（Resource）

注意：`inst` 是树重建时的 Resource 引用，在树未刷新期间有效。刷新后树重建，inst 更新为新对象。

---

## 4. 不做的事（Out of Scope）

- ❌ 增量刷新（只更新变化的 Trigger）—— 复杂，YAGNI
- ❌ 自动滚动到选中项 —— 后续
- ❌ 刷新进度指示器 —— 后续

---

## 4. 实现规格

### 4.1 plugin.gd 改动
- `_enter_tree`：连 `scene_changed.connect(_on_topology_scene_changed)`
- `_exit_tree`：断开
- 新增 `_on_topology_scene_changed(_scene_root)` → `_topology.request_refresh()`
- override `_save_external_data()` → `_topology.request_refresh()`

### 4.2 fuse_topology.gd 改动
- 新增 `_refresh_timer: Timer`（_init 创建 + add_child）
- 新增 `request_refresh()`（防抖：Timer.start()）
- 新增 `_do_refresh()`（捕获选中 → refresh() → 恢复选中）
- 新增 `_capture_selection() -> String`（TreeItem → 唯一标识）
- 新增 `_restore_selection(key: String)`（遍历树恢复）
- 新增 `_get_tree_path(item) -> String`（TreeItem 链路径）
- `_init` 连 `_tree.item_activated.connect(_on_item_activated)`
- 新增 `_on_item_activated()`（双击 → edit_node / edit_resource）

---

## 5. 验收标准

- [ ] 场景切换（tab 切换/双击打开）→ Topology 自动刷新（0.5s 防抖）
- [ ] 保存场景（Ctrl+S）→ Topology 自动刷新
- [ ] 刷新前选中 Trigger/指令 → 刷新后选中恢复（同名 Trigger/同位指令）
- [ ] Topology 未显示（非 Fuse tab）→ 不刷新（守卫）
- [ ] 快速连续切换（< 0.5s）→ 仅刷新 1 次（防抖）
- [ ] 手动刷新按钮仍可用（不变）
- [ ] 双击 Trigger 项 → Inspector 跳转到场景中对应 Trigger 节点
- [ ] 双击指令项 → Inspector 显示指令 Resource
- [ ] 双击 EventBinding 项 → Inspector 显示 binding Resource
- [ ] 现有 Topology 功能不破坏

---

**下一步**：用户审 spec → writing-plans。
