# 实现计划：全局变量资源加载/保存指令

> **版本：** v2（修订版）
> **修订内容：** 修正评估中发现的 6 项问题

## 需求重述

Bricks 可视化编程系统目前缺少两个关键指令：

1. **LoadGlobalVariables** - 从 GlobalVariableAssistant 关联的资源文件中加载全局变量到内存（运行时重新加载）
2. **SaveGlobalVariables** - 将运行时内存中的全局变量保存回 GlobalVariableAssistant 关联的资源文件

**使用场景：**
- 游戏运行时重新加载存档数据（LoadGlobalVariables）
- 手动触发存档保存（SaveGlobalVariables）
- 在关键节点（如关卡完成、退出前）确保变量持久化

## 架构分析

### 现有调用链

```
GlobalVariableAssistant (Node, 场景中)
    ├── resource_path: String      # 关联的资源文件路径
    ├── current_resource: Resource  # 关联的资源引用
    ├── load_resource(path)        # 通过 Manager 加载
    ├── save_current_resource()    # 通过 Manager 保存
    └── save_persistent_variables() # 保存持久化变量

GlobalVariableManager (RefCounted, 单例)
    ├── _variables: Dictionary      # 内存中的全局变量
    ├── load_from_resource(path)    # 从文件加载到内存（内部硬编码清空）
    ├── save_to_resource(path)      # 从内存保存到文件（保存全部变量）
    └── [新增] save_persistent_to_resource(path)  # 仅保存持久化变量
```

### 指令与 Assistant / Manager 的分工

**为什么不能完全通过 Assistant 操作？**

Assistant 的保存方法有局限性：
- `save_current_resource()` — 只能保存到 `resource_path`，不支持自定义路径
- `save_persistent_variables()` — 同上，且无"仅持久化变量"过滤逻辑

Manager 的方法更灵活：
- `save_to_resource(path)` / `load_from_resource(path)` — 接受任意路径参数

**实际策略：路径从 Assistant 获取，操作由 Manager 执行**

| 步骤 | 职责 | 说明 |
|------|------|------|
| 获取 Assistant 实例 | Assistant | 获取场景中用户配置的节点 |
| 获取资源路径 | Assistant | ASSISTANT_RESOURCE 模式下从 `resource_path` 读取 |
| 执行加载/保存 | Manager | 调用 `load_from_resource()` / `save_to_resource()` / `save_persistent_to_resource()` |

Assistant 的角色是**配置入口**，提供资源路径；Manager 的角色是**执行引擎**，完成实际的 I/O 操作。

### 重要行为说明

**加载操作的破坏性：** `GlobalVariableManager.load_from_resource()` 内部会**清空所有内存中的全局变量**再重新加载。运行时通过其他指令动态创建的、不在资源文件中的全局变量将丢失。指令描述和日志需明确说明此行为。

**空实例陷阱：** `GlobalVariableAssistant.get_instance()` 在场景中无 Assistant 节点时，会创建一个**无 `resource_path` 的空实例**。指令必须检查 `resource_path.is_empty()` 而非仅检查实例非 null。

### 参考：CreateVariable 的 Assistant 检测模式

`CreateVariable` 指令已实现 `detected_assistant` + `_detect_and_validate_assistant()` 模式（9 个现有指令引用了此模式）。本方案的两个指令应遵循相同模式：

```gdscript
# 1. 声明实例变量
var detected_assistant: GlobalVariableAssistant = null

# 2. 检测并验证（execute 中调用）
func _detect_and_validate_assistant() -> bool:
    detected_assistant = GlobalVariableAssistant.get_instance()
    if detected_assistant == null:
        # 报错...
        return false
    if detected_assistant.resource_path.is_empty():
        # 报错：资源路径未配置...
        return false
    return true

# 3. reset() 中清理
func reset():
    super.reset()
    detected_assistant = null
```

## 实现方案

### Phase 0：Manager 层新增方法

在 `GlobalVariableManager` 中新增 `save_persistent_to_resource(path)` 方法，与现有 `save_to_resource()` 并列，保持保存逻辑统一。

**文件：** `addons/bricks/core/global_variable_manager.gd`

```gdscript
## 仅保存持久化变量到资源文件
func save_persistent_to_resource(path: String) -> bool:
    if path.is_empty():
        _log_error("资源路径不能为空")
        return false

    var resource = GlobalVariableResource.new()
    resource.description = "全局变量存储（仅持久化）"

    _mutex.lock()
    var persistent_count = 0
    for name in _variables:
        var variable = _variables[name]
        if variable.persistent:
            var var_data = {
                "value": variable.value,
                "scope": variable.scope,
                "persistent": true,
                "description": variable.description
            }
            resource.add_variable(name, var_data)
            persistent_count += 1
    _mutex.unlock()

    if persistent_count == 0:
        _log_info("没有持久化变量需要保存")
        # 仍保存空资源，保持文件存在
        pass

    var error = ResourceSaver.save(resource, path)
    if error != OK:
        _log_error("资源保存失败: %s (错误码: %d)" % [path, error])
        return false

    _log_info("持久化变量保存成功: %s (保存了 %d 个变量)" % [path, persistent_count])
    return true
```

