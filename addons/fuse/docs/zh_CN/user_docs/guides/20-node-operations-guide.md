> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/20-node-operations-guide.md)

# Node Operations 指令指南

## 概述

Node Operations 提供 **21 个指令**，用于在运行时操作节点树，覆盖场景实例化、节点查找、组操作、生命周期管理、属性控制、通信和高级操作。所有指令位于 `instructions/node_operations/` 目录。

| 分类 | 指令数 | 指令名称 |
|------|--------|---------|
| 场景实例化 | 3 | InstantiateScene、RecyclePooledScene、WarmUpPool |
| 节点查找与枚举 | 7 | FindNode、GetAllChildren、GetAllChildrenPosition、GetChildByIndex、GetLastChild、GetRandomChild、GetChildCount |
| 组操作 | 2 | GetNodesInGroup、GetGroupCount |
| 节点生命周期 | 3 | CloneNode、QueueFreeNode、ReparentNode |
| 节点属性 | 3 | SetPropertyValue、SetGlobalPosition、SetProcessMode |
| 节点控制 | 2 | EnableDisableNode、EmitSignal |
| 高级操作 | 1 | RunTargetNodeFunction |

---

## 场景实例化

### InstantiateScene

**文件：** `instructions/node_operations/instantiate_scene.gd`
**class_name：** InstantiateScene

从场景路径动态实例化场景。支持对象池、位置模式、变量引用等。

| 参数 | 类型 | 说明 |
|------|------|------|
| `scene_path` | String | 待实例化的场景路径（.tscn） |
| `parent_node` | NodePath | 实例化后的父节点（可选，默认当前场景） |
| `position_mode` | PositionMode | 位置来源：`MANUAL`（手动指定）或 `VARIABLE`（从变量读取） |
| `spawn_position` | Vector3 | 手动生成位置（position_mode=MANUAL 时） |
| `position_variable` | String | 位置变量名（position_mode=VARIABLE 时） |
| `position_scope` | VariableScope | 位置变量作用域 |
| `spawn_offset` | Vector3 | 生成位置偏移 |
| `save_instance_id` | bool | 是否保存实例 ID 到变量 |
| `target_variable` | String | 实例 ID 目标变量名 |
| `save_to_scope` | VariableScope | 实例 ID 保存作用域 |
| `use_object_pool` | bool | 是否使用对象池 |
| `pool_initial_size` | int | 池初始大小（默认 20） |
| `pool_max_size` | int | 池最大大小（默认 100） |

**位置配置：** 通过 `position_mode` 选择手动坐标或从变量读取，支持 `spawn_offset` 偏移量。

**对象池复用：** 启用 `use_object_pool` 后，实例化前会先尝试从对象池取用。

### RecyclePooledScene

**文件：** `instructions/node_operations/recycle_pooled_scene.gd`
**class_name：** RecyclePooledScene

将已实例化的场景回收到对象池，而非直接删除。回收后的对象可被 `InstantiateScene` 复用。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 要回收的节点 |

### WarmUpPool

**文件：** `instructions/node_operations/warm_up_pool.gd`
**class_name：** WarmUpPool

预先在对象池中创建指定数量的场景实例，减少运行时实例化卡顿。

| 参数 | 类型 | 说明 |
|------|------|------|
| `scene_path` | String | 场景路径 |
| `pool_size` | int | 预创建数量 |

---

## 节点查找与枚举

### FindNode

**文件：** `instructions/node_operations/find_node.gd`
**class_name：** FindNode

按条件在场景树中查找节点，支持三种搜索维度。

| 参数 | 类型 | 说明 |
|------|------|------|
| `search_type` | SearchType | `BY_NAME`（按名称）、`BY_TYPE`（按类型）、`BY_GROUP`（按组） |
| `search_value` | String | 搜索值（名称/类型名/组名） |
| `search_scope` | SearchScope | 搜索范围：`CHILDREN`（子节点）、`SCENE`（当前场景）、`GLOBAL`（全场景树） |
| `recursive` | bool | 是否递归查找（默认 true） |
| `first_match_only` | bool | 是否只返回第一个匹配项（默认 true） |
| `result_variable` | String | 结果保存的变量名 |
| `result_scope` | VariableScope | 结果变量作用域（Local/Scope/Global） |
| `error_handling` | ErrorHandling | 未找到时：`STRICT`（记录错误）/ `SILENT`（静默）/ `WARNING`（记录警告） |

