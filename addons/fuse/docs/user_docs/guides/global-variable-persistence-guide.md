# 全局变量持久化系统

Fuse 提供全局变量持久化功能，通过 `LoadGlobalVariables` 和 `SaveGlobalVariables` 指令实现游戏存档/读档。

## 组件概览

| 组件 | 类型 | 用途 |
|------|------|------|
| LoadGlobalVariables | 指令 | 从资源文件加载全局变量（读档） |
| SaveGlobalVariables | 指令 | 将全局变量保存到资源文件（存档） |

## 资源文件

持久化使用 `GlobalVariableResource` 资源文件（.tres）存储变量数据。

### 配置资源

1. 在 `GlobalVariableAssistant` 的 `save_load` 配置中设置保存路径
2. 或者手动创建 `GlobalVariableResource` 资源文件

---

## SaveGlobalVariables

将当前全局变量保存到资源文件。

**文件:** [save_global_variables.gd](../../../instructions/variables/save_global_variables.gd)
**分类:** Variables
**图标:** LocalVariable

### 保存目标

| 选项 | 说明 |
|------|------|
| Assistant Resource | 使用 GlobalVariableAssistant 配置的资源路径 |
| Custom Path | 使用自定义路径 |

### 保存范围

| 选项 | 说明 |
|------|------|
| ALL | 保存所有变量 |
| PERSISTENT_ONLY | 仅保存标记为持久化的变量 |

### 属性说明

| 属性 | 类型 | 说明 |
|------|------|------|
| save_target | SaveTarget | 保存目标选择 |
| custom_path | String | 自定义资源路径（仅 Custom Path 时） |
| save_scope | SaveScope | 保存范围 |

---

## LoadGlobalVariables

从资源文件加载全局变量。

**文件:** [load_global_variables.gd](../../../instructions/variables/load_global_variables.gd)
**分类:** Variables
**图标:** LocalVariable

### 加载来源

| 选项 | 说明 |
|------|------|
| Assistant Resource | 使用 GlobalVariableAssistant 配置的资源路径 |
| Custom Path | 使用自定义路径 |

### 属性说明

| 属性 | 类型 | 说明 |
|------|------|------|
| load_source | LoadSource | 加载来源选择 |
| custom_path | String | 自定义资源路径（仅 Custom Path 时） |

---

## 使用流程

### 方式一：使用 Assistant 配置（推荐）

在 `GlobalVariableAssistant` 资源中配置保存路径：

```
GlobalVariableAssistant (Resource)
├── save_load/
│   ├── save_path: "user://saves/game_save.tres"
│   └── auto_save_enabled: true
```

然后直接使用指令：

```
Trigger: GameStart
│
└── LoadGlobalVariables
    load_source: Assistant Resource

Trigger: GameExit (或自动保存)
│
└── SaveGlobalVariables
    save_target: Assistant Resource
    save_scope: ALL (或 PERSISTENT_ONLY)
```

### 方式二：使用自定义路径

```
Trigger: SaveGame (玩家按下快捷键)
│
└── SaveGlobalVariables
    save_target: Custom Path
    custom_path: "user://saves/save_slot_1.tres"
    save_scope: ALL

Trigger: LoadGame (读取存档)
│
└── LoadGlobalVariables
    load_source: Custom Path
    custom_path: "user://saves/save_slot_1.tres"
```

---

## 完整示例

### 多存档槽位

```
Trigger: SaveGame (快捷键 S)
│
├── SaveGlobalVariables
│   save_target: Custom Path
│   custom_path: "user://saves/save_01.tres"
│   save_scope: PERSISTENT_ONLY
│
└── LogInstruction
    message: "游戏已保存到存档槽 1"

Trigger: LoadGame_Slot1 (快捷键 L)
│
├── LoadGlobalVariables
│   load_source: Custom Path
│   custom_path: "user://saves/save_01.tres"
│
└── LogInstruction
    message: "已从存档槽 1 读取游戏"
```

### 自动保存

在 `GlobalVariableAssistant` 中启用自动保存：

```
GlobalVariableAssistant (Resource)
├── save_load/
│   ├── save_path: "user://saves/autosave.tres"
│   └── auto_save_enabled: true
│   └── auto_save_interval: 300.0  # 5分钟自动保存
```

---

## 持久化变量标记

只有标记为 `persistent` 的变量才会被 `PERSISTENT_ONLY` 模式保存。

### 在 GlobalVariableResource 中标记

```
GlobalVariableResource (Inspector)
├── variables/
│   ├── hp: 100 (persistent: true)
│   ├── max_hp: 100 (persistent: true)
│   ├── score: 0 (persistent: true)
│   └── temp_timer: 0 (persistent: false)  # 不保存
```

### 使用变量指令设置持久化

```
SetVariable
variable_name: "score"
value: 100
is_persistent: true
```

---

## 注意事项

- `custom_path` 支持 `user://` 协议，会保存到用户数据目录
- 确保目标目录存在，`SaveGlobalVariables` 不会自动创建目录
- 加载时如果文件不存在会报错，确保存档文件已创建
- 建议使用 `PERSISTENT_ONLY` 避免保存临时状态（如冷却计时器）

---

## 错误处理

如果保存/加载失败，指令会输出错误日志。常见问题：

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| 文件不存在 | 加载时文件未创建 | 先保存再加载 |
| 路径无效 | 自定义路径格式错误 | 使用 `user://saves/xxx.tres` 格式 |
| 权限不足 | 无法写入目录 | 检查目录权限 |

---

**相关文档:**
- [全局变量管理器 V2](global_variable_manager_v2.md)
- [变量系统 V2 迁移](../../archive/archive/variable_system_v2_migration.md)