**设计理由：** 统一由 Manager 负责所有持久化操作，避免 SaveGlobalVariables 指令直接使用 `ResourceSaver.save()` 导致路径不一致。

### Phase 1：LoadGlobalVariables 指令

**文件：** `addons/bricks/instructions/variables/load_global_variables.gd`
**类名：** `LoadGlobalVariables`

**导出属性：**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `load_source` | enum | `ASSISTANT_RESOURCE` | 加载来源：助手资源 / 自定义路径 |
| `custom_path` | String | `""` | 自定义资源路径（load_source == CUSTOM_PATH 时使用） |

> **v1 修订：移除了 `clear_existing` 属性。** `load_from_resource()` 内部硬编码了清空操作，该属性无法生效。

**枚举定义：**
```gdscript
enum LoadSource {
    ASSISTANT_RESOURCE,  # 使用 Assistant 配置的资源路径
    CUSTOM_PATH          # 使用自定义路径
}
```

**执行逻辑：**
1. 调用 `_detect_and_validate_assistant()` 获取并验证 Assistant 实例
2. 根据加载来源确定路径：
   - `ASSISTANT_RESOURCE` → `detected_assistant.resource_path`
   - `CUSTOM_PATH` → `custom_path`（额外验证非空）
3. 通过 Manager 执行加载：`GlobalVariableManager.get_instance().load_from_resource(resolved_path)`
4. 加载成功：记录加载的变量数量
5. 加载失败：设置错误并记录日志

**资源名称格式：**
- `加载全局变量 [助手资源]`
- `加载全局变量 [自定义路径] 'res://...'`

### Phase 2：SaveGlobalVariables 指令

**文件：** `addons/bricks/instructions/variables/save_global_variables.gd`
**类名：** `SaveGlobalVariables`

**导出属性：**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `save_target` | enum | `ASSISTANT_RESOURCE` | 保存目标：助手资源 / 自定义路径 |
| `custom_path` | String | `""` | 自定义资源路径（save_target == CUSTOM_PATH 时使用） |
| `save_scope` | enum | `ALL` | 保存范围：所有变量 / 仅持久化变量 |

**枚举定义：**
```gdscript
enum SaveTarget {
    ASSISTANT_RESOURCE,  # 保存到 Assistant 配置的资源路径
    CUSTOM_PATH          # 保存到自定义路径
}

enum SaveScope {
    ALL,                 # 保存所有变量
    PERSISTENT_ONLY      # 仅保存持久化变量
}
```

**执行逻辑：**

> **v1 修订：统一通过 Manager 执行保存操作（详见"指令与 Assistant / Manager 的分工"章节）。**

1. 调用 `_detect_and_validate_assistant()` 获取并验证 Assistant 实例
2. 根据保存目标确定路径：
   - `ASSISTANT_RESOURCE` → `detected_assistant.resource_path`
   - `CUSTOM_PATH` → `custom_path`（额外验证非空）
3. 根据保存范围调用 Manager 方法：
   - `ALL` → `GlobalVariableManager.get_instance().save_to_resource(resolved_path)`
   - `PERSISTENT_ONLY` → `GlobalVariableManager.get_instance().save_persistent_to_resource(resolved_path)`
4. 保存成功：记录保存的变量数量
5. 保存失败：设置错误并记录日志

**资源名称格式：**
- `保存全局变量 [助手资源] [全部]`
- `保存全局变量 [自定义路径] 'res://...' [仅持久化]`

## 本地化键

需要添加到 `addons/bricks/localization/translations.csv`：

> **v1 修订：合并冗余键，两个指令共享来源/目标的枚举标签。**

### 指令名称与描述

| 键 | 中文 | English |
|----|------|---------|
| `BRICKS_INSTRUCTION_LOAD_GLOBAL_VARIABLES_NAME` | 加载全局变量 | Load Global Variables |
| `BRICKS_INSTRUCTION_LOAD_GLOBAL_VARIABLES_DESC` | 从资源文件加载全局变量到内存（注意：会清空当前所有内存中的全局变量） | Load global variables from a resource file (Warning: clears all in-memory global variables) |
| `BRICKS_INSTRUCTION_LOAD_GLOBAL_VARIABLES_RESOURCE` | 加载全局变量 | Load Global Variables |
| `BRICKS_INSTRUCTION_SAVE_GLOBAL_VARIABLES_NAME` | 保存全局变量 | Save Global Variables |
| `BRICKS_INSTRUCTION_SAVE_GLOBAL_VARIABLES_DESC` | 将内存中的全局变量保存到资源文件，支持保存全部变量或仅持久化变量 | Save global variables from memory to a resource file |
| `BRICKS_INSTRUCTION_SAVE_GLOBAL_VARIABLES_RESOURCE` | 保存全局变量 | Save Global Variables |

### 共享枚举标签（两个指令复用）