### GetAllChildren

**文件：** `instructions/node_operations/get_all_children.gd`
**class_name：** GetAllChildren

获取节点的所有直接子节点，结果保存到变量数组。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target` | NodePath | 目标节点 |
| `save_to_scope` | String | 保存数组的变量名 |
| `scope_source` | ScopeSource | 作用域来源 |

### GetAllChildrenPosition

**文件：** `instructions/node_operations/get_all_children_position.gd`
**class_name：** GetAllChildrenPosition

获取所有直接子节点的位置信息，返回包含节点名和位置的 Dictionary 数组。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target` | NodePath | 目标节点 |
| `save_to_scope` | String | 保存的变量名 |
| `scope_source` | ScopeSource | 作用域来源 |

### GetChildByIndex

**文件：** `instructions/node_operations/get_child_by_index.gd`
**class_name：** GetChildByIndex

按索引获取子节点（支持正负索引，负值从末尾计数）。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target` | NodePath | 目标节点 |
| `index` | int | 子节点索引 |
| `save_to_scope` | String | 保存的变量名 |
| `scope_source` | ScopeSource | 作用域来源 |

### GetLastChild

**文件：** `instructions/node_operations/get_last_child.gd`
**class_name：** GetLastChild

获取最后一个子节点（`get_child(get_child_count() - 1)`）。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target` | NodePath | 目标节点 |
| `save_to_scope` | String | 保存的变量名 |
| `scope_source` | ScopeSource | 作用域来源 |

### GetRandomChild

**文件：** `instructions/node_operations/get_random_child.gd`
**class_name：** GetRandomChild

随机获取一个子节点。适用于随机奖励、随机敌人生成等。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target` | NodePath | 目标节点 |
| `save_to_scope` | String | 保存的变量名 |
| `scope_source` | ScopeSource | 作用域来源 |

### GetChildCount

**文件：** `instructions/node_operations/get_child_count.gd`
**class_name：** GetChildCount

获取直接子节点数量，结果保存到变量。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target` | NodePath | 目标节点 |
| `save_to_scope` | String | 保存的变量名 |
| `scope_source` | ScopeSource | 作用域来源 |

---

## 组操作

### GetNodesInGroup

**文件：** `instructions/node_operations/get_nodes_in_group.gd`
**class_name：** GetNodesInGroup

获取指定组中的所有节点，结果保存为变量数组。

| 参数 | 类型 | 说明 |
|------|------|------|
| `group_name` | String | 组名称 |
| `save_to_scope` | String | 保存的变量名 |
| `scope_source` | ScopeSource | 作用域来源 |

### GetGroupCount

**文件：** `instructions/node_operations/get_group_count.gd`
**class_name：** GetGroupCount

获取指定组中的节点数量。

| 参数 | 类型 | 说明 |
|------|------|------|
| `group_name` | String | 组名称 |
| `save_to_scope` | String | 保存的变量名 |
| `scope_source` | ScopeSource | 作用域来源 |

---

## 节点生命周期

### CloneNode

**文件：** `instructions/node_operations/clone_node.gd`
**class_name：** CloneNode

克隆一个节点及其子节点（`Node.duplicate()`）。可选择是否保留变量引用。

| 参数 | 类型 | 说明 |
|------|------|------|
| `source_node` | NodePath | 源节点 |
| `parent_node` | NodePath | 克隆后的父节点（可选，默认同父） |
| `preserve_variables` | bool | 是否保留变量数据 |

### QueueFreeNode

**文件：** `instructions/node_operations/queue_free_node.gd`
**class_name：** QueueFreeNode

将节点加入删除队列（`queue_free()`），在当前帧结束后安全删除。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 要删除的节点 |

### ReparentNode

**文件：** `instructions/node_operations/reparent_node.gd`
**class_name：** ReparentNode

将节点从一个父节点移动到另一个父节点。支持保持全局变换。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 要移动的节点 |
| `new_parent` | NodePath | 新的父节点 |
| `keep_global_transform` | bool | 是否保持全局位置/旋转/缩放不变 |

---

## 节点属性控制

### SetPropertyValue

**文件：** `instructions/node_operations/set_property_value.gd`
**class_name：** SetPropertyValue

设置节点的任意属性值。支持从变量读取目标值。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标节点 |
| `target_property` | String | 属性名称 |
| `new_value` | Variant | 属性值（直接值模式） |
| `set_with_variable` | bool | 是否从变量读取值 |
| `variable_name` | String | 值变量名（变量模式） |
| `variable_scope` | VariableScope | 变量作用域（Local/Scope/Global） |

### SetGlobalPosition

**文件：** `instructions/node_operations/set_global_position.gd`
**class_name：** SetGlobalPosition

直接设置节点的全局位置（`global_position`），忽略父节点变换。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标节点 |
| `position` | Vector2/Vector3 | 目标全局位置 |
| `use_variable` | bool | 是否从变量读取位置 |
| `position_variable` | String | 位置变量名 |
| `position_scope` | ScopeSource | 变量作用域 |

### SetProcessMode

**文件：** `instructions/node_operations/set_process_mode.gd`
**class_name：** SetProcessMode

设置节点的处理模式（`process_mode`），控制节点是否接收 `_process` / `_physics_process` 回调。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标节点 |
| `process_mode` | ProcessMode | Godot ProcessMode 枚举值 |

### EnableDisableNode

**文件：** `instructions/node_operations/enable_disable_node.gd`
**class_name：** EnableDisableNode

启用或禁用节点（`process_mode` + `visible` 组合控制）。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标节点 |
| `enabled` | bool | 启用/禁用 |

---

## 节点通信

### EmitSignal

**文件：** `instructions/node_operations/emit_signal.gd`
**class_name：** EmitSignal

在指定节点上发射信号。可用于自定义节点间的消息通信。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 发射信号的节点 |
| `signal_name` | String | 信号名称 |
| `argument_count` | int | 信号参数数量（0-5） |
| `arg0` ~ `arg4` | Variant | 信号参数值 |
| `use_variables` | bool | 是否从变量读取参数 |

---

## 高级操作

### RunTargetNodeFunction

**文件：** `instructions/node_operations/run_target_node_function.gd`
**class_name：** RunTargetNodeFunction

在目标节点上动态调用指定方法。支持参数传递和返回值捕获。参数使用动态绑定系统，自动适配实际方法签名。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标节点 |
| `target_function` | String | 方法名称 |
| `store_result` | bool | 是否捕获返回值 |
| `result_variable_name` | String | 返回值保存的变量名 |
| `result_variable_scope` | VariableScope | 返回值变量作用域（Local/Scope/Global） |
| `param_0` ~ `param_N` | Variant | 动态参数（根据选中方法的签名自动生成） |

---

## 常见用例

### 运行时动态创建敌人

```
Trigger: OnInterval (每 3 秒)
├── InstantiateScene
│   scene_path: "res://enemies/goblin.tscn"
│   parent_node: "/root/Game/EnemyContainer"
│   use_variable: false
└── SetPosition
    target_node: (上一行结果)
    position: (随机位置)
    space: Global
```

### 场景切换时转移节点

```
Trigger: OnSignalFromGroup (scene_manager, "switching_scene")
├── FindNode
│   search_type: BY_NAME
│   search_value: "PlayerHUD"
│   scope: SCENE_TREE
├── ReparentNode
│   target_node: (找到的 HUD)
│   new_parent: "/root/NewScene/UI"
│   keep_global_transform: true
└── LogInstruction
    message: "HUD 已转移到新场景"
```

### 批量查找子节点

```
Trigger: OnReady
├── GetAllChildren
│   target: "/root/Game/ItemContainer"
│   save_to_scope: "items"
├── ForEach
│   array: {scope:items}
│   └── RunTargetNodeFunction
│       target_node: (当前元素)
│       function_name: "collect"
```

---

## 注意事项

- **节点路径 vs 变量引用**：多数指令既支持 NodePath 也支持变量中的节点引用。路径更稳定，引用性能更好。
- **实例化后延迟引用**：`InstantiateScene` 返回的节点在当前指令序列中即可使用，无需等待帧循环。
- **组名大小写**：Godot 组名区分大小写，保持一致。
- **QueueFreeNode 不会立即删除**：节点在当前帧结束后才被释放，之后引用该节点会导致错误。