| 键 | 中文 | English |
|----|------|---------|
| `BRICKS_GLOBAL_VARS_TARGET_ASSISTANT` | 助手资源 | Assistant Resource |
| `BRICKS_GLOBAL_VARS_TARGET_CUSTOM` | 自定义路径 | Custom Path |
| `BRICKS_GLOBAL_VARS_SCOPE_ALL` | 全部变量 | All Variables |
| `BRICKS_GLOBAL_VARS_SCOPE_PERSISTENT` | 仅持久化 | Persistent Only |

### 资源名称标签

| 键 | 中文 | English |
|----|------|---------|
| `BRICKS_GLOBAL_VARS_LOAD_FROM` | 从{source}加载 | Load from {source} |
| `BRICKS_GLOBAL_VARS_SAVE_TO` | 保存到{target} | Save to {target} |

### 日志

| 键 | 中文 | English |
|----|------|---------|
| `BRICKS_LOG_GLOBAL_VARS_LOADED` | 全局变量加载成功，共{count}个变量 | Global variables loaded, {count} variables |
| `BRICKS_LOG_GLOBAL_VARS_SAVED` | 全局变量保存成功，共{count}个变量 | Global variables saved, {count} variables |
| `BRICKS_LOG_GLOBAL_VARS_PERSISTENT_SAVED` | 持久化变量保存成功，共{count}个变量 | Persistent variables saved, {count} variables |

### 错误（复用已有键）

| 键 | 状态 |
|----|------|
| `BRICKS_ERROR_ASSISTANT_NOT_FOUND` | 已存在（create_variable 使用） |
| `BRICKS_ERROR_ASSISTANT_NO_RESOURCE` | 已存在（create_variable 使用） |
| `BRICKS_ERROR_RESOURCE_PATH_EMPTY` | 已存在（global_variable_assistant 使用） |

> 无需新增错误键，复用已有的即可。

## 实现阶段

### Phase 0：Manager 层扩展（前置依赖）
1. 在 `global_variable_manager.gd` 中新增 `save_persistent_to_resource(path)` 方法
2. 与现有 `save_to_resource()` 保持一致的代码风格和日志格式

### Phase 1：LoadGlobalVariables 指令
1. 创建 `addons/bricks/instructions/variables/load_global_variables.gd`
2. 实现完整的指令逻辑：
   - `_get_instruction_metadata()` 静态元数据
   - `_get_property_list()` + `_validate_property()` 条件属性
   - `_detect_and_validate_assistant()` Assistant 检测
   - `execute()` 执行逻辑
   - `_update_resource_name()` / `validate()` / `get_description()` 必需方法
   - `reset()` / `_cleanup_resources()` 生命周期
   - 统一日志方法
3. 添加本地化键到 `translations.csv`

### Phase 2：SaveGlobalVariables 指令
1. 创建 `addons/bricks/instructions/variables/save_global_variables.gd`
2. 实现完整的指令逻辑（与 Phase 1 结构相同）
3. 添加本地化键到 `translations.csv`

### Phase 3：自动保存机制优化
1. `_save_persistent_variables()` 改用 `manager.save_persistent_to_resource(resource_path)` — 名实相符，仅保存持久化变量
2. `auto_save_on_change` 默认值改为 `false` — 让显式保存指令成为游戏状态管理的主角
3. 保留 `auto_save`（退出/窗口关闭时保存）作为安全网

### Phase 4：验证
1. 运行 `/gdscript-validate` 验证所有修改的脚本
2. 在编辑器中验证 Inspector 显示和属性条件化
3. 确认指令选择器能正确显示新指令

## 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `addons/bricks/core/global_variable_manager.gd` | 修改 | 新增 `save_persistent_to_resource()` 方法 |
| `addons/bricks/core/global_variable_assistant.gd` | 修改 | 自动保存改用 `save_persistent_to_resource()`；`auto_save_on_change` 默认值改为 `false` |
| `addons/bricks/instructions/variables/load_global_variables.gd` | 新建 | LoadGlobalVariables 指令 |
| `addons/bricks/instructions/variables/save_global_variables.gd` | 新建 | SaveGlobalVariables 指令 |
| `addons/bricks/localization/translations.csv` | 修改 | 追加约 14 个翻译键 |

## 风险评估

| 风险 | 级别 | 缓解措施 |
|------|------|----------|
| GlobalVariableAssistant 空实例 | MEDIUM | 检查 `resource_path.is_empty()`，不仅检查非 null |
| 加载破坏性（清空变量） | MEDIUM | 在指令描述和日志中明确警告 |
| 资源路径无效 | MEDIUM | 完整的路径验证和错误提示 |
| 加载/保存 I/O 失败 | LOW | 使用 Godot ResourceSaver/ResourceLoader 内置错误处理 |
| 线程安全 | LOW | 指令在主线程执行，Manager 内部已有 Mutex |

## 复杂度评估

**整体复杂度：LOW**
- 两个指令均为简单的同步指令
- 核心逻辑委托给 GlobalVariableManager 的 API
- Manager 层新增方法与现有 `save_to_resource()` 结构一致
- 属性条件化遵循现有 CreateVariable / SetVariable 的模式
